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

/// The board has 180 places, and only real players are on it: the places nobody
/// has taken are left empty (the screen draws them) and fill up as players join.
void main() {
  test('the board has 180 places', () {
    expect(LeaderboardService.boardSize, 180);
  });

  test('only the players there are: no made-up players fill the board', () async {
    final service = LeaderboardService(FixedRepository([
      for (var i = 0; i < 7; i++) real('Real $i', 100 + i, id: 'id$i'),
    ]));
    final board = await service.ranked();
    expect(board, hasLength(7));
    expect(board.first.playerName, 'Real 6'); // best first
    expect(board.map((e) => e.playerName).toSet(), hasLength(7));
  });

  test('an empty board has no rows at all (every place is empty)', () async {
    expect(await LeaderboardService(FixedRepository(const [])).ranked(), isEmpty);
  });

  test('more than 180 players: only the first 180 are on the board', () async {
    final service = LeaderboardService(FixedRepository([
      for (var i = 0; i < 200; i++) real('P$i', i + 1, id: 'id$i'),
    ]));
    final board = await service.ranked();
    expect(board, hasLength(180));
    expect(board.first.totalPoints, 200);
    expect(board.last.totalPoints, 21);
  });

  test('every ranking lists the real player, and only them', () async {
    final service = LeaderboardService(FixedRepository([real('Me', 300, id: 'me')]));
    for (final sort in LeaderboardSort.values) {
      final board = await service.ranked(sort);
      expect(board.map((e) => e.playerName), ['Me'], reason: sort.name);
    }
  });

  test('this device\'s own board has no built-in players either', () async {
    final local = LocalLeaderboardRepository(InMemoryStorageService());
    expect(await local.fetchEntries(), isEmpty);
    await local.submit(real('Me', 40));
    final board = await LeaderboardService(local).ranked();
    expect(board.map((e) => e.playerName), ['Me']);
  });
}
