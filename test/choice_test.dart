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

    test('the bull-safe routes stay optimal even with low trebles (55 -> T5 D20)', () {
      expect(advisor.optimalDarts(55), contains(d('T5')));
      // Trebles come first: a treble works on 55 (T15 D5), so the single S15 is not lit.
      expect(advisor.optimalDarts(55), contains(d('T15')));
      expect(advisor.optimalDarts(55), isNot(contains(d('S15'))));
    });

    group('priority: trebles first, singles only if needed, doubles only if popular', () {
      /// The darts of the standard (chart / bull-safe) routes: "popular and optimal".
      Set<DartThrow> standardSetup(int target) => {
            for (final r in optimal.optimalRoutes(target))
              ...(r.length == 1 ? r.darts : r.setupDarts),
          };

      test('when a treble can do the job, no extra singles are lit', () {
        for (final target in engine.checkoutableTargets) {
          if (engine.minimumDarts(target) == 1) continue;
          final lit = advisor.optimalDarts(target);
          if (!lit.any((x) => x.isTreble)) continue;
          for (final single in lit.where((x) => x.multiplier == Multiplier.single)) {
            expect(standardSetup(target), contains(single),
                reason: '$single lit on $target next to a treble, but it is not a standard dart');
          }
        }
      });

      test('singles are lit when no treble can do it (e.g. 41)', () {
        final lit = advisor.optimalDarts(41);
        expect(lit.any((x) => x.isTreble), isFalse);
        expect(lit.every((x) => x.multiplier == Multiplier.single), isTrue);
        expect(lit, isNotEmpty);
      });

      test('a double or the Bull is only a lit setup dart when the standard route uses it', () {
        for (final target in engine.checkoutableTargets) {
          if (engine.minimumDarts(target) == 1) continue;
          for (final x in advisor.optimalDarts(target)) {
            if (x.multiplier == Multiplier.double) {
              expect(standardSetup(target), contains(x),
                  reason: '$x lit as a setup dart on $target');
            }
          }
        }
        // The Bull is standard on 82 (Bull D16) ...
        expect(advisor.optimalDarts(82), contains(d('Bull')));
        // ... but not a first dart on 100 or 150, where only the trebles are lit.
        expect(advisor.optimalDarts(100), {d('T20')});
        expect(advisor.optimalDarts(150), {d('T18'), d('T19'), d('T20')});
      });

      test('121 lights trebles only', () {
        final lit = advisor.optimalDarts(121);
        expect(lit.every((x) => x.isTreble), isTrue);
        expect(lit, containsAll([d('T20'), d('T11'), d('T19'), d('T14')]));
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

    test('85 with three darts', () {
      expect(rate(85, 'T17'), DartQuality.optimal);
      expect(rate(85, 'T15'), DartQuality.optimal);
      expect(rate(85, 'T19'), DartQuality.optimal);
      // 15 then 20 then Bull is a fine, but longer, way
      expect(rate(85, 'S15'), DartQuality.fine);
      expect(rate(85, 'S20'), DartQuality.fine);
      expect(rate(85, 'S25'), DartQuality.fine);
      expect(rate(85, 'Bull'), DartQuality.fine);
      // T3 is a silly dart
      expect(rate(85, 'T3'), DartQuality.poor);
      expect(rate(85, 'D20'), DartQuality.poor); // non-finishing double
    });

    test('a finishing double that checks out is optimal; the wrong one busts', () {
      expect(rate(34, 'D17', left: 2), DartQuality.optimal);
      expect(rate(34, 'D20', left: 2), DartQuality.bust); // below zero
    });

    test('zero without a double is a bust; leaving 1 is a bust', () {
      expect(rate(20, 'S20'), DartQuality.bust); // zero, but not a double
      expect(rate(20, 'S19'), DartQuality.bust); // leaves 1
      expect(rate(20, 'T7'), DartQuality.bust); // below zero
    });

    test('a dart that leaves too many darts needed is poor', () {
      // After T17 on 85, 34 is left with two darts. S17 leaves 17, which needs
      // two darts but only one is left.
      expect(rate(34, 'S17', left: 2), DartQuality.poor);
      expect(rate(34, 'S14', left: 2), DartQuality.fine); // leaves 20 -> D10
    });
  });

  group('ChoiceRound', () {
    ChoiceRound round(int target) => ChoiceRound(target, advisor);

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
      final r = round(85);
      expect(r.remaining, 85);
      r.throwDart(d('S15'));
      expect(r.remaining, 70);
      r.throwDart(d('S20'));
      expect(r.remaining, 50);
      expect(r.dartsLeft, 1);
      r.throwDart(d('Bull'));
      expect(r.status, RoundStatus.checkedOut);
    });

    test('S15 S20 Bull checks out but is not optimal; so is S25 S20 D20', () {
      for (final darts in [['S15', 'S20', 'Bull'], ['S25', 'S20', 'D20']]) {
        final r = round(85);
        for (final t in darts) {
          r.throwDart(d(t));
        }
        expect(r.isCheckedOut, isTrue, reason: '$darts');
        expect(r.isOptimal, isFalse, reason: '$darts');
        expect(r.steps.first.quality, DartQuality.fine);
      }
    });

    test('T3 first is rated poor even if it still checks out', () {
      final r = round(85);
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
          final pick = (advisor.optimalDarts(r.remaining).toList()
                ..sort((a, b) => b.score.compareTo(a.score)))
              .first;
          r.throwDart(pick);
        }
        expect(r.isOptimal, isTrue, reason: '$target');
        expect(r.steps.length, engine.minimumDarts(target), reason: '$target');
      }
    });
  });
}
