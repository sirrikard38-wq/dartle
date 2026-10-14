import 'dart:convert';

import '../storage/storage_service.dart';
import 'leaderboard_service.dart';

/// One answer to a web request.
class HttpReply {
  const HttpReply(this.status, this.body);

  final int status;
  final String body;

  bool get ok => status >= 200 && status < 300;
}

/// The only thing the online leaderboard needs from the web: send a request,
/// get the answer. The browser version is in `lib/ui/online_setup.dart`; tests
/// use a fake.
abstract interface class JsonHttp {
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  });
}

/// Something went wrong talking to the online board.
class OnlineException implements Exception {
  const OnlineException(this.message);

  final String message;

  @override
  String toString() => 'OnlineException: $message';
}

/// Where the shared leaderboard lives: a Firebase Realtime Database. Read from
/// `web/online.json`; without it (or with it unfinished) the leaderboard simply
/// stays on this device. See docs/online-leaderboard.md for the setup.
class OnlineConfig {
  const OnlineConfig({
    required this.databaseUrl,
    required this.apiKey,
    this.authBase = defaultAuthBase,
    this.tokenBase = defaultTokenBase,
  });

  static const String defaultAuthBase = 'https://identitytoolkit.googleapis.com';
  static const String defaultTokenBase = 'https://securetoken.googleapis.com';

  /// e.g. `https://dartle-default-rtdb.firebaseio.com` (no trailing slash).
  final String databaseUrl;

  /// The Firebase web API key. It is not a secret: it only says which project
  /// the sign-in belongs to. The database rules are what protect the data.
  final String apiKey;

  /// Where anonymous sign-in and token refresh go (only changed in tests).
  final String authBase;
  final String tokenBase;

  /// Reads `online.json`. Null when it is empty, unfinished or not valid, which
  /// means "no online leaderboard".
  static OnlineConfig? tryParse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      var url = ((json['databaseUrl'] as String?) ?? '').trim();
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      final key = ((json['apiKey'] as String?) ?? '').trim();
      if (url.isEmpty || key.isEmpty) return null;
      final secure = url.startsWith('https://');
      final local = url.startsWith('http://localhost') || url.startsWith('http://127.0.0.1');
      if (!secure && !local) return null;
      return OnlineConfig(
        databaseUrl: url,
        apiKey: key,
        authBase: (json['authBase'] as String?) ?? defaultAuthBase,
        tokenBase: (json['tokenBase'] as String?) ?? defaultTokenBase,
      );
    } on Object {
      return null;
    }
  }
}

/// The player's anonymous Firebase sign-in: no password, no account to make.
/// The first time, Firebase hands out an id; it is kept on the device and the
/// short-lived token that goes with it is renewed when it runs out. The
/// database rules only let a player write the entry under their own id.
class FirebaseSession {
  FirebaseSession(this._config, this._http, this._storage, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const String storageKey = 'dartle.online.session.v1';

  final OnlineConfig _config;
  final JsonHttp _http;
  final StorageService _storage;
  final DateTime Function() _now;

  bool _loaded = false;
  String? _id;
  String? _refreshToken;
  String? _token;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  /// The saved id (null before the first sign-in).
  Future<String?> knownId() async {
    await _load();
    return _id;
  }

  /// A valid token and the id it belongs to, signing in or renewing as needed.
  Future<({String id, String token})> signedIn() async {
    await _load();
    final token = _token;
    final id = _id;
    if (token != null && id != null && _now().isBefore(_expires.subtract(const Duration(minutes: 1)))) {
      return (id: id, token: token);
    }
    if (_refreshToken != null && await _renew()) {
      return (id: _id!, token: _token!);
    }
    await _signUp();
    return (id: _id!, token: _token!);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _storage.read(storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, Object?>;
      _id = json['id'] as String?;
      _refreshToken = json['refreshToken'] as String?;
    } on Object {
      _id = null;
      _refreshToken = null;
    }
  }

  Future<void> _save() => _storage.write(
      storageKey, jsonEncode({'id': _id, 'refreshToken': _refreshToken}));

  /// Gets a new token with the saved refresh token. False when Firebase says
  /// the sign-in no longer exists (then a new one is made); anything else wrong
  /// (no connection, a server error) is an error, so a hiccup never makes a
  /// second player of the same person.
  Future<bool> _renew() async {
    final reply = await _http.send(
      'POST',
      Uri.parse('${_config.tokenBase}/v1/token').replace(queryParameters: {'key': _config.apiKey}),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(_refreshToken!)}',
    );
    if (reply.status == 400 || reply.status == 401) {
      _refreshToken = null;
      return false;
    }
    if (!reply.ok) throw OnlineException('token renewal failed (${reply.status})');
    final json = jsonDecode(reply.body) as Map<String, Object?>;
    _take(
      id: (json['user_id'] as String?) ?? _id,
      token: json['id_token'] as String?,
      refreshToken: (json['refresh_token'] as String?) ?? _refreshToken,
      expiresInSeconds: json['expires_in'],
    );
    await _save();
    return true;
  }

  Future<void> _signUp() async {
    final reply = await _http.send(
      'POST',
      Uri.parse('${_config.authBase}/v1/accounts:signUp').replace(queryParameters: {'key': _config.apiKey}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'returnSecureToken': true}),
    );
    if (!reply.ok) throw OnlineException('sign-in failed (${reply.status})');
    final json = jsonDecode(reply.body) as Map<String, Object?>;
    _take(
      id: json['localId'] as String?,
      token: json['idToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresInSeconds: json['expiresIn'],
    );
    await _save();
  }

  void _take({
    required String? id,
    required String? token,
    required String? refreshToken,
    required Object? expiresInSeconds,
  }) {
    if (id == null || token == null || refreshToken == null) {
      throw const OnlineException('sign-in answer is incomplete');
    }
    _id = id;
    _token = token;
    _refreshToken = refreshToken;
    final seconds = int.tryParse('$expiresInSeconds') ?? 3600;
    _expires = _now().add(Duration(seconds: seconds));
  }
}

/// The shared leaderboard: everyone who plays Dartle, in a Firebase Realtime
/// Database under `/leaderboard/<player id>`.
///
///  * Reading needs no sign-in. If the board cannot be reached, the scores on
///    this device (and the sample players) are shown instead.
///  * Every submit also keeps the local copy and then tries the online board;
///    a failed upload is quietly retried with the next result, because every
///    submit carries the player's whole totals.
class OnlineLeaderboardRepository implements LeaderboardRepository {
  OnlineLeaderboardRepository({
    required OnlineConfig config,
    required JsonHttp http,
    required StorageService storage,
    required LeaderboardRepository local,
    DateTime Function()? now,
    this.maxEntries = 500,
    this.requestTimeout = const Duration(seconds: 6),
  })  : _config = config,
        _http = http,
        _local = local,
        _session = FirebaseSession(config, http, storage, now: now);

  /// The most players loaded (the top ones by points).
  final int maxEntries;

  /// How long to wait for the online board before giving up and showing this
  /// device's scores (and before skipping an upload until the next result).
  final Duration requestTimeout;

  static const String path = 'leaderboard';
  static const int maxNameLength = 20;

  final OnlineConfig _config;
  final JsonHttp _http;
  final LeaderboardRepository _local;
  final FirebaseSession _session;

  bool _online = false;
  String? _playerId;

  @override
  bool get isOnline => _online;

  @override
  String? get playerId => _playerId;

  @override
  Future<List<LeaderboardEntry>> fetchEntries() async {
    try {
      final reply = await _http
          .send(
            'GET',
            Uri.parse('${_config.databaseUrl}/$path.json').replace(queryParameters: {
              'orderBy': '"totalPoints"',
              'limitToLast': '$maxEntries',
            }),
          )
          .timeout(requestTimeout);
      if (!reply.ok) throw OnlineException('leaderboard answered ${reply.status}');
      final decoded = jsonDecode(reply.body); // null when nobody has played yet
      final entries = <LeaderboardEntry>[];
      if (decoded is Map) {
        decoded.forEach((id, value) {
          final entry = _parse('$id', value);
          if (entry != null) entries.add(entry);
        });
      }
      _playerId = await _session.knownId();
      _online = true;
      return entries;
    } on Object {
      _online = false;
      return _local.fetchEntries();
    }
  }

  @override
  Future<void> submit(LeaderboardEntry entry) async {
    await _local.submit(entry);
    try {
      // Signing in and uploading together get one time limit each.
      final session = await _session.signedIn().timeout(requestTimeout);
      final reply = await _http
          .send(
            'PUT',
            Uri.parse('${_config.databaseUrl}/$path/${session.id}.json')
                .replace(queryParameters: {'auth': session.token}),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_payload(entry)),
          )
          .timeout(requestTimeout);
      if (reply.ok) _playerId = session.id;
    } on Object {
      // No connection, or the board is down: the next result sends it again.
    }
  }

  /// What is stored for a player: no id (the id is the key), no empty values.
  Map<String, Object?> _payload(LeaderboardEntry e) {
    final name = e.playerName.length > maxNameLength
        ? e.playerName.substring(0, maxNameLength)
        : e.playerName;
    return {
      'playerName': name,
      'totalPoints': e.totalPoints < 0 ? 0 : e.totalPoints,
      if (e.averageTimeMs != null) 'averageTimeMs': e.averageTimeMs,
      'accuracyPercent': e.accuracyPercent,
      'optimalPercent': e.optimalPercent,
      'attempts': e.attempts,
    };
  }

  /// One row of the board; anything malformed is skipped, never fatal.
  LeaderboardEntry? _parse(String id, Object? value) {
    if (value is! Map) return null;
    try {
      final json = value.cast<String, Object?>();
      final entry = LeaderboardEntry.fromJson({...json, 'id': id});
      if (entry.playerName.trim().isEmpty) return null;
      return entry;
    } on Object {
      return null;
    }
  }
}
