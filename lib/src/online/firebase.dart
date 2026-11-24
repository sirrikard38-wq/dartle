import 'dart:convert';

import '../storage/storage_service.dart';

/// One answer to a web request.
class HttpReply {
  const HttpReply(this.status, this.body);

  final int status;
  final String body;

  bool get ok => status >= 200 && status < 300;
}

/// The only thing the online part needs from the web: send a request,
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

/// Where the shared Felgalizacije live: a Firebase Realtime Database. Read from
/// `web/online.json`; without it (or with it unfinished) every Felgalizacija
/// simply stays on its phone. See docs/online.md for the setup.
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
  /// means "nothing online".
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
/// short-lived token that goes with it is renewed when it runs out. The id
/// is this phone's account: the names of a Felgalizacija are synced to it.
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
