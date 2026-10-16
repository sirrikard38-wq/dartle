import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// A stand-in for Firebase: anonymous sign-in, token renewal and a Realtime
/// Database that follows the same rule as firebase/database.rules.json - a
/// signed-in player may only write the row under their own id.
class FakeFirebase implements JsonHttp {
  final List<String> log = [];
  final Map<String, Object?> board = {};

  bool offline = false;
  int? tokenRenewalStatus; // forces an answer to the renewal request
  int signUps = 0;
  int renewals = 0;
  Duration tokenLife = const Duration(hours: 1);
  Uri? lastGet;

  final Map<String, String> _tokenOwner = {};
  final Map<String, String> _refreshOwner = {};
  int _counter = 0;

  /// What the clock-driven tests move forward.
  DateTime now = DateTime(2026, 10, 15, 12);

  String _newToken(String uid) {
    final token = 'token-${_counter++}';
    _tokenOwner[token] = uid;
    return token;
  }

  @override
  Future<HttpReply> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    if (offline) throw const SocketException('no connection');
    log.add('$method ${url.path}');
    final json = (body != null && (headers['Content-Type'] ?? '').contains('json'))
        ? jsonDecode(body) as Map<String, Object?>
        : null;

    if (url.path.endsWith('/v1/accounts:signUp')) {
      expect(url.queryParameters['key'], 'api-key');
      expect(json, {'returnSecureToken': true});
      signUps++;
      final uid = 'uid${signUps}abc';
      final refresh = 'refresh-$uid';
      _refreshOwner[refresh] = uid;
      return HttpReply(
        200,
        jsonEncode({
          'idToken': _newToken(uid),
          'refreshToken': refresh,
          'expiresIn': '${tokenLife.inSeconds}',
          'localId': uid,
        }),
      );
    }

    if (url.path.endsWith('/v1/token')) {
      renewals++;
      if (tokenRenewalStatus != null) return HttpReply(tokenRenewalStatus!, '{}');
      final form = Uri.splitQueryString(body ?? '');
      expect(form['grant_type'], 'refresh_token');
      final uid = _refreshOwner[form['refresh_token']];
      if (uid == null) return const HttpReply(400, '{"error":{"message":"INVALID_REFRESH_TOKEN"}}');
      return HttpReply(
        200,
        jsonEncode({
          'id_token': _newToken(uid),
          'refresh_token': form['refresh_token'],
          'expires_in': '${tokenLife.inSeconds}',
          'user_id': uid,
        }),
      );
    }

    if (method == 'GET' && url.path == '/leaderboard.json') {
      lastGet = url;
      return HttpReply(200, jsonEncode(board.isEmpty ? null : board));
    }

    if (method == 'PUT' && url.path.startsWith('/leaderboard/')) {
      final id = url.path.substring('/leaderboard/'.length).replaceAll('.json', '');
      final owner = _tokenOwner[url.queryParameters['auth']];
      if (owner == null || owner != id) {
        return const HttpReply(401, '{"error":"Permission denied"}'); // the rules
      }
      final entry = json!;
      final name = entry['playerName'];
      if (name is! String || name.isEmpty || name.length > 20) {
        return const HttpReply(400, '{"error":"Permission denied"}'); // the rules
      }
      board[id] = entry;
      return HttpReply(200, body!);
    }
    return const HttpReply(404, 'null');
  }
}

LeaderboardEntry entry(String name, int points, {int attempts = 4, int? ms = 5000}) =>
    LeaderboardEntry(
      playerName: name,
      totalPoints: points,
      averageTimeMs: ms,
      accuracyPercent: 75,
      optimalPercent: 50,
      attempts: attempts,
    );

void main() {
  late FakeFirebase firebase;
  late InMemoryStorageService storage;
  late LocalLeaderboardRepository local;
  const config = OnlineConfig(databaseUrl: 'https://dartle-default-rtdb.firebaseio.com', apiKey: 'api-key');

  OnlineLeaderboardRepository repo() => OnlineLeaderboardRepository(
        config: config,
        http: firebase,
        storage: storage,
        local: local,
        now: () => firebase.now,
      );

  setUp(() {
    firebase = FakeFirebase();
    storage = InMemoryStorageService();
    local = LocalLeaderboardRepository(InMemoryStorageService());
  });

  group('OnlineConfig', () {
    test('reads the database address and API key, and drops a trailing slash', () {
      final c = OnlineConfig.tryParse(
          '{"databaseUrl": "https://dartle-default-rtdb.firebaseio.com/", "apiKey": " abc "}')!;
      expect(c.databaseUrl, 'https://dartle-default-rtdb.firebaseio.com');
      expect(c.apiKey, 'abc');
      expect(c.authBase, OnlineConfig.defaultAuthBase);
      expect(c.tokenBase, OnlineConfig.defaultTokenBase);
    });

    test('works with the regional addresses Firebase uses', () {
      final c = OnlineConfig.tryParse(
          '{"databaseUrl": "https://dartle-default-rtdb.europe-west1.firebasedatabase.app", "apiKey": "k"}');
      expect(c, isNotNull);
    });

    test('an empty or unfinished file means "no online leaderboard"', () {
      for (final text in [
        '{"databaseUrl": "", "apiKey": ""}',
        '{"databaseUrl": "https://x.firebaseio.com", "apiKey": ""}',
        '{"databaseUrl": "", "apiKey": "k"}',
        '{}',
        '[]',
        'not json',
        '',
      ]) {
        expect(OnlineConfig.tryParse(text), isNull, reason: text);
      }
    });

    test('only a secure address is accepted (or localhost, for testing)', () {
      expect(OnlineConfig.tryParse('{"databaseUrl": "http://example.com", "apiKey": "k"}'), isNull);
      expect(OnlineConfig.tryParse('{"databaseUrl": "http://localhost:9000", "apiKey": "k"}'), isNotNull);
      expect(OnlineConfig.tryParse('{"databaseUrl": "https://x.firebaseio.com", "apiKey": "k"}'), isNotNull);
    });

    test('the file shipped in web/ is a valid config, or empty for a board on this device', () {
      final shipped = File('web/online.json').readAsStringSync();
      expect(jsonDecode(shipped), isA<Map<String, Object?>>());
      // Filled in (a real board) or empty (this device only): both are valid files.
      final parsed = OnlineConfig.tryParse(shipped);
      if (parsed != null) {
        expect(parsed.databaseUrl, startsWith('https://'));
        expect(parsed.apiKey, isNotEmpty);
      }
    });
  });

  group('FirebaseSession (anonymous sign-in)', () {
    FirebaseSession session() =>
        FirebaseSession(config, firebase, storage, now: () => firebase.now);

    test('signs in once, then reuses the token with no more requests', () async {
      final s = session();
      final first = await s.signedIn();
      final second = await s.signedIn();
      expect(first.id, 'uid1abc');
      expect(second.token, first.token);
      expect(firebase.signUps, 1);
      expect(firebase.log, hasLength(1));
    });

    test('renews the token when it runs out, keeping the same player', () async {
      final s = session();
      final first = await s.signedIn();
      firebase.now = firebase.now.add(const Duration(hours: 2));
      final later = await s.signedIn();
      expect(later.id, first.id, reason: 'still the same player');
      expect(later.token, isNot(first.token));
      expect(firebase.signUps, 1);
      expect(firebase.renewals, 1);
    });

    test('renews a minute before the token expires', () async {
      final s = session();
      final first = await s.signedIn();
      firebase.now = firebase.now.add(const Duration(minutes: 59, seconds: 30));
      expect((await s.signedIn()).token, isNot(first.token));
    });

    test('remembers the player on the device: no new sign-in after a restart', () async {
      final first = await session().signedIn();
      final restarted = await session().signedIn();
      expect(restarted.id, first.id);
      expect(firebase.signUps, 1);
      expect(firebase.renewals, 1, reason: 'a fresh start renews with the saved key');
    });

    test('knownId needs no network', () async {
      expect(await session().knownId(), isNull);
      await session().signedIn();
      firebase.offline = true;
      expect(await session().knownId(), 'uid1abc');
    });

    test('a sign-in Firebase no longer knows is replaced by a new one', () async {
      await session().signedIn();
      await storage.write(FirebaseSession.storageKey,
          jsonEncode({'id': 'uid1abc', 'refreshToken': 'refresh-that-is-gone'}));
      final again = await session().signedIn();
      expect(again.id, 'uid2abc');
      expect(firebase.signUps, 2);
    });

    test('a server hiccup while renewing never makes a second player', () async {
      await session().signedIn();
      firebase.tokenRenewalStatus = 500;
      await expectLater(session().signedIn(), throwsA(isA<OnlineException>()));
      expect(firebase.signUps, 1);
    });

    test('no connection is an error, not a new player', () async {
      firebase.offline = true;
      await expectLater(session().signedIn(), throwsA(anything));
    });
  });

  group('OnlineLeaderboardRepository', () {
    test('an empty board is online and empty - no sample players', () async {
      final r = repo();
      expect(await r.fetchEntries(), isEmpty);
      expect(r.isOnline, isTrue);
    });

    test('reads the top players by points, with their ids', () async {
      firebase.board['p1'] = {
        'playerName': 'Alice', 'totalPoints': 30, 'averageTimeMs': 4100,
        'accuracyPercent': 80.5, 'optimalPercent': 60, 'attempts': 12,
      };
      firebase.board['p2'] = {
        'playerName': 'Bob', 'totalPoints': 55, 'accuracyPercent': 60,
        'optimalPercent': 20.0, 'attempts': 9, // no average time yet
      };
      final r = repo();
      final entries = await r.fetchEntries();
      expect(entries.map((e) => e.id), unorderedEquals(['p1', 'p2']));
      final alice = entries.firstWhere((e) => e.id == 'p1');
      expect(alice.playerName, 'Alice');
      expect(alice.totalPoints, 30);
      expect(alice.averageTimeMs, 4100);
      expect(alice.accuracyPercent, 80.5);
      expect(entries.firstWhere((e) => e.id == 'p2').averageTimeMs, isNull);
      expect(firebase.lastGet!.queryParameters['orderBy'], '"totalPoints"');
      expect(firebase.lastGet!.queryParameters['limitToLast'], '180');
      expect(r.isOnline, isTrue);
    });

    test('the board has the top 180 players, the best by points', () async {
      expect(OnlineLeaderboardRepository.topPlayers, 180);
      for (var i = 1; i <= 200; i++) {
        firebase.board['p$i'] = {
          'playerName': 'Player $i', 'totalPoints': i, 'accuracyPercent': 50,
          'optimalPercent': 50, 'attempts': 4,
        };
      }
      final entries = await repo().fetchEntries();
      expect(entries, hasLength(180));
      expect(entries.map((e) => e.totalPoints).reduce((a, b) => a < b ? a : b), 21,
          reason: 'the 20 lowest of 200 players are cut');
      expect(entries.map((e) => e.totalPoints).reduce((a, b) => a > b ? a : b), 200);
    });

    test('fewer than 180 players: all of them are there', () async {
      for (var i = 1; i <= 50; i++) {
        firebase.board['p$i'] = {
          'playerName': 'Player $i', 'totalPoints': i, 'accuracyPercent': 50,
          'optimalPercent': 50, 'attempts': 4,
        };
      }
      expect(await repo().fetchEntries(), hasLength(50));
    });

    test('numbers that come back as 12.0 are still whole numbers', () async {
      firebase.board['p1'] = {
        'playerName': 'A', 'totalPoints': 12.0, 'accuracyPercent': 50,
        'optimalPercent': 50, 'attempts': 3.0,
      };
      final e = (await repo().fetchEntries()).single;
      expect(e.totalPoints, 12);
      expect(e.attempts, 3);
    });

    test('a damaged row is skipped, never fatal', () async {
      firebase.board['good'] = {
        'playerName': 'Fine', 'totalPoints': 5, 'accuracyPercent': 1,
        'optimalPercent': 1, 'attempts': 1,
      };
      firebase.board['junk'] = 'not a map';
      firebase.board['noName'] = {'totalPoints': 5};
      firebase.board['blank'] = {
        'playerName': '  ', 'totalPoints': 5, 'accuracyPercent': 1,
        'optimalPercent': 1, 'attempts': 1,
      };
      expect((await repo().fetchEntries()).map((e) => e.id), ['good']);
    });

    test('no connection: this device\'s scores, offline', () async {
      await local.submit(entry('Me', 40));
      firebase.offline = true;
      final r = repo();
      final entries = await r.fetchEntries();
      expect(r.isOnline, isFalse);
      expect(entries.map((e) => e.playerName), ['Me'], reason: 'no sample players');
    });

    test('a server error also falls back to this device', () async {
      final bad = _AlwaysStatus(503);
      final r = OnlineLeaderboardRepository(
          config: config, http: bad, storage: storage, local: local);
      await r.fetchEntries();
      expect(r.isOnline, isFalse);
    });

    test('a board that never answers is given up on after the time limit', () async {
      await local.submit(entry('Me', 7));
      final r = OnlineLeaderboardRepository(
        config: config,
        http: _NeverAnswers(),
        storage: storage,
        local: local,
        requestTimeout: const Duration(milliseconds: 50),
      );
      final entries = await r.fetchEntries().timeout(const Duration(seconds: 5));
      expect(r.isOnline, isFalse);
      expect(entries.map((e) => e.playerName), contains('Me'));
    });

    test('an upload that never answers does not hold the game up', () async {
      final r = OnlineLeaderboardRepository(
        config: config,
        http: _NeverAnswers(),
        storage: storage,
        local: local,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await r.submit(entry('Me', 7)).timeout(const Duration(seconds: 5));
      expect((await local.fetchEntries()).map((e) => e.playerName), contains('Me'));
    });

    test('the limit is a few seconds by default', () {
      expect(repo().requestTimeout, const Duration(seconds: 6));
    });

    test('coming back online switches back to the shared board', () async {
      final r = repo();
      firebase.offline = true;
      await r.fetchEntries();
      expect(r.isOnline, isFalse);
      firebase.offline = false;
      await r.fetchEntries();
      expect(r.isOnline, isTrue);
    });
  });

  group('submitting a score', () {
    test('writes the player\'s row under their own id, with their token', () async {
      final r = repo();
      await r.submit(entry('Phil', 21, attempts: 7));
      final id = (await FirebaseSession(config, firebase, storage).knownId())!;
      expect(firebase.log.where((l) => l.startsWith('PUT')).single, 'PUT /leaderboard/$id.json');
      expect(firebase.board[id], {
        'playerName': 'Phil', 'totalPoints': 21, 'averageTimeMs': 5000,
        'accuracyPercent': 75.0, 'optimalPercent': 50.0, 'attempts': 7,
      });
      expect(r.playerId, id);
    });

    test('the next result replaces the same row - one row per player', () async {
      final r = repo();
      await r.submit(entry('Phil', 5));
      await r.submit(entry('Phil', 9));
      await r.submit(entry('Philip', 12)); // renamed
      expect(firebase.board, hasLength(1));
      expect(firebase.board.values.single, containsPair('playerName', 'Philip'));
      expect(firebase.board.values.single, containsPair('totalPoints', 12));
      expect(firebase.signUps, 1);
    });

    test('a player with no average time yet leaves that field out', () async {
      await repo().submit(entry('New', 0, ms: null));
      expect((firebase.board.values.single as Map<String, Object?>).containsKey('averageTimeMs'), isFalse);
    });

    test('a long name is cut to 20 letters, which the rules allow', () async {
      await repo().submit(entry('x' * 50, 3));
      expect(((firebase.board.values.single as Map<String, Object?>)['playerName'] as String).length, 20);
    });

    test('it also keeps the score on this device', () async {
      await repo().submit(entry('Phil', 8));
      expect((await local.fetchEntries()).map((e) => e.playerName), contains('Phil'));
    });

    test('offline: nothing breaks, and the next result catches the board up', () async {
      final r = repo();
      firebase.offline = true;
      await r.submit(entry('Phil', 4)); // must not throw
      expect(firebase.board, isEmpty);
      expect((await local.fetchEntries()).map((e) => e.playerName), contains('Phil'));
      firebase.offline = false;
      await r.submit(entry('Phil', 9));
      expect(firebase.board.values.single, containsPair('totalPoints', 9));
    });

    test('a refused write (the rules said no) is quietly ignored', () async {
      final bad = _AlwaysStatus(401);
      final r = OnlineLeaderboardRepository(
          config: config, http: bad, storage: storage, local: local);
      await r.submit(entry('Phil', 1));
      expect(r.playerId, isNull);
    });

    test('two devices are two players with their own rows', () async {
      await repo().submit(entry('Alice', 10));
      final other = OnlineLeaderboardRepository(
        config: config,
        http: firebase,
        storage: InMemoryStorageService(), // a different phone
        local: LocalLeaderboardRepository(InMemoryStorageService()),
        now: () => firebase.now,
      );
      await other.submit(entry('Bob', 20));
      expect(firebase.board, hasLength(2));
      expect(firebase.board.values.map((e) => (e as Map)['playerName']), unorderedEquals(['Alice', 'Bob']));
    });
  });

  group('the leaderboard screen\'s service', () {
    test('ranks everyone on the shared board and marks which row is mine', () async {
      final mine = repo();
      final service = LeaderboardService(mine);
      await service.submit('Me', const StatisticsService().summarize(const []));
      firebase.board['someoneElse'] = {
        'playerName': 'Zed', 'totalPoints': 99, 'accuracyPercent': 90,
        'optimalPercent': 80, 'attempts': 30,
      };
      final ranked = await service.ranked(LeaderboardSort.points);
      expect(service.isOnline, isTrue);
      expect(ranked.first.playerName, 'Zed');
      expect(ranked.map((e) => e.playerName), isNot(contains('Bully')), reason: 'no sample players online');
      final me = ranked.firstWhere((e) => e.playerName == 'Me');
      expect(me.id, service.playerId);
    });

    test('with no online board it is the local one, as before', () async {
      final service = LeaderboardService(local);
      expect(service.isOnline, isFalse);
      expect(service.playerId, isNull);
    });
  });

  group('database rules file', () {
    final rules = (jsonDecode(File('firebase/database.rules.json').readAsStringSync())
        as Map<String, Object?>)['rules'] as Map<String, Object?>;
    final board = rules['leaderboard'] as Map<String, Object?>;
    final row = board[r'$playerId'] as Map<String, Object?>;

    test('everything is closed except the leaderboard', () {
      expect(rules['.read'], false);
      expect(rules['.write'], false);
    });

    test('everyone may read the board, and it is indexed by points', () {
      expect(board['.read'], true);
      expect(board['.indexOn'], contains('totalPoints'));
    });

    test('a player may only write the row under their own id', () {
      expect(row['.write'], contains(r'auth.uid === $playerId'));
      expect(row['.write'], contains('auth != null'));
    });

    test('each field is checked, and no other field is allowed', () {
      for (final field in ['playerName', 'totalPoints', 'averageTimeMs', 'accuracyPercent', 'optimalPercent', 'attempts']) {
        expect((row[field] as Map)['.validate'], isNotEmpty, reason: field);
      }
      expect((row[r'$other'] as Map)['.validate'], false);
      expect((row['playerName'] as Map)['.validate'], contains('<= 20'));
      expect((row['accuracyPercent'] as Map)['.validate'], contains('<= 100'));
    });

    test('the fields the app writes are exactly the fields the rules allow', () async {
      await repo().submit(entry('Phil', 3));
      final written = firebase.board.values.single as Map;
      for (final key in written.keys) {
        expect(row.containsKey(key), isTrue, reason: '$key is not allowed by the rules');
      }
    });
  });
}

/// A connection that never answers.
class _NeverAnswers implements JsonHttp {
  @override
  Future<HttpReply> send(String method, Uri url,
          {Map<String, String> headers = const {}, String? body}) =>
      Completer<HttpReply>().future;
}

/// Every request gets the same status.
class _AlwaysStatus implements JsonHttp {
  _AlwaysStatus(this.status);

  final int status;

  @override
  Future<HttpReply> send(String method, Uri url,
          {Map<String, String> headers = const {}, String? body}) async =>
      HttpReply(status, '{}');
}
