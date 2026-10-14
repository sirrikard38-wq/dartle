import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);

  const impossible = [159, 162, 163, 165, 166, 168, 169];

  test('catalog covers every checkoutable target exactly once', () {
    expect(catalog.all.map((c) => c.target), engine.checkoutableTargets);
  });

  test('every catalog challenge has a legal solution of its dart count', () {
    for (final c in catalog.all) {
      expect(engine.canCheckoutIn(c.target, c.dartCount), isTrue,
          reason: '${c.target} in ${c.dartCount}');
      expect(engine.isLegalRoute(c.target, c.optimalRoute), isTrue);
      expect(c.dartCount, engine.minimumDarts(c.target));
      expect(c.hasCheckout, isTrue);
    }
  });

  test('the numbers with no checkout are in the catalog separately', () {
    expect(catalog.impossible.map((c) => c.target), impossible);
    for (final c in catalog.impossible) {
      expect(c.hasCheckout, isFalse);
      expect(c.optimalRoute.isEmpty, isTrue);
      expect(c.dartCount, 0);
      expect(c.layout, BoxLayout.all, reason: 'all three boxes are free');
      expect(catalog.forTarget(c.target), isNull);
      expect(catalog.anyForTarget(c.target), c);
    }
    expect(catalog.anyForTarget(1), isNull);
    expect(catalog.anyForTarget(171), isNull);
  });

  test('140 is never a two-dart challenge', () {
    expect(catalog.forTarget(140)!.dartCount, 3);
    expect(engine.canCheckoutIn(140, 2), isFalse);
  });

  test('difficulty pools are non-empty and partition the catalog', () {
    var total = 0;
    for (final level in DifficultyLevel.values) {
      final pool = catalog.forLevel(level);
      expect(pool.length, greaterThanOrEqualTo(10), reason: level.name);
      expect(pool.every((c) => c.difficulty == level), isTrue);
      total += pool.length;
    }
    expect(total, catalog.all.length);
  });

  test('difficulty matches expectations', () {
    expect(catalog.forTarget(40)!.difficulty, DifficultyLevel.easy);
    expect(catalog.forTarget(32)!.difficulty, DifficultyLevel.easy);
    expect(catalog.forTarget(170)!.difficulty, DifficultyLevel.hard);
    expect(catalog.forTarget(167)!.difficulty, DifficultyLevel.hard);
  });

  test('generator output is always valid across many draws and seeds', () {
    for (var seed = 0; seed < 10; seed++) {
      final gen = ChallengeGenerator(catalog, random: Random(seed));
      for (final level in DifficultyLevel.values) {
        for (var i = 0; i < 300; i++) {
          final c = gen.next(level);
          expect(c.difficulty, level);
          expect(engine.canCheckoutIn(c.target, c.dartCount), isTrue,
              reason: '${c.target} x ${c.dartCount}');
          expect(c.optimalRoute.total, c.target);
        }
      }
    }
  });

  test('a number that can be done in 2 darts is never played in 3', () {
    final gen = ChallengeGenerator(catalog, random: Random(3));
    for (var i = 0; i < 5000; i++) {
      final c = gen.next();
      if (!c.hasCheckout) continue;
      expect(c.dartCount, engine.minimumDarts(c.target), reason: '${c.target}');
      expect(optimal.isOptimal(c.target, c.optimalRoute), isTrue);
      expect(c.optimalRoute.length, c.dartsLeft);
    }
  });

  group('the calculator: all one-dart numbers together 2%, every other number equal', () {
    // The 21 one-dart numbers share 2% (about 0.095% each); the other 148
    // numbers (2- and 3-dart checkouts and the 7 with none) share 98% equally.
    const oneDartTotal = 0.02;
    const oneDartShare = oneDartTotal / 21;
    const otherShare = (1 - oneDartTotal) / 148;

    test('2 to 170, the no-checkout numbers included', () {
      final gen = ChallengeGenerator(catalog, random: Random(42), memory: 5);
      final counts = <int, int>{};
      const draws = 80000;
      for (var i = 0; i < draws; i++) {
        final c = gen.next();
        counts[c.target] = (counts[c.target] ?? 0) + 1;
      }
      final all = [...engine.checkoutableTargets, ...impossible]..sort();
      expect(counts.keys.toSet(), all.toSet());
      expect(all, hasLength(169), reason: '2 to 170');
      for (final entry in counts.entries) {
        final oneDart = catalog.forTarget(entry.key)?.dartCount == 1;
        final expected = draws * (oneDart ? oneDartShare : otherShare);
        final slack = oneDart ? 0.5 : 0.3; // a rare number is noisier
        expect(entry.value, inInclusiveRange(expected * (1 - slack), expected * (1 + slack)),
            reason: '${entry.key} drawn ${entry.value}x, expected ~${expected.round()}');
      }
      // 1-, 2- and 3-dart checkouts all appear.
      expect({for (final t in engine.checkoutableTargets) catalog.forTarget(t)!.dartCount},
          {1, 2, 3});
    });

    test('the one-dart numbers come up 2% of the time in total', () {
      expect(ChallengeGenerator.calculatorOneDartTotalPercent, 2);
      final gen = ChallengeGenerator(catalog, random: Random(5), memory: 3);
      var oneDart = 0;
      const draws = 60000;
      for (var i = 0; i < draws; i++) {
        final c = gen.next();
        if (c.hasCheckout && c.dartCount == 1) oneDart++;
      }
      expect(oneDart / draws, closeTo(oneDartTotal, 0.004));
      expect(
          [for (final c in catalog.all) if (c.dartCount == 1) c.target], hasLength(21),
          reason: 'D1-D20 and the Bull');
    });

    test('numbers with no checkout come up about 4.6% of the time', () {
      final gen = ChallengeGenerator(catalog, random: Random(8));
      var none = 0;
      const draws = 40000;
      for (var i = 0; i < draws; i++) {
        if (!gen.next().hasCheckout) none++;
      }
      expect(none / draws, closeTo(7 * otherShare, 0.008));
    });
  });

  group('the boxes that are crossed out', () {
    test('a one-dart number always has its first two boxes used', () {
      for (final target in [2, 16, 40, 50]) {
        final layout = catalog.forTarget(target)!.layout;
        expect(layout, BoxLayout.leftTwoUsed);
        expect(layout.free, [2]);
        expect(layout.freeCount, 1);
      }
    });

    test('a three-dart number never has a box used', () {
      for (final target in [111, 140, 170]) {
        expect(catalog.forTarget(target)!.layout, BoxLayout.all);
      }
      expect(BoxLayout.all.free, [0, 1, 2]);
    });

    test('every two-dart number always has the left box used - never the right', () {
      expect(BoxLayout.leftUsed.free, [1, 2]);
      expect(BoxLayout.values, hasLength(3), reason: 'no layout crosses the right box');
      for (final c in catalog.all) {
        if (c.dartCount != 2) continue;
        expect(c.layout, BoxLayout.leftUsed, reason: '${c.target}');
        expect(c.layout.isUsed(0), isTrue);
        expect(c.layout.isUsed(2), isFalse);
      }
    });

    test('the layout follows from the fewest darts', () {
      expect(BoxLayout.defaultFor(0), BoxLayout.all, reason: 'no checkout: all free');
      expect(BoxLayout.defaultFor(1), BoxLayout.leftTwoUsed);
      expect(BoxLayout.defaultFor(2), BoxLayout.leftUsed);
      expect(BoxLayout.defaultFor(3), BoxLayout.all);
    });

    test('the generator hands out the boxes and always leaves a legal answer', () {
      final gen = ChallengeGenerator(catalog, random: Random(9));
      final seen = <String>{};
      for (var i = 0; i < 6000; i++) {
        final c = gen.next();
        if (!c.hasCheckout) {
          seen.add('none');
          continue;
        }
        expect(c.dartsLeft, c.dartCount, reason: 'free boxes = fewest darts');
        expect(c.layout.free.length, c.dartsLeft);
        expect(c.optimalRoute.total, c.target);
        expect(c.optimalRoute.length, c.dartsLeft);
        seen.add('${c.dartCount}-${c.layout.name}');
      }
      expect(seen, {'none', '1-leftTwoUsed', '2-leftUsed', '3-all'});
    });

    test('57 is always the bull-safe T7 D18 with the left box used', () {
      final c = catalog.forTarget(57)!;
      expect(c.optimalRoute.notation, 'T7 D18');
      expect(c.layout, BoxLayout.leftUsed);
      expect(c.dartsLeft, 2);
      expect(c.dartCount, 2);
    });
  });

  group('Checkout practice draws', () {
    test('never a no-checkout number, one-dart numbers about 1% each', () {
      final gen = ChallengeGenerator(catalog, random: Random(21), memory: 3);
      final counts = <int, int>{};
      const draws = 60000;
      for (var i = 0; i < draws; i++) {
        final c = gen.next(null, Deal.practice);
        expect(c.hasCheckout, isTrue);
        counts[c.target] = (counts[c.target] ?? 0) + 1;
      }
      final oneDart = [
        for (final c in catalog.all)
          if (c.dartCount == 1) c.target,
      ];
      expect(oneDart, hasLength(21)); // D1-D20 and the Bull
      for (final t in oneDart) {
        expect(counts[t]! / draws, closeTo(0.01, 0.004), reason: 'one-dart $t');
      }
      final multi = [
        for (final c in catalog.all)
          if (c.dartCount > 1) c.target,
      ];
      final multiShare = multi.fold<int>(0, (s, t) => s + (counts[t] ?? 0)) / draws;
      expect(multiShare, closeTo(1 - 0.21, 0.02));
      for (final t in multi) {
        expect(counts[t], isNotNull, reason: '$t is reachable');
      }
    });
  });

  test('forNumber deals a picked number, and refuses the impossible and the out of range', () {
    final gen = ChallengeGenerator(catalog, random: Random(2));
    final c = gen.forNumber(40)!; // one-dart numbers are allowed here
    expect(c.dartCount, 1);
    expect(c.layout, BoxLayout.leftTwoUsed);
    expect(gen.forNumber(57), isNotNull);
    for (final n in [...impossible, 0, 1, 171, 500]) {
      expect(gen.forNumber(n), isNull, reason: '$n');
    }
    expect(gen.isImpossible(169), isTrue);
    expect(gen.isImpossible(170), isFalse);
    expect(gen.isImpossible(1), isFalse);
  });

  test('generator avoids immediate and recent repeats', () {
    final gen = ChallengeGenerator(catalog, random: Random(1), memory: 5);
    final drawn = [for (var i = 0; i < 500; i++) gen.next(DifficultyLevel.medium).target];
    for (var i = 5; i < drawn.length; i++) {
      expect(drawn.sublist(i - 5, i), isNot(contains(drawn[i])));
    }
  });
}
