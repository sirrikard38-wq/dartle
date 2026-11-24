import 'dart:convert';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

final DateTime day = DateTime(2026, 11, 24);

FelgaLedger book(String json) => FelgaLedger.fromJson(json);

/// Two phones sharing one Felgalizacija through the stand-in online place.
class Phone {
  Phone(this.remote, this.copy);

  final StorageFelgaRemote remote;
  FelgaCopy copy;

  FelgaLedger get ledger => FelgaLedger.fromJson(copy.book);

  void change(void Function(FelgaLedger l) what) {
    final l = ledger;
    what(l);
    copy = copy.withNow(book: l.toJson());
  }

  Future<void> sync() async => copy = await syncFelga(remote, 'pass', copy);
}

void main() {
  test('SHA-256 gives the known answers', () {
    expect(sha256Hex(utf8.encode('')), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(sha256Hex(utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    expect(felgaKey('Ab3#x?'), hasLength(64));
    expect(felgaKey('Ab3#x?'), isNot(felgaKey('Ab3#x!')));
  });

  test('a member keeps their account in the book', () {
    final l = FelgaLedger()
      ..add('Riko', uid: 'u1')
      ..add('Tin');
    final back = book(l.toJson());
    expect(back.members.map((m) => m.uid), ['u1', null]);
    expect(back.memberOf('u1')!.name, 'Riko');
    expect(back.unsynced.map((m) => m.name), ['Tin']);
    expect(back.claimByName('Tin', 'u1'), isFalse, reason: 'u1 already has a name');
    expect(back.claimByName('Tin', 'u2'), isTrue);
    expect(back.unsynced, isEmpty);
  });

  test('the stand-in refuses a write that is not one more than what is there', () async {
    final remote = StorageFelgaRemote(InMemoryStorageService(), uid: 'u1');
    expect(await remote.push('p', const RemoteFelga('A', '{}', 2)), isFalse);
    expect(await remote.push('p', const RemoteFelga('A', '{}', 1)), isTrue);
    expect(await remote.push('p', const RemoteFelga('A', '{}', 1)), isFalse);
    expect(await remote.push('p', const RemoteFelga('B', '{}', 2)), isTrue);
    expect((await remote.fetch('p'))!.name, 'B');
    expect(await remote.fetch('other'), isNull);
  });

  group('two phones', () {
    late StorageFelgaRemote online;
    late Phone a, b;

    setUp(() async {
      online = StorageFelgaRemote(InMemoryStorageService(), uid: 'x');
      final start = FelgaLedger()
        ..add('Riko')
        ..add('Tin')
        ..add('Mihovil');
      a = Phone(online, FelgaCopy(name: 'Klub', book: start.toJson()));
      await a.sync(); // goes online as rev 1
      final there = (await online.fetch('pass'))!;
      expect(there.rev, 1);
      b = Phone(online,
          FelgaCopy(name: there.name, book: there.book, rev: there.rev, baseName: there.name, baseBook: there.book));
    });

    test('a change on one shows on the other', () async {
      a.change((l) => l.step(l.members[1], 1, day));
      await a.sync();
      expect(a.copy.changed, isFalse);
      await b.sync();
      expect(b.ledger.members[1].points, 1);
      expect(b.copy.rev, 2);
    });

    test('changes made at once on both are all kept', () async {
      a.change((l) {
        l.step(l.members[0], 1, day);
        l.members[2].paidCents += 100;
      });
      b.change((l) {
        l.step(l.members[0], 1, day);
        l.step(l.members[1], 1, day);
        l.add('Stjepan');
      });
      await a.sync();
      await b.sync(); // refused first, then on top of a's
      await a.sync();
      for (final p in [a, b]) {
        final l = p.ledger;
        expect([for (final m in l.members) m.name], ['Riko', 'Tin', 'Mihovil', 'Stjepan']);
        expect([for (final m in l.members) m.points], [2, 1, 0, 0]);
        expect(l.members[2].paidCents, 100);
        expect(l.history.where((d) => d.name == 'Riko').single.count, 2);
      }
      expect(a.copy.book, b.copy.book);
    });

    test('a reset on one keeps what the other added after it', () async {
      a.change((l) => l.step(l.members[0], 1, day));
      await a.sync();
      await b.sync();
      // b resets while a adds a felga for Tin
      b.change((l) => l.reset(day));
      a.change((l) => l.step(l.members[1], 1, day));
      await a.sync();
      await b.sync();
      final l = b.ledger;
      expect([for (final m in l.members) m.points], [0, 1, 0]);
      expect(l.periods, hasLength(1));
      expect(l.currentDays.map((d) => d.name), ['Tin']);
    });

    test('a name taken out on one stays out', () async {
      b.change((l) => l.remove(l.members[2]));
      a.change((l) => l.step(l.members[0], 1, day));
      await b.sync();
      await a.sync();
      expect([for (final m in a.ledger.members) m.name], ['Riko', 'Tin']);
      expect(a.ledger.members[0].points, 1);
    });

    test('joining as one of the names syncs it to that phone', () async {
      b.change((l) => l.members[2].uid = 'phone-b');
      await b.sync();
      await a.sync();
      expect(a.ledger.memberOf('phone-b')!.name, 'Mihovil');
      expect(a.ledger.unsynced.map((m) => m.name), ['Riko', 'Tin']);
    });

    test('a new name of the Felgalizacija goes over', () async {
      a.copy = a.copy.withNow(name: 'Klub 2');
      await a.sync();
      await b.sync();
      expect(b.copy.name, 'Klub 2');
    });
  });

  test('takeFrom keeps the same member objects for the same names', () {
    final here = FelgaLedger()
      ..add('Riko')
      ..add('Tin');
    final riko = here.members.first;
    final there = FelgaLedger()
      ..add('Tin')
      ..add('Riko');
    there.members.last.points = 3;
    here.takeFrom(there);
    expect(here.members.map((m) => m.name), ['Tin', 'Riko']);
    expect(identical(here.members.last, riko), isTrue);
    expect(riko.points, 3);
  });

  test('Firebase: the place, the body and a refusal', () async {
    final http = _FakeHttp();
    final config = OnlineConfig.tryParse('{"databaseUrl": "https://db.example", "apiKey": "k"}')!;
    final storage = InMemoryStorageService();
    final remote = FirebaseFelgaRemote(config: config, http: http, session: FirebaseSession(config, http, storage));
    expect(await remote.fetch('pw'), isNull);
    expect(http.lastUrl!.path, '/felga/${felgaKey('pw')}.json');
    expect(http.lastUrl!.queryParameters['auth'], 'tok');
    expect(await remote.push('pw', const RemoteFelga('N', '{}', 1)), isTrue);
    expect(jsonDecode(http.lastBody!), {'name': 'N', 'book': '{}', 'rev': 1});
    expect((await remote.fetch('pw'))!.rev, 1);
    http.refuse = true;
    expect(await remote.push('pw', const RemoteFelga('N', '{}', 2)), isFalse);
    expect(await remote.me(), 'uid-1');
  });
}

class _FakeHttp implements JsonHttp {
  Uri? lastUrl;
  String? lastBody;
  String stored = 'null';
  bool refuse = false;

  @override
  Future<HttpReply> send(String method, Uri url, {Map<String, String> headers = const {}, String? body}) async {
    if (url.path.endsWith('accounts:signUp')) {
      return HttpReply(200, jsonEncode({'idToken': 'tok', 'refreshToken': 'r', 'localId': 'uid-1', 'expiresIn': '3600'}));
    }
    lastUrl = url;
    lastBody = body;
    if (method == 'GET') return HttpReply(200, stored);
    if (refuse) return const HttpReply(401, '{"error": "Permission denied"}');
    stored = body!;
    return HttpReply(200, body);
  }
}
