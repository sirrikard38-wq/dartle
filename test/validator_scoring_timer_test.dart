import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);
  final validator = CheckoutValidator(engine, optimal);

  List<DartThrow> darts(String text) => CheckoutRoute.parse(text).darts;

  group('CheckoutValidator', () {
    final c72 = catalog.forTarget(72)!; // optimal T20 D6

    test('72 = T20 + D6 is correct and optimal', () {
      final r = validator.validate(c72, darts('T20 D6'));
      expect(r.outcome, AttemptOutcome.correct);
      expect(r.isOptimal, isTrue);
      expect(r.message, contains('60 + 12 = 72'));
    });

    test('72 = T18 + D9 is correct but not optimal', () {
      final r = validator.validate(c72, darts('T18 D9'));
      expect(r.isCorrect, isTrue);
      expect(r.isOptimal, isFalse);
    });

    test('72 = T20 + D5 is rejected with explanation', () {
      final r = validator.validate(c72, darts('T20 D5'));
      expect(r.outcome, AttemptOutcome.wrongTotal);
      expect(r.message, contains('60 + 10 = 70'));
      expect(r.message, contains('does not equal 72'));
    });

    test('correct total ending on a single/treble is an invalid finish', () {
      final r = validator.validate(c72, darts('T18 S18'));
      expect(r.outcome, AttemptOutcome.invalidFinish);
      expect(r.message, contains('final dart must be a double or Bull'));
      expect(validator.validate(c72, darts('D6 T20')).outcome,
          AttemptOutcome.invalidFinish);
    });

    test('outer bull cannot finish 25-ending routes', () {
      final c = catalog.forTarget(50)!;
      expect(validator.validate(c, darts('25')).outcome, AttemptOutcome.wrongTotal);
      expect(validator.validate(c, darts('Bull')).isCorrect, isTrue);
    });

    test('wrong dart count is reported clearly', () {
      final r = validator.validate(c72, darts('S20 S20 D6'));
      expect(r.outcome, AttemptOutcome.wrongDartCount);
      expect(r.message, contains('exactly 2 darts'));
      expect(validator.validate(c72, const []).outcome,
          AttemptOutcome.wrongDartCount);
    });

    test('two boxes for 67: only the bull-safe T17 D8 is optimal', () {
      final c = catalog.forTarget(67)!;
      expect(c.dartCount, 2);
      expect(validator.validate(c, darts('T17 D8')).isOptimal, isTrue);
      final other = validator.validate(c, darts('T19 D5')); // 57 + 10 = 67
      expect(other.isCorrect, isTrue);
      expect(other.isOptimal, isFalse);
    });

    test('170 accepts only T20 T20 Bull', () {
      final c = catalog.forTarget(170)!;
      expect(validator.validate(c, darts('T20 T20 Bull')).isOptimal, isTrue);
      expect(validator.validate(c, darts('T20 T20 D20')).outcome,
          AttemptOutcome.wrongTotal);
    });
  });

  group('ScoringService', () {
    const scoring = ScoringService();
    const slow = Duration(seconds: 60);
    const fast = Duration(milliseconds: 500);
    // Inside the 30s limit but too slow for any speed bonus.
    const inTime = Duration(seconds: 25);

    ScoreBreakdown score({
      bool correct = true,
      int complexity = 2,
      int darts = 2,
      bool optimal = false,
      Duration elapsed = inTime,
    }) =>
        scoring.score(
          correct: correct,
          complexity: complexity,
          darts: darts,
          optimal: optimal,
          elapsed: elapsed,
        );

    test('base points are small whole numbers: +2 easy up to +6 hard', () {
      expect(scoring.basePoints(0), 2); // e.g. D20
      expect(scoring.basePoints(1), 3);
      expect(scoring.basePoints(2), 4);
      expect(scoring.basePoints(4), 6);
      expect(scoring.basePoints(6), 6); // e.g. 170
      expect(scoring.basePoints(40), 6, reason: 'capped at the maximum');
      expect(scoring.basePoints(-3), 2, reason: 'never below the minimum');
    });

    test('totals stay in a single-digit range, never hundreds', () {
      final perfectHard = score(complexity: 6, darts: 3, optimal: true, elapsed: fast);
      expect(perfectHard.total, 8); // 6 + 1 optimal + 1 speed
      final easySlow = score(complexity: 0, darts: 1, elapsed: inTime);
      expect(easySlow.total, 2);
      for (var c = 0; c <= 8; c++) {
        final best = score(complexity: c, darts: 3, optimal: true, elapsed: fast).total;
        expect(best, inInclusiveRange(2, 8), reason: 'complexity $c');
      }
    });

    test('harder checkouts are worth more', () {
      final points = [for (var c = 0; c <= 6; c++) score(complexity: c).total];
      for (var i = 1; i < points.length; i++) {
        expect(points[i], greaterThanOrEqualTo(points[i - 1]));
      }
      expect(points.last, greaterThan(points.first));
    });

    test('a wrong or skipped checkout loses what it was worth', () {
      expect(score(correct: false, complexity: 0).total, -2);
      expect(score(correct: false, complexity: 4).total, -6);
      expect(score(correct: false, complexity: 6).total, -6);
      expect(score(correct: false).isMistake, isTrue);
      // Speed or an optimal flag cannot rescue a miss.
      expect(score(correct: false, optimal: true, elapsed: fast).total,
          score(correct: false).total);
    });

    test('a hard miss costs more than an easy miss', () {
      expect(score(correct: false, complexity: 5).total,
          lessThan(score(correct: false, complexity: 0).total));
    });

    test('optimal route earns a bonus', () {
      expect(score(optimal: false).optimalBonus, 0);
      expect(score(optimal: true).optimalBonus, scoring.config.optimalBonus);
      expect(score(optimal: true).total, greaterThan(score(optimal: false).total));
    });

    test('speed bonus is bounded and never increases with time', () {
      final bonuses = [
        for (var ms = 0; ms <= 60000; ms += 500)
          score(elapsed: Duration(milliseconds: ms)).speedBonus
      ];
      for (var i = 1; i < bonuses.length; i++) {
        expect(bonuses[i], lessThanOrEqualTo(bonuses[i - 1]));
      }
      expect(bonuses.every((b) => b >= 0), isTrue);
      expect(bonuses.first, lessThanOrEqualTo(scoring.config.maxSpeedBonus));
      expect(score(elapsed: fast).speedBonus, greaterThan(0));
      expect(score(elapsed: slow).speedBonus, 0);
    });

    test('total is the sum of all parts', () {
      final s = score(complexity: 6, darts: 3, optimal: true, elapsed: fast);
      expect(s.total, s.base + s.optimalBonus + s.speedBonus);
      expect(s.timePenalty, 0);
      expect(s.mistakePenalty, 0);
    });

    test('no penalty inside the 30s limit, including exactly at it', () {
      expect(score(elapsed: const Duration(seconds: 29)).timePenalty, 0);
      expect(score(elapsed: const Duration(seconds: 30)).timePenalty, 0);
    });

    test('overtime costs 1 point per started 5 seconds', () {
      expect(scoring.timePenalty(const Duration(milliseconds: 30001)), 1);
      expect(scoring.timePenalty(const Duration(seconds: 35)), 1);
      expect(scoring.timePenalty(const Duration(milliseconds: 35001)), 2);
      // 38.33s elapsed = clock showing -8.33s => 8.33s over => 2 points.
      final s = score(elapsed: const Duration(milliseconds: 38330), complexity: 6, darts: 3);
      expect(s.timePenalty, 2);
      expect(s.total, s.base + s.optimalBonus + s.speedBonus - s.timePenalty);
      expect(score(elapsed: const Duration(seconds: 70)).timePenalty, 8);
    });

    test('a correct checkout that is very late shows the real loss, not zero', () {
      // 107.5s elapsed = 77.5s over = 16 blocks of 5s (the screen showed -22 at 107.50s over).
      final s = score(complexity: 0, darts: 1, elapsed: const Duration(minutes: 10));
      expect(s.timePenalty, greaterThan(s.base));
      expect(s.total, s.base + s.optimalBonus + s.speedBonus - s.timePenalty);
      expect(s.total, lessThan(0));
    });

    test('the amount shown is the true net of earnings and overtime', () {
      // 107.5s over the 30s limit costs ceil(107.5 / 5) = 22 points.
      final late = scoring.timePenalty(const Duration(milliseconds: 137500));
      expect(late, 22);
      final s = score(complexity: 2, darts: 2, optimal: true, elapsed: const Duration(milliseconds: 137500));
      // base 4 + optimal 1 + speed 0 - 22
      expect(s.total, 4 + 1 + 0 - 22);
      expect(s.total, -17);
    });

    test('untimed (Checkout practice): no speed bonus and no overtime penalty', () {
      final slowAndLate = scoring.score(
        correct: true,
        complexity: 2,
        darts: 2,
        optimal: true,
        elapsed: const Duration(minutes: 5),
        timed: false,
      );
      expect(slowAndLate.timePenalty, 0);
      expect(slowAndLate.speedBonus, 0);
      expect(slowAndLate.total, scoring.basePoints(2) + scoring.config.optimalBonus);

      // However fast, an untimed answer earns no speed bonus either.
      final instant = scoring.score(
        correct: true, complexity: 2, darts: 2, optimal: false,
        elapsed: Duration.zero, timed: false,
      );
      expect(instant.speedBonus, 0);
      expect(instant.total, scoring.basePoints(2));
      // The same answer WITH a clock does get the bonus.
      final timedInstant = scoring.score(
        correct: true, complexity: 2, darts: 2, optimal: false, elapsed: Duration.zero,
      );
      expect(timedInstant.speedBonus, greaterThan(0));
    });

    test('a miss is a flat loss: overtime does not stack on top', () {
      final s = score(correct: false, complexity: 3, elapsed: const Duration(minutes: 1));
      expect(s.total, -5);
      expect(s.timePenalty, 0);
    });
  });

  group('AttemptTimer', () {
    late Duration now;
    late AttemptTimer timer;
    setUp(() {
      now = const Duration(seconds: 100);
      timer = AttemptTimer(() => now);
    });

    test('is zero before starting', () {
      expect(timer.elapsed, Duration.zero);
      expect(timer.isRunning, isFalse);
    });

    test('measures elapsed time from start', () {
      timer.start();
      now += const Duration(milliseconds: 4820);
      expect(timer.elapsed, const Duration(milliseconds: 4820));
      expect(timer.isRunning, isTrue);
    });

    test('start() on a running timer does not reset it (UI re-render safe)', () {
      timer.start();
      now += const Duration(seconds: 3);
      timer.start();
      timer.start();
      now += const Duration(seconds: 1);
      expect(timer.elapsed, const Duration(seconds: 4));
    });

    test('stop freezes the time and is idempotent', () {
      timer.start();
      now += const Duration(seconds: 2);
      expect(timer.stop(), const Duration(seconds: 2));
      now += const Duration(seconds: 10);
      expect(timer.stop(), const Duration(seconds: 2));
      expect(timer.elapsed, const Duration(seconds: 2));
      expect(timer.isStopped, isTrue);
    });

    test('restart begins a fresh measurement', () {
      timer.start();
      now += const Duration(seconds: 5);
      timer.stop();
      timer.restart();
      now += const Duration(seconds: 1);
      expect(timer.elapsed, const Duration(seconds: 1));
    });
  });
}
