import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

DartThrow d(String text) => DartThrow.parse(text);

void main() {
  final tutor = CheckoutTutor(OptimalRouteService(CheckoutEngine()));

  group('the tutorial card', () {
    test('127 with three darts: T20, as S20 still leaves T19 Bull; not T19, as S19 leaves 108', () {
      final card = tutor.card(127, 3)!;
      expect(card.aims, [d('T20')]);
      expect(card.route!.notation, 'T20 T17 D8');
      expect(card.hits.single.left, 67);
      expect(card.hits.single.route!.notation, 'T17 D8');
      expect(card.misses.single.dart, d('S20'));
      expect(card.misses.single.left, 107);
      expect(card.misses.single.route!.notation, 'T19 Bull');
      expect(card.whyNot, d('T19'));
      expect(card.whyNotMisses.single.left, 108);
      expect(card.whyNotMisses.single.hasCheckout, isFalse);
    });

    test('48 with two darts: between S16 and S8, a hit each', () {
      final card = tutor.card(48, 2)!;
      expect(card.aims, [d('S16'), d('S8')]);
      expect(card.hits.map((h) => h.route!.notation), ['D16', 'D20']);
      expect(card.misses, isEmpty);
      expect(card.whyNot, isNull);
    });

    test('why not only where a miss changes the outcome: not on 100, not on 149', () {
      expect(tutor.card(100, 3)!.whyNot, isNull); // S20 and S19 both still leave a checkout
      expect(tutor.card(149, 3)!.whyNot, isNull); // S20 and S19 both leave none
      expect(tutor.card(61, 2)!.whyNot, d('T19')); // S11 leaves the Bull, S19 leaves 42
      final engine = CheckoutEngine();
      var cards = 0, withWhy = 0;
      for (final target in engine.checkoutableTargets) {
        for (var darts = engine.minimumDarts(target)!; darts <= 3; darts++) {
          cards++;
          if (tutor.card(target, darts)!.whyNot != null) withWhy++;
        }
      }
      expect(withWhy, lessThan(cards ~/ 5), reason: 'most numbers have none');
    });

    test('149 with three darts: T19 first is right too - S20 and S19 both leave no checkout', () {
      expect(tutor.isRight(149, 3, d('T19')), isTrue);
      expect(tutor.isRight(149, 3, d('T20')), isTrue);
      // 127: T19 is no part of the route, and S19 leaves 108.
      expect(tutor.isRight(127, 3, d('T19')), isFalse);
    });

    test('why not is only ever a sensible aim: no low triple, no double that does not finish', () {
      final engine = CheckoutEngine();
      for (final target in engine.checkoutableTargets) {
        for (var darts = engine.minimumDarts(target)!; darts <= 3; darts++) {
          final other = tutor.card(target, darts)!.whyNot;
          if (other == null) continue;
          expect(ChoiceAdvisor.isNaturalAim(other) || other.score == target, isTrue, reason: '$target $darts $other');
        }
      }
    });

    test('the targets almost as good are on the card: 62 with three darts, T14 and T18', () {
      final card = tutor.card(62, 3)!;
      expect(card.aims, [d('T10')]);
      expect(card.alsoGood, containsAll([d('T14'), d('T18')]));
    });

    test('one dart: a double checks out; with no checkout, a setup for the next visit', () {
      final forty = tutor.card(40, 1)!;
      expect(forty.hits.single.checkedOut, isTrue);
      expect(forty.misses.single.dart, d('S20'));
      final fortyOne = tutor.card(41, 1)!;
      expect(fortyOne.route, isNull);
      expect(fortyOne.aims, [d('S9')]);
      expect(fortyOne.hits.single.left, 32);
      expect(fortyOne.whyNot, isNull);
    });

    test('a miss is the single of a triple or a double, the neighbours of a single, 25 for the Bull', () {
      expect(CheckoutTutor.missesOf(d('T20')), [d('S20')]);
      expect(CheckoutTutor.missesOf(d('D16')), [d('S16')]);
      expect(CheckoutTutor.missesOf(d('S20')), [d('S5'), d('S1')]);
      expect(CheckoutTutor.missesOf(DartThrow.bull), [DartThrow.outerBull]);
      expect(CheckoutTutor.missesOf(DartThrow.outerBull), isEmpty);
    });

    test('a bust is a bust: 40 with one dart, S20 would leave 20 with none', () {
      expect(tutor.outcome(40, 2, d('T20')).bust, isTrue);
      expect(tutor.outcome(20, 1, d('S19')).bust, isTrue); // leaves 1
      expect(tutor.outcome(20, 1, d('S20')).bust, isTrue); // zero without a double
    });

    test('a miss into single: a treble or a double into its single, the Bull into 25; none for a single', () {
      expect(CheckoutTutor.missIntoSingle(d('T20')), d('S20'));
      expect(CheckoutTutor.missIntoSingle(d('D16')), d('S16'));
      expect(CheckoutTutor.missIntoSingle(DartThrow.bull), DartThrow.outerBull);
      expect(CheckoutTutor.missIntoSingle(d('S16')), isNull);
      expect(CheckoutTutor.missIntoSingle(DartThrow.outerBull), isNull);
      // 127 with three darts: T20 missed into S20 leaves 107, still T19 Bull.
      final miss = tutor.firstMiss(127, 3, CheckoutRoute([d('T20'), d('T17'), d('D8')]))!;
      expect(miss.left, 107);
      expect(miss.route!.notation, 'T19 Bull');
      expect(tutor.firstMiss(48, 2, CheckoutRoute([d('S16'), d('D16')])), isNull);
    });

    test('the neighbours of a number as the board hangs: the one further left first', () {
      String sides(String dart) {
        final (left, right) = CheckoutTutor.sideNeighbours(d(dart))!;
        return '${left.notation} ${right.notation}';
      }

      expect(sides('S16'), 'S8 S7'); // 48: S8 leaves 40, S7 leaves 41
      expect(sides('S20'), 'S5 S1');
      expect(sides('S3'), 'S19 S17');
      expect(sides('S6'), 'S13 S10'); // as far left: the higher one first
      expect(sides('S11'), 'S14 S8');
      expect(sides('T20'), 'S5 S1'); // a treble or a double too
      expect(sides('D16'), 'S8 S7');
      expect(CheckoutTutor.sideNeighbours(DartThrow.outerBull), isNull);
      expect(CheckoutTutor.sideNeighbours(DartThrow.bull), isNull);
    });

    test('the other bed of the number: T18 and S18 swap, the double into its single, Bull and 25 swap', () {
      expect(CheckoutTutor.singleOrTriple(d('T18')), d('S18'));
      expect(CheckoutTutor.singleOrTriple(d('S18')), d('T18'));
      expect(CheckoutTutor.singleOrTriple(d('D16')), d('S16'));
      expect(CheckoutTutor.singleOrTriple(DartThrow.bull), DartThrow.outerBull);
      expect(CheckoutTutor.singleOrTriple(DartThrow.outerBull), DartThrow.bull);
      // 48 with two darts, S16 D16: T16 instead leaves no checkout (bust).
      expect(tutor.outcome(48, 2, d('T16')).bust, isTrue);
    });

    test('the review of a Practice checkout: optimal, good (and why) or wrong', () {
      CheckoutRoute r(String text) => CheckoutRoute([for (final t in text.split(' ')) d(t)]);
      final optimal = tutor.review(127, 3, r('T20 T17 D8'), correct: true, optimal: true);
      expect(optimal.kind, ReviewKind.optimal);
      expect(optimal.miss!.left, 107);
      // T19 T10 D20 checks out, but S19 leaves 108; on T20 S20 leaves T19 Bull.
      final good = tutor.review(127, 3, r('T19 T10 D20'), correct: true, optimal: false);
      expect(good.kind, ReviewKind.good);
      expect(good.reason, GoodReason.missKeepsCheckout);
      expect(good.miss!.hasCheckout, isFalse);
      expect(good.optimalMiss!.hasCheckout, isTrue);
      // 100 with three darts the long way: the optimal routes need two.
      final longer = tutor.review(100, 3, r('S20 T20 D10'), correct: true, optimal: false);
      expect(longer.reason, GoodReason.fewerDarts);
      expect(longer.fewestDarts, 2);
      final wrong = tutor.review(100, 2, r('T20 D10'), correct: false, optimal: false);
      expect(wrong.kind, ReviewKind.wrong);
    });

    test('every number with a checkout has a card for every darts in hand it can be done with', () {
      final engine = CheckoutEngine();
      for (final target in engine.checkoutableTargets) {
        for (var darts = engine.minimumDarts(target)!; darts <= 3; darts++) {
          final card = tutor.card(target, darts);
          expect(card?.route, isNotNull, reason: '$target with $darts');
          expect(card!.hits, isNotEmpty);
        }
      }
    });
  });

  group('the tutorial session', () {
    final engine = CheckoutEngine();
    final optimal = OptimalRouteService(engine);
    final catalog = CheckoutCatalog(engine, optimal);
    TutorialSession newSession(int seed) => TutorialSession(tutor,
        generator: ChallengeGenerator(catalog, random: Random(seed)),
        validator: CheckoutValidator(engine, optimal),
        random: Random(seed));
    // [target] played with [darts] darts, as the calculator deals it.
    Challenge challenge(int target, int darts) {
      final dealt = catalog.forTarget(target)!;
      return dealt.darts == darts ? dealt : dealt.withDarts(darts, optimal.optimalRoutesIn(target, darts).first);
    }

    test('Input: digits make the number, from 2 to 170, and every part shows it', () {
      final clock = DateTime(2026);
      final session = TutorialSession(tutor,
          generator: ChallengeGenerator(catalog, random: Random(1)),
          validator: CheckoutValidator(engine, optimal),
          random: Random(1),
          now: () => clock);
      // Input starts on the Practice question; Learn has its darts.
      final question = session.practiceTarget;
      expect(session.typedTarget, question);
      expect(session.learnDarts, session.practiceDarts);
      // The first digit typed starts a new number.
      session.typeDigit(0); // no leading zero
      expect(session.typedDigits, '');
      session.typeDigit(1); // 1: not a number to play, the question stays
      expect(session.shownTarget, question);
      session
        ..typeDigit(2)
        ..typeDigit(7)
        ..typeDigit(4); // three digits at the most
      expect(session.typedTarget, 127);
      // At once the number of Practice, Learn and Favorites.
      expect(session.shownTarget, 127);
      expect(session.practiceTarget, 127);
      expect(session.thrown, isEmpty);
      session.learnDarts = 3;
      expect(session.learnCard!.aims, [d('T20')]);
      session.learnDarts = 2;
      expect(session.learnCard!.darts, 2);
      session.deleteDigit();
      expect(session.shownTarget, 12);
      session
        ..deleteDigit()
        ..deleteDigit();
      expect(session.typedTarget, isNull);
      expect(session.shownTarget, 12); // the last number stays
      // A new question is in Input too, and the next digit starts afresh.
      session.newQuestion();
      expect(session.typedTarget, session.practiceTarget);
      expect(session.learnDarts, session.practiceDarts);
      session.typeDigit(4);
      expect(session.typedDigits, '4');
    });

    test('Input: 3 seconds after the last key, the next digit starts a new number', () {
      var clock = DateTime(2026);
      final session = TutorialSession(tutor,
          generator: ChallengeGenerator(catalog, random: Random(2)),
          validator: CheckoutValidator(engine, optimal),
          random: Random(2),
          now: () => clock);
      session
        ..typeDigit(1)
        ..typeDigit(0);
      clock = clock.add(const Duration(seconds: 2)); // still typing
      session.typeDigit(2);
      expect(session.typedDigits, '102');
      // Off to Practice and Learn, back after more than 3 seconds: 4 is a new number.
      clock = clock.add(const Duration(seconds: 3));
      session.typeDigit(4);
      expect(session.typedDigits, '4');
      expect(session.shownTarget, 4);
      session.typeDigit(0);
      expect(session.typedDigits, '40');
      // UNDO counts as a key: what is left can be typed on.
      clock = clock.add(const Duration(seconds: 5));
      session.deleteDigit();
      session.typeDigit(1);
      expect(session.typedDigits, '41');
      // A number with no checkout is played too: "No checkout" is the answer.
      clock = clock.add(const Duration(seconds: 3));
      session
        ..typeDigit(1)
        ..typeDigit(6)
        ..typeDigit(9);
      expect(session.practice.hasCheckout, isFalse);
      expect(session.learnCard, isNull);
    });

    test('Practice deals as Checkout calculator: now and then a number with no checkout', () {
      final session = newSession(7);
      var none = 0;
      for (var i = 0; i < 400; i++) {
        session.newQuestion();
        expect(session.thrown, isEmpty);
        expect(session.practiceRight, isNull);
        if (!session.practice.hasCheckout) none++;
      }
      expect(none, greaterThan(0));
    });

    test('Practice: the table route is optimal, judged with the last dart; undo takes a dart back', () {
      final session = newSession(3)
        ..play(challenge(127, 3))
        ..throwPractice(d('T20'))
        ..throwPractice(d('T19'));
      expect(session.practiceDone, isFalse);
      session.undoPractice(); // pressed the wrong one
      expect(session.thrown, [d('T20')]);
      session
        ..throwPractice(d('T17'))
        ..throwPractice(d('D8'));
      expect(session.practiceDone, isTrue);
      expect(session.practiceRight, isTrue);
      expect(session.result!.optimalRoutes, isNotEmpty);
      session.undoPractice(); // judged: it stays
      expect(session.thrown, hasLength(3));
      // Replay: the same number from the first dart.
      session.replay();
      expect(session.thrown, isEmpty);
      expect(session.practiceTarget, 127);
      session.newQuestion();
      expect(session.thrown, isEmpty);
    });

    test('Practice: as in the calculator, darts that add up end it early; a bust uses every box', () {
      final early = newSession(3)
        ..play(challenge(64, 3))
        ..throwPractice(d('T16'))
        ..throwPractice(d('D8'));
      expect(early.practiceDone, isTrue);
      expect(early.result!.isCorrect, isTrue);
      final bust = newSession(3)
        ..play(challenge(40, 1))
        ..throwPractice(d('S20'));
      expect(bust.practiceDone, isTrue);
      expect(bust.practiceRight, isFalse);
    });

    test('Practice: a two-dart number switches between two and three darts, before the first dart', () {
      final session = newSession(3)..play(challenge(100, 2));
      expect(session.canChooseDarts, isTrue);
      session.chooseOtherDarts();
      expect(session.practiceDarts, 3);
      expect(session.learnDarts, 3);
      session.chooseOtherDarts();
      expect(session.practiceDarts, 2);
      session.throwPractice(d('T20'));
      expect(session.canChooseDarts, isFalse, reason: 'not once a dart is thrown');
      // One-dart and three-dart numbers have no choice.
      expect((newSession(3)..play(challenge(40, 1))).canChooseDarts, isFalse);
      expect((newSession(3)..play(challenge(170, 3))).canChooseDarts, isFalse);
    });

    test('Practice: "No checkout" is right on a number with none', () {
      final session = newSession(3)..play(Challenge.noCheckout(169));
      session.pressNoCheckout();
      expect(session.result!.isNoCheckoutAnswer, isTrue);
      expect(session.result!.encouragement, isNotNull);
      final wrong = newSession(3)
        ..play(challenge(100, 2))
        ..pressNoCheckout();
      expect(wrong.result!.isCorrect, isFalse);
    });

    test('a target almost as good is right too', () {
      final session = newSession(3)
        ..play(challenge(62, 3))
        ..throwPractice(d('T18'))
        ..throwPractice(d('D4'));
      expect(session.practiceRight, isTrue);
    });

    test('Learn says what the Practice checkout was: nothing before it is played or on a right "No checkout"', () {
      final session = newSession(3)..play(challenge(127, 3));
      expect(session.practiceReview, isNull);
      session
        ..throwPractice(d('T19'))
        ..throwPractice(d('T10'))
        ..throwPractice(d('D20'));
      expect(session.practiceReview!.kind, ReviewKind.good);
      session
        ..replay()
        ..throwPractice(d('T20'))
        ..throwPractice(d('T17'))
        ..throwPractice(d('D8'));
      expect(session.practiceReview!.kind, ReviewKind.optimal);
      final none = newSession(3)
        ..play(Challenge.noCheckout(169))
        ..pressNoCheckout();
      expect(none.practiceReview, isNull);
      final missed = newSession(3)
        ..play(challenge(100, 2))
        ..pressNoCheckout();
      expect(missed.practiceReview!.kind, ReviewKind.wrong);
      expect(missed.practiceReview!.route.darts, isEmpty);
    });

    test('65 with three darts is 25 D20: two darts, not Bull S7 D4', () {
      final card = tutor.card(65, 3)!;
      expect(card.aims, [DartThrow.outerBull]);
      expect(card.misses, isEmpty);
      expect(card.route!.notation, '25 D20');
    });
  });
}
