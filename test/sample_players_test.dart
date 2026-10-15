import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

LeaderboardEntry real(String name, int points, {String? id}) => LeaderboardEntry(
      id: id,
      playerName: name,
      totalPoints: points,
      averageTimeMs: 5000,
      accuracyPercent: 80,
      optimalPercent: 60,
      attempts: 20,
    );

/// A repository that hands out a fixed list, like the online board.
class FixedRepository implements LeaderboardRepository {
  FixedRepository(this.entries);
  final List<LeaderboardEntry> entries;

  @override
  Future<List<LeaderboardEntry>> fetchEntries() async => entries;

  @override
  Future<void> submit(LeaderboardEntry entry) async {}

  @override
  bool get isOnline => true;

  @override
  String? get playerId => null;
}

void main() {
  group('SamplePlayers', () {
    test('there are 180, with different names, all marked as samples', () {
      final all = SamplePlayers.all;
      expect(all, hasLength(180));
      expect(all.map((e) => e.playerName).toSet(), hasLength(180));
      expect(all.every((e) => e.isSample), isTrue);
      expect(all.every((e) => e.playerName.isNotEmpty && e.playerName.length <= 20), isTrue);
      expect(all.every((e) => e.id == null), isTrue, reason: 'never a real id');
    });

    test('best points first, from 60 down to 1', () {
      final points = SamplePlayers.all.map((e) => e.totalPoints).toList();
      expect(points.first, 60);
      expect(points.last, 1);
      for (var i = 1; i < points.length; i++) {
        expect(points[i], lessThanOrEqualTo(points[i - 1]), reason: 'place $i');
      }
    });

    test('the other figures are plausible', () {
      for (final e in SamplePlayers.all) {
        expect(e.accuracyPercent, inInclusiveRange(0, 100));
        expect(e.optimalPercent, inInclusiveRange(0, 100));
        expect(e.averageTimeMs, inInclusiveRange(1000, 30000));
        expect(e.attempts, greaterThan(0));
      }
    });

    test('the list is the same every time', () {
      expect(identical(SamplePlayers.all, SamplePlayers.all), isTrue);
      expect(SamplePlayers.all.first.playerName, isNotEmpty);
    });
  });

  group('the leaderboard always has 180 rows', () {
    test('7 real players and 173 samples, the real ones first by points', () async {
      final service = LeaderboardService(FixedRepository([
        for (var i = 0; i < 7; i++) real('Real $i', 100 + i, id: 'id$i'),
      ]));
      final board = await service.ranked();
      expect(board, hasLength(180));
      expect(board.where((e) => !e.isSample), hasLength(7));
      expect(board.where((e) => e.isSample), hasLength(173));
      // Real players with more than 60 points are above every sample player.
      expect(board.take(7).every((e) => !e.isSample), isTrue);
      expect(board.first.playerName, 'Real 6');
    });

    test('the best sample players go first, so real players take over the top', () {
      final padded = LeaderboardService.withSamples([real('A', 5), real('B', 6)]);
      final samples = padded.where((e) => e.isSample).toList();
      expect(samples, hasLength(178));
      expect(samples.first.playerName, SamplePlayers.all[2].playerName,
          reason: 'the two best samples made room for the two real players');
    });

    test('180 real players: no samples at all', () {
      final entries = [for (var i = 0; i < 180; i++) real('P$i', i)];
      final padded = LeaderboardService.withSamples(entries);
      expect(padded, hasLength(180));
      expect(padded.any((e) => e.isSample), isFalse);
    });

    test('more than 180 real players: only the first 180 rows are shown', () async {
      final service = LeaderboardService(FixedRepository([
        for (var i = 0; i < 200; i++) real('P$i', i + 1, id: 'id$i'),
      ]));
      final board = await service.ranked();
      expect(board, hasLength(180));
      expect(board.any((e) => e.isSample), isFalse);
      expect(board.first.totalPoints, 200);
    });

    test('every ranking has 180 rows', () async {
      final service = LeaderboardService(FixedRepository([real('Me', 300, id: 'me')]));
      for (final sort in LeaderboardSort.values) {
        final board = await service.ranked(sort);
        expect(board, hasLength(180), reason: sort.name);
        expect(board.where((e) => !e.isSample).single.playerName, 'Me', reason: sort.name);
      }
    });

    test('sample rows a repository sends are replaced, not added to', () async {
      final storage = InMemoryStorageService();
      final local = LocalLeaderboardRepository(storage);
      await local.submit(real('Me', 40));
      final service = LeaderboardService(local);
      final board = await service.ranked();
      expect(board, hasLength(180));
      expect(board.where((e) => !e.isSample).map((e) => e.playerName), ['Me']);
      // The old four sample rivals are not extra rows.
      expect(board.where((e) => e.isSample), hasLength(179));
    });

    test('an empty board is all samples', () async {
      final board = await LeaderboardService(FixedRepository(const [])).ranked();
      expect(board, hasLength(180));
      expect(board.every((e) => e.isSample), isTrue);
    });
  });
}
