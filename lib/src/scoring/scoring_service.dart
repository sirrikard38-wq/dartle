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
          'Time left: ${seconds}s. That is more than 0, so this checkout counts.',
          'It is checkout number $streakAfter in a row, so it scores '
              '$points ${points == 1 ? 'point' : 'points'}.',
          'Keep going: the next one in a row is worth ${streakAfter + 1}. '
              'A miss starts the count again from 0.',
        ];
      case ScoreKind.late:
        return [
          'Time left: ${seconds}s. The clock had run out, so no points this time.',
          'Your streak of $streakBefore is kept, but it did not grow.',
          'Finish with time left (above 0) to score again.',
        ];
      case ScoreKind.miss:
        return [
          'That was not right, so no points.',
          streakBefore == 0
              ? 'Your streak is 0. Get one right to start it.'
              : 'Your streak of $streakBefore starts again from 0.',
        ];
      case ScoreKind.none:
        return ['A replay does not score and has no clock.'];
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
