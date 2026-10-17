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

  group('RouteOrder.forPopup: a Bull finish next to the route with the treble of its single', () {
    final engine = CheckoutEngine();
    final optimal = OptimalRouteService(engine);

    List<String> popup(int target) =>
        RouteOrder.forPopup(optimal.optimalRoutes(target)).map((x) => x.notation).toList();

    test('57: S7 Bull moves up next to T7 D18, the rest stays as it was', () {
      // By finisher it would be T17 D3, T7 D18, S17 D20, S7 Bull.
      expect(order(optimal.optimalRoutes(57)), ['T17 D3', 'T7 D18', 'S17 D20', 'S7 Bull']);
      expect(popup(57), ['T17 D3', 'T7 D18', 'S7 Bull', 'S17 D20']);
    });

    test('130: T20 S20 Bull is next to T20 T20 D5', () {
      expect(popup(130), ['T20 T20 D5', 'T20 S20 Bull']);
    });

    test('119: every Bull finish with a single is right after its partner', () {
      final list = popup(119);
      for (final pair in [
        ('T19 T12 D13', 'T19 S12 Bull'),
        ('T20 T9 D16', 'T20 S9 Bull'),
        ('T18 T15 D10', 'T18 S15 Bull'),
        ('T17 T18 D7', 'T17 S18 Bull'),
      ]) {
        final partner = list.indexOf(pair.$1);
        expect(partner, greaterThanOrEqualTo(0), reason: pair.$1);
        expect(list[partner + 1], pair.$2, reason: '${pair.$2} next to ${pair.$1}');
      }
    });

    test('a Bull finish with no partner stays at the end: S1 Bull has no D24, T20 Bull has no single', () {
      expect(popup(51).last, 'S1 Bull');
      expect(popup(51), order(optimal.optimalRoutes(51)), reason: 'nothing moved on 51');
      expect(popup(110), order(optimal.optimalRoutes(110)));
    });

    test('works from the finisher order whatever order the routes come in', () {
      final routes = optimal.optimalRoutes(119);
      final expected = RouteOrder.forPopup(routes).map((x) => x.notation).toList();
      for (var seed = 0; seed < 15; seed++) {
        final shuffled = routes.toList()..shuffle(Random(seed));
        expect(RouteOrder.forPopup(shuffled).map((x) => x.notation).toList(), expected, reason: 'seed $seed');
      }
    });

    /// An independent check of the rule: [other] is [bull] with one single made a
    /// treble of the same number, finishing on a double that is not the Bull.
    bool isPartner(CheckoutRoute bull, CheckoutRoute other) {
      if (other.length != bull.length || other.darts.last.isBull) return false;
      if (other.darts.last.multiplier != Multiplier.double) return false;
      String key(Iterable<DartThrow> darts) => (darts.map((d) => d.notation).toList()..sort()).join(' ');
      for (final single in bull.setupDarts.where((d) => d.multiplier == Multiplier.single && !d.isOuterBull)) {
        final swapped = [...bull.setupDarts]..remove(single);
        swapped.add(DartThrow(Multiplier.treble, single.number));
        if (key(swapped) == key(other.setupDarts)) return true;
      }
      return false;
    }

    test('every number: the same routes; only partnered Bull finishes move, and the rest keeps its order', () {
      var moved = 0;
      for (final n in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(n);
        final byFinisher = RouteOrder.byFinisher(routes);
        final result = RouteOrder.forPopup(routes);
        expect(result.map((x) => x.notation).toSet(), byFinisher.map((x) => x.notation).toSet(),
            reason: '$n keeps every route');
        expect(result, hasLength(byFinisher.length), reason: '$n');

        // The Bull finishes that have a partner are the ones that move.
        final partnered = [
          for (final x in byFinisher)
            if (x.darts.last.isBull && byFinisher.any((o) => isPartner(x, o))) x,
        ];
        moved += partnered.length;
        List<String> without(List<CheckoutRoute> list) =>
            [for (final x in list) if (!partnered.contains(x)) x.notation];
        expect(without(result), without(byFinisher), reason: '$n: everything else keeps its order');

        // Each one is right after its partner.
        for (final bull in partnered) {
          final at = result.indexOf(bull);
          expect(isPartner(bull, result[at - 1]), isTrue,
              reason: '$n: $bull should follow its partner, but follows ${result[at - 1]}');
        }
        // A Bull finish with no partner is not moved relative to the other unpartnered Bull finishes.
        List<String> lonelyBulls(List<CheckoutRoute> list) => [
              for (final x in list)
                if (x.darts.last.isBull && !partnered.contains(x)) x.notation,
            ];
        expect(lonelyBulls(result), lonelyBulls(byFinisher), reason: '$n');
      }
      expect(moved, greaterThan(20), reason: 'the rule applies to many numbers');
    });
  });

  test('the All possibilities popup lists the routes in that order', () {
    final screen = File('lib/ui/result_screen.dart').readAsStringSync();
    expect(screen, contains('for (final route in RouteOrder.forPopup(result.optimalRoutes)) figureFor(route)'));
  });
}
