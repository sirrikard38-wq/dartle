import 'dart:io';
import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  CheckoutRoute r(String text) => CheckoutRoute.parse(text);
  List<String> order(Iterable<CheckoutRoute> routes) =>
      RouteOrder.byFinisher(routes).map((x) => x.notation).toList();

  group('RouteOrder.byFinisher: D1, D2 ... D20, then the Bull', () {
    test('goes by the value of the dart the route finishes on', () {
      final routes = [
        r('T20 Bull'), r('T20 D20'), r('T20 D6'), r('T10 D1'), r('T19 D2'), r('T20 D13'),
      ];
      expect(order(routes), ['T10 D1', 'T19 D2', 'T20 D6', 'T20 D13', 'T20 D20', 'T20 Bull']);
    });

    test('the Bull comes after D20', () {
      expect(order([r('T20 T20 Bull'), r('T20 T20 D20')]), ['T20 T20 D20', 'T20 T20 Bull']);
      expect(RouteOrder.finisherValue(r('T20 Bull')), greaterThan(RouteOrder.finisherValue(r('T20 D20'))));
    });

    test('the same finisher: the smaller setup darts first', () {
      // 132 on D9: T18 T20 before T19 T19.
      expect(order([r('T19 T19 D9'), r('T20 T18 D9')]), ['T20 T18 D9', 'T19 T19 D9']);
      // The order the setup darts were written in does not matter.
      expect(order([r('T20 T16 D12'), r('T16 T20 D12')]).toSet(), hasLength(2));
      expect(order([r('T20 S1 D12'), r('S1 T20 D12'), r('S1 T19 D12')]).first, 'S1 T19 D12');
    });

    test('the order never depends on the order it was given in', () {
      final routes = [
        r('T20 T16 D12'), r('T19 T17 D12'), r('T20 D20 D16'), r('T20 T20 D6'),
        r('T18 T18 D12'), r('T20 D18 D18'), r('T19 T19 D9'), r('T20 T18 D9'),
      ];
      final expected = order(routes);
      for (var seed = 0; seed < 25; seed++) {
        expect(order(routes.toList()..shuffle(Random(seed))), expected, reason: 'seed $seed');
      }
    });

    test('every number: the same routes, finishers going up, the Bull last', () {
      final engine = CheckoutEngine();
      final optimal = OptimalRouteService(engine);
      var checked = 0;
      for (final n in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(n);
        final sorted = RouteOrder.byFinisher(routes);
        expect(sorted.map((x) => x.notation).toSet(), routes.map((x) => x.notation).toSet(),
            reason: '$n keeps every route');
        expect(sorted, hasLength(routes.length), reason: '$n');
        final values = sorted.map(RouteOrder.finisherValue).toList();
        for (var i = 1; i < values.length; i++) {
          expect(values[i], greaterThanOrEqualTo(values[i - 1]), reason: '$n ${sorted[i]}');
        }
        if (sorted.any((x) => x.darts.last.isBull)) {
          expect(sorted.last.darts.last.isBull, isTrue, reason: '$n: the Bull is last');
        }
        checked++;
      }
      expect(checked, greaterThan(100));
    });

    test('132 starts on D6 and ends on D20', () {
      final engine = CheckoutEngine();
      final sorted = RouteOrder.byFinisher(OptimalRouteService(engine).optimalRoutes(132));
      expect(sorted.first.notation, 'T20 T20 D6');
      expect(sorted.last.darts.last.notation, 'D20');
      expect(sorted.map((x) => x.darts.last.notation).toList(),
          ['D6', 'D9', 'D9', 'D12', 'D12', 'D12', 'D15', 'D15', 'D15', 'D16', 'D18', 'D18', 'D18', 'D20']);
    });
  });

  test('the All possibilities popup lists the routes in that order', () {
    final screen = File('lib/ui/result_screen.dart').readAsStringSync();
    expect(screen, contains('for (final route in RouteOrder.byFinisher(result.optimalRoutes)) figureFor(route)'));
  });
}
