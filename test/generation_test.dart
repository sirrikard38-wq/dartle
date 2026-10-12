import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);

  test('catalog covers every checkoutable target exactly once', () {
    expect(catalog.all.map((c) => c.target), engine.checkoutableTargets);
  });

  test('every catalog challenge has a legal solution of its dart count', () {
    for (final c in catalog.all) {
      expect(engine.canCheckoutIn(c.target, c.dartCount), isTrue,
          reason: '${c.target} in ${c.dartCount}');
      expect(engine.isLegalRoute(c.target, c.optimalRoute), isTrue);
      expect(c.dartCount, engine.minimumDarts(c.target));
    }
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
    expect(catalog.forTarget(72)!.difficulty, DifficultyLevel.medium);
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

  test('with no level every checkout number is reachable and roughly equal', () {
    final gen = ChallengeGenerator(catalog, random: Random(42), memory: 5);
    final counts = <int, int>{};
    const draws = 40000;
    for (var i = 0; i < draws; i++) {
      final c = gen.next();
      counts[c.target] = (counts[c.target] ?? 0) + 1;
    }
    expect(counts.keys.toSet(), engine.checkoutableTargets.toSet());
    final expected = draws / engine.checkoutableTargets.length;
    for (final entry in counts.entries) {
      expect(entry.value, inInclusiveRange(expected * 0.7, expected * 1.3),
          reason: '${entry.key} drawn ${entry.value}x, expected ~${expected.round()}');
    }
    // 1-, 2- and 3-dart checkouts all appear.
    expect(
        {for (final t in counts.keys) catalog.forTarget(t)!.dartCount}, {1, 2, 3});
  });

  test('a number that can be done in 2 darts is never played in 3', () {
    final gen = ChallengeGenerator(catalog, random: Random(3));
    for (var i = 0; i < 5000; i++) {
      final c = gen.next();
      expect(c.dartCount, engine.minimumDarts(c.target), reason: '${c.target}');
      expect(optimal.isOptimal(c.target, c.optimalRoute, dartsLeft: c.dartsLeft), isTrue);
    }
    // And a longer-than-minimum route is never "optimal" - unless all three
    // darts are free on 51 to 70 (single, single, double, see below).
    expect(optimal.isOptimal(67, CheckoutRoute.parse('S17 S10 D20')), isFalse);
    expect(optimal.optimalRoutes(67).every((r) => r.length == 2), isTrue);
    expect(optimal.isOptimal(67, CheckoutRoute.parse('S17 S10 D20'), dartsLeft: 2), isFalse);
  });

  group('three boxes, some already thrown', () {
    test('a one-dart number always has two darts already thrown', () {
      final random = Random(5);
      for (var i = 0; i < 200; i++) {
        expect(Visit.dartsLeft(1, random), 1);
      }
    });

    test('a three-dart number always has all three darts free', () {
      final random = Random(5);
      for (var i = 0; i < 200; i++) {
        expect(Visit.dartsLeft(3, random), 3);
      }
    });

    test('a two-dart number is half the time on two darts, half on all three', () {
      final random = Random(11);
      final counts = {2: 0, 3: 0};
      for (var i = 0; i < 10000; i++) {
        counts.update(Visit.dartsLeft(2, random), (n) => n + 1);
      }
      expect(counts[2]! + counts[3]!, 10000);
      expect(counts[2], inInclusiveRange(4700, 5300));
    });

    test('the generator deals the darts and always leaves a legal answer', () {
      final gen = ChallengeGenerator(catalog, random: Random(9));
      final seen = <String>{};
      for (var i = 0; i < 4000; i++) {
        final c = gen.next();
        expect(c.dartsLeft, inInclusiveRange(c.dartCount, 3), reason: '${c.target}');
        expect(c.alreadyThrown, 3 - c.dartsLeft);
        expect(c.optimalRoute.total, c.target);
        expect(c.optimalRoute.length, lessThanOrEqualTo(c.dartsLeft));
        seen.add('${c.dartCount}->${c.dartsLeft}');
      }
      expect(seen, {'1->1', '2->2', '2->3', '3->3'});
    });

    test('without dealing there are no thrown darts (Checkout practice)', () {
      final gen = ChallengeGenerator(catalog, random: Random(9));
      for (var i = 0; i < 500; i++) {
        final c = gen.next(null, false);
        expect(c.dartsLeft, c.dartCount);
      }
    });
  });

  group('51 to 70: bull-safe with two darts, single single double with three', () {
    test('first dart already thrown: the bull-safe treble finish, as before', () {
      expect(optimal.optimalRoutes(67, dartsLeft: 2).map((r) => r.notation), ['T17 D8']);
      expect(optimal.optimalRoute(61, dartsLeft: 2)!.notation, 'T11 D14');
      expect(optimal.isOptimal(60, CheckoutRoute.parse('T10 D15'), dartsLeft: 2), isTrue);
    });

    test('all three free: every optimal route is single, single, double', () {
      for (var target = 51; target <= 70; target++) {
        final routes = optimal.optimalRoutes(target, dartsLeft: 3);
        expect(routes, isNotEmpty, reason: '$target');
        for (final r in routes) {
          expect(SingleSingleDouble.isSingleSingleDouble(r), isTrue, reason: '$target $r');
          expect(engine.isLegalRoute(target, r), isTrue, reason: '$target $r');
        }
      }
    });

    test('all three free: single single double beats treble double', () {
      for (final text in ['S14 S13 D20', 'S20 S7 D20', 'S19 S16 D16']) {
        expect(optimal.isOptimal(67, CheckoutRoute.parse(text), dartsLeft: 3), isTrue,
            reason: text);
      }
      // A single, single, double that does not add up is not optimal.
      expect(optimal.isOptimal(67, CheckoutRoute.parse('S10 S9 D16'), dartsLeft: 3), isFalse);
      expect(optimal.isOptimal(67, CheckoutRoute.parse('T17 D8'), dartsLeft: 3), isFalse);
      expect(optimal.isOptimal(60, CheckoutRoute.parse('T10 D15'), dartsLeft: 3), isFalse);
      // The order of the two singles does not matter.
      expect(optimal.isOptimal(67, CheckoutRoute.parse('S13 S14 D20'), dartsLeft: 3), isTrue);
      // The finisher does.
      expect(optimal.isOptimal(67, CheckoutRoute.parse('S14 D20 S13'), dartsLeft: 3), isFalse);
    });

    test('the example shown is a double that is easy to follow up, with an even pair', () {
      expect(optimal.optimalRoute(60, dartsLeft: 3)!.notation, 'S10 S10 D20');
      expect(optimal.optimalRoute(70, dartsLeft: 3)!.notation, 'S15 S15 D20');
    });

    test('outside 51 to 70 a spare dart changes nothing', () {
      for (final target in [50, 71, 72, 85, 100, 110]) {
        expect(optimal.optimalRoutes(target, dartsLeft: 3).map((r) => r.notation),
            optimal.optimalRoutes(target).map((r) => r.notation),
            reason: '$target');
      }
      expect(optimal.optimalRoutes(120, dartsLeft: 3).map((r) => r.notation),
          ['T20 S20 D20']);
    });

    test('a dealt challenge carries the matching reference route', () {
      final base = catalog.forTarget(67)!;
      final two = catalog.dealt(base, 2);
      expect(two.optimalRoute.notation, 'T17 D8');
      expect(two.alreadyThrown, 1);
      final three = catalog.dealt(base, 3);
      expect(SingleSingleDouble.isSingleSingleDouble(three.optimalRoute), isTrue);
      expect(three.alreadyThrown, 0);
      expect(three.dartCount, 2, reason: 'the fewest darts is still two');
    });
  });

  test('generator avoids immediate and recent repeats', () {
    final gen = ChallengeGenerator(catalog, random: Random(1), memory: 5);
    final drawn = [for (var i = 0; i < 500; i++) gen.next(DifficultyLevel.medium).target];
    for (var i = 5; i < drawn.length; i++) {
      expect(drawn.sublist(i - 5, i), isNot(contains(drawn[i])));
    }
  });
}
