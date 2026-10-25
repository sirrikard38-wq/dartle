import 'dart:io';
import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  treblePairingTests();
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

    test('57: S7 Bull moves up next to T7 D18, T17 D3 next to S17 D20, the rest stays as it was', () {
      // By finisher it would be T17 D3, T7 D18, S19 D19, S17 D20, S7 Bull.
      expect(order(optimal.optimalRoutes(57)), ['T17 D3', 'T7 D18', 'S19 D19', 'S17 D20', 'S7 Bull']);
      // T17 D3 then goes right after its single, S17 D20.
      expect(popup(57), ['T7 D18', 'S7 Bull', 'S19 D19', 'S17 D20', 'T17 D3']);
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
      List<String> bullOnly(int n) => RouteOrder.withBullPairsTogether(RouteOrder.byFinisher(optimal.optimalRoutes(n)))
          .map((x) => x.notation)
          .toList();
      expect(bullOnly(51).last, 'S1 Bull');
      expect(bullOnly(51), order(optimal.optimalRoutes(51)), reason: 'no Bull finish moved on 51');
      expect(bullOnly(110), order(optimal.optimalRoutes(110)));
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
        final result = RouteOrder.withBullPairsTogether(byFinisher);
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
    expect(screen, contains('RouteOrder.forPopup(result.optimalRoutes)'));
  });
}

void treblePairingTests() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  List<String> popup(int target) =>
      RouteOrder.forPopup(optimal.optimalRoutes(target)).map((x) => x.notation).toList();

  group('RouteOrder.forPopup: a two-dart treble route right next to the single of its number', () {
    test('23: T7 D1 next to S7 D8, T5 D4 next to S5 D9, T3 D7 next to S3 D10, T1 D10 next to S1 D11 (one side or the other)', () {
      final list = popup(23);
      for (final (single, treble) in [
        ('S7 D8', 'T7 D1'),
        ('S5 D9', 'T5 D4'),
        ('S3 D10', 'T3 D7'),
        ('S1 D11', 'T1 D10'),
      ]) {
        final at = list.indexOf(single);
        expect(at, greaterThanOrEqualTo(0), reason: single);
        expect((list.indexOf(treble) - at).abs(), 1, reason: '$treble right next to $single');
      }
    });

    test('43: T11 D5 is next to S11 D16', () {
      final list = popup(43);
      expect((list.indexOf('T11 D5') - list.indexOf('S11 D16')).abs(), 1);
    });

    test('every number: nothing lost or added, and every treble with a single is next to it', () {
      for (final n in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(n);
        final list = RouteOrder.forPopup(routes);
        expect(list.map((x) => x.notation).toSet(), routes.map((x) => x.notation).toSet(), reason: '$n');
        expect(list, hasLength(routes.length), reason: '$n');
        for (final treble in list) {
          if (treble.length != 2 || !treble.darts.first.isTreble) continue;
          final number = treble.darts.first.number;
          final singles = [
            for (var i = 0; i < list.length; i++)
              if (list[i].length == 2 &&
                  list[i].darts.first.multiplier == Multiplier.single &&
                  list[i].darts.first.number == number)
                i,
          ];
          if (singles.isEmpty) continue;
          final at = list.indexOf(treble);
          expect(singles.any((i) => (i - at).abs() == 1), isTrue,
              reason: '$n: ${treble.notation} should be next to its single');
        }
      }
    });
  });
}
