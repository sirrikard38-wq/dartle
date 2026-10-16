import '../domain/difficulty.dart';
import 'attempt_record.dart';

/// Aggregates for a set of attempts.
class StatsSummary {
  const StatsSummary({
    required this.totalAttempts,
    required this.successes,
    required this.optimalSuccesses,
    required this.totalPoints,
    required this.averageSuccessTimeMs,
    required this.fastestSuccessMs,
    required this.pointsByDifficulty,
    required this.successesByDartCount,
    required this.bestSessionPoints,
    required this.bestSinglePoints,
  });

  final int totalAttempts;
  final int successes;
  final int optimalSuccesses;
  final int totalPoints;

  /// Mean time of successful checkouts, or null if none yet.
  final int? averageSuccessTimeMs;
  final int? fastestSuccessMs;
  final Map<DifficultyLevel, int> pointsByDifficulty;

  /// Key = dart count (1, 2, 3).
  final Map<int, int> successesByDartCount;
  final int bestSessionPoints;
  final int bestSinglePoints;

  int get failures => totalAttempts - successes;

  /// 0-100.
  double get accuracyPercent =>
      totalAttempts == 0 ? 0 : successes * 100 / totalAttempts;

  /// Share of successful checkouts that used the optimal route, 0-100.
  double get optimalPercent =>
      successes == 0 ? 0 : optimalSuccesses * 100 / successes;
}

/// Performance on one specific checkout number.
class TargetStats {
  const TargetStats({
    required this.target,
    required this.attempts,
    required this.successes,
    required this.optimalSuccesses,
    required this.averageSuccessTimeMs,
    required this.bestTimeMs,
  });

  final int target;
  final int attempts;
  final int successes;
  final int optimalSuccesses;
  final int? averageSuccessTimeMs;
  final int? bestTimeMs;

  double get accuracyPercent => attempts == 0 ? 0 : successes * 100 / attempts;
}

/// Pure functions over attempt history. No storage, no UI.
class StatisticsService {
  const StatisticsService();

  StatsSummary summarize(List<AttemptRecord> history) {
    final wins = history.where((r) => r.correct).toList();
    // Only timed games (Checkout calculator) count towards time statistics.
    final winTimes = wins.where((r) => r.mode.isTimed).map((r) => r.timeMs).toList();

    final pointsByDifficulty = {
      for (final level in DifficultyLevel.values) level: 0,
    };
    final successesByDarts = {1: 0, 2: 0, 3: 0};
    final sessionPoints = <int, int>{};
    var bestSingle = 0;
    var total = 0;

    for (final r in history) {
      total += r.points;
      pointsByDifficulty[r.difficulty] =
          pointsByDifficulty[r.difficulty]! + r.points;
      sessionPoints[r.sessionId] = (sessionPoints[r.sessionId] ?? 0) + r.points;
      if (r.points > bestSingle) bestSingle = r.points;
      // A right "No checkout" uses no darts (dart count 0), so it is not in the
      // by-darts bars.
      if (r.correct && r.dartCount > 0) {
        successesByDarts[r.dartCount] = (successesByDarts[r.dartCount] ?? 0) + 1;
      }
    }

    return StatsSummary(
      totalAttempts: history.length,
      successes: wins.length,
      optimalSuccesses: wins.where((r) => r.optimal).length,
      totalPoints: total,
      averageSuccessTimeMs: _mean(winTimes),
      fastestSuccessMs: winTimes.isEmpty ? null : winTimes.reduce(_min),
      pointsByDifficulty: pointsByDifficulty,
      successesByDartCount: successesByDarts,
      bestSessionPoints:
          sessionPoints.values.fold(0, (best, p) => p > best ? p : best),
      bestSinglePoints: bestSingle,
    );
  }

  /// Per-number stats, keyed by target.
  Map<int, TargetStats> byTarget(List<AttemptRecord> history) {
    final grouped = <int, List<AttemptRecord>>{};
    for (final r in history) {
      grouped.putIfAbsent(r.target, () => []).add(r);
    }
    return {
      for (final entry in grouped.entries) entry.key: _targetStats(entry.key, entry.value),
    };
  }

  /// Every number played, the weakest first: lowest accuracy, then most attempts.
  List<TargetStats> _weakestFirst(List<AttemptRecord> history) =>
      byTarget(history).values.toList()
        ..sort((a, b) {
          final byAcc = a.accuracyPercent.compareTo(b.accuracyPercent);
          return byAcc != 0 ? byAcc : b.attempts.compareTo(a.attempts);
        });

  /// Weakest numbers first: lowest accuracy, then most attempts.
  List<TargetStats> weakestTargets(List<AttemptRecord> history, {int limit = 5}) =>
      _weakestFirst(history).take(limit).toList();

  /// The numbers that need practice: the [limit] weakest numbers that were ever
  /// missed, listed from the largest number to the smallest.
  List<TargetStats> needsPractice(List<AttemptRecord> history, {int limit = 5}) =>
      _weakestFirst(history).where((t) => t.successes < t.attempts).take(limit).toList()
        ..sort((a, b) => b.target.compareTo(a.target));

  TargetStats _targetStats(int target, List<AttemptRecord> records) {
    final wins = records.where((r) => r.correct).toList();
    final times = wins.where((r) => r.mode.isTimed).map((r) => r.timeMs).toList();
    return TargetStats(
      target: target,
      attempts: records.length,
      successes: wins.length,
      optimalSuccesses: wins.where((r) => r.optimal).length,
      averageSuccessTimeMs: _mean(times),
      bestTimeMs: times.isEmpty ? null : times.reduce(_min),
    );
  }

  int? _mean(List<int> values) => values.isEmpty
      ? null
      : (values.reduce((a, b) => a + b) / values.length).round();

  int _min(int a, int b) => a < b ? a : b;
}
