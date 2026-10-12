/// Tunable numbers for scoring. Swap or edit without touching the formula.
///
/// Points are deliberately small whole numbers: +2 for an easy number close to
/// zero up to +6 for a hard one, plus at most +1 optimal and +1 speed (so +8 is
/// a perfect hard checkout). A miss costs what the checkout was worth.
class ScoringConfig {
  const ScoringConfig({
    this.minBasePoints = 2,
    this.maxBasePoints = 6,
    this.optimalBonus = 1,
    this.maxSpeedBonus = 1,
    this.fastSecondsPerDart = 2.0,
    this.slowSecondsPerDart = 10.0,
    this.timeLimit = const Duration(seconds: 30),
    this.overtimeSecondsPerPoint = 5,
  });

  /// Worth of the easiest checkout (complexity 0, e.g. D20).
  final int minBasePoints;

  /// Worth of the hardest checkouts; base points never exceed this.
  final int maxBasePoints;

  /// Extra points for matching an optimal route.
  final int optimalBonus;

  /// Speed bonus at its maximum.
  final int maxSpeedBonus;

  /// At or below this time per dart the full speed bonus is earned.
  final double fastSecondsPerDart;

  /// At or above this time per dart no speed bonus is earned.
  final double slowSecondsPerDart;

  /// The clock counts down from this; past zero it goes negative.
  final Duration timeLimit;

  /// Every started block of this many seconds over the limit costs 1 point.
  final int overtimeSecondsPerPoint;
}

/// Itemised score so the UI can show exactly where points came from.
class ScoreBreakdown {
  const ScoreBreakdown({
    this.base = 0,
    this.optimalBonus = 0,
    this.speedBonus = 0,
    this.timePenalty = 0,
    this.mistakePenalty = 0,
  });

  static const ScoreBreakdown zero = ScoreBreakdown();

  final int base;
  final int optimalBonus;
  final int speedBonus;

  /// Points lost for finishing after the clock ran out (positive, subtracted).
  final int timePenalty;

  /// Points lost for a wrong or skipped checkout (positive, subtracted).
  final int mistakePenalty;

  bool get isMistake => mistakePenalty > 0;

  /// The real amount won or lost. A mistake is negative, and so is a correct
  /// checkout that is so late the overtime penalty is bigger than what it
  /// earned - it is no longer rounded up to zero.
  int get total {
    if (isMistake) return -mistakePenalty;
    return base + optimalBonus + speedBonus - timePenalty;
  }
}

/// Base + Optimal + Speed - Overtime, or a penalty for a mistake.
/// No UI or DOM knowledge.
class ScoringService {
  const ScoringService([this.config = const ScoringConfig()]);

  final ScoringConfig config;

  /// What a checkout of this [complexity] is worth: easy numbers are worth the
  /// minimum, the hardest routes the maximum.
  int basePoints(int complexity) {
    final points = config.minBasePoints + complexity;
    if (points > config.maxBasePoints) return config.maxBasePoints;
    return points < config.minBasePoints ? config.minBasePoints : points;
  }

  /// With [timed] false (Checkout practice) there is no clock: no speed bonus and
  /// no overtime penalty, just the checkout and the optimal bonus.
  ScoreBreakdown score({
    required bool correct,
    required int complexity,
    required int darts,
    required bool optimal,
    required Duration elapsed,
    bool timed = true,
  }) {
    final base = basePoints(complexity);
    // A wrong or skipped answer costs what the checkout was worth.
    if (!correct) return ScoreBreakdown(mistakePenalty: base);
    return ScoreBreakdown(
      base: base,
      optimalBonus: optimal ? config.optimalBonus : 0,
      speedBonus: timed ? speedBonus(base: base, darts: darts, elapsed: elapsed) : 0,
      timePenalty: timed ? timePenalty(elapsed) : 0,
    );
  }

  /// Points lost for going past the time limit; 0 while time remains.
  int timePenalty(Duration elapsed) {
    final over = elapsed - config.timeLimit;
    if (over <= Duration.zero) return 0;
    final block = config.overtimeSecondsPerPoint * Duration.millisecondsPerSecond;
    return (over.inMilliseconds / block).ceil();
  }

  /// Bonus for answering quickly. Must be non-negative, never exceed
  /// `maxSpeedBonus`, and never increase as [elapsed] grows.
  int speedBonus({
    required int base,
    required int darts,
    required Duration elapsed,
  }) {
    // TODO(human): choose the speed-bonus curve (the default below is linear).
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final perDart = seconds / darts;
    final span = config.slowSecondsPerDart - config.fastSecondsPerDart;
    final fraction =
        ((config.slowSecondsPerDart - perDart) / span).clamp(0.0, 1.0);
    return (config.maxSpeedBonus * fraction).round();
  }
}
