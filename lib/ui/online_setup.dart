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

/// The leaderboard for this device: the shared online one when `online.json`
/// is filled in, otherwise just the scores on this device.
Future<LeaderboardRepository?> buildLeaderboard(StorageService storage) async {
  final config = await loadOnlineConfig();
  if (config == null) return null;
  return OnlineLeaderboardRepository(
    config: config,
    http: BrowserJsonHttp(),
    storage: storage,
    local: LocalLeaderboardRepository(storage),
  );
}
