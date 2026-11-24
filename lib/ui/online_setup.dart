import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';

/// Web requests for the online leaderboard, through the browser's `fetch`.
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

/// Reads `online.json` next to the page. Null (no online leaderboard, scores
/// stay on this device) when the file is missing, empty or unfinished. It is
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

/// The online place as read at the start (null: none), and the one sign-in
/// of this device that the leaderboard and Felgalizacija share - so the two
/// never sign in as two players at once.
OnlineConfig? _config;
FirebaseSession? _session;
StorageService? _storage;

/// The leaderboard for this device: the shared online one when `online.json`
/// is filled in, otherwise just the scores on this device.
Future<LeaderboardRepository?> buildLeaderboard(StorageService storage) async {
  final config = _config = await loadOnlineConfig();
  _storage = storage;
  if (config == null) return null;
  final http = BrowserJsonHttp();
  final session = _session = FirebaseSession(config, http, storage);
  return OnlineLeaderboardRepository(
    config: config,
    http: http,
    storage: storage,
    session: session,
    local: LocalLeaderboardRepository(storage),
  );
}

/// Where Felgalizacije are shared: the Firebase of the leaderboard - but on
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
