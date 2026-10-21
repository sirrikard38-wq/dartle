import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  CheckoutRoute r(String text) => CheckoutRoute.parse(text);
  Set<String> notations(Iterable<CheckoutRoute> routes) => {for (final x in routes) x.notation};

  group('neighbours on the board', () {
    test('16 and 8 are neighbours, so are 20 and 1 and 5 and 20', () {
      expect(AimPairs.areNeighbours(16, 8), isTrue);
      expect(AimPairs.areNeighbours(8, 16), isTrue);
      expect(AimPairs.areNeighbours(20, 1), isTrue);
      expect(AimPairs.areNeighbours(5, 20), isTrue);
      expect(AimPairs.areNeighbours(20, 18), isFalse);
      expect(AimPairs.areNeighbours(16, 16), isFalse);
    });

    test('there are 20 pairs of neighbours', () {
      expect(AimPairs.neighbourPairs, hasLength(20));
    });
  });

  group('two darts: the first dart is an aim with two possible hits', () {
    test('64 is T16 D8, T8 D20, D16 D16 next to the bull-safe T14 D11 and S14 Bull', () {
      expect(notations(optimal.optimalRoutes(64)),
          {'T14 D11', 'S14 Bull', 'T16 D8', 'T8 D20', 'D16 D16'});
    });

    test('43 is T11 D5 next to S11 D16 (the single and triple of 11)', () {
      expect(optimal.isOptimal(43, r('T11 D5')), isTrue);
      expect(optimal.isOptimal(43, r('S11 D16')), isTrue);
    });

    test('only the best group: aims with a better double both ways beat the others', () {
      // 35: S11 / T11 leave D12 / D1; S5 / T5 would leave D15 / D10.
      final routes = notations(AimPairs.twoDartRoutes(35));
      expect(routes, containsAll(['T11 D1', 'S11 D12']));
      expect(routes, isNot(contains('T5 D10')));
    });

    test('the same better double twice: 64 D16 D16, not 76 D19 D19', () {
      expect(AimPairs.sameDoubleTwice(64)?.notation, 'D16 D16');
      expect(AimPairs.sameDoubleTwice(76), isNull);
      expect(AimPairs.sameDoubleTwice(63), isNull);
    });

    test('every aim route is legal for its number', () {
      for (var t = AimPairs.minTwoDartTarget; t <= CheckoutEngine.maxCheckout; t++) {
        for (final route in AimPairs.twoDartRoutes(t)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
        }
      }
    });
  });

  group('three darts on a two-dart number over 40', () {
    test('64 is S8 S16 D20 (either order) and S16 S16 D16', () {
      final routes = optimal.optimalRoutesIn(64, 3);
      expect(routes.any(r('S8 S16 D20').isEquivalentTo), isTrue);
      expect(routes.any(r('S16 S8 D20').isEquivalentTo), isTrue);
      expect(routes.any(r('S16 S16 D16').isEquivalentTo), isTrue);
      // Same number as the double comes first.
      expect(routes.first.notation, 'S16 S16 D16');
      expect(optimal.isOptimalIn(64, 3, r('S16 S8 D20')), isTrue);
      // Two darts are not optimal when three have to be used.
      expect(optimal.isOptimalIn(64, 3, r('T16 D8')), isFalse);
    });

    test('only better doubles when there are any, then the most singles', () {
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        final routes = AimPairs.threeDartRoutes(t);
        expect(routes, isNotEmpty, reason: '$t');
        for (final route in routes) {
          expect(route.length, 3, reason: '$t ${route.notation}');
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
        }
        final singles = routes.map(OptimalRouteService.singles).toSet();
        expect(singles, hasLength(1), reason: '$t: all with the same number of singles');
      }
      expect(AimPairs.threeDartRoutes(41).every(BetterDoubles.leavesBetterDouble), isTrue);
    });

    test('not for numbers of 40 or less, nor for 1- or 3-dart numbers', () {
      expect(AimPairs.threeDartRoutes(39), isEmpty);
      expect(optimal.hasThreeDartOption(39), isFalse);
      expect(optimal.hasThreeDartOption(40), isFalse); // one dart: D20
      expect(optimal.hasThreeDartOption(150), isFalse); // three darts anyway
      expect(optimal.hasThreeDartOption(41), isTrue);
      expect(optimal.hasThreeDartOption(110), isTrue);
    });
  });

  group('optimal routes in an exact number of darts', () {
    test('the fewest darts is the normal list', () {
      expect(optimal.optimalRoutesIn(57, 2), optimal.optimalRoutes(57));
    });

    test('fewer darts than needed, or a count that cannot do it, is empty', () {
      expect(optimal.optimalRoutesIn(150, 2), isEmpty);
      expect(optimal.optimalRoutesIn(100, 1), isEmpty);
      expect(optimal.optimalRoutesIn(170, 2), isEmpty);
    });

    test('a one-dart number with two darts: the most singles (40: S20 D10 ...)', () {
      final routes = optimal.optimalRoutesIn(40, 2);
      expect(routes, isNotEmpty);
      expect(routes.every((x) => x.length == 2), isTrue);
      expect(routes.any(r('S20 D10').isEquivalentTo), isTrue);
    });
  });
}
