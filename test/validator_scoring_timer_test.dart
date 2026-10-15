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

    test('72 = T18 + D9 is correct and equally optimal (a treble of 15 or more)', () {
      final r = validator.validate(c72, darts('T18 D9'));
      expect(r.isCorrect, isTrue);
      expect(r.isOptimal, isTrue);
    });

    test('72 = T14 + D15 is correct but not optimal (T14 is a silly aim)', () {
      final r = validator.validate(c72, darts('T14 D15'));
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

    test('a miscount has an equation: 142 entered as T20 T20 D16 is 60 + 60 + 32 = 152', () {
      final c142 = catalog.forTarget(142)!;
      final r = validator.validate(c142, darts('T20 T20 D16'));
      expect(r.outcome, AttemptOutcome.wrongTotal);
      expect(r.playerRoute.arithmetic, '60 + 60 + 32 = 152');
    });

    test('only a miscount is wrongTotal: a right total on a non-double is not', () {
      final r = validator.validate(c72, darts('T18 S18'));
      expect(r.outcome, AttemptOutcome.invalidFinish);
      expect(r.outcome, isNot(AttemptOutcome.wrongTotal));
      expect(validator.validate(c72, darts('T20 D6')).outcome, AttemptOutcome.correct);
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

    test('67 with the first box used: the bull-safe T17 D8 and S17 Bull are optimal', () {
      final c = catalog.forTarget(67)!;
      expect(c.dartCount, 2);
      expect(c.layout, BoxLayout.leftUsed);
      expect(validator.validate(c, darts('T17 D8')).isOptimal, isTrue);
      expect(validator.validate(c, darts('S17 Bull')).isOptimal, isTrue);
      final other = validator.validate(c, darts('T19 D5')); // 57 + 10 = 67
      expect(other.isCorrect, isTrue);
      expect(other.isOptimal, isFalse);
    });

    test('57: the bull-safe routes and a single that leaves a better double are optimal', () {
      final c = catalog.forTarget(57)!;
      expect(c.dartsLeft, 2);
      for (final text in ['T7 D18', 'S7 Bull', 'S17 D20']) {
        expect(validator.validate(c, darts(text)).isOptimal, isTrue, reason: text);
      }
      // The outer bull is too hard to hit to be an aim.
      expect(validator.validate(c, darts('25 D16')).isOptimal, isFalse);
      // S19 D19 checks 57 out, but D19 is not one of the better doubles.
      final r = validator.validate(c, darts('S19 D19'));
      expect(r.isCorrect, isTrue);
      expect(r.isOptimal, isFalse);
    });

    test('132: T20 D20 D16 and T20 T20 D6 are optimal, T19 25 Bull is not', () {
      final c = catalog.forTarget(132)!;
      expect(c.dartsLeft, 3);
      for (final text in ['T20 D20 D16', 'T20 T20 D6', 'D20 T20 D16']) {
        final r = validator.validate(c, darts(text));
        expect(r.isCorrect, isTrue, reason: text);
        expect(r.isOptimal, isTrue, reason: text);
      }
      final outerBull = validator.validate(c, darts('T19 25 Bull'));
      expect(outerBull.isCorrect, isTrue);
      expect(outerBull.isOptimal, isFalse);
    });

    test('109: after T19 (52 left) a single and a better double is optimal too', () {
      final c = catalog.forTarget(109)!;
      expect(c.dartsLeft, 3);
      for (final text in ['T19 S20 D16', 'T19 S2 Bull', 'T19 S12 D20', 'S20 T19 D16']) {
        final r = validator.validate(c, darts(text));
        expect(r.isCorrect, isTrue, reason: text);
        expect(r.isOptimal, isTrue, reason: text);
      }
    });

    test('170 accepts only T20 T20 Bull', () {
      final c = catalog.forTarget(170)!;
      expect(validator.validate(c, darts('T20 T20 Bull')).isOptimal, isTrue);
      expect(validator.validate(c, darts('T20 T20 D20')).outcome,
          AttemptOutcome.wrongTotal);
    });

    group('No checkout', () {
      final impossible = catalog.impossible.first; // 159

      test('the right answer on a number with no checkout', () {
        expect(impossible.hasCheckout, isFalse);
        final r = validator.validateNoCheckout(impossible);
        expect(r.outcome, AttemptOutcome.noCheckoutCorrect);
        expect(r.isCorrect, isTrue);
        expect(r.isOptimal, isTrue, reason: 'using no darts is the best there is');
      });

      test('pressed on a number that can be checked out: a miss', () {
        final r = validator.validateNoCheckout(catalog.forTarget(72)!);
        expect(r.outcome, AttemptOutcome.noCheckoutWrong);
        expect(r.isCorrect, isFalse);
        expect(r.message, contains('T20 D6'));
      });

      test('darts entered on a number with no checkout are wrong', () {
        final r = validator.validate(impossible, darts('T20 T20 D20'));
        expect(r.outcome, AttemptOutcome.noCheckoutMissed);
        expect(r.isCorrect, isFalse);
      });
    });
  });

  group('ScoringService (streak points)', () {
    const scoring = ScoringService();
    const inTime = Duration(seconds: 12);
    const late = Duration(seconds: -3);

    ScoreBreakdown score({bool correct = true, Duration timeLeft = inTime, int streak = 0}) =>
        scoring.score(correct: correct, timeLeft: timeLeft, streakBefore: streak);

    test('a correct checkout with time left scores the streak length', () {
      for (var streak = 0; streak < 10; streak++) {
        final s = score(streak: streak);
        expect(s.kind, ScoreKind.counted);
        expect(s.points, streak + 1, reason: 'checkout number ${streak + 1} in a row');
        expect(s.streakAfter, streak + 1);
      }
    });

    test('ten in a row: 1 + 2 + ... + 10', () {
      var streak = 0;
      var total = 0;
      for (var i = 0; i < 10; i++) {
        final s = score(streak: streak);
        total += s.total;
        streak = s.streakAfter;
      }
      expect(streak, 10);
      expect(total, 55);
      expect(score(streak: 9).points, 10);
    });

    test('a miss scores nothing, costs nothing and resets the streak', () {
      final s = score(correct: false, streak: 7);
      expect(s.kind, ScoreKind.miss);
      expect(s.isMistake, isTrue);
      expect(s.total, 0);
      expect(s.streakAfter, 0);
      expect(s.streakBefore, 7);
    });

    test('correct but after the clock ran out: no points, the streak is kept', () {
      final s = score(timeLeft: late, streak: 4);
      expect(s.kind, ScoreKind.late);
      expect(s.total, 0);
      expect(s.streakAfter, 4, reason: 'kept, but it did not grow');
    });

    test('exactly zero time left is too late; any time left counts', () {
      expect(score(timeLeft: Duration.zero, streak: 2).kind, ScoreKind.late);
      expect(score(timeLeft: const Duration(milliseconds: 1), streak: 2).total, 3);
    });

    test('the score never goes down', () {
      for (final correct in [true, false]) {
        for (final left in [inTime, late, Duration.zero]) {
          expect(score(correct: correct, timeLeft: left, streak: 5).total, greaterThanOrEqualTo(0));
        }
      }
    });

    test('every kind explains itself in plain sentences', () {
      expect(score(streak: 5).explain().join(' '), contains('6 points'));
      expect(score(streak: 0).explain().join(' '), contains('1 point.'));
      expect(score(timeLeft: late, streak: 4).explain().join(' '), contains('streak of 4 is kept'));
      expect(score(correct: false, streak: 3).explain().join(' '), contains('starts again from 0'));
      expect(ScoreBreakdown.none.explain().join(' '), contains('replay'));
    });

    test('the clock still counts down from 30 seconds', () {
      expect(scoring.config.timeLimit, const Duration(seconds: 30));
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
