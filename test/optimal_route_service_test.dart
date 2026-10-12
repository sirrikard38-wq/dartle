import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);

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

    test('every alternate is legal and minimum-dart', () {
      alternateOptimalCheckouts.forEach((target, routes) {
        for (final text in routes) {
          final route = CheckoutRoute.parse(text);
          expect(engine.isLegalRoute(target, route), isTrue, reason: text);
          expect(route.length, engine.minimumDarts(target), reason: text);
        }
      });
    });
  });

  group('bull-safe finish', () {
    test('two-dart finish: treble (R-50), then the double that is left', () {
      expect(BullSafeFinish.twoDartFinish(67)!.notation, 'T17 D8');
      expect(BullSafeFinish.twoDartFinish(61)!.notation, 'T11 D14');
      expect(BullSafeFinish.twoDartFinish(55)!.notation, 'T5 D20');
      expect(BullSafeFinish.twoDartFinish(70)!.notation, 'T20 D5');
      expect(BullSafeFinish.twoDartFinish(54), isNull);
      expect(BullSafeFinish.twoDartFinish(71), isNull);
      expect(BullSafeFinish.twoDartFinish(50), isNull);
    });

    test('missing the treble onto the single always leaves exactly Bull', () {
      for (var r = BullSafeFinish.minRemaining; r <= BullSafeFinish.maxRemaining; r++) {
        final finish = BullSafeFinish.twoDartFinish(r)!;
        final treble = finish.darts.first;
        expect(treble.isTreble, isTrue, reason: '$r');
        expect(r - treble.number, 50, reason: 'S${treble.number} on $r leaves Bull');
        expect(finish.total, r);
        expect(finish.endsOnDouble, isTrue);
      }
    });

    test('2-dart targets 55..70 teach the bull-safe route', () {
      for (var t = 55; t <= 70; t++) {
        expect(optimal.optimalRoute(t)!.notation, BullSafeFinish.twoDartFinish(t)!.notation,
            reason: '$t');
        expect(engine.minimumDarts(t), 2, reason: '$t is a two-dart number');
      }
      expect(optimal.optimalRoute(67)!.notation, 'T17 D8');
    });

    test('121: every first treble that leaves a bull-safe finish is optimal', () {
      for (final text in ['T20 T11 D14', 'T19 T14 D11', 'T18 T17 D8', 'T17 T20 D5']) {
        expect(optimal.isOptimal(121, CheckoutRoute.parse(text)), isTrue, reason: text);
      }
      // Order of the setup darts does not matter.
      expect(optimal.isOptimal(121, CheckoutRoute.parse('T11 T20 D14')), isTrue);
      // Legal, but the first dart leaves nothing bull-safe.
      expect(engine.isLegalRoute(121, CheckoutRoute.parse('T20 S25 D18')), isTrue);
      expect(optimal.isOptimal(121, CheckoutRoute.parse('T20 S25 D18')), isFalse);
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
      // 124's chart route T20 T16 D8 is still accepted next to the bull-safe T20 T14 D11.
      expect(optimal.isOptimal(124, CheckoutRoute.parse('T20 T16 D8')), isTrue);
      expect(optimal.isOptimal(124, CheckoutRoute.parse('T20 T14 D11')), isTrue);
      expect(optimal.optimalRoute(124)!.notation, 'T20 T14 D11'); // primary
    });

    test('120 is exempt: it stays exactly the classic T20 S20 D20', () {
      expect(optimal.optimalRoutes(120).map((r) => r.notation), ['T20 S20 D20']);
      expect(optimal.isOptimal(120, CheckoutRoute.parse('T20 T10 D15')), isFalse);
      expect(engine.isLegalRoute(120, CheckoutRoute.parse('T20 T10 D15')), isTrue);
    });
  });

  group('OptimalRouteService', () {
    test('known canonical routes', () {
      const known = {
        40: 'D20', 50: 'Bull', 72: 'T20 D6', 82: 'Bull D16', 100: 'T20 D20',
        110: 'T20 Bull', 120: 'T20 S20 D20', 130: 'T20 T20 D5',
        160: 'T20 T20 D20', 167: 'T20 T19 Bull', 170: 'T20 T20 Bull',
      };
      known.forEach((target, text) {
        expect(optimal.optimalRoute(target)?.notation, text, reason: '$target');
      });
    });

    test('returns null for impossible targets', () {
      for (final t in [159, 162, 163, 165, 166, 168, 169, 171, 1]) {
        expect(optimal.optimalRoute(t), isNull);
        expect(optimal.optimalRoutes(t), isEmpty);
      }
    });

    test('legal-but-not-optimal routes are not optimal', () {
      expect(optimal.isOptimal(72, CheckoutRoute.parse('T20 D6')), isTrue);
      expect(optimal.isOptimal(72, CheckoutRoute.parse('T16 D12')), isTrue);
      final other = CheckoutRoute.parse('T18 D9');
      expect(engine.isLegalRoute(72, other), isTrue);
      expect(optimal.isOptimal(72, other), isFalse);
      expect(optimal.isOptimal(135, CheckoutRoute.parse('Bull T15 D20')), isTrue);
    });

    test('setup-dart order does not affect optimality', () {
      expect(optimal.isOptimal(133, CheckoutRoute.parse('T20 T19 D8')), isTrue);
      expect(optimal.isOptimal(133, CheckoutRoute.parse('T19 T20 D8')), isTrue);
      expect(optimal.isOptimal(133, CheckoutRoute.parse('T19 D8 T20')), isFalse);
      expect(optimal.isOptimal(170, CheckoutRoute.parse('T20 T20 Bull')), isTrue);
      expect(optimal.isOptimal(170, CheckoutRoute.parse('Bull T20 T20')), isFalse);
    });

    test('falls back to CheckoutStrategy when the chart has no entry', () {
      final bare = OptimalRouteService(engine, canonical: const {}, alternates: const {});
      for (final target in engine.checkoutableTargets) {
        final route = bare.optimalRoute(target)!;
        expect(engine.isLegalRoute(target, route), isTrue, reason: '$target');
        expect(route.length, engine.minimumDarts(target), reason: '$target');
      }
      expect(bare.optimalRoute(40)!.notation, 'D20');
      expect(bare.optimalRoute(170)!.notation, 'T20 T20 Bull');
    });

    test('an illegal chart entry is ignored, not taught', () {
      final bad = OptimalRouteService(engine,
          canonical: const {72: 'T20 D5'}, alternates: const {});
      expect(engine.isLegalRoute(72, bad.optimalRoute(72)!), isTrue);
    });
  });
}
