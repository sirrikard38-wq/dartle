import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// Totals that cannot be finished in three darts (well-known chart gaps).
const nonCheckouts = {1, 159, 162, 163, 165, 166, 168, 169};

void main() {
  group('DartThrow', () {
    test('scores', () {
      expect(DartThrow.parse('S20').score, 20);
      expect(DartThrow.parse('D20').score, 40);
      expect(DartThrow.parse('T20').score, 60);
      expect(DartThrow.bull.score, 50);
      expect(DartThrow.outerBull.score, 25);
    });

    test('notation round-trips for every segment', () {
      for (final dart in DartThrow.allSegments) {
        expect(DartThrow.parse(dart.notation), dart);
      }
    });

    test('has exactly 62 legal segments, none a treble 25', () {
      expect(DartThrow.allSegments, hasLength(62));
      expect(() => DartThrow(Multiplier.treble, 25), throwsArgumentError);
      expect(() => DartThrow(Multiplier.single, 21), throwsArgumentError);
      expect(() => DartThrow(Multiplier.double, 0), throwsArgumentError);
    });

    test('only doubles and bull may finish; 25 may not', () {
      final finishers = DartThrow.allSegments.where((d) => d.isFinishingDart);
      expect(finishers, hasLength(21));
      expect(DartThrow.bull.isFinishingDart, isTrue);
      expect(DartThrow.outerBull.isFinishingDart, isFalse);
      expect(DartThrow.parse('T20').isFinishingDart, isFalse);
      expect(DartThrow.parse('S20').isFinishingDart, isFalse);
    });
  });

  group('CheckoutEngine', () {
    final engine = CheckoutEngine();

    test('checkoutable targets are exactly 2..170 minus the known gaps', () {
      final expected = [
        for (var n = 2; n <= 170; n++)
          if (!nonCheckouts.contains(n)) n
      ];
      expect(engine.checkoutableTargets, expected);
    });

    test('impossible numbers are rejected', () {
      for (final n in [...nonCheckouts, 0, -4, 171, 200]) {
        expect(engine.isCheckoutable(n), isFalse, reason: '$n');
        expect(engine.legalRoutes(n), isEmpty, reason: '$n');
        expect(engine.minimumDarts(n), isNull, reason: '$n');
      }
    });

    test('every indexed route is genuinely legal', () {
      for (final target in engine.checkoutableTargets) {
        for (final route in engine.legalRoutes(target)) {
          expect(route.total, target);
          expect(route.endsOnDouble, isTrue);
          expect(route.length, inInclusiveRange(1, 3));
        }
      }
    });

    test('minimum darts for key values', () {
      const expected = {
        2: 1, 4: 1, 40: 1, 50: 1, 3: 2, 41: 2, 60: 2, 61: 2, 98: 2, 99: 3, 100: 2,
        110: 2, 111: 3, 120: 3, 130: 3, 140: 3, 150: 3, 160: 3, 167: 3,
        170: 3,
      };
      expected.forEach((target, darts) {
        expect(engine.minimumDarts(target), darts, reason: '$target');
      });
    });

    test('one-dart checkouts are exactly 2..40 evens and 50', () {
      final oneDart = [
        for (final t in engine.checkoutableTargets)
          if (engine.canCheckoutIn(t, 1)) t
      ];
      expect(oneDart, [for (var n = 2; n <= 40; n += 2) n, 50]);
    });

    test('upper range cannot be done in two darts', () {
      for (final n in [111, 120, 130, 140, 150, 160, 167, 168, 169, 170]) {
        expect(engine.canCheckoutIn(n, 2), isFalse, reason: '$n');
        expect(engine.legalRoutes(n, darts: 2), isEmpty, reason: '$n');
      }
      expect(engine.canCheckoutIn(110, 2), isTrue); // T20 Bull
    });

    test('170 has exactly one route: T20 T20 Bull', () {
      expect(engine.legalRoutes(170).map((r) => r.notation), ['T20 T20 Bull']);
    });

    test('bull is a legal finisher; outer bull is not', () {
      expect(engine.isLegalRoute(50, CheckoutRoute.parse('Bull')), isTrue);
      expect(engine.isLegalRoute(25, CheckoutRoute.parse('25')), isFalse);
      expect(engine.isLegalRoute(60, CheckoutRoute.parse('T20')), isFalse);
      expect(engine.isLegalRoute(72, CheckoutRoute.parse('T20 D6')), isTrue);
      expect(engine.isLegalRoute(72, CheckoutRoute.parse('T18 S18')), isFalse);
    });

    test('the finisher is fixed but setup darts are a combination', () {
      // Different finisher => different checkout.
      expect(CheckoutRoute.parse('T20 D6').isEquivalentTo(CheckoutRoute.parse('D6 T20')),
          isFalse);
      expect(engine.legalRoutes(72, darts: 2).map((r) => r.notation),
          isNot(contains('D6 T20')));
      // Setup order is irrelevant.
      expect(
          CheckoutRoute.parse('T19 T20 D8')
              .isEquivalentTo(CheckoutRoute.parse('T20 T19 D8')),
          isTrue);
      expect(CheckoutRoute.parse('T19 T20 D8').normalized.notation, 'T20 T19 D8');
    });

    test('legal routes list each combination once', () {
      final routes = engine.legalRoutes(133, darts: 3);
      final keys = routes.map((r) => r.normalized.notation).toList();
      expect(keys.toSet(), hasLength(keys.length), reason: 'no permutations');
      expect(routes.map((r) => r.notation), contains('T20 T19 D8'));
      expect(routes.map((r) => r.notation), isNot(contains('T19 T20 D8')));
    });
  });
}
