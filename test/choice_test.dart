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

    test('order does not matter: both darts of a combination are optimal first', () {
      // 121 -> T20 T11 D14 and friends; T11 and T20 are both fine to throw first.
      final best = advisor.optimalDarts(121);
      expect(best, containsAll([d('T20'), d('T11'), d('T19'), d('T14')]));
    });

    test('the bull-safe routes stay optimal even with low trebles (55 -> T5 D20, S5 Bull)', () {
      // 55 also has the singles that leave a better double: S15 D20, S19 D18,
      // and the trebles whose single leaves a double too: T15 D5 (S15 D20) and
      // T17 D2 (S17 D19).
      expect(advisor.optimalDarts(55), {d('T5'), d('S5'), d('S15'), d('S19'), d('T15'), d('T17'), d('S17')});
    });

    group('priority: fewest darts, bull-safe, then the most singles', () {
      test('57: the bull-safe darts and the singles that leave a better double are lit', () {
        // T17 D3 is there too: S17 leaves D20, T17 leaves D3 (not a better one).
        expect(advisor.optimalDarts(57), {d('T7'), d('S7'), d('S17'), d('T17'), d('S19')});
        expect(advisor.optimalRoutes(57).map((r) => r.notation),
            ['T7 D18', 'S7 Bull', 'S17 D20', 'T17 D3', 'S19 D19']);
        // S19 D19 is there too: 19 and 7 are neighbours and S7 leaves the Bull.
        expect(advisor.optimalDarts(57), contains(d('S19')));
      });

      test('over 60 the bull-safe darts are lit, the outer bull on 61 and 65, and neighbour aims', () {
        expect(advisor.optimalDarts(65), {d('T15'), d('S15'), d('S25')});
        // 61: T19 leaves D2 and its neighbour T7 leaves D20.
        expect(advisor.optimalDarts(61), {d('T11'), d('S11'), d('S25'), d('T19'), d('T7')});
        expect(advisor.optimalDarts(67), {d('T17'), d('S17')}); // nothing extra here
      });

      test('65: the outer bull then D20 is optimal at every step', () {
        final r = ChoiceRound(65, advisor, layout: BoxLayout.leftUsed)
          ..throwDart(d('S25'))
          ..throwDart(d('D20'));
        expect(r.isCheckedOut, isTrue);
        expect(r.isOptimal, isTrue);
      });

      test('35 lights the singles, and the trebles whose single also leaves a double', () {
        final lit = advisor.optimalDarts(35);
        expect(lit, isNotEmpty);
        expect(lit, containsAll([d('S15'), d('S3'), d('S17')]));
        // T5 D10 with S5 D15: one of the two doubles is not a better one, still lit.
        expect(lit.where((x) => x.multiplier != Multiplier.single).toSet(),
            {d('T11'), d('T9'), d('T7'), d('T5'), d('T3'), d('T1')});
      });

      test('43: the triple of 11 is a good starting dart, its single leaves a checkout too', () {
        final r = ChoiceRound(43, advisor, layout: BoxLayout.leftUsed);
        expect(r.optimalDarts, containsAll([d('T11'), d('S11')]));
        expect(advisor.rate(remaining: 43, dartsLeft: 2, dart: d('T11')), DartQuality.optimal);
        r.throwDart(d('T11')); // leaves 10
        expect(r.remaining, 10);
        expect(r.optimalDarts, {d('D5')});
        r.throwDart(d('D5'));
        expect(r.isCheckedOut, isTrue);
        expect(r.isOptimal, isTrue);
      });

      test('58 lights the neighbours T6 and T10, but not T14 (nothing next to it leaves a double)', () {
        expect(advisor.optimalDarts(58), containsAll([d('T6'), d('T10')])); // D20 or D14
        expect(advisor.optimalDarts(58), contains(d('T8'))); // S8 leaves the Bull
        expect(advisor.optimalDarts(58), isNot(contains(d('T14'))));
      });

      test('no treble can do it with a single: trebles of 15 and up are lit (85, 150)', () {
        expect(advisor.optimalDarts(100), {d('T20')});
        expect(advisor.optimalDarts(150), {d('T18'), d('T19'), d('T20')});
      });

      test('a double or the Bull is only a lit setup dart on a chart route (82)', () {
        expect(advisor.optimalDarts(82), contains(d('Bull')));
        for (final target in engine.checkoutableTargets) {
          if (engine.minimumDarts(target) == 1) continue;
          for (final x in advisor.optimalDarts(target)) {
            if (x.multiplier == Multiplier.double) {
              expect(optimal.optimalRoutes(target).any((r) => r.setupDarts.contains(x)), isTrue,
                  reason: '$x lit as a setup dart on $target');
            }
          }
        }
      });

      test('121 lights the trebles and the singles that leave a finish', () {
        final lit = advisor.optimalDarts(121);
        expect(lit, containsAll([d('T20'), d('T11'), d('T19'), d('T14'), d('S11'), d('S14')]));
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

    test('85 with three darts (all have to be used)', () {
      for (final dart in advisor.optimalDartsIn(85, 3)) {
        expect(rate(85, dart.notation), DartQuality.optimal, reason: dart.notation);
      }
      // S15 is one - 15 is an aim (T15 leaves D20, S15 leaves 70); S20 is not
      // (T20 leaves 25), nor is a setup double like D10
      expect(rate(85, 'S15'), DartQuality.optimal);
      expect(rate(85, 'S20'), isNot(DartQuality.optimal));
      expect(rate(85, 'D10'), DartQuality.poor);
      // T3 is a silly dart
      expect(rate(85, 'T3'), DartQuality.poor);
      expect(rate(85, 'D2'), DartQuality.poor); // a setup double that is no part of a route
    });

    test('68 with three darts lights only its aims, S18 T18 to S6 T6 - not S19, S1, S2, S3 or S11', () {
      final first = advisor.nextOptimalDarts(68, 3, const []);
      expect(first, {
        for (final n in [18, 20, 16, 14, 12, 10, 6]) ...[d('S$n'), d('T$n')],
      });
      expect(advisor.optimalDartsIn(68, 3), first);
      expect(rate(68, 'S19'), isNot(DartQuality.optimal));
      // After S1 (no route has it) the darts of what is left light up: 67 is
      // T17 D8 or S17 Bull.
      expect(advisor.nextOptimalDarts(68, 3, [d('S1')]), {d('S17'), d('T17')});
    });

    test('a finishing double that checks out is optimal with the last dart; with darts left it is a miss', () {
      expect(rate(34, 'D17', left: 1), DartQuality.optimal);
      expect(rate(34, 'D17', left: 2), DartQuality.bust); // a dart still to throw
      expect(rate(34, 'D20', left: 2), DartQuality.bust); // below zero
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
      // Both darts have to be used: S14 then D10 is the way.
      expect(rate(34, 'S14', left: 2), DartQuality.optimal);
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

    test('85 with three darts: S15 then T10 then D20 is optimal at every step', () {
      final r = three(85)..throwDart(d('S15'));
      // S15 leaves 70, so what follows is the rest of 85's three-dart routes
      // with S15 in them: T10 (T10 S15 D20), and the routes of 70: T20 D5,
      // S20 Bull.
      expect(r.optimalDarts, containsAll([d('T10'), d('S20'), d('T20')]));
      r.throwDart(d('T10'));
      expect(r.optimalDarts, {d('D20')});
      r.throwDart(d('D20'));
      expect(r.isOptimal, isTrue);
    });

    test('93 with three darts: S19 leaves 74, then T20 D7 is optimal at every step', () {
      final r = three(93)..throwDart(d('S19'));
      expect(r.remaining, 74);
      expect(r.optimalDarts, contains(d('T20')));
      r.throwDart(d('T20'));
      expect(r.optimalDarts, contains(d('D7')));
      r.throwDart(d('D7'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
    });

    test('checking out with a dart still in hand is a miss: 64 with three darts, T16 D8', () {
      final r = three(64)
        ..throwDart(d('T16'))
        ..throwDart(d('D8'));
      expect(r.status, RoundStatus.finishedEarly);
      expect(r.isCheckedOut, isFalse);
      expect(r.isOptimal, isFalse);
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
      expect(r.optimalDarts, {d('T7'), d('S7'), d('S17'), d('T17'), d('S19')});
      r.throwDart(d('S7')); // leaves exactly 50
      expect(r.remaining, 50);
      r.throwDart(d('Bull'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
    });

    test('the treble of 7 works too: T7 then D18', () {
      final r = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('T7'))
        ..throwDart(d('D18'));
      expect(r.isOptimal, isTrue);
    });

    test('S17 then D20 checks 57 out and is optimal: a single that leaves a better double', () {
      final other = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S17'))
        ..throwDart(d('D20'));
      expect(other.isCheckedOut, isTrue);
      expect(other.isOptimal, isTrue);
      expect(other.steps.first.quality, DartQuality.optimal);
    });

    test('S19 then D19 checks 57 out and is optimal: 19 and 7 are neighbours, S7 leaves the Bull', () {
      final other = ChoiceRound(57, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S19'))
        ..throwDart(d('D19'));
      expect(other.isCheckedOut, isTrue);
      expect(other.isOptimal, isTrue);
      expect(other.steps.first.quality, DartQuality.optimal);
    });

    test('132: T20, D20, D16 is optimal at every step (the outer bull is no aim)', () {
      final r = ChoiceRound(132, advisor)
        ..throwDart(d('T20'))
        ..throwDart(d('D20'))
        ..throwDart(d('D16'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
      expect(r.steps.map((s) => s.quality), everyElement(DartQuality.optimal));
      expect(advisor.optimalDarts(132), isNot(contains(DartThrow.outerBull)));
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

    test('119 with three free: after T19 the bull-safe pair is lit', () {
      final r = ChoiceRound(119, advisor)..throwDart(d('T19'));
      expect(r.remaining, 62);
      // Only the rest of 119's own optimal routes that start with T19.
      expect(r.optimalDarts, {d('T12'), d('S12')});
      r.throwDart(d('S12'));
      r.throwDart(d('Bull'));
      expect(r.isOptimal, isTrue);
    });
  });
}
