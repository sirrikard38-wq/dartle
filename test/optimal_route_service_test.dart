import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

CheckoutRoute r(String text) => CheckoutRoute.parse(text);

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);

  Set<String> notations(int target, int darts) => {
        for (final route in optimal.optimalRoutesIn(target, darts)) route.notation,
      };

  group('canonical chart', () {
    test('every checkoutable target has a chart entry', () {
      final missing = engine.checkoutableTargets
          .where((t) => !canonicalCheckouts.containsKey(t));
      expect(missing, isEmpty);
    });

    test('every chart entry is legal, totals correctly and is minimum-dart', () {
      for (final entry in canonicalCheckouts.entries) {
        final route = CheckoutRoute.parse(entry.value);
        expect(route.total, entry.key, reason: '${entry.key}: ${entry.value}');
        expect(engine.isLegalRoute(entry.key, route), isTrue, reason: '${entry.key}: ${entry.value}');
        expect(route.length, engine.minimumDarts(entry.key), reason: '${entry.key}: ${entry.value}');
      }
    });
  });

  group('the checkout tables', () {
    test('one row for every number from 2 to 170, with 1, 2 and 3 darts in hand', () {
      for (final darts in [1, 2, 3]) {
        expect(checkoutTables[darts]!.keys.toSet(), {for (var t = 2; t <= 170; t++) t}, reason: '$darts');
      }
    });

    test('every row reads: its targets, and routes that check out in the darts in hand', () {
      for (final darts in [1, 2, 3]) {
        checkoutTables[darts]!.forEach((target, row) {
          expect(CheckoutTable.aims(row), isNotEmpty, reason: '$darts $target');
          CheckoutTable.alternatives(row);
          final setup = row.rule == 'Priprema' || row.rule == 'Nema izlaza';
          final routes = CheckoutTable.routes(row, target);
          expect(routes.isEmpty, setup, reason: '$darts $target ${row.route}');
          for (final route in routes) {
            expect(route.length, lessThanOrEqualTo(darts), reason: '$darts $target $route');
            expect(engine.isLegalRoute(target, route), isTrue, reason: '$darts $target $route');
          }
        });
      }
    });

    test('a pair of neighbours is a route each; "ili" is either route', () {
      final pair = CheckoutTable.row(48, 2)!;
      expect(CheckoutTable.aims(pair).map((d) => d.notation), ['S16', 'S8']);
      expect(CheckoutTable.routes(pair, 48).map((x) => x.notation), ['S16 D16', 'S8 D20']);
      final either = CheckoutTable.row(61, 3)!;
      expect(CheckoutTable.routes(either, 61).map((x) => x.notation), ['25 D18', 'Bull S3 D4']);
      // A setup for the next visit is no route: 99 with two darts.
      expect(CheckoutTable.routes(CheckoutTable.row(99, 2)!, 99), isEmpty);
    });
  });

  group('optimal routes', () {
    test('the table route first, then a route for each target almost as good', () {
      // 62 with three darts: T10, or T14 (20 is D10) and T18 (8 is D4).
      expect(optimal.optimalRoutesIn(62, 3).map((x) => x.notation).take(3), ['T10 D16', 'T14 D10', 'T18 D4']);
      expect(optimal.aimsIn(62, 3).map((d) => d.notation).toSet(), containsAll(['T10', 'T14', 'T18']));
    });

    test('a target just as good counts too: of the same kind, its hit leaves a checkout as soon, its miss as often', () {
      // 25 with two darts: the table's S17 (S3 and S9 almost as good), and S19
      // and S7 - S7 leaves D9, a miss into S19 leaves D3.
      expect(optimal.aimsIn(25, 2).map((d) => d.notation).toSet(), {'S17', 'S3', 'S9', 'S19', 'S7'});
      expect(optimal.isOptimal(25, r('S7 D9')), isTrue);
      // S1 leaves D12, but a miss into S20 or S18 leaves nothing.
      expect(optimal.isOptimal(25, r('S1 D12')), isFalse);
      // A single is not a treble: 57 is S17, S19 or S7, not T17 D3.
      expect(optimal.isOptimal(57, r('T17 D3')), isFalse);
    });

    test('127 with three darts is T20, not T19; T17 can go first too', () {
      expect(optimal.optimalRoutesIn(127, 3).first.notation, 'T20 T17 D8');
      // S17 still leaves 110 (T20 Bull), as much as S20 leaves (107, T19 Bull).
      expect(optimal.aimsIn(127, 3), {DartThrow.parse('T20'), DartThrow.parse('T17')});
    });

    test('the other dart of the table route counts when its miss is no worse: 149, T19', () {
      // S20 leaves 129 and S19 leaves 130: no checkout either way.
      expect(optimal.aimsIn(149, 3), contains(DartThrow.parse('T19')));
      expect(optimal.missesKept(149, 3, DartThrow.parse('T20')), 0);
      expect(optimal.missesKept(127, 3, DartThrow.parse('T20')), 1);
      expect(optimal.missesKept(127, 3, DartThrow.parse('T19')), 0);
    });

    test('61 with three darts: the Bull area first, 25 or the Bull', () {
      expect(notations(61, 3), {'25 D18', 'Bull S3 D4'});
      expect(optimal.aimsIn(61, 3), {DartThrow.bull, DartThrow.outerBull});
      // With two darts it is T11 D14.
      expect(notations(61, 2), {'T11 D14'});
    });

    test('a route may use fewer darts than are in hand: 64 with three darts is T16 D8', () {
      expect(optimal.isOptimalIn(64, 3, r('T16 D8')), isTrue);
      expect(optimal.isOptimalIn(40, 3, r('D20')), isTrue);
      expect(optimal.isOptimalIn(64, 2, r('T16 D8')), isFalse);
      expect(optimal.isOptimalIn(64, 2, r('T14 D11')), isTrue);
    });

    test('known routes with the fewest darts', () {
      const known = {
        40: 'D20', 50: 'Bull', 100: 'T20 D20', 110: 'T20 Bull', 120: 'T20 S20 D20',
        130: 'T20 T20 D5', 160: 'T20 T20 D20', 167: 'T20 T19 Bull', 170: 'T20 T20 Bull',
      };
      known.forEach((target, text) {
        expect(optimal.optimalRoute(target)?.notation, text, reason: '$target');
      });
    });

    test('every number that can be checked out has routes, all legal, none twice', () {
      for (final target in engine.checkoutableTargets) {
        for (var darts = engine.minimumDarts(target)!; darts <= 3; darts++) {
          final routes = optimal.optimalRoutesIn(target, darts);
          expect(routes, isNotEmpty, reason: '$target with $darts');
          for (final route in routes) {
            expect(engine.isLegalRoute(target, route), isTrue, reason: '$target $route');
            expect(route.length, lessThanOrEqualTo(darts), reason: '$target $route');
          }
          for (var i = 0; i < routes.length; i++) {
            for (var j = i + 1; j < routes.length; j++) {
              expect(routes[i].isEquivalentTo(routes[j]), isFalse, reason: '$target ${routes[i]} twice');
            }
          }
        }
      }
    });

    test('impossible numbers, and fewer darts than needed, have nothing', () {
      for (final t in [159, 162, 163, 165, 166, 168, 169, 171, 1]) {
        expect(optimal.optimalRoute(t), isNull, reason: '$t');
        expect(optimal.optimalRoutesIn(t, 3), isEmpty, reason: '$t');
      }
      expect(optimal.optimalRoutesIn(150, 2), isEmpty);
      expect(optimal.optimalRoutesIn(100, 1), isEmpty);
    });

    test('setup-dart order does not matter, the finisher does', () {
      expect(optimal.isOptimal(170, r('T20 T20 Bull')), isTrue);
      expect(optimal.isOptimal(170, r('Bull T20 T20')), isFalse);
      expect(optimal.isOptimal(167, r('T19 T20 Bull')), isTrue);
    });

    test('three darts: dealt over 60, a choice up to 60, never for one- and three-dart numbers', () {
      expect(optimal.hasThreeDartOption(61), isTrue);
      expect(optimal.hasThreeDartOption(60), isFalse);
      expect(optimal.hasPracticeThreeDartOption(60), isTrue);
      expect(optimal.hasPracticeThreeDartOption(47), isTrue);
      for (final n in [40, 50, 150]) {
        expect(optimal.hasThreeDartOption(n), isFalse, reason: '$n');
        expect(optimal.hasPracticeThreeDartOption(n), isFalse, reason: '$n');
      }
    });
  });

  group('better doubles', () {
    test('the set is D20, D18, D16, D14, D12, D10, D8, D6, D5, D4, D2, D1', () {
      expect(BetterDoubles.numbers, {20, 18, 16, 14, 12, 10, 8, 6, 5, 4, 2, 1});
      expect(BetterDoubles.isBetter(DartThrow.parse('D20')), isTrue);
      expect(BetterDoubles.isBetter(DartThrow.parse('D19')), isFalse);
      expect(BetterDoubles.isBetter(DartThrow.parse('Bull')), isFalse);
      expect(BetterDoubles.isBetter(DartThrow.parse('T20')), isFalse);
    });

    test('a route leaves a better double when it finishes on one', () {
      expect(BetterDoubles.leavesBetterDouble(r('T20 D5')), isTrue);
      expect(BetterDoubles.leavesBetterDouble(r('T20 T20 Bull')), isFalse);
    });

    final routes = [r('S16 D16'), r('S8 D20'), r('T8 D12'), r('S19 D19'), r('S12 D18')];

    test('extras: one more route with a better double, then up to 2 others', () {
      final extras = BetterDoubles.extras(routes, exclude: [routes.first]);
      expect(extras, hasLength(3));
      expect(BetterDoubles.leavesBetterDouble(extras.first), isTrue);
      expect(extras.any((x) => x.isEquivalentTo(routes.first)), isFalse);
    });

    test('extras never repeat a route that is already on screen', () {
      final extras = BetterDoubles.extras(routes, exclude: [routes[0], routes[1]]);
      expect(extras.any((x) => x.isEquivalentTo(routes[1])), isFalse);
      expect(extras, hasLength(3));
    });

    test('the treble whose single also leaves a better double is among the extras (T8 D12)', () {
      expect(BetterDoubles.extras(routes, exclude: [routes.first]).map((x) => x.notation), contains('T8 D12'));
      expect(BetterDoubles.isSafeTreble(r('T11 D5')), isTrue);
      expect(BetterDoubles.isSafeTreble(r('T14 D5')), isFalse);
    });

    test('extras of a number with one optimal route is empty', () {
      final only = optimal.optimalRoutes(170);
      expect(BetterDoubles.extras(only, exclude: [only.first]), isEmpty);
    });
  });
}
