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

    test('48 with two darts: between S16 and S8; not S20, as S5 and S1 leave no checkout', () {
      final card = tutor.card(48, 2)!;
      expect(card.aims, [d('S16'), d('S8')]);
      expect(card.hits.map((h) => h.route!.notation), ['D16', 'D20']);
      expect(card.misses, isEmpty);
      expect(card.whyNot, d('S20'));
      expect(card.whyNotMisses.map((m) => m.hasCheckout), [false, false]);
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

    test('Practice: every question can be checked out, and only the first press counts', () {
      final session = TutorialSession(tutor, random: Random(7));
      for (var i = 0; i < 200; i++) {
        session.newQuestion();
        expect(session.practiceCard.route, isNotNull, reason: '${session.practiceTarget}');
        expect(session.answer, isNull);
      }
      final right = session.practiceCard.aims.first;
      session.pressAnswer(right);
      expect(session.answerRight, isTrue);
      session.pressAnswer(d('S1'));
      expect(session.answer, right);
      session.newQuestion();
      expect(session.answerRight, isNull);
    });

    test('a target almost as good is right too', () {
      final session = TutorialSession(tutor, random: Random(3))
        ..practiceTarget = 62
        ..practiceDarts = 3
        ..pressAnswer(d('T18'));
      expect(session.answerRight, isTrue);
    });
  });
}
