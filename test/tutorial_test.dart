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
    test('Learn: digits make the number, from 2 to 170', () {
      final session = TutorialSession(tutor, random: Random(1));
      expect(session.learnCard, isNull);
      session.typeDigit(0); // no leading zero
      expect(session.learnDigits, '');
      session
        ..typeDigit(1)
        ..typeDigit(2)
        ..typeDigit(7)
        ..typeDigit(4); // three digits at the most
      expect(session.learnTarget, 127);
      // The card waits until the typing stops.
      expect(session.learnCard, isNull);
      session.showTypedNumber();
      expect(session.learnCard!.aims, [d('T20')]);
      session.learnDarts = 2;
      expect(session.learnCard!.darts, 2);
      session.deleteDigit();
      expect(session.learnTarget, 12);
      session
        ..deleteDigit()
        ..deleteDigit();
      expect(session.learnTarget, isNull);
    });

    test('Practice: every question can be checked out; it is played out with every dart', () {
      final session = TutorialSession(tutor, random: Random(7));
      for (var i = 0; i < 200; i++) {
        session.newQuestion();
        expect(session.practiceCard.route, isNotNull, reason: '${session.practiceTarget}');
        expect(session.thrown, isEmpty);
        expect(session.practiceRight, isNull);
      }
    });

    test('Practice: the table route is right, shown once it is played out; undo takes a dart back', () {
      final session = TutorialSession(tutor, random: Random(3))
        ..practiceTarget = 127
        ..practiceDarts = 3
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
      session.undoPractice(); // played out: it stays
      expect(session.thrown, hasLength(3));
      session.newQuestion();
      expect(session.thrown, isEmpty);
    });

    test('Practice: a route that finishes early is right when the table says so; a bust is not', () {
      final early = TutorialSession(tutor, random: Random(3))
        ..practiceTarget = 64
        ..practiceDarts = 3
        ..throwPractice(d('T16'))
        ..throwPractice(d('D8'));
      expect(early.practiceDone, isTrue);
      expect(early.practiceRight, isTrue);
      final bust = TutorialSession(tutor, random: Random(3))
        ..practiceTarget = 40
        ..practiceDarts = 2
        ..throwPractice(d('T20'));
      expect(bust.practiceDone, isTrue);
      expect(bust.practiceRight, isFalse);
    });

    test('a target almost as good is right too', () {
      final session = TutorialSession(tutor, random: Random(3))
        ..practiceTarget = 62
        ..practiceDarts = 3
        ..throwPractice(d('T18'))
        ..throwPractice(d('D4'));
      expect(session.practiceRight, isTrue);
    });

    test('the bull area: 65 with three darts is 25 D20 or Bull S7 D4, both hits', () {
      final card = tutor.card(65, 3)!;
      expect(card.aims, [DartThrow.outerBull, DartThrow.bull]);
      expect(card.misses, isEmpty);
      expect(card.hits.map((h) => card.routeOf(h)!.notation), ['25 D20', 'Bull S7 D4']);
    });
  });
}
