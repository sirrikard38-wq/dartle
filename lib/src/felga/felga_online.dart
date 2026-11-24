import 'dart:convert';

import '../online/firebase.dart';
import '../storage/storage_service.dart';
import 'felga_ledger.dart';

/// Where a Felgalizacija is kept online: its password, hashed (SHA-256), so
/// the place says nothing of the password and only who knows the password
/// finds it. Nobody can list the places (see firebase/database.rules.json).
String felgaKey(String password) => sha256Hex(utf8.encode('dartle-felga:$password'));

/// A Felgalizacija as it is online: its name, its book ([FelgaLedger.toJson])
/// and how many times it was written ([rev]: each write is the one before + 1,
/// so a phone that writes over a newer one is refused).
class RemoteFelga {
  const RemoteFelga(this.name, this.book, this.rev);

  final String name;
  final String book;
  final int rev;
}

/// The place online the Felgalizacije are shared through.
abstract interface class FelgaRemote {
  /// This device's account (signing in the first time).
  Future<String> me();

  /// The Felgalizacija with [password]; null when there is none.
  Future<RemoteFelga?> fetch(String password);

  /// Writes [next] (its [RemoteFelga.rev] one more than what is there, 1 for a
  /// new one). False when it is refused: another phone was quicker (or the
  /// online place is not set up for it).
  Future<bool> push(String password, RemoteFelga next);
}

/// What one phone has of a Felgalizacija: its name and book now, and what
/// they were when it last matched the one online ([rev], [baseName],
/// [baseBook]; rev 0: never online yet).
class FelgaCopy {
  const FelgaCopy({required this.name, required this.book, this.rev = 0, this.baseName, this.baseBook});

  final String name;
  final String book;
  final int rev;
  final String? baseName;
  final String? baseBook;

  /// Something changed here that is not online yet.
  bool get changed => rev == 0 || name != baseName || book != baseBook;

  FelgaCopy withNow({String? name, String? book}) =>
      FelgaCopy(name: name ?? this.name, book: book ?? this.book, rev: rev, baseName: baseName, baseBook: baseBook);

  /// This phone's book and name written online as [rev].
  FelgaCopy sentAs(int rev) => FelgaCopy(name: name, book: book, rev: rev, baseName: name, baseBook: book);

  /// [theirs] taken in: what changed here since the last match put on top of it.
  FelgaCopy on(RemoteFelga theirs) {
    final base = baseBook;
    final String book;
    if (rev == 0 || base == null) {
      book = theirs.book; // nothing to go by: the one online
    } else if (this.book == base) {
      book = theirs.book;
    } else {
      book = FelgaLedger.merged(FelgaLedger.fromJson(base), FelgaLedger.fromJson(this.book), FelgaLedger.fromJson(theirs.book))
          .toJson();
    }
    return FelgaCopy(
      name: name != baseName && rev != 0 ? name : theirs.name,
      book: book,
      rev: theirs.rev,
      baseName: theirs.name,
      baseBook: theirs.book,
    );
  }

  /// What is kept on the phone besides the name and book.
  String metaJson() => jsonEncode({'rev': rev, 'baseName': baseName, 'baseBook': baseBook});

  static FelgaCopy fromMeta({required String name, required String book, String? meta}) {
    try {
      final json = jsonDecode(meta ?? '') as Map<String, Object?>;
      return FelgaCopy(
        name: name,
        book: book,
        rev: (json['rev'] as num?)?.toInt() ?? 0,
        baseName: json['baseName'] as String?,
        baseBook: json['baseBook'] as String?,
      );
    } on Object {
      return FelgaCopy(name: name, book: book);
    }
  }
}

/// Brings [mine] and the one online together: what is new online comes in,
/// what is new here goes up (put on top of the newest one, never over it).
/// A new one goes online as it is. Throws when the online place cannot be
/// reached; the answer is what this phone should keep.
Future<FelgaCopy> syncFelga(FelgaRemote remote, String password, FelgaCopy mine) async {
  var copy = mine;
  for (var attempt = 0; attempt < 3; attempt++) {
    final theirs = await remote.fetch(password);
    if (theirs == null) {
      if (await remote.push(password, RemoteFelga(copy.name, copy.book, 1))) return copy.sentAs(1);
      return copy; // refused with nothing there: not set up online
    }
    if (theirs.rev != copy.rev) copy = copy.on(theirs);
    if (!copy.changed) return copy;
    final next = theirs.rev + 1;
    if (await remote.push(password, RemoteFelga(copy.name, copy.book, next))) return copy.sentAs(next);
    // Another phone was quicker: once more on top of what it wrote.
  }
  return copy;
}

/// The Felgalizacije in the Firebase Realtime Database, under `/felga/<key>`,
/// written by signed-in phones only.
class FirebaseFelgaRemote implements FelgaRemote {
  FirebaseFelgaRemote({
    required OnlineConfig config,
    required JsonHttp http,
    required FirebaseSession session,
    this.timeout = const Duration(seconds: 8),
  })  : _config = config,
        _http = http,
        _session = session;

  static const String path = 'felga';

  final OnlineConfig _config;
  final JsonHttp _http;
  final FirebaseSession _session;
  final Duration timeout;

  Future<({String id, String token})> _signedIn() => _session.signedIn().timeout(timeout);

  Uri _url(String password, String token) =>
      Uri.parse('${_config.databaseUrl}/$path/${felgaKey(password)}.json').replace(queryParameters: {'auth': token});

  @override
  Future<String> me() async => (await _signedIn()).id;

  @override
  Future<RemoteFelga?> fetch(String password) async {
    final session = await _signedIn();
    final reply = await _http.send('GET', _url(password, session.token)).timeout(timeout);
    if (!reply.ok) throw OnlineException('Felgalizacija answered ${reply.status}');
    final json = jsonDecode(reply.body);
    if (json == null) return null;
    if (json is! Map) throw const OnlineException('Felgalizacija is not readable');
    final name = json['name'], book = json['book'], rev = json['rev'];
    if (name is! String || book is! String || rev is! num) {
      throw const OnlineException('Felgalizacija is not readable');
    }
    return RemoteFelga(name, book, rev.toInt());
  }

  @override
  Future<bool> push(String password, RemoteFelga next) async {
    final session = await _signedIn();
    final reply = await _http
        .send('PUT', _url(password, session.token),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': next.name, 'book': next.book, 'rev': next.rev}))
        .timeout(timeout);
    if (reply.ok) return true;
    if (reply.status == 401 || reply.status == 403) return false;
    throw OnlineException('Felgalizacija answered ${reply.status}');
  }
}

/// The online place played on this device's own storage, with the same rule
/// (each write one more than the one before): for trying the app out locally
/// (and the tests) without touching the real one.
class StorageFelgaRemote implements FelgaRemote {
  StorageFelgaRemote(this._storage, {required this.uid});

  final StorageService _storage;
  final String uid;

  static String keyOf(String password) => 'dartle.felga-test-online.${felgaKey(password)}';

  @override
  Future<String> me() async => uid;

  @override
  Future<RemoteFelga?> fetch(String password) async {
    final raw = await _storage.read(keyOf(password));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, Object?>;
    return RemoteFelga(json['name'] as String, json['book'] as String, (json['rev'] as num).toInt());
  }

  @override
  Future<bool> push(String password, RemoteFelga next) async {
    final now = await fetch(password);
    if (next.rev != (now?.rev ?? 0) + 1) return false;
    await _storage.write(keyOf(password), jsonEncode({'name': next.name, 'book': next.book, 'rev': next.rev}));
    return true;
  }
}

/// SHA-256 of [message], as 64 hex digits (no package needed; kept to 32-bit
/// steps so it gives the same answer compiled to JavaScript).
String sha256Hex(List<int> message) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  const mask = 0xffffffff;
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & mask;

  final bytes = [...message, 0x80];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  final bits = message.length * 8; // under 2^32 bits: the high four bytes are 0
  bytes.addAll([0, 0, 0, 0, (bits >> 24) & 0xff, (bits >> 16) & 0xff, (bits >> 8) & 0xff, bits & 0xff]);

  final h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < bytes.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final at = chunk + i * 4;
      w[i] = ((bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]) & mask;
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((e ^ mask) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & mask;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & mask;
    }
    h[0] = (h[0] + a) & mask;
    h[1] = (h[1] + b) & mask;
    h[2] = (h[2] + c) & mask;
    h[3] = (h[3] + d) & mask;
    h[4] = (h[4] + e) & mask;
    h[5] = (h[5] + f) & mask;
    h[6] = (h[6] + g) & mask;
    h[7] = (h[7] + hh) & mask;
  }
  return [for (final v in h) v.toRadixString(16).padLeft(8, '0')].join();
}
