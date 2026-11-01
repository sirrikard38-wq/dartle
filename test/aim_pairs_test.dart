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

  group('two darts up to 60: a single that leaves a better double, and its near misses', () {
    test('48: S8 and S16 are neighbours, so those two, then T8 D12, D16 D8 and D8 D16', () {
      expect(notations(AimPairs.goodSingleRoutes(48)),
          {'S16 D16', 'S8 D20', 'T8 D12', 'D16 D8', 'D8 D16'});
      expect(notations(optimal.optimalRoutes(48)), notations(AimPairs.goodSingleRoutes(48)));
      // S12 and S20 leave better doubles too, but neither has a neighbour that does.
      expect(optimal.isOptimal(48, r('S12 D18')), isFalse);
      expect(optimal.isOptimal(48, r('S20 D14')), isFalse);
      expect(optimal.isOptimal(48, r('D12 D12')), isFalse);
    });

    test('no neighbouring pair: every such single counts, with its misses', () {
      expect(notations(optimal.optimalRoutes(58)), {'S18 D20', 'T18 D2'});
      expect(notations(optimal.optimalRoutes(60)), {'S20 D20', 'D20 D10'});
      expect(notations(optimal.optimalRoutes(59)), {'S19 D20', 'T19 D1'});
      expect(notations(optimal.optimalRoutes(56)),
          {'S20 D18', 'S16 D20', 'T16 D4', 'D20 D8', 'D16 D12'});
    });

    test('a pair: only its singles and their misses, and a miss must leave a better double', () {
      // 19, 7 and 3 sit side by side, S15 and S11 have no neighbour that counts.
      expect(notations(optimal.optimalRoutes(35)), {'S19 D8', 'S7 D14', 'S3 D16'});
      expect(notations(optimal.optimalRoutes(43)), {'S19 D12', 'S7 D18', 'S3 D20'});
      expect(notations(optimal.optimalRoutes(42)), {'S10 D16', 'S6 D18', 'T10 D6', 'T6 D12'});
    });

    test('57 is S17 D20 alone: the Bull routes and the doubles outside the set are gone', () {
      expect(notations(optimal.optimalRoutes(57)), {'S17 D20'});
      for (final route in ['T7 D18', 'S7 Bull', 'S19 D19', 'T17 D3']) {
        expect(engine.isLegalRoute(57, r(route)), isTrue, reason: route);
        expect(optimal.isOptimal(57, r(route)), isFalse, reason: route);
      }
    });

    test('every two-dart number up to 60: a first dart of a single that counts, a better double last', () {
      for (var t = 3; t <= AimPairs.maxGoodSingleTarget; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        final routes = optimal.optimalRoutes(t);
        expect(routes, isNotEmpty, reason: '$t');
        final singles = {
          for (final route in routes)
            if (route.darts.first.multiplier == Multiplier.single) route.darts.first.number,
        };
        expect(singles, isNotEmpty, reason: '$t');
        for (final route in routes) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(BetterDoubles.leavesBetterDouble(route), isTrue, reason: '$t ${route.notation}');
          expect(singles, contains(route.darts.first.number), reason: '$t ${route.notation}');
        }
      }
    });

    test('the chart route stays first when it is one of them, or else a single comes first', () {
      for (var t = 3; t <= AimPairs.maxGoodSingleTarget; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        final routes = optimal.optimalRoutes(t);
        final chart = CheckoutRoute.parse(canonicalCheckouts[t]!);
        if (routes.any(chart.isEquivalentTo)) {
          expect(routes.first.isEquivalentTo(chart), isTrue, reason: '$t');
        } else {
          expect(routes.first.darts.first.multiplier, Multiplier.single, reason: '$t');
        }
      }
    });
  });

  group('two darts: the first dart is an aim with two possible hits (what follows the first of three darts)', () {
    test('43 has T11 D5 next to S11 D16, and 64 has T16 D8 and T8 D20', () {
      expect(notations(AimPairs.twoDartRoutes(43)), containsAll(['T11 D5', 'S11 D16']));
      expect(notations(AimPairs.twoDartRoutes(64)), containsAll(['T16 D8', 'T8 D20']));
    });

    test('only the best group: aims with a better double both ways beat the others', () {
      // 35: S11 / T11 leave D12 / D1; S5 / T5 would leave D15 / D10.
      final routes = notations(AimPairs.twoDartRoutes(35));
      expect(routes, containsAll(['T11 D1', 'S11 D12']));
      expect(routes, isNot(contains('T5 D10')));
    });

    test('every single/triple pair of a number on 20 to 60, any doubles', () {
      expect(notations(AimPairs.sameNumberRoutes(35)), containsAll(['T5 D10', 'S5 D15']));
      expect(notations(AimPairs.sameNumberRoutes(52)), containsAll(['T14 D5', 'S14 D19']));
      expect(AimPairs.sameNumberRoutes(19), isEmpty);
      expect(AimPairs.sameNumberRoutes(61), isEmpty);
    });

    test('three darts over 60 keep the routes two darts have lost: 60 was T10 D15, 74 is S14 T10 D15', () {
      expect(optimal.isOptimal(60, r('T10 D15')), isFalse);
      expect(optimal.isOptimalIn(74, 3, r('S14 T10 D15')), isTrue);
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
      // The best aim comes first: S14 leaves the Bull and T14 leaves D11.
      expect(routes.first.notation, 'S14 S10 D20');
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
      // The aim routes come first: 93's only aim is 19 (T19 leaves D18, S19
      // leaves 74).
      expect(optimal.threeDartAims(93), [19]);
      expect(optimal.optimalRoutesIn(93, 3).first.notation, 'T19 S18 D9');
    });

    test('only S15 to S20 start a follow-up route, and every route starts with an aim: 97 has 4', () {
      expect(OptimalRouteService.followUpLowestSingle, 15);
      // S3 leaves 90 (T20 D15), but S3 is not a high single.
      expect(optimal.isOptimalIn(93, 3, r('S3 T20 D15')), isFalse);
      // S15 leaves 78 (T18 D12), but 15 is no aim on 93 (T15 leaves 48).
      expect(optimal.isOptimalIn(93, 3, r('S15 T18 D12')), isFalse);
      expect(optimal.optimalRoutesIn(97, 3), hasLength(4));
      final first = optimal.threeDartFirstDarts(97);
      for (final route in optimal.optimalRoutesIn(97, 3)) {
        expect(route.setupDarts.any(first.contains), isTrue, reason: route.notation);
      }
    });

    test('74 keeps the follow-ups of its aims (S20 leaves 54), and S14 T10 D15 through the aim 14', () {
      expect(optimal.optimalRoutesIn(74, 3).length, greaterThan(40));
      expect(optimal.isOptimalIn(74, 3, r('S20 T14 D6')), isTrue); // S20 leaves 54, whose T14 D6 is optimal
      // S14 is an aim on 74 (T14 leaves D16); S14 leaves 60, whose T10 D15 is optimal.
      expect(optimal.isOptimalIn(74, 3, r('S14 T10 D15')), isTrue);
      expect(optimal.isOptimalIn(74, 3, r('S14 T14 D9')), isTrue);
    });

    test('the first dart is one of the aims and nothing else: 68 is 18 first (S18 leaves the Bull, T18 D7)', () {
      expect(optimal.threeDartAims(68), [18, 20, 16, 12, 14, 10, 6]);
      expect(optimal.threeDartFirstDarts(68), {
        for (final n in [18, 20, 16, 14, 12, 10, 6]) ...[DartThrow.parse('S$n'), DartThrow.parse('T$n')],
      });
      expect(optimal.optimalRoutesIn(68, 3).first.notation, 'S18 S10 D20');
      // No route without an aim: not S19 (S19 and S3 together leave 46), S1,
      // S2, S3 or S11 first.
      for (final route in ['S19 S11 D19', 'S17 S1 Bull', 'S1 T17 D8', 'S15 S3 Bull', 'T11 S11 D12']) {
        expect(optimal.isOptimalIn(68, 3, r(route)), isFalse, reason: route);
      }
      // S2 can still come second: S16 leaves 52, then S2 leaves the Bull.
      expect(optimal.isOptimalIn(68, 3, r('S16 S2 Bull')), isTrue);
      // Every two-dart number over 60 has aims.
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) == 2) expect(optimal.threeDartAims(t), isNotEmpty, reason: '$t');
      }
    });

    test('an odd double or the Bull has no backup, so a single that leaves a better double follows: 88 is T18 S18 D8, not T18 S4 D15', () {
      List<String> routes(int left) => [for (final x in AimPairs.twoDartsOnDoubleRoutes(left)) x.notation];
      expect(routes(34), ['S18 D8', 'S14 D10', 'S10 D12', 'S6 D14', 'S2 D16']);
      expect(routes(14), ['S12 D1', 'S10 D2', 'S6 D4', 'S4 D5', 'S2 D6']);
      expect(routes(50), ['S18 D16', 'S14 D18', 'S10 D20']);
      // A double with a backup has just that; 44 is no double; 2 has no single.
      expect(routes(28), ['S14 D7']);
      expect(routes(44), isEmpty);
      expect(routes(2), isEmpty);
      expect(optimal.isOptimalIn(88, 3, r('T18 S18 D8')), isTrue);
      for (final route in ['T18 S4 D15', 'T18 S8 D13', 'T18 S12 D11', 'T18 T2 D14']) {
        expect(optimal.isOptimalIn(88, 3, r(route)), isFalse, reason: route);
      }
      // 68: T18 leaves 14, and no triple follows it.
      expect(optimal.isOptimalIn(68, 3, r('T18 S2 D6')), isTrue);
      expect(optimal.isOptimalIn(68, 3, r('T18 T2 D4')), isFalse);
      // The Bull after a triple, and S20 first on 110 stays.
      expect(notations(optimal.optimalRoutesIn(110, 3)),
          {'T20 S10 D20', 'T20 S14 D18', 'T20 S18 D16', 'T20 S20 D15', 'T18 S20 D18'});
      // It can still start with an aim's single: S16 leaves 72, then T18 D9.
      expect(optimal.isOptimalIn(88, 3, r('S16 T18 D9')), isTrue);
    });

    test('a double with a backup: 88 is T20 S14 D7 (D14 missed into S14 still has D7), not T20 S4 D12', () {
      expect(AimPairs.missedDoubleRoute(28)!.notation, 'S14 D7');
      expect(AimPairs.missedDoubleRoute(40)!.notation, 'S20 D10');
      expect(AimPairs.missedDoubleRoute(4)!.notation, 'S2 D1');
      // 14: S7 leaves 7. 34: S17 leaves 17. 2: nothing after D1. 44 is no double,
      // and the Bull has no backup.
      for (final left in [2, 14, 34, 44, 50]) {
        expect(AimPairs.missedDoubleRoute(left), isNull, reason: '$left');
      }
      expect(notations(optimal.optimalRoutesIn(28, 2)), {'S14 D7'});
      expect(optimal.optimalRoutesIn(88, 3).first.notation, 'T20 S14 D7');
      expect(optimal.isOptimalIn(88, 3, r('T16 S20 D10')), isTrue);
      for (final route in ['T20 S4 D12', 'T20 S8 D10', 'T20 T8 D2', 'T16 S4 D18']) {
        expect(optimal.isOptimalIn(88, 3, r(route)), isFalse, reason: route);
      }
      // It can still start with an aim's single: S16 leaves 72, then T20 D6.
      expect(optimal.isOptimalIn(88, 3, r('S16 T20 D6')), isTrue);
    });

    test('every route can be thrown from an aim, and after its triple comes the backup or a single that leaves a better double', () {
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        final first = optimal.threeDartFirstDarts(t);
        bool fine(DartThrow a, DartThrow b) {
          if (!first.contains(a)) return false;
          if (!a.isTreble) return true;
          final backup = AimPairs.missedDoubleRoute(t - a.score);
          if (backup != null) return backup.darts.first == b;
          return b.multiplier == Multiplier.single &&
              BetterDoubles.isBetter(AimPairs.finisherFor(t - a.score - b.score)!);
        }

        for (final route in optimal.optimalRoutesIn(t, 3)) {
          final [a, b] = route.setupDarts.toList();
          expect(fine(a, b) || fine(b, a), isTrue, reason: '$t ${route.notation}');
        }
      }
    });

    test('64: S14 then T14 D4 (S14 D18 if T14 is missed) - the single and triple of one number', () {
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
      // ...when the number is an aim: on 74, T10 leaves 44 and T6 56.
      expect(optimal.isOptimalIn(74, 3, r('S10 T10 D17')), isFalse);
      expect(optimal.isOptimalIn(74, 3, r('S6 T6 Bull')), isFalse);
      expect(optimal.isOptimalIn(64, 3, r('S14 T14 D4')), isTrue);
      expect(AimPairs.sameNumberThreeDartRoutes(60), isEmpty); // two darts there
      for (var t = AimPairs.threeDartAbove + 1; t <= CheckoutEngine.maxCheckout; t++) {
        if (engine.minimumDarts(t) != 2) continue;
        final first = optimal.threeDartFirstDarts(t);
        for (final route in AimPairs.sameNumberThreeDartRoutes(t)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(optimal.isOptimalIn(t, 3, route), route.setupDarts.any(first.contains),
              reason: '$t ${route.notation}');
        }
      }
    });

    test('two singles and the triple of a number leave doubles: it and its neighbours count, any double', () {
      // The rule's own examples on 64 (S16 S16 D16, T16 D8).
      for (final route in ['S16 S16 D16', 'S16 S8 D20', 'T8 S8 D16', 'S16 T8 D12', 'T16 S8 D4']) {
        expect(optimal.isOptimalIn(64, 3, r(route)), isTrue, reason: route);
      }
      // What it adds, whatever the double is.
      for (final (target, route) in [
        (64, 'S18 T4 D17'),
        (66, 'S18 T4 D18'),
        (66, 'T8 S16 D13'),
        (68, 'S18 T4 D19'),
        (70, 'S18 S18 D17'),
        (70, 'S18 T4 D20'),
        (70, 'T8 S16 D15'),
        (74, 'S20 S20 D17'),
        (78, 'S20 S20 D19'),
      ]) {
        expect(optimal.isOptimalIn(target, 3, r(route)), isTrue, reason: '$target $route');
      }
      expect(notations(AimPairs.twoSinglesRoutes(64)), containsAll(['S16 S16 D16', 'S18 T4 D17']));
      // No number's neighbours make a number of their own: 64 is not S7 S7 Bull.
      expect(notations(AimPairs.twoSinglesRoutes(64)), isNot(contains('S7 S7 Bull')));
      expect(AimPairs.twoSinglesRoutes(93), isEmpty); // S n S n cannot leave a double
    });

    test('they still have to start with an aim, and a triple keeps to what follows it', () {
      // 11 is no aim on 64: neither S11 nor T11 leaves a double.
      expect(optimal.isOptimalIn(64, 3, r('T11 S11 D10')), isFalse);
      // 64: T18 leaves D5, and S4 would leave D3.
      expect(notations(AimPairs.twoSinglesRoutes(64)), contains('T18 S4 D3'));
      expect(optimal.isOptimalIn(64, 3, r('T18 S4 D3')), isFalse);
      // 62: T20 leaves 2, which cannot use the last two darts, so 20 is no aim.
      expect(notations(AimPairs.twoSinglesRoutes(62)), contains('S20 S20 D11'));
      expect(optimal.isOptimalIn(62, 3, r('S20 S20 D11')), isFalse);
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

  group('three darts under 60: a choice in the practice modes', () {
    test('the aims: the triple leaves a double, and so does the single or two of the single', () {
      expect(optimal.threeDartAims(47), [15, 13, 11, 9, 7]);
      expect(optimal.threeDartAims(58), [18, 16, 14, 12, 10, 8]);
      // 42: 12 is there because S12 leaves D15 and T12 leaves D3.
      expect(optimal.threeDartAims(42), [12, 10, 8, 6, 4, 2]);
      // 48: S4 leaves 44, but S4 S4 leaves D20 and T4 leaves D18.
      expect(optimal.threeDartAims(48), contains(4));
      expect(optimal.threeDartFirstDarts(47), {
        for (final n in [15, 13, 11, 9, 7]) ...[DartThrow.parse('S$n'), DartThrow.parse('T$n')],
      });
    });

    test('every two-dart number from 5 to 59 has it, 3 and 60 do not, and it never comes dealt', () {
      var numbers = 0;
      for (var t = 2; t <= AimPairs.threeDartAbove; t++) {
        final expected = engine.minimumDarts(t) == 2 && t != 3 && t != AimPairs.threeDartAbove;
        expect(optimal.hasPracticeThreeDartOption(t), expected, reason: '$t');
        expect(optimal.hasThreeDartOption(t), isFalse, reason: '$t');
        if (expected) numbers++;
      }
      expect(numbers, 36);
      final catalog = CheckoutCatalog(engine, optimal);
      expect(catalog.threeDartFor(47), isNull);
      expect(catalog.otherDarts(catalog.forTarget(47)!)?.darts, 3);
      expect(catalog.otherDarts(catalog.forTarget(47)!.withDarts(3, r('S7 D20')))?.darts, 2);
      expect(catalog.otherDarts(catalog.forTarget(60)!), isNull);
      expect(catalog.otherDarts(catalog.forTarget(40)!), isNull);
    });

    test('47: a first dart that leaves a double, then that double, or its single and the next double', () {
      expect(notations(optimal.optimalRoutesIn(47, 3)), {
        'S15 D16', 'T15 D1', 'S13 D17', 'T13 D4', 'S11 D18', 'T11 D7', 'S9 D19', 'T9 D10', 'S7 D20', 'T7 D13',
        'S16 S15 D8', 'T13 S4 D2', 'S18 S11 D9', 'T9 S10 D5', 'S20 S7 D10',
      });
      // A better double first: that is the route shown after a miss.
      expect(optimal.optimalRoutesIn(47, 3).first.notation, 'S15 D16');
      expect(optimal.optimalRoutesIn(42, 3).first.notation, 'S10 D16');
    });

    test('the Bull and an odd double have no second chance: 59 is S9 Bull, 47 T7 D13', () {
      expect(AimPairs.doubleAndItsSingle(40), {DartThrow.parse('D20'), DartThrow.parse('S20')});
      expect(AimPairs.doubleAndItsSingle(26), {DartThrow.parse('D13')});
      expect(AimPairs.doubleAndItsSingle(50), {DartThrow.bull});
      expect(AimPairs.doubleAndItsSingle(44), isEmpty);
      expect(notations(optimal.optimalRoutesIn(59, 3)),
          {'S19 D20', 'T19 D1', 'T9 D16', 'S9 Bull', 'S20 S19 D10', 'T9 S16 D8'});
    });

    test('a single that leaves no double has the same or a neighbouring number: 48 is S4 S4 D20', () {
      for (final route in ['S4 S4 D20', 'T4 S4 D16', 'S18 S4 D13']) {
        expect(optimal.optimalRoutesIn(48, 3).any(r(route).isEquivalentTo), isTrue, reason: route);
      }
      // S12 leaves D18, so D18 is the dart: not S12 S12 D12.
      expect(optimal.optimalRoutesIn(48, 3).any(r('S12 S12 D12').isEquivalentTo), isFalse);
    });

    test('every route starts on a lit dart and is legal, with a better double or not', () {
      for (var t = 5; t < AimPairs.threeDartAbove; t++) {
        if (!optimal.hasPracticeThreeDartOption(t)) continue;
        final first = optimal.threeDartFirstDarts(t);
        final routes = optimal.optimalRoutesIn(t, 3);
        expect(routes, isNotEmpty, reason: '$t');
        for (final route in routes) {
          expect(route.isCheckoutFor(t), isTrue, reason: '$t ${route.notation}');
          expect(route.setupDarts.any(first.contains), isTrue, reason: '$t ${route.notation}');
        }
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
  Set<String> notations(Iterable<CheckoutRoute> routes) => {for (final x in routes) x.notation};

  group('neighbouring singles then a double, on 41 to 60 (what follows the first of three darts)', () {
    test('42: 8 and 16 are neighbours - S8 D17 and S16 D13', () {
      expect(notations(AimPairs.neighbourSingleRoutes(42)), containsAll(['S8 D17', 'S16 D13']));
      expect(optimal.isOptimal(42, r('S8 D17')), isFalse); // two darts have rule one
    });

    test('whatever the doubles are: 57 has S19 D19 (19 and 7, S7 leaves the Bull)', () {
      expect(notations(AimPairs.neighbourSingleRoutes(57)), containsAll(['S19 D19', 'S7 Bull']));
    });

    test('only from 41 to 60', () {
      expect(AimPairs.neighbourSingleRoutes(40), isEmpty);
      expect(AimPairs.neighbourSingleRoutes(61), isEmpty);
      expect(AimPairs.neighbourSingleRoutes(42), isNotEmpty);
      for (var t = AimPairs.minNeighbourSingleTarget; t <= AimPairs.maxNeighbourSingleTarget; t++) {
        for (final route in AimPairs.neighbourSingleRoutes(t)) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
        }
      }
    });

    test('49 never comes with three darts: that is a choice in the practice modes', () {
      expect(optimal.hasThreeDartOption(49), isFalse);
      expect(optimal.hasPracticeThreeDartOption(49), isTrue);
    });
  });
}
