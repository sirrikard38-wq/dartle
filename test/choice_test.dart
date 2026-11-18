import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

DartThrow d(String text) => DartThrow.parse(text);

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final advisor = ChoiceAdvisor(engine, optimal);

  group('ChoiceAdvisor - what is equally optimal', () {
    test('85 (two darts): T15, T17 and T19 are equally optimal first darts', () {
      final best = advisor.optimalDarts(85);
      expect(best, containsAll([d('T15'), d('T17'), d('T19')]));
      expect(best, isNot(contains(d('T3'))));
      expect(best, isNot(contains(d('S15'))));
      expect(best, isNot(contains(d('Bull'))));
    });

    test('85: the equally optimal routes are all the two-dart ones', () {
      final routes = advisor.optimalRoutes(85).map((r) => r.notation).toSet();
      expect(routes, containsAll(['T15 D20', 'T17 D17', 'T19 D14']));
      expect(routes.every((r) => r.split(' ').length == 2), isTrue);
    });

    test('a number one dart can finish: only its double is optimal', () {
      expect(advisor.optimalDarts(34), {d('D17')});
      expect(advisor.optimalDarts(50), {d('Bull')});
      expect(advisor.optimalDarts(40), {d('D20')});
    });

    test('121 lights the table\'s T20, T17 almost as good, and T11 of the route (S11 still leaves T20 Bull)', () {
      expect(advisor.optimalDarts(121), {d('T20'), d('T17'), d('T11')});
    });

    test('55 lights S15 and S19, almost as good', () {
      expect(advisor.optimalDarts(55), {d('S15'), d('S19')});
    });

    group('the checkout table of the number and the darts in hand', () {
      test('57 lights S17 only', () {
        expect(advisor.optimalDarts(57), {d('S17')});
        expect(advisor.optimalRoutes(57).map((r) => r.notation), ['S17 D20']);
      });

      test('61 to 70 with two darts light the triple: 61 T11, 65 T15, 67 T17', () {
        expect(advisor.optimalDarts(65), {d('T15')});
        expect(advisor.optimalDarts(61), {d('T11')});
        expect(advisor.optimalDarts(67), {d('T17')});
      });

      test('65: the outer bull then D20 checks out, but it is not optimal any more', () {
        final r = ChoiceRound(65, advisor, layout: BoxLayout.leftUsed)
          ..throwDart(d('S25'))
          ..throwDart(d('D20'));
        expect(r.isCheckedOut, isTrue);
        expect(r.isOptimal, isFalse);
      });

      test('35 lights its three neighbouring singles, and no triple', () {
        expect(advisor.optimalDarts(35), {d('S19'), d('S7'), d('S3')});
      });

      test('48 lights the neighbours S16 and S8: S8 then D20 is optimal', () {
        expect(advisor.optimalDarts(48), {d('S8'), d('S16')});
        final r = ChoiceRound(48, advisor, layout: BoxLayout.leftUsed)..throwDart(d('S8'));
        expect(r.remaining, 40);
        expect(r.optimalDarts, {d('D20')});
        r.throwDart(d('D20'));
        expect(r.isCheckedOut, isTrue);
        expect(r.isOptimal, isTrue);
      });

      test('58 lights S18, nothing else', () {
        expect(advisor.optimalDarts(58), {d('S18')});
      });

      test('100 lights T20; 150 T20, T19 and T18 of the route (S20 and S18 both leave no checkout)', () {
        expect(advisor.optimalDarts(100), {d('T20')});
        expect(advisor.optimalDarts(150), {d('T20'), d('T19'), d('T18')});
      });

      test('a double is a lit setup dart where the table says so: 72 lights T16, D20 and D18', () {
        expect(advisor.optimalDarts(72), {d('T16'), d('D20'), d('D18')});
      });

      test('every lit dart starts an optimal route', () {
        for (final target in engine.checkoutableTargets) {
          for (final x in advisor.optimalDarts(target)) {
            expect(optimal.optimalRoutes(target).any((r) => r.darts.first == x || r.setupDarts.contains(x)),
                isTrue, reason: '$x lit on $target');
          }
        }
      });
    });

    test('impossible numbers have nothing optimal', () {
      expect(advisor.optimalDarts(169), isEmpty);
      expect(advisor.optimalRoutes(1), isEmpty);
    });

    test('every optimal dart really leads to a fewest-darts finish', () {
      for (final target in engine.checkoutableTargets) {
        final minimum = engine.minimumDarts(target)!;
        final best = advisor.optimalDarts(target);
        expect(best, isNotEmpty, reason: '$target');
        for (final dart in best) {
          if (minimum == 1) {
            expect(dart.score, target);
            expect(dart.isFinishingDart, isTrue);
          } else {
            final after = target - dart.score;
            expect(engine.minimumDarts(after), minimum - 1,
                reason: '$dart on $target leaves $after');
          }
        }
      }
    });
  });

  group('ChoiceAdvisor - rating a dart', () {
    DartQuality rate(int remaining, String dart, {int left = 3}) =>
        advisor.rate(remaining: remaining, dartsLeft: left, dart: d(dart));

    test('85 with two darts', () {
      expect(rate(85, 'T17', left: 2), DartQuality.optimal);
      expect(rate(85, 'T15', left: 2), DartQuality.optimal);
      expect(rate(85, 'T19', left: 2), DartQuality.optimal);
      // 70 cannot be finished with the one dart left
      expect(rate(85, 'S15', left: 2), DartQuality.poor);
      expect(rate(85, 'T3', left: 2), DartQuality.poor);
      expect(rate(85, 'D20', left: 2), DartQuality.poor); // non-finishing double
    });

    test('85 with three darts: the table\'s T15 and T19', () {
      expect(advisor.optimalDartsIn(85, 3), {d('T15'), d('T19')});
      expect(rate(85, 'T15'), DartQuality.optimal);
      expect(rate(85, 'S20'), isNot(DartQuality.optimal));
      expect(rate(85, 'D10'), DartQuality.poor); // a setup double the table does not use
      expect(rate(85, 'T3'), DartQuality.poor); // a silly dart
    });

    test('after a dart, the table of what is left with the darts left: 68 with three, S1, then 67 is T17', () {
      expect(advisor.optimalDartsIn(68, 3), {d('T12'), d('T20'), d('T16')});
      expect(advisor.nextOptimalDarts(68, 3, [d('S1')]), {d('T17')});
      // 127: T20, then 67 with two darts.
      expect(advisor.nextOptimalDarts(127, 3, [d('T20')]), {d('T17')});
      // 64 with three: D12 leaves 40 with two darts, so D20.
      expect(advisor.nextOptimalDarts(64, 3, [d('D12')]), {d('D20')});
    });

    test('47 with three darts: S7, S15 or S19; after S7, D20; after S7 and S20, D10', () {
      expect(advisor.optimalDartsIn(47, 3), {d('S7'), d('S15'), d('S19')});
      expect(advisor.nextOptimalDarts(47, 3, [d('S7')]), {d('D20')});
      expect(advisor.nextOptimalDarts(47, 3, [d('S7'), d('S20')]), {d('D10')});
    });

    test('a lit double checks out with darts left; an unlit finish with darts left is a miss', () {
      expect(rate(34, 'D17', left: 1), DartQuality.optimal);
      expect(rate(34, 'D17', left: 2), DartQuality.optimal); // 34 with two darts: D17
      expect(rate(34, 'D20', left: 2), DartQuality.bust); // below zero
      expect(advisor.rate(remaining: 50, dartsLeft: 2, dart: DartThrow.bull), DartQuality.bust);
      expect(advisor.rate(remaining: 40, dartsLeft: 2, dart: d('D20'), best: {d('S20')}),
          DartQuality.bust);
    });

    test('a setup the table gives for the next visit is optimal: 41 with one dart, S9', () {
      expect(advisor.optimalDartsIn(41, 1), {d('S9')});
      expect(rate(41, 'S9', left: 1), DartQuality.optimal);
    });

    test('zero without a double is a bust; leaving 1 is a bust', () {
      expect(rate(20, 'S20'), DartQuality.bust); // zero, but not a double
      expect(rate(20, 'S19'), DartQuality.bust); // leaves 1
      expect(rate(20, 'T7'), DartQuality.bust); // below zero
    });

    test('a dart that leaves too many darts needed is poor', () {
      // After T17 on 85 with three darts, 34 is left with two. S17 leaves 17,
      // which needs two darts but only one is left.
      expect(rate(34, 'S17', left: 2), DartQuality.poor);
      // S14 still checks out (D10), but the table says D17 straight away.
      expect(rate(34, 'S14', left: 2), DartQuality.fine);
    });
  });

  group('ChoiceRound', () {
    // Played with the fewest darts, as the game deals it.
    ChoiceRound round(int target) => ChoiceRound(target, advisor,
        layout: BoxLayout.defaultFor(engine.minimumDarts(target)!));
    // A two-dart number with all three boxes free: every dart has to be used.
    ChoiceRound three(int target) => ChoiceRound(target, advisor);

    test('85: T17 then D17 checks out in the fewest darts', () {
      final r = round(85);
      r.throwDart(d('T17'));
      expect(r.remaining, 34);
      expect(r.status, RoundStatus.inProgress);
      r.throwDart(d('D17'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
      expect(r.steps.map((s) => s.quality), [DartQuality.optimal, DartQuality.optimal]);
    });

    test('the remaining number updates after every dart', () {
      final r = three(85);
      expect(r.remaining, 85);
      r.throwDart(d('S15'));
      expect(r.remaining, 70);
      r.throwDart(d('S20'));
      expect(r.remaining, 50);
      expect(r.dartsLeft, 1);
      r.throwDart(d('Bull'));
      expect(r.status, RoundStatus.checkedOut);
    });

    test('D10 S15 Bull checks 85 out with three darts but is not optimal (a setup double)', () {
      final r = three(85);
      for (final t in ['D10', 'S15', 'Bull']) {
        r.throwDart(d(t));
      }
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isFalse);
      expect(r.steps.first.quality, DartQuality.poor);
    });

    test('85 with three darts: T15 then D20 with a dart in hand is optimal', () {
      final r = three(85)..throwDart(d('T15'));
      expect(r.optimalDarts, {d('D20')});
      r.throwDart(d('D20'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
    });

    test('64 with three darts: T16 D8, the table\'s route, is optimal with a dart in hand', () {
      final r = three(64)
        ..throwDart(d('T16'))
        ..throwDart(d('D8'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
    });

    test('an unlit finish with a dart in hand is a miss: 50 with two darts, the Bull', () {
      final r = ChoiceRound(50, advisor, layout: BoxLayout.leftUsed)..throwDart(DartThrow.bull);
      expect(r.status, RoundStatus.finishedEarly);
      expect(r.isCheckedOut, isFalse);
      expect(r.steps.last.bustReason, contains('all of them have to be used'));
    });

    test('T3 first is rated poor even if it still checks out', () {
      final r = three(85);
      r.throwDart(d('T3')); // 85 - 9 = 76
      r.throwDart(d('T20')); // 16
      r.throwDart(d('D8'));
      expect(r.isCheckedOut, isTrue);
      expect(r.steps.first.quality, DartQuality.poor);
      expect(r.isOptimal, isFalse);
    });

    test('each step remembers the equally optimal choices it could have made', () {
      final r = round(85)..throwDart(d('S15'));
      expect(r.steps.single.optimalChoices, containsAll([d('T15'), d('T17'), d('T19')]));
      expect(r.steps.single.remainingBefore, 85);
    });

    test('a press anywhere on a number counts as its highlighted best dart', () {
      // 85: the highlighted darts are T15, T17 and T19.
      final best = advisor.optimalDarts(85);
      for (final (pressed, worth) in [
        ('T17', 'T17'), // the highlighted area itself
        ('S17', 'T17'), // pressed in the singles: still worth T17
        ('D17', 'T17'), // or in the doubles
        ('S15', 'T15'),
        ('S19', 'T19'),
        ('T3', 'T3'), // 3 has no highlighted dart: worth exactly what was tapped
        ('S3', 'S3'),
        ('Bull', 'Bull'),
        ('S20', 'S20'), // 20 has none either on 85
      ]) {
        expect(ChoiceAdvisor.resolveTap(best, d(pressed)).notation, worth, reason: pressed);
      }
    });

    test('a tapped area that is itself highlighted is used as it is', () {
      final best = {d('T20'), d('S20')};
      expect(ChoiceAdvisor.resolveTap(best, d('S20')), d('S20'));
      expect(ChoiceAdvisor.resolveTap(best, d('T20')), d('T20'));
      // D20 is not highlighted: it snaps to the higher-scoring highlighted 20.
      expect(ChoiceAdvisor.resolveTap(best, d('D20')), d('T20'));
    });

    test('the bull area snaps to a highlighted Bull', () {
      expect(ChoiceAdvisor.resolveTap({d('Bull')}, d('25')), d('Bull'));
      expect(ChoiceAdvisor.resolveTap({d('T20')}, d('25')), d('25'));
    });

    test('with no hints, a press is worth exactly what was tapped', () {
      expect(ChoiceAdvisor.resolveTap(const {}, d('S7')), d('S7'));
    });

    test('bust ends the round and keeps the score where it was', () {
      final r = round(34)..throwDart(d('D20'));
      expect(r.status, RoundStatus.bust);
      expect(r.remaining, 34);
      expect(r.steps.single.bustReason, contains('below zero'));
      r.throwDart(d('D17')); // ignored: round is over
      expect(r.steps, hasLength(1));
    });

    test('running out of darts ends the round', () {
      final r = round(100)
        ..throwDart(d('S1'))
        ..throwDart(d('S1'))
        ..throwDart(d('S1'));
      expect(r.status, RoundStatus.outOfDarts);
      expect(r.isCheckedOut, isFalse);
    });

    test('undo replays the round', () {
      final r = round(85)..throwDart(d('T17'));
      r.undo();
      expect(r.remaining, 85);
      expect(r.steps, isEmpty);
      r.throwDart(d('T19'));
      expect(r.remaining, 28);
    });

    test('every number can be checked out optimally by following the advice', () {
      for (final target in engine.checkoutableTargets) {
        final r = round(target);
        while (!r.isFinished) {
          final pick = (r.optimalDarts.toList()
                ..sort((a, b) => b.score.compareTo(a.score)))
              .first;
          r.throwDart(pick);
        }
        expect(r.isOptimal, isTrue, reason: '$target');
        expect(r.steps.length, engine.minimumDarts(target), reason: '$target');
      }
    });
  });

  group('ChoiceRound with crossed-out boxes', () {
    test('the free boxes are the darts: first box used leaves two', () {
      final r = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed);
      expect(r.maxDarts, 2);
      expect(r.dartsLeft, 2);
      expect(r.optimalDarts, {d('S17')});
      r.throwDart(d('S7')); // leaves exactly 50
      expect(r.remaining, 50);
      r.throwDart(d('Bull'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isFalse); // a checkout, but not the optimal way any more
    });

    test('61 with two darts: T11 then D14 is optimal; S11 then the Bull only checks out', () {
      final treble = ChoiceRound(61, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('T11'))
        ..throwDart(d('D14'));
      expect(treble.isOptimal, isTrue);
      final bull = ChoiceRound(61, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S11'))
        ..throwDart(d('Bull'));
      expect(bull.isCheckedOut, isTrue);
      expect(bull.isOptimal, isFalse);
    });

    test('S17 then D20 checks 57 out and is optimal: a single that leaves a better double', () {
      final other = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S17'))
        ..throwDart(d('D20'));
      expect(other.isCheckedOut, isTrue);
      expect(other.isOptimal, isTrue);
      expect(other.steps.first.quality, DartQuality.optimal);
    });

    test('S19 then D19 checks 57 out, but D19 is not a better double, so not optimal', () {
      final other = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S19'))
        ..throwDart(d('D19'));
      expect(other.isCheckedOut, isTrue);
      expect(other.isOptimal, isFalse);
      expect(other.steps.first.quality, DartQuality.fine);
    });

    test('47 with three darts: S7, then D20 with a dart in hand is checked out and optimal', () {
      final r = ChoiceRound(47, advisor)
        ..throwDart(d('S7'))
        ..throwDart(d('D20'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
    });

    test('47 with three darts: the double missed into S20, then D10 checks out', () {
      final r = ChoiceRound(47, advisor)
        ..throwDart(d('S7'))
        ..throwDart(d('S20'));
      expect(r.isFinished, isFalse);
      expect(r.optimalDarts, {d('D10')});
      r.throwDart(d('D10'));
      expect(r.isCheckedOut, isTrue);
      expect(r.steps.map((s) => s.quality), [DartQuality.optimal, DartQuality.fine, DartQuality.optimal]);
    });

    test('47 with three darts: S19 is almost as good, so S19 then D14 is optimal', () {
      final r = ChoiceRound(47, advisor)
        ..throwDart(d('S19'))
        ..throwDart(d('D14'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
    });

    test('88 with three darts: T20, then D14 with a dart in hand, as the table says', () {
      final r = ChoiceRound(88, advisor)
        ..throwDart(d('T20'))
        ..throwDart(d('D14'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isTrue);
    });

    test('132: the Bull, T14, D20 is optimal at every step', () {
      expect(advisor.optimalDarts(132), {DartThrow.bull, DartThrow.outerBull});
      final r = ChoiceRound(132, advisor)
        ..throwDart(DartThrow.bull)
        ..throwDart(d('T14'))
        ..throwDart(d('D20'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
      expect(r.steps.map((s) => s.quality), everyElement(DartQuality.optimal));
    });

    test('109: T19, S20, D16 is optimal at every step (52 left, then a single and D16)', () {
      final r = ChoiceRound(109, advisor)
        ..throwDart(d('T19'))
        ..throwDart(d('S20'))
        ..throwDart(d('D16'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
      expect(r.steps.map((s) => s.quality), everyElement(DartQuality.optimal));
    });

    test('a one-dart number has one free box', () {
      final r = ChoiceRound(40, advisor, layout: BoxLayout.leftTwoUsed);
      expect(r.maxDarts, 1);
      expect(r.optimalDarts, {d('D20')});
      r.throwDart(d('D20'));
      expect(r.isCheckedOut && r.isOptimal, isTrue);
    });

    test('with fewer free boxes you run out of darts sooner', () {
      final r = ChoiceRound(85, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S1'))
        ..throwDart(d('S1'));
      expect(r.status, RoundStatus.outOfDarts);
    });

    test('119 with three free: after T19, 62 with two darts is T12, then D13', () {
      final r = ChoiceRound(119, advisor)..throwDart(d('T19'));
      expect(r.remaining, 62);
      expect(r.optimalDarts, {d('T12')});
      r.throwDart(d('T12'));
      r.throwDart(d('D13'));
      expect(r.isOptimal, isTrue);
    });
  });
}
