import '../i18n/i18n.dart';

/// Tunable numbers for scoring.
///
/// Points come from a streak: a correct checkout with time left on the clock
/// scores as many points as checkouts you have got in a row.
class ScoringConfig {
  const ScoringConfig({this.timeLimit = const Duration(seconds: 30)});

  /// The clock counts down from this; past zero it goes negative.
  final Duration timeLimit;
}

/// What an answer did to the score.
enum ScoreKind {
  /// Correct with time left: scores the streak length.
  counted,

  /// Correct, but the clock had run out: no points, the streak is kept.
  late,

  /// Wrong: no points, the streak starts again from 0.
  miss,

  /// Nothing was scored (a replay).
  none,
}

/// The score for one answer, with everything needed to explain it.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.kind,
    this.points = 0,
    this.streakBefore = 0,
    this.streakAfter = 0,
    this.timeLeft = Duration.zero,
  });

  static const ScoreBreakdown none = ScoreBreakdown(kind: ScoreKind.none);

  final ScoreKind kind;

  /// Points won (never negative).
  final int points;
  final int streakBefore;
  final int streakAfter;

  /// The clock when the answer was given; negative once time was up.
  final Duration timeLeft;

  /// The amount added to the session score.
  int get total => points;

  bool get isMistake => kind == ScoreKind.miss;

  /// Why the answer scored what it did, one plain sentence per line.
  List<String> explain() {
    final seconds = (timeLeft.inMilliseconds / 1000).toStringAsFixed(2);
    switch (kind) {
      case ScoreKind.counted:
        return [
          tr('Time left: {seconds}s. That is more than 0, so this checkout counts.',
              {'seconds': seconds}),
          trn(points, 'It is checkout number {streak} in a row, so it scores {n} point.',
              'It is checkout number {streak} in a row, so it scores {n} points.',
              {'streak': streakAfter}),
          tr('Keep going: the next one in a row is worth {next}. '
              'A miss starts the count again from 0.', {'next': streakAfter + 1}),
        ];
      case ScoreKind.late:
        return [
          tr('Time left: {seconds}s. The clock had run out, so no points this time.',
              {'seconds': seconds}),
          tr('Your streak of {streak} is kept, but it did not grow.', {'streak': streakBefore}),
          tr('Finish with time left (above 0) to score again.'),
        ];
      case ScoreKind.miss:
        return [
          tr('That was not right, so no points.'),
          streakBefore == 0
              ? tr('Your streak is 0. Get one right to start it.')
              : tr('Your streak of {streak} starts again from 0.', {'streak': streakBefore}),
        ];
      case ScoreKind.none:
        return [tr('A replay does not score and has no clock.')];
    }
  }
}

/// Streak scoring. No UI or DOM knowledge.
///
///  * A correct answer with time left (above 0) scores the streak length: the
///    1st in a row is 1 point, the 2nd is 2, ... the 10th is 10.
///  * A correct answer after the clock ran out scores 0 and keeps the streak.
///  * A wrong answer scores 0 and resets the streak.
class ScoringService {
  const ScoringService([this.config = const ScoringConfig()]);

  final ScoringConfig config;

  ScoreBreakdown score({
    required bool correct,
    required Duration timeLeft,
    required int streakBefore,
  }) {
    if (!correct) {
      return ScoreBreakdown(
        kind: ScoreKind.miss,
        streakBefore: streakBefore,
        timeLeft: timeLeft,
      );
    }
    if (timeLeft > Duration.zero) {
      final streak = streakBefore + 1;
      return ScoreBreakdown(
        kind: ScoreKind.counted,
        points: streak,
        streakBefore: streakBefore,
        streakAfter: streak,
        timeLeft: timeLeft,
      );
    }
    return ScoreBreakdown(
      kind: ScoreKind.late,
      streakBefore: streakBefore,
      streakAfter: streakBefore,
      timeLeft: timeLeft,
    );
  }
}
