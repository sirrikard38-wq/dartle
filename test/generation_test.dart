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
      expect(optimal.isOptimal(c.target, c.optimalRoute), isTrue);
    }
    // And a longer-than-minimum route is never "optimal".
    expect(optimal.isOptimal(67, CheckoutRoute.parse('S17 S10 D20')), isFalse);
    expect(optimal.optimalRoutes(67).every((r) => r.length == 2), isTrue);
  });

  test('generator avoids immediate and recent repeats', () {
    final gen = ChallengeGenerator(catalog, random: Random(1), memory: 5);
    final drawn = [for (var i = 0; i < 500; i++) gen.next(DifficultyLevel.medium).target];
    for (var i = 5; i < drawn.length; i++) {
      expect(drawn.sublist(i - 5, i), isNot(contains(drawn[i])));
    }
  });
}
