import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';

/// Web requests for Felgalizacija online, through the browser's `fetch`.
class BrowserJsonHttp implements JsonHttp {
  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final init = web.RequestInit(
      method: method,
      headers: headers.jsify() as JSObject,
      body: body?.toJS,
    );
    final response = await web.window.fetch(url.toString().toJS, init).toDart;
    final text = (await response.text().toDart).toDart;
    return HttpReply(response.status, text);
  }
}

/// Reads `online.json` next to the page. Null (nothing online: every
/// Felgalizacija stays on its phone) when the file is missing, empty or unfinished. It is
/// always checked with the server, so a change to the file shows up at once and
/// not after the browser's saved copy expires.
Future<OnlineConfig?> loadOnlineConfig() async {
  try {
    final response =
        await web.window.fetch('online.json'.toJS, web.RequestInit(cache: 'no-cache')).toDart;
    if (!response.ok) return null;
    final text = (await response.text().toDart).toDart;
    return OnlineConfig.tryParse(text);
  } on Object {
    return null;
  }
}

/// The online place as read at the start (null: none) and this phone's one
/// sign-in.
OnlineConfig? _config;
FirebaseSession? _session;
StorageService? _storage;

/// Reads where Felgalizacije are shared (`online.json`), at the start.
Future<void> setUpOnline(StorageService storage) async {
  _storage = storage;
  final config = _config = await loadOnlineConfig();
  if (config != null) _session = FirebaseSession(config, BrowserJsonHttp(), storage);
}

/// Where Felgalizacije are shared: the Firebase of `online.json` - but on
/// this computer (localhost, trying the app out) a stand-in kept in this
/// browser, so trying it never writes to the real one. Null without either.
FelgaRemote? felgaRemote() {
  final host = web.window.location.hostname;
  if (host == 'localhost' || host == '127.0.0.1') {
    String uid;
    try {
      // One "phone" per tab: two tabs can try joining each other.
      uid = web.window.sessionStorage.getItem('dartle.felga-test-uid') ??
          'tab-${DateTime.now().microsecondsSinceEpoch}';
      web.window.sessionStorage.setItem('dartle.felga-test-uid', uid);
    } on Object {
      uid = 'tab';
    }
    return StorageFelgaRemote(_storage ?? InMemoryStorageService(), uid: uid);
  }
  final config = _config, session = _session;
  if (config == null || session == null) return null;
  return FirebaseFelgaRemote(config: config, http: BrowserJsonHttp(), session: session);
}
