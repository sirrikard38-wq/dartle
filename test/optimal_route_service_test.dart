import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

CheckoutRoute r(String text) => CheckoutRoute.parse(text);

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);

  Set<String> notations(int target) => {
        for (final route in optimal.optimalRoutes(target)) route.notation,
      };

  group('canonical chart', () {
    test('every checkoutable target has a chart entry', () {
      final missing = engine.checkoutableTargets
          .where((t) => !canonicalCheckouts.containsKey(t));
      expect(missing, isEmpty);
    });

    test('chart contains no impossible targets', () {
      for (final t in canonicalCheckouts.keys) {
        expect(engine.isCheckoutable(t), isTrue, reason: '$t');
      }
    });

    test('every chart entry is legal, totals correctly and is minimum-dart', () {
      for (final entry in canonicalCheckouts.entries) {
        final route = CheckoutRoute.parse(entry.value);
        expect(route.total, entry.key, reason: '${entry.key}: ${entry.value}');
        expect(engine.isLegalRoute(entry.key, route), isTrue,
            reason: '${entry.key}: ${entry.value}');
        expect(route.length, engine.minimumDarts(entry.key),
            reason: '${entry.key}: ${entry.value} not minimum darts');
      }
    });
  });

  group('bull-safe finish', () {
    test('treble route: the treble of (R-50), then the double that is left', () {
      expect(BullSafeFinish.twoDartFinish(67)!.notation, 'T17 D8');
      expect(BullSafeFinish.twoDartFinish(61)!.notation, 'T11 D14');
      expect(BullSafeFinish.twoDartFinish(55)!.notation, 'T5 D20');
      expect(BullSafeFinish.twoDartFinish(57)!.notation, 'T7 D18');
      expect(BullSafeFinish.twoDartFinish(70)!.notation, 'T20 D5');
      expect(BullSafeFinish.twoDartFinish(54), isNull);
      expect(BullSafeFinish.twoDartFinish(71), isNull);
      expect(BullSafeFinish.twoDartFinish(50), isNull);
    });

    test('single route: that single leaves exactly 50, then the Bull', () {
      expect(BullSafeFinish.twoDartSingleBull(57)!.notation, 'S7 Bull');
      expect(BullSafeFinish.twoDartSingleBull(52)!.notation, 'S2 Bull');
      expect(BullSafeFinish.twoDartSingleBull(51)!.notation, 'S1 Bull');
      expect(BullSafeFinish.twoDartSingleBull(70)!.notation, 'S20 Bull');
      expect(BullSafeFinish.twoDartSingleBull(50), isNull, reason: '50 is just the Bull');
      expect(BullSafeFinish.twoDartSingleBull(71), isNull);
    });

    test('both routes of a number, the treble one first', () {
      expect(BullSafeFinish.twoDartRoutes(57).map((x) => x.notation), ['T7 D18', 'S7 Bull']);
      expect(BullSafeFinish.twoDartRoutes(53).map((x) => x.notation), ['S3 Bull']);
      expect(BullSafeFinish.twoDartRoutes(75), isEmpty);
    });

    test('missing the treble onto the single always leaves exactly Bull', () {
      for (var rem = BullSafeFinish.minRemaining; rem <= BullSafeFinish.maxRemaining; rem++) {
        final finish = BullSafeFinish.twoDartFinish(rem)!;
        final treble = finish.darts.first;
        expect(treble.isTreble, isTrue, reason: '$rem');
        expect(rem - treble.number, 50, reason: 'S${treble.number} on $rem leaves Bull');
        expect(finish.total, rem);
        expect(finish.endsOnDouble, isTrue);
        final single = BullSafeFinish.twoDartSingleBull(rem)!;
        expect(single.total, rem);
        expect(single.darts.last.isBull, isTrue);
      }
    });

    test('119: T19 S12 Bull and T19 T12 D13 are both optimal (and the others like them)', () {
      expect(notations(119), containsAll(['T19 S12 Bull', 'T19 T12 D13', 'T20 S9 Bull',
          'T20 T9 D16', 'T18 S15 Bull', 'T18 T15 D10', 'T17 S18 Bull', 'T17 T18 D7']));
    });

    test('121: every first treble that leaves a bull-safe finish is optimal', () {
      for (final text in ['T20 T11 D14', 'T19 T14 D11', 'T18 T17 D8', 'T17 T20 D5',
          'T20 S11 Bull', 'T19 S14 Bull']) {
        expect(optimal.isOptimal(121, r(text)), isTrue, reason: text);
      }
      // Order of the setup darts does not matter.
      expect(optimal.isOptimal(121, r('T11 T20 D14')), isTrue);
      // Legal, but the first dart leaves nothing bull-safe.
      expect(engine.isLegalRoute(121, r('T20 S25 D18')), isTrue);
      expect(optimal.isOptimal(121, r('T20 S25 D18')), isFalse);
    });

    test('every bull-safe three-dart route is legal and minimum-length', () {
      for (final target in engine.checkoutableTargets) {
        if (engine.minimumDarts(target) != 3) continue;
        if (chartOnlyCheckouts.contains(target)) continue; // keeps its classic route
        for (final route in BullSafeFinish.threeDartRoutes(target)) {
          expect(engine.isLegalRoute(target, route), isTrue, reason: '$target $route');
          expect(optimal.isOptimal(target, route), isTrue, reason: '$target $route');
        }
      }
    });

    test('the chart route stays accepted for three-dart numbers', () {
      // 124's chart route T20 T16 D8 is accepted next to the bull-safe T20 T14 D11.
      expect(optimal.isOptimal(124, r('T20 T16 D8')), isTrue);
      expect(optimal.isOptimal(124, r('T20 T14 D11')), isTrue);
      expect(optimal.optimalRoute(124)!.notation, 'T20 T14 D11'); // primary
    });

    test('120 is exempt: it stays exactly the classic T20 S20 D20', () {
      expect(optimal.optimalRoutes(120).map((x) => x.notation), ['T20 S20 D20']);
      expect(optimal.isOptimal(120, r('T20 T10 D15')), isFalse);
      expect(engine.isLegalRoute(120, r('T20 T10 D15')), isTrue);
    });
  });

  group('two darts over 50 up to 70: always bull-safe', () {
    test('the triple of the number whose single leaves Bull, or that single and Bull', () {
      expect(notations(57), {'T7 D18', 'S7 Bull'});
      expect(notations(65), {'T15 D10', 'S15 Bull'});
      expect(notations(70), {'T20 D5', 'S20 Bull'});
      // 51..54 have no triple route, only the single and the Bull.
      expect(notations(52), {'S2 Bull'});
      expect(notations(51), {'S1 Bull'});
      expect(optimal.optimalRoute(67)!.notation, 'T17 D8'); // primary
    });

    test('a single and a double is not optimal there, even though it checks out', () {
      for (final text in ['S17 D20', 'S19 D19', '25 D16']) {
        expect(engine.isLegalRoute(57, r(text)), isTrue, reason: text);
        expect(optimal.isOptimal(57, r(text)), isFalse, reason: text);
      }
      expect(optimal.isOptimal(65, r('25 D20')), isFalse);
      expect(optimal.isOptimal(52, r('S12 D20')), isFalse);
    });

    test('every 2-dart target from 55 to 70 teaches the bull-safe route first', () {
      for (var t = 55; t <= 70; t++) {
        expect(optimal.optimalRoute(t)!.notation, BullSafeFinish.twoDartFinish(t)!.notation,
            reason: '$t');
        expect(engine.minimumDarts(t), 2, reason: '$t is a two-dart number');
      }
    });

    test('every 2-dart target from 51 to 70 has only the bull-safe routes', () {
      for (var t = 51; t <= 70; t++) {
        expect(engine.minimumDarts(t), 2, reason: '$t');
        expect(notations(t), {for (final x in BullSafeFinish.twoDartRoutes(t)) x.notation},
            reason: '$t');
      }
    });
  });

  group('more singles win: never a treble or double where a single will do', () {
    test('35: S15 D10, S3 D16, S17 D9 are all optimal - T5 D10 is not', () {
      for (final text in ['S15 D10', 'S3 D16', 'S17 D9', 'S19 D8', 'S1 D17']) {
        expect(optimal.isOptimal(35, r(text)), isTrue, reason: text);
      }
      expect(engine.isLegalRoute(35, r('T5 D10')), isTrue);
      expect(optimal.isOptimal(35, r('T5 D10')), isFalse);
    });

    test('42: any single that leaves a double is optimal, a triple route is not', () {
      expect(optimal.isOptimal(42, r('S2 D20')), isTrue);
      expect(optimal.isOptimal(42, r('S10 D16')), isTrue);
      expect(optimal.isOptimal(42, r('T2 D18')), isFalse);
      expect(engine.isLegalRoute(42, r('T2 D18')), isTrue);
    });

    test('where no single can do it, trebles of 15 and up are optimal', () {
      expect(notations(85), {'T15 D20', 'T17 D17', 'T19 D14'});
      expect(notations(72), containsAll(['T20 D6', 'T16 D12', 'T18 D9']));
      expect(optimal.isOptimal(72, r('T14 D15')), isFalse);
    });

    test('a double as a setup dart ranks last: it is never optimal when a better way exists', () {
      expect(engine.isLegalRoute(150, r('T20 D20 Bull')), isTrue);
      expect(optimal.isOptimal(150, r('T20 D20 Bull')), isFalse);
      expect(optimal.isOptimal(150, r('T20 T18 D18')), isTrue);
    });

    test('the outer bull is a single', () {
      expect(optimal.isOptimal(135, r('T20 25 Bull')), isTrue);
      expect(optimal.isOptimal(35, r('25 D5')), isTrue); // 25 + 10
    });

    test('a chart route with fewer singles than the best is not optimal', () {
      // 135's chart entry T20 T17 D12 has no single where T20 25 Bull has one.
      expect(optimal.isOptimal(135, r('T20 T17 D12')), isFalse);
    });
  });

  group('OptimalRouteService', () {
    test('known routes', () {
      const known = {
        40: 'D20', 50: 'Bull', 72: 'T20 D6', 100: 'T20 D20', 110: 'T20 Bull',
        120: 'T20 S20 D20', 130: 'T20 T20 D5', 160: 'T20 T20 D20',
        167: 'T20 T19 Bull', 170: 'T20 T20 Bull',
      };
      known.forEach((target, text) {
        expect(optimal.optimalRoute(target)?.notation, text, reason: '$target');
      });
    });

    test('130: T20 T20 D5 and the backup S20 T20 Bull', () {
      expect(notations(130), {'T20 T20 D5', 'T20 S20 Bull'});
      expect(optimal.isOptimal(130, r('S20 T20 Bull')), isTrue);
    });

    test('a single route finishes one-dart numbers', () {
      for (final t in [2, 16, 32, 40, 50]) {
        expect(optimal.optimalRoutes(t), hasLength(1), reason: '$t');
        expect(optimal.optimalRoutes(t).single.length, 1);
      }
    });

    test('returns null for impossible targets', () {
      for (final t in [159, 162, 163, 165, 166, 168, 169, 171, 1]) {
        expect(optimal.optimalRoute(t), isNull);
        expect(optimal.optimalRoutes(t), isEmpty);
      }
    });

    test('every checkoutable number has optimal routes, all legal and fewest-darts', () {
      for (final target in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(target);
        expect(routes, isNotEmpty, reason: '$target');
        for (final route in routes) {
          expect(engine.isLegalRoute(target, route), isTrue, reason: '$target $route');
          expect(route.length, engine.minimumDarts(target), reason: '$target $route');
        }
        // No route listed twice.
        for (var i = 0; i < routes.length; i++) {
          for (var j = i + 1; j < routes.length; j++) {
            expect(routes[i].isEquivalentTo(routes[j]), isFalse,
                reason: '$target ${routes[i]} twice');
          }
        }
      }
    });

    test('setup-dart order does not affect optimality', () {
      expect(optimal.isOptimal(133, r('T20 T19 D8')), isTrue);
      expect(optimal.isOptimal(133, r('T19 T20 D8')), isTrue);
      expect(optimal.isOptimal(133, r('T19 D8 T20')), isFalse);
      expect(optimal.isOptimal(170, r('T20 T20 Bull')), isTrue);
      expect(optimal.isOptimal(170, r('Bull T20 T20')), isFalse);
    });

    test('a longer-than-minimum route is never optimal', () {
      expect(optimal.isOptimal(67, r('S17 S10 D20')), isFalse);
      expect(optimal.optimalRoutes(67).every((x) => x.length == 2), isTrue);
    });

    test('falls back to CheckoutStrategy when the chart has no entry', () {
      final bare = OptimalRouteService(engine, canonical: const {});
      for (final target in engine.checkoutableTargets) {
        final route = bare.optimalRoute(target)!;
        expect(engine.isLegalRoute(target, route), isTrue, reason: '$target');
        expect(route.length, engine.minimumDarts(target), reason: '$target');
      }
      expect(bare.optimalRoute(40)!.notation, 'D20');
      expect(bare.optimalRoute(170)!.notation, 'T20 T20 Bull');
    });

    test('an illegal chart entry is ignored, not taught', () {
      final bad = OptimalRouteService(engine, canonical: const {72: 'T20 D5'});
      expect(engine.isLegalRoute(72, bad.optimalRoute(72)!), isTrue);
    });
  });

  group('better doubles', () {
    test('the set is D20, D18, D16, D14, D12, D10, D8, D6, D5, D4, D2, D1', () {
      expect(BetterDoubles.numbers, {20, 18, 16, 14, 12, 10, 8, 6, 5, 4, 2, 1});
      expect(BetterDoubles.isBetter(DartThrow.parse('D20')), isTrue);
      expect(BetterDoubles.isBetter(DartThrow.parse('D5')), isTrue);
      expect(BetterDoubles.isBetter(DartThrow.parse('D19')), isFalse);
      expect(BetterDoubles.isBetter(DartThrow.parse('D3')), isFalse);
      expect(BetterDoubles.isBetter(DartThrow.parse('Bull')), isFalse);
      expect(BetterDoubles.isBetter(DartThrow.parse('T20')), isFalse);
    });

    test('a route leaves a better double when it finishes on one', () {
      expect(BetterDoubles.leavesBetterDouble(r('T20 D5')), isTrue);
      expect(BetterDoubles.leavesBetterDouble(r('T20 T20 Bull')), isFalse);
      expect(BetterDoubles.leavesBetterDouble(r('S19 D19')), isFalse);
    });

    test('extras: one more route with a better double, then up to 2 others', () {
      final routes = optimal.optimalRoutes(35);
      expect(routes.length, greaterThan(4), reason: 'plenty to choose from');
      final primary = routes.first;
      final extras = BetterDoubles.extras(routes, primary);
      expect(extras, hasLength(3));
      expect(extras, isNotEmpty);
      expect(BetterDoubles.leavesBetterDouble(extras.first), isTrue);
      expect(extras.any((x) => x.isEquivalentTo(primary)), isFalse);
      for (final x in extras) {
        expect(optimal.isOptimal(35, x), isTrue);
      }
    });

    test('extras of a number with one optimal route is empty', () {
      final routes = optimal.optimalRoutes(170);
      expect(BetterDoubles.extras(routes, routes.first), isEmpty);
    });
  });
}
