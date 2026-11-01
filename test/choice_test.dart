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

    test('55 lights the singles that leave a better double and their misses, no Bull', () {
      expect(advisor.optimalDarts(55), {d('S15'), d('S19'), d('T15')});
    });

    group('priority: fewest darts, then the rule of the number', () {
      test('57 lights S17 only: the single that leaves a better double', () {
        expect(advisor.optimalDarts(57), {d('S17')});
        expect(advisor.optimalRoutes(57).map((r) => r.notation), ['S17 D20']);
      });

      test('over 60 up to 70 the bull-safe darts are lit and nothing else', () {
        expect(advisor.optimalDarts(65), {d('T15'), d('S15')});
        expect(advisor.optimalDarts(61), {d('T11'), d('S11')});
        expect(advisor.optimalDarts(67), {d('T17'), d('S17')});
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

      test('48 lights the neighbours S8 and S16, and T8, D8 and D16 for a near miss', () {
        expect(advisor.optimalDarts(48), {d('S8'), d('S16'), d('T8'), d('D8'), d('D16')});
        final r = ChoiceRound(48, advisor, layout: BoxLayout.leftUsed);
        expect(advisor.rate(remaining: 48, dartsLeft: 2, dart: d('T8')), DartQuality.optimal);
        r.throwDart(d('T8')); // leaves 24
        expect(r.remaining, 24);
        expect(r.optimalDarts, {d('D12')});
        r.throwDart(d('D12'));
        expect(r.isCheckedOut, isTrue);
        expect(r.isOptimal, isTrue);
      });

      test('58 lights S18 and its miss T18, nothing else', () {
        expect(advisor.optimalDarts(58), {d('S18'), d('T18')});
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

    test('88 with three darts: after T20 only S14 is lit, then D7; after T16 only S20', () {
      expect(advisor.nextOptimalDarts(88, 3, [d('T20')]), {d('S14')});
      expect(advisor.nextOptimalDarts(88, 3, [d('T20'), d('S14')]), {d('D7')});
      expect(advisor.nextOptimalDarts(88, 3, [d('T16')]), {d('S20')});
    });

    test('after a triple that leaves an odd double or the Bull, only the singles that leave a good double are lit', () {
      Set<DartThrow> singles(List<int> numbers) => {for (final n in numbers) d('S$n')};
      // 88: T18 leaves 34, and S4 would leave D15.
      expect(advisor.nextOptimalDarts(88, 3, [d('T18')]), singles([2, 6, 10, 14, 18]));
      expect(advisor.nextOptimalDarts(88, 3, [d('T18'), d('S18')]), {d('D8')});
      // 68: T18 leaves 14 - no T2, and S8 would leave D3.
      expect(advisor.nextOptimalDarts(68, 3, [d('T18')]), singles([2, 4, 6, 10, 12]));
      // 110: T20 leaves the Bull.
      expect(advisor.nextOptimalDarts(110, 3, [d('T20')]), singles([10, 14, 18]));
      // A single is free when it leaves the Bull: 64 is S14, then T14 D4.
      expect(advisor.nextOptimalDarts(64, 3, [d('S14')]), contains(d('T14')));
    });

    test('an unlit dart keeps to the same rule: D12 on 64 leaves D20, so S20 is lit', () {
      expect(advisor.nextOptimalDarts(64, 3, [d('D12')]), {d('S20')});
    });

    test('rule 4 over 60: after an aim its neighbour lights up too (64: S18, then T4)', () {
      expect(advisor.nextOptimalDarts(64, 3, [d('S18')]), contains(d('T4')));
      expect(advisor.nextOptimalDarts(64, 3, [d('S18'), d('T4')]), {d('D17')});
      expect(advisor.nextOptimalDarts(74, 3, [d('S20')]), contains(d('S20')));
      // After a triple it stays as it was: 64, T18 leaves D5.
      expect(advisor.nextOptimalDarts(64, 3, [d('T18')]), isNot(contains(d('S4'))));
    });

    test('three darts under 60: the aims are lit, then the double and its single', () {
      expect(advisor.optimalDartsIn(47, 3), {
        for (final n in [15, 13, 11, 9, 7]) ...[d('S$n'), d('T$n')],
      });
      expect(advisor.nextOptimalDarts(47, 3, [d('S7')]), {d('D20'), d('S20')});
      expect(advisor.nextOptimalDarts(47, 3, [d('S7'), d('S20')]), {d('D10')});
      // An odd double has no second chance.
      expect(advisor.nextOptimalDarts(47, 3, [d('T7')]), {d('D13')});
      // Any first dart that leaves a double, lit or not: S19 is no aim on 47.
      expect(advisor.nextOptimalDarts(47, 3, [d('S19')]), {d('D14'), d('S14')});
      // The Bull is just the Bull.
      expect(advisor.nextOptimalDarts(59, 3, [d('S9')]), {DartThrow.bull});
      // A single that leaves no double: the same number or a neighbour.
      expect(advisor.nextOptimalDarts(48, 3, [d('S4')]), {d('S4'), d('T4'), d('S18')});
      // A dart that leaves no double and is on no route: the rule of what is left.
      expect(advisor.nextOptimalDarts(47, 3, [d('S3')]), advisor.optimalDartsIn(44, 2));
    });

    test('a finishing double that checks out is optimal with the last dart; with darts left it is a miss', () {
      expect(rate(34, 'D17', left: 1), DartQuality.optimal);
      expect(rate(34, 'D17', left: 2), DartQuality.bust); // a dart still to throw
      expect(rate(34, 'D20', left: 2), DartQuality.bust); // below zero
    });

    test('unless that double is lit: under 60 it finishes with a dart left', () {
      expect(advisor.rate(remaining: 40, dartsLeft: 2, dart: d('D20'), best: {d('D20'), d('S20')}),
          DartQuality.optimal);
      expect(advisor.rate(remaining: 40, dartsLeft: 2, dart: d('D20'), best: {d('S20')}),
          DartQuality.bust);
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
      expect(r.optimalDarts, {d('S17')});
      r.throwDart(d('S7')); // leaves exactly 50
      expect(r.remaining, 50);
      r.throwDart(d('Bull'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isFalse); // a checkout, but not the optimal way any more
    });

    test('over 60 the Bull is still optimal: S11 then the Bull, T11 then D14', () {
      final bull = ChoiceRound(61, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('S11'))
        ..throwDart(d('Bull'));
      expect(bull.isOptimal, isTrue);
      final treble = ChoiceRound(61, advisor, layout: BoxLayout.leftUsed)
        ..throwDart(d('T11'))
        ..throwDart(d('D14'));
      expect(treble.isOptimal, isTrue);
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

    test('47 with three darts: the double missed into S20, then D10 is optimal at every step', () {
      final r = ChoiceRound(47, advisor)
        ..throwDart(d('S7'))
        ..throwDart(d('S20'));
      expect(r.isFinished, isFalse);
      expect(r.optimalDarts, {d('D10')});
      r.throwDart(d('D10'));
      expect(r.isCheckedOut, isTrue);
      expect(r.isOptimal, isTrue);
    });

    test('47 with three darts: S19 is no aim, so S19 then D14 checks out but is not optimal', () {
      final r = ChoiceRound(47, advisor)
        ..throwDart(d('S19'))
        ..throwDart(d('D14'));
      expect(r.status, RoundStatus.checkedOut);
      expect(r.isOptimal, isFalse);
      expect(r.steps.first.quality, DartQuality.fine);
      expect(r.steps.last.quality, DartQuality.optimal);
    });

    test('over 60 a double with a dart in hand stays a miss: 88, T20, then D14', () {
      final r = ChoiceRound(88, advisor)
        ..throwDart(d('T20'))
        ..throwDart(d('D14'));
      expect(r.status, RoundStatus.finishedEarly);
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
