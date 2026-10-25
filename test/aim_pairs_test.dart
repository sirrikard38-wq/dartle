import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  neighbourSingleTests();
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

    test('the old routes stay: every single/triple pair of a number on 20 to 60, any doubles', () {
      expect(optimal.isOptimal(35, r('T5 D10')), isTrue); // S5 leaves D15
      expect(optimal.isOptimal(52, r('S14 D19')), isTrue); // T14 leaves D5
      for (var t = AimPairs.minTwoDartTarget; t <= AimPairs.maxSameNumberTarget; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        for (final route in AimPairs.sameNumberRoutes(t)) {
          expect(optimal.isOptimal(t, route), isTrue, reason: '$t ${route.notation}');
        }
      }
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
      expect(AimPairs.threeDartRoutes(64).every(BetterDoubles.leavesBetterDouble), isTrue);
    });

    test('not for numbers of 60 or less, nor for 1- or 3-dart numbers', () {
      expect(AimPairs.threeDartRoutes(49), isEmpty);
      for (final n in [39, 40, 41, 49, 60]) {
        expect(optimal.hasThreeDartOption(n), isFalse, reason: '$n');
      }
      expect(optimal.hasThreeDartOption(150), isFalse); // three darts anyway
      expect(optimal.hasThreeDartOption(61), isTrue);
      expect(optimal.hasThreeDartOption(110), isTrue);
    });

    test('a high single that leaves a two-dart number over 60, then its optimal route: 93 is S19 T20 D7', () {
      // S19 leaves 74, whose routes include T20 D7.
      expect(optimal.optimalRoutes(74).any(r('T20 D7').isEquivalentTo), isTrue);
      expect(optimal.isOptimalIn(93, 3, r('S19 T20 D7')), isTrue);
      expect(optimal.isOptimalIn(93, 3, r('T20 S19 D7')), isTrue); // any order
      // The aim routes stay, ahead of the follow-ups.
      expect(optimal.optimalRoutesIn(64, 3).first.notation, 'S16 S16 D16');
      expect(optimal.optimalRoutesIn(93, 3).take(AimPairs.threeDartRoutes(93).length),
          AimPairs.threeDartRoutes(93));
    });

    test('any single can be the first dart: every number lights up on 74 and 64', () {
      // S3 leaves 90 (T20 D15); S14 leaves 60; S1 leaves 73.
      expect(optimal.isOptimalIn(93, 3, r('S3 T20 D15')), isTrue);
      for (final target in [64, 74]) {
        final firsts = {
          for (final route in optimal.optimalRoutesIn(target, 3)) ...route.setupDarts,
        };
        for (var n = 1; n <= 20; n++) {
          expect(firsts.contains(DartThrow(Multiplier.single, n)), isTrue, reason: '$target S$n');
        }
      }
    });

    test('64: S14 then T14 D4 (S14 D18 if T14 is missed) - the aim works on the 50 left too', () {
      expect(optimal.isOptimalIn(64, 3, r('S14 T14 D4')), isTrue);
      expect(optimal.isOptimalIn(64, 3, r('T14 S14 D4')), isTrue); // any order
      expect(optimal.isOptimalIn(64, 3, r('S14 S14 D18')), isTrue);
      // 50 with two darts has the aim routes next to the singles.
      expect(optimal.optimalRoutesIn(50, 2).any(r('T14 D4').isEquivalentTo), isTrue);
      expect(optimal.optimalRoutesIn(50, 2).any(r('S14 D18').isEquivalentTo), isTrue);
    });

    test('the single and the triple of the same number, then any double: 74 is S14 T14 D9', () {
      // D9 is not a better double, and S14 would leave 46 after T14 is missed,
      // but the single and triple of one number then a double is optimal anyway.
      expect(optimal.isOptimalIn(74, 3, r('S14 T14 D9')), isTrue);
      expect(optimal.isOptimalIn(74, 3, r('T14 S14 D9')), isTrue);
      expect(optimal.isOptimalIn(74, 3, r('S10 T10 D17')), isTrue);
      expect(optimal.isOptimalIn(74, 3, r('S6 T6 Bull')), isTrue);
      expect(optimal.isOptimalIn(64, 3, r('S14 T14 D4')), isTrue);
      expect(AimPairs.sameNumberThreeDartRoutes(60), isEmpty); // two darts there
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        for (final route in AimPairs.sameNumberThreeDartRoutes(t)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(optimal.isOptimalIn(t, 3, route), isTrue, reason: '$t ${route.notation}');
        }
      }
    });

    test('every three-dart route is legal, and numbers with a three-dart option all have routes', () {
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        for (final route in optimal.optimalRoutesIn(t, 3)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(route.length, 3, reason: '$t ${route.notation}');
        }
      }
    });

    test('every 2-dart number over 60 has a three-dart option', () {
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        expect(optimal.hasThreeDartOption(t), engine.minimumDarts(t) == 2, reason: '$t');
      }
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

void neighbourSingleTests() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  CheckoutRoute r(String text) => CheckoutRoute.parse(text);

  group('neighbouring singles then a double, on 41 to 60 (two darts)', () {
    test('42: 8 and 16 are neighbours - S8 D17 and S16 D13 are optimal', () {
      expect(optimal.isOptimal(42, r('S8 D17')), isTrue);
      expect(optimal.isOptimal(42, r('S16 D13')), isTrue);
      expect(optimal.optimalRoutes(42).every((x) => x.length == 2), isTrue);
    });

    test('whatever the doubles are: 57 has S19 D19 (19 and 7, S7 leaves the Bull)', () {
      expect(optimal.isOptimal(57, r('S19 D19')), isTrue);
      expect(optimal.isOptimal(57, r('S7 Bull')), isTrue);
    });

    test('only from 41 to 60', () {
      expect(AimPairs.neighbourSingleRoutes(40), isEmpty);
      expect(AimPairs.neighbourSingleRoutes(61), isEmpty);
      expect(AimPairs.neighbourSingleRoutes(42), isNotEmpty);
      for (var t = AimPairs.minNeighbourSingleTarget; t <= AimPairs.maxNeighbourSingleTarget; t++) {
        for (final route in AimPairs.neighbourSingleRoutes(t)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(optimal.isOptimal(t, route), isTrue, reason: '$t ${route.notation}');
        }
      }
    });

    test('and no three-dart option there: 49 stays two darts', () {
      expect(optimal.hasThreeDartOption(49), isFalse);
      expect(optimal.optimalRoutesIn(49, 3).every((x) => x.length == 3), isTrue);
    });
  });
}
