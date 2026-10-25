import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

CheckoutRoute r(String text) => CheckoutRoute.parse(text);

void main() {
  trebleLeaveTests();
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
      expect(engine.isLegalRoute(121, r('T20 T15 D8')), isTrue);
      expect(optimal.isOptimal(121, r('T20 T15 D8')), isFalse);
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

  group('two darts over 50 up to 70: bull-safe', () {
    test('the triple of the number whose single leaves Bull, or that single and Bull', () {
      // Over 60 these are the optimal routes (and, on 61 and 65 only, the outer
      // bull and a better double - see the next groups).
      expect(notations(65), {'T15 D10', 'S15 Bull', '25 D20'});
      expect(notations(70), {'T20 D5', 'S20 Bull'});
      expect(optimal.optimalRoute(67)!.notation, 'T17 D8'); // primary
      // From 51 to 60 they are optimal too (see the next group), and still first.
      expect(notations(57), containsAll(['T7 D18', 'S7 Bull']));
      expect(notations(52), contains('S2 Bull')); // 51..54 have no triple route
      expect(notations(51), contains('S1 Bull'));
    });

    test('over 60 only the outer bull and a better double is added: 61 and 65', () {
      // No ordinary single can leave a better double there, so the outer bull is
      // accepted as the single.
      for (final (target, text) in [(65, '25 D20'), (61, '25 D18')]) {
        expect(engine.isLegalRoute(target, r(text)), isTrue, reason: text);
        expect(optimal.isOptimal(target, r(text)), isTrue, reason: text);
      }
      // D19 is not a better double, so 25 D19 on 63 is still not optimal.
      expect(engine.isLegalRoute(63, r('25 D19')), isTrue);
      expect(optimal.isOptimal(63, r('25 D19')), isFalse);
      // Nothing is added on the other numbers over 60.
      for (var t = 61; t <= 70; t++) {
        final extra = SingleLeave.outerBullRoutes(t);
        expect(extra.length, (t == 61 || t == 65) ? 1 : 0, reason: '$t');
      }
    });

    test('every 2-dart target from 55 to 70 teaches the bull-safe route first', () {
      for (var t = 55; t <= 70; t++) {
        expect(optimal.optimalRoute(t)!.notation, BullSafeFinish.twoDartFinish(t)!.notation,
            reason: '$t');
        expect(engine.minimumDarts(t), 2, reason: '$t is a two-dart number');
      }
    });

    test('every 2-dart target from 61 to 70 has the bull-safe routes (61, 65 the outer bull) and the aims', () {
      // 61 is also T19 D2 and T7 D20: aiming where 19 and 7 meet on the
      // triple ring, either hit leaves a better double.
      expect(notations(61), containsAll(['T19 D2', 'T7 D20']));
      for (var t = 61; t <= 70; t++) {
        expect(engine.minimumDarts(t), 2, reason: '$t');
        expect(
            notations(t),
            {
              for (final x in [
                ...BullSafeFinish.twoDartRoutes(t),
                ...SingleLeave.outerBullRoutes(t),
                ...AimPairs.twoDartRoutes(t),
                if (AimPairs.sameDoubleTwice(t) case final twice?) twice,
              ])
                x.notation,
            },
            reason: '$t');
      }
    });

    test('every 2-dart target from 51 to 60 has the bull-safe routes first', () {
      for (var t = 51; t <= 60; t++) {
        final safe = BullSafeFinish.twoDartRoutes(t).map((x) => x.notation).toList();
        final all = optimal.optimalRoutes(t).map((x) => x.notation).toList();
        expect(all.take(safe.length), safe, reason: '$t');
      }
    });
  });

  group('two darts from 41 to 60: a single that leaves a better double is optimal too', () {
    test('57: S17 D20 next to the bull-safe T7 D18 and S7 Bull (never the outer bull)', () {
      expect(optimal.optimalRoutes(57).map((x) => x.notation),
          ['T7 D18', 'S7 Bull', 'S17 D20', 'T17 D3', 'S19 D19']);
    });

    test('60 is S20 D20 as well as T10 D15 and S10 Bull, and T16 D6 / T8 D18', () {
      // 16 and 8 are neighbours: T16 leaves D6, T8 leaves D18.
      expect(notations(60), {'T10 D15', 'S10 Bull', 'S20 D20', 'T16 D6', 'T8 D18'});
    });

    test('51 to 54: the singles, the Bull, the trebles whose single leaves a double, and the aims', () {
      expect(notations(51), containsAll({'S1 Bull', 'S11 D20', 'S15 D18', 'S19 D16'}));
      expect(notations(52), {
        'S2 Bull', 'S12 D20', 'S16 D18', 'S20 D16', // the usual ones
        'T16 D2', 'T12 D8', // S16 leaves D18, S12 leaves D20
        'T14 D5', 'S14 D19', // D19 is not a better double, still listed
        'T8 D14', // T16 and T8 are neighbours: D2 or D14
      });
    });

    test('S19 D19 is optimal on 57 (19 and 7 are neighbours: S7 leaves the Bull), S20 D19 not on 58', () {
      expect(engine.isLegalRoute(57, r('S19 D19')), isTrue);
      expect(optimal.isOptimal(57, r('S19 D19')), isTrue);
      expect(engine.isLegalRoute(58, r('S20 D19')), isTrue);
      expect(optimal.isOptimal(58, r('S20 D19')), isFalse);
    });

    test('every such route is legal and optimal, from 41 to 60', () {
      for (var t = SingleLeave.minTarget; t <= SingleLeave.maxTarget; t++) {
        expect(engine.minimumDarts(t), t == 50 ? 1 : 2, reason: '$t');
        final routes = SingleLeave.twoDartRoutes(t);
        if (t != 50) expect(routes, isNotEmpty, reason: '$t');
        for (final route in routes) {
          expect(engine.isLegalRoute(t, route), isTrue, reason: '$t ${route.notation}');
          expect(BetterDoubles.leavesBetterDouble(route), isTrue, reason: route.notation);
          expect(route.darts.first.multiplier, Multiplier.single, reason: route.notation);
          if (t != 50) expect(optimal.isOptimal(t, route), isTrue, reason: '$t ${route.notation}');
        }
      }
    });

    test('50 is still only the Bull: one dart is fewer than two', () {
      expect(notations(50), {'Bull'});
      expect(optimal.isOptimal(50, r('S10 D20')), isFalse);
    });

    test('40 and below, and 61 and above, are outside the rule', () {
      expect(SingleLeave.covers(40), isFalse);
      expect(SingleLeave.covers(41), isTrue);
      expect(SingleLeave.covers(60), isTrue);
      expect(SingleLeave.covers(61), isFalse);
      expect(SingleLeave.twoDartRoutes(40), isEmpty);
      expect(SingleLeave.twoDartRoutes(61), isEmpty);
    });

    test('the routes are listed on the biggest double first', () {
      expect(SingleLeave.twoDartRoutes(52).map((x) => x.notation), ['S12 D20', 'S16 D18', 'S20 D16']);
      expect(SingleLeave.twoDartRoutes(57).map((x) => x.notation), ['S17 D20']);
    });

    test('109: T19 leaves 52, then S20 D16 (or S12 D20, S16 D18) is optimal, in any order', () {
      for (final text in ['T19 S20 D16', 'S20 T19 D16', 'T19 S12 D20', 'T19 S16 D18']) {
        expect(engine.isLegalRoute(109, r(text)), isTrue, reason: text);
        expect(optimal.isOptimal(109, r(text)), isTrue, reason: text);
      }
      // The bull-safe route is still the first one shown.
      expect(optimal.optimalRoute(109)!.notation,
          BullSafeFinish.threeDartRoutes(109).first.notation);
      expect(notations(109), contains('T19 S2 Bull'));
      // D19 is not one of the better doubles.
      expect(engine.isLegalRoute(109, r('T19 S14 D19')), isTrue);
      expect(optimal.isOptimal(109, r('T19 S14 D19')), isFalse);
    });

    test('after the first treble the same rule applies, and only there', () {
      // 121: T20 leaves 61, where the outer bull is the accepted single (25 D18).
      expect(optimal.isOptimal(121, r('T20 S25 D18')), isTrue);
      // T20 leaves 63 on 123, and 25 D19 is not a better double.
      expect(engine.isLegalRoute(123, r('T20 25 D19')), isTrue);
      expect(optimal.isOptimal(123, r('T20 25 D19')), isFalse);
      var checked = 0;
      for (final target in engine.checkoutableTargets) {
        if (engine.minimumDarts(target) != 3 || chartOnlyCheckouts.contains(target)) continue;
        for (final route in SingleLeave.threeDartRoutes(target)) {
          final left = target - route.darts.first.score;
          expect(route.darts.first.isTreble, isTrue, reason: '$target ${route.notation}');
          expect(left, inInclusiveRange(51, 70), reason: '$target ${route.notation}');
          // A leave over 60 is only ever the outer bull and a better double.
          if (left > 60) expect(route.darts[1].isOuterBull, isTrue, reason: '$target');
          expect(engine.isLegalRoute(target, route), isTrue, reason: '$target ${route.notation}');
          expect(optimal.isOptimal(target, route), isTrue, reason: '$target ${route.notation}');
          checked++;
        }
      }
      expect(checked, greaterThan(20));
    });

    test('120 keeps exactly its classic route', () {
      expect(SingleLeave.threeDartRoutes(120), isNotEmpty); // T20 leaves 60 ...
      expect(optimal.optimalRoutes(120).map((x) => x.notation), ['T20 S20 D20']);
    });
  });

  group('more singles win: never a treble or double where a single will do', () {
    test('35: S15 D10, S3 D16, S17 D9 are all optimal, and T11 D1 and T5 D10', () {
      for (final text in ['S15 D10', 'S3 D16', 'S17 D9', 'S19 D8', 'S1 D17', 'T11 D1', 'T5 D10']) {
        expect(optimal.isOptimal(35, r(text)), isTrue, reason: text);
      }
    });

    test('42: any single that leaves a double is optimal, and so is a triple whose single does', () {
      expect(optimal.isOptimal(42, r('S2 D20')), isTrue);
      expect(optimal.isOptimal(42, r('S10 D16')), isTrue);
      expect(optimal.isOptimal(42, r('T2 D18')), isTrue); // S2 leaves D20
      expect(optimal.isOptimal(42, r('T4 D15')), isTrue); // S4 leaves D19
    });

    test('a triple is not optimal when no hit next to it leaves a double: 58 T14 D8', () {
      // S14 would leave 44; T11 and T9 (its neighbours) leave odd numbers.
      expect(engine.isLegalRoute(58, r('T14 D8')), isTrue);
      expect(optimal.isOptimal(58, r('T14 D8')), isFalse);
      // T6 D20 is: T6 and T10 are neighbours, and T10 leaves D14.
      expect(optimal.isOptimal(58, r('T6 D20')), isTrue);
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

    test('the outer bull is hardly ever an aim: it is far too hard to hit', () {
      // It used to count as a single and made T20 25 Bull the only way on 135.
      expect(engine.isLegalRoute(135, r('T20 25 Bull')), isTrue);
      expect(optimal.isOptimal(135, r('T20 25 Bull')), isFalse);
      expect(optimal.isOptimal(35, r('25 D5')), isFalse); // 25 + 10
      expect(optimal.isOptimal(132, r('T19 25 Bull')), isFalse);
      // The one exception: the outer bull and a better double, with 61 or 65
      // left (61: 25 D18, 65: 25 D20), on its own or after a first treble.
      for (final n in engine.checkoutableTargets) {
        for (final route in optimal.optimalRoutes(n)) {
          if (!route.darts.any((d) => d.isOuterBull)) continue;
          final last2 = route.darts.sublist(route.length - 2);
          expect(last2.first.isOuterBull, isTrue, reason: '$n $route');
          expect([61, 65], contains(last2.fold<int>(0, (s, d) => s + d.score)),
              reason: '$n $route');
          expect(BetterDoubles.leavesBetterDouble(route), isTrue, reason: '$n $route');
        }
      }
    });

    test('with no single to throw, the chart route is as good as any: 135', () {
      // 135 has no route with a real single, so T20 T17 D12 is optimal.
      expect(optimal.isOptimal(135, r('T20 T17 D12')), isTrue);
      expect(optimal.isOptimal(135, r('T19 T18 D12')), isTrue);
    });

    test('132: T20 D20 D16 and T20 T20 D6 are optimal', () {
      for (final text in ['T20 D20 D16', 'D20 T20 D16', 'T20 T20 D6', 'T20 T16 D12']) {
        expect(engine.isLegalRoute(132, r(text)), isTrue, reason: text);
        expect(optimal.isOptimal(132, r(text)), isTrue, reason: text);
      }
    });

    test('a setup double only counts when the route finishes on a better double', () {
      expect(optimal.isOptimal(132, r('T20 D20 D16')), isTrue); // D16 is a better double
      expect(engine.isLegalRoute(150, r('T20 D20 Bull')), isTrue);
      expect(optimal.isOptimal(150, r('T20 D20 Bull')), isFalse); // finishes on the Bull
      expect(engine.isLegalRoute(132, r('T18 D20 D19')), isTrue);
      expect(optimal.isOptimal(132, r('T18 D20 D19')), isFalse); // D19 is not a better double
      // The same two-dart double-doubles for 72 and 80.
      expect(notations(72), containsAll(['D20 D16', 'D16 D20', 'D18 D18']));
      expect(notations(80), contains('D20 D20'));
      // Never in the way of the classic route.
      expect(optimal.optimalRoute(72)!.notation, 'T20 D6');
      expect(optimal.optimalRoute(80)!.notation, 'T20 D10');
    });

    test('every optimal route with a double among its setup darts finishes on a better double', () {
      for (final n in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(n);
        for (final route in routes) {
          final doubles = route.setupDarts.where((d) => d.multiplier == Multiplier.double).length;
          if (doubles > 0 && !chartOnlyCheckouts.contains(n)) {
            expect(BetterDoubles.leavesBetterDouble(route), isTrue, reason: '$n $route');
          }
        }
      }
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
      final extras = BetterDoubles.extras(routes, exclude: [primary]);
      expect(extras, hasLength(3));
      expect(BetterDoubles.leavesBetterDouble(extras.first), isTrue);
      expect(extras.any((x) => x.isEquivalentTo(primary)), isFalse);
      for (final x in extras) {
        expect(optimal.isOptimal(35, x), isTrue);
      }
    });

    test('extras never repeat a route that is already on screen (the one entered)', () {
      final routes = optimal.optimalRoutes(35);
      final primary = routes.first;
      final entered = routes[3]; // the player entered another optimal route
      final extras = BetterDoubles.extras(routes, exclude: [primary, entered]);
      expect(extras.any((x) => x.isEquivalentTo(entered)), isFalse);
      expect(extras.any((x) => x.isEquivalentTo(primary)), isFalse);
      expect(extras, hasLength(3));
      // Without excluding the entered route, it can come back (here: it is
      // still one of the optimal routes, so it is in All possibilities).
      expect(routes.any((x) => x.isEquivalentTo(entered)), isTrue);
    });

    test('when the player entered an optimal route, the primary can be an extra', () {
      final routes = optimal.optimalRoutes(57); // T7 D18, S7 Bull, S17 D20, T17 D3
      final entered = routes[1];
      final extras = BetterDoubles.extras(routes, exclude: [entered]);
      expect(extras.map((x) => x.notation), ['T7 D18', 'S17 D20', 'T17 D3']);
    });

    test('43: the treble whose single also leaves a better double is among the extras', () {
      final routes = optimal.optimalRoutes(43);
      final extras = BetterDoubles.extras(routes, exclude: [routes.first]);
      expect(extras.map((x) => x.notation), contains('T11 D5'));
      expect(extras, hasLength(3));
    });

    test('isSafeTreble: T11 D5 yes (S11 leaves D16); T14 D5 and T7 D18 no', () {
      expect(BetterDoubles.isSafeTreble(r('T11 D5')), isTrue);
      expect(BetterDoubles.isSafeTreble(r('T14 D5')), isFalse); // S14 leaves D19
      expect(BetterDoubles.isSafeTreble(r('T7 D18')), isFalse); // S7 leaves the Bull
      expect(BetterDoubles.isSafeTreble(r('S11 D16')), isFalse);
    });

    test('extras of a number with one optimal route is empty', () {
      final routes = optimal.optimalRoutes(170);
      expect(BetterDoubles.extras(routes, exclude: [routes.first]), isEmpty);
    });
  });
}

void trebleLeaveTests() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  test('43: T11 D5 is optimal because T11 and S11 both leave a better double', () {
    expect(optimal.isOptimal(43, CheckoutRoute.parse('T11 D5')), isTrue);
    expect(optimal.isOptimal(43, CheckoutRoute.parse('S11 D16')), isTrue);
  });

  test('only for 20 to 60: 17 has S5 D6 but not T5 D1, 29 has T9 D1', () {
    expect(engine.isLegalRoute(17, CheckoutRoute.parse('T5 D1')), isTrue);
    expect(optimal.isOptimal(17, CheckoutRoute.parse('S5 D6')), isTrue);
    expect(optimal.isOptimal(17, CheckoutRoute.parse('T5 D1')), isFalse);
    expect(optimal.isOptimal(29, CheckoutRoute.parse('T9 D1')), isTrue);
    expect(optimal.isOptimal(29, CheckoutRoute.parse('S9 D10')), isTrue);
  });
}
