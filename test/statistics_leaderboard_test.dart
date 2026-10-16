import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

AttemptRecord rec({
  int session = 1,
  int target = 72,
  int darts = 2,
  DifficultyLevel level = DifficultyLevel.medium,
  bool correct = true,
  bool optimal = true,
  int timeMs = 5000,
  int points = 100,
}) =>
    AttemptRecord(
      sessionId: session,
      timestampMs: 0,
      target: target,
      dartCount: darts,
      difficulty: level,
      correct: correct,
      optimal: optimal,
      timeMs: timeMs,
      points: points,
      playerRoute: '',
      optimalRoute: '',
    );

void main() {
  const stats = StatisticsService();

  group('StatisticsService', () {
    test('empty history is safe', () {
      final s = stats.summarize(const []);
      expect(s.totalAttempts, 0);
      expect(s.accuracyPercent, 0);
      expect(s.averageSuccessTimeMs, isNull);
      expect(s.fastestSuccessMs, isNull);
    });

    test('summary aggregates', () {
      final s = stats.summarize([
        rec(timeMs: 4000, points: 200),
        rec(timeMs: 6000, points: 100, optimal: false),
        rec(correct: false, optimal: false, timeMs: 1000, points: 0),
        rec(level: DifficultyLevel.hard, darts: 3, timeMs: 9000, points: 500),
        rec(level: DifficultyLevel.easy, darts: 1, timeMs: 2000, points: 50, session: 2),
      ]);
      expect(s.totalAttempts, 5);
      expect(s.successes, 4);
      expect(s.failures, 1);
      expect(s.accuracyPercent, 80);
      expect(s.optimalSuccesses, 3);
      expect(s.optimalPercent, 75);
      expect(s.totalPoints, 850);
      expect(s.averageSuccessTimeMs, 5250); // failures excluded
      expect(s.fastestSuccessMs, 2000);
      expect(s.pointsByDifficulty[DifficultyLevel.medium], 300);
      expect(s.pointsByDifficulty[DifficultyLevel.hard], 500);
      expect(s.pointsByDifficulty[DifficultyLevel.easy], 50);
      expect(s.successesByDartCount, {1: 1, 2: 2, 3: 1});
      expect(s.bestSessionPoints, 800);
      expect(s.bestSinglePoints, 500);
    });

    test('time statistics ignore Checkout practice (it has no clock)', () {
      AttemptRecord choice(int timeMs) => AttemptRecord(
            sessionId: 1, timestampMs: 0, target: 85, dartCount: 2,
            difficulty: DifficultyLevel.medium, correct: true, optimal: true,
            timeMs: timeMs, points: 5, playerRoute: '', optimalRoute: '',
            mode: GameMode.choice,
          );
      final s = stats.summarize([
        rec(timeMs: 4000),
        rec(timeMs: 6000),
        choice(1), // would wreck the average and fastest if it counted
        choice(900000),
      ]);
      expect(s.averageSuccessTimeMs, 5000);
      expect(s.fastestSuccessMs, 4000);
      // ... but they still count as attempts, successes and points.
      expect(s.totalAttempts, 4);
      expect(s.successes, 4);
      expect(s.totalPoints, 100 + 100 + 5 + 5);

      final per = stats.byTarget([choice(1), choice(2)])[85]!;
      expect(per.successes, 2);
      expect(per.averageSuccessTimeMs, isNull);
      expect(per.bestTimeMs, isNull);
    });

    test('per-number stats', () {
      final per = stats.byTarget([
        for (var i = 0; i < 12; i++) rec(timeMs: 4000 + i * 100, optimal: i < 10),
        rec(correct: false, optimal: false),
        rec(correct: false, optimal: false),
        rec(target: 40),
      ]);
      final s = per[72]!;
      expect(s.attempts, 14);
      expect(s.successes, 12);
      expect(s.accuracyPercent, closeTo(85.7, 0.05));
      expect(s.optimalSuccesses, 10);
      expect(s.bestTimeMs, 4000);
      expect(per[40]!.attempts, 1);
    });

    test('weakest targets sort by lowest accuracy first', () {
      final weak = stats.weakestTargets([
        rec(target: 40),
        rec(target: 72, correct: false),
        rec(target: 100, correct: false),
        rec(target: 100, correct: false),
        rec(target: 100),
      ]);
      expect(weak.map((t) => t.target), [72, 100, 40]);
    });

    test('needs practice: the missed numbers, the largest number at the top', () {
      final list = stats.needsPractice([
        rec(target: 40), // never missed: not listed
        rec(target: 72, correct: false),
        rec(target: 100, correct: false),
        rec(target: 100, correct: false),
        rec(target: 100),
        rec(target: 16, correct: false),
        rec(target: 170, correct: false),
      ]);
      expect(list.map((t) => t.target), [170, 100, 72, 16]);
    });

    test('needs practice keeps the five weakest, then puts them largest to smallest', () {
      // Seven numbers, each missed once; 50 and 60 were also won once, so they
      // are the least weak and fall off the list of five.
      final history = [
        for (final t in [30, 90, 20, 110, 8, 50, 60]) rec(target: t, correct: false),
        rec(target: 50),
        rec(target: 60),
      ];
      final list = stats.needsPractice(history);
      expect(list, hasLength(5));
      expect(list.map((t) => t.target), [110, 90, 30, 20, 8]);
    });

    test('needs practice is empty until something has been missed', () {
      expect(stats.needsPractice([]), isEmpty);
      expect(stats.needsPractice([rec(target: 40), rec(target: 72)]), isEmpty);
    });

    test('history records survive a JSON round trip', () {
      final r = rec(target: 170, darts: 3, level: DifficultyLevel.hard);
      final back = AttemptRecord.fromJson(r.toJson());
      expect(back.target, 170);
      expect(back.difficulty, DifficultyLevel.hard);
      expect(back.dartCount, 3);
    });
  });

  group('HistoryRepository', () {
    test('round trips and tolerates corrupt data', () async {
      final storage = InMemoryStorageService();
      final repo = HistoryRepository(storage);
      await repo.save([rec(), rec(target: 40)]);
      expect((await repo.load()).map((r) => r.target), [72, 40]);
      await storage.write(HistoryRepository.storageKey, '{not json');
      expect(await repo.load(), isEmpty);
    });

    test('two repositories under different keys are independent', () async {
      final storage = InMemoryStorageService();
      final stats = HistoryRepository(storage);
      final board = HistoryRepository(storage, key: 'board');
      expect(await board.loadIfSaved(), isNull, reason: 'nothing saved yet');
      await stats.save([rec()]);
      await board.save([rec(), rec(target: 40)]);
      await stats.clear();
      expect(await stats.loadIfSaved(), isNull);
      expect((await board.load()).map((r) => r.target), [72, 40]);
    });
  });

  group('Leaderboard', () {
    LeaderboardEntry e(String n, int pts, int? ms, double acc, double opt) =>
        LeaderboardEntry(
          playerName: n,
          totalPoints: pts,
          averageTimeMs: ms,
          accuracyPercent: acc,
          optimalPercent: opt,
          attempts: 10,
        );
    final entries = [
      e('a', 100, 5000, 50, 10),
      e('b', 300, null, 70, 90),
      e('c', 200, 3000, 90, 50),
    ];

    List<String> names(LeaderboardSort s) =>
        LeaderboardService.rank(entries, s).map((x) => x.playerName).toList();

    test('ranks by each criterion', () {
      expect(names(LeaderboardSort.points), ['b', 'c', 'a']);
      expect(names(LeaderboardSort.averageTime), ['c', 'a', 'b']);
      expect(names(LeaderboardSort.accuracy), ['c', 'b', 'a']);
      expect(names(LeaderboardSort.optimalPercent), ['b', 'c', 'a']);
    });

    test('local repository replaces a player entry, and adds no players of its own', () async {
      final service =
          LeaderboardService(LocalLeaderboardRepository(InMemoryStorageService()));
      await service.submit('Me', stats.summarize([rec(points: 9999)]));
      await service.submit('Me', stats.summarize([rec(points: 9999), rec(points: 1)]));
      final board = await service.ranked();
      expect(board.map((x) => x.playerName), ['Me']);
    });
  });
}
