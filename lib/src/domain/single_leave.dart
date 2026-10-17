import 'better_doubles.dart';
import 'bull_safe_finish.dart';
import 'checkout_route.dart';
import 'dart_throw.dart';

/// "Single, then a better double": with two darts left on 41 to 60, a single
/// that leaves one of the [BetterDoubles] is as good as the bull-safe finish.
/// 57 is S17 D20 as well as T7 D18 and S7 Bull; 60 is S20 D20; 52 is S12 D20,
/// S16 D18 and S20 D16.
///
/// The same goes for the last two darts of a three-dart number whose first
/// treble leaves 51 to 60: 109 is T19 and then S20 D16 as well as T19 S2 Bull.
///
/// The outer bull is not a single here: it is far too hard to hit - except on
/// 61 and 65, where nothing else can leave a better double ([outerBullRoutes]).
abstract final class SingleLeave {
  /// The numbers this applies to, 41 to 60.
  static const int minTarget = 41;
  static const int maxTarget = 60;

  static bool covers(int target) => target >= minTarget && target <= maxTarget;

  /// Every `single + better double` finish for [target], on the biggest double
  /// first (D20, D18, D16, ...). Empty outside 41..60.
  static List<CheckoutRoute> twoDartRoutes(int target) {
    if (!covers(target)) return const [];
    final doubles = BetterDoubles.numbers.toList()..sort((a, b) => b.compareTo(a));
    final routes = <CheckoutRoute>[];
    for (final number in doubles) {
      final single = target - 2 * number;
      if (!_isSingleOnBoard(single)) continue;
      routes.add(CheckoutRoute([
        DartThrow(Multiplier.single, single),
        DartThrow(Multiplier.double, number),
      ]));
    }
    return routes;
  }

  /// Over 60 no ordinary single can leave a better double (S20 D20 is the most,
  /// 60), so for 61 to 70 the outer bull is accepted as the single: 61 is
  /// 25 D18 and 65 is 25 D20. This is the one place the outer bull is an aim.
  static List<CheckoutRoute> outerBullRoutes(int target) {
    if (target <= maxTarget || !BullSafeFinish.covers(target)) return const [];
    final left = target - DartThrow.bullNumber;
    if (left.isOdd || !BetterDoubles.numbers.contains(left ~/ 2)) return const [];
    return [
      CheckoutRoute([DartThrow.outerBull, DartThrow(Multiplier.double, left ~/ 2)]),
    ];
  }

  /// Three-dart routes for [target]: a first treble that leaves a bull-safe
  /// number (51 to 70), then a single and a better double (for a leave of 51 to
  /// 60) or the outer bull and a better double (61 and 65). 109 -> T19 S20 D16.
  /// Highest first treble first.
  static List<CheckoutRoute> threeDartRoutes(int target) {
    final routes = <CheckoutRoute>[];
    for (var k = DartThrow.maxBoardNumber; k >= 1; k--) {
      final left = target - 3 * k;
      if (!BullSafeFinish.covers(left)) continue;
      for (final finish in [...twoDartRoutes(left), ...outerBullRoutes(left)]) {
        routes.add(CheckoutRoute([DartThrow(Multiplier.treble, k), ...finish.darts]));
      }
    }
    return routes;
  }

  /// Two darts left on 2 to 60: a first dart at the treble of a number whose
  /// single also leaves a double. 43 is T11 D5 next to S11 D16 (33 and 11 both
  /// leave a better double). Only when both doubles are in [BetterDoubles]; the
  /// treble route is listed, the single one is an ordinary route already.
  /// Highest number first.
  static List<CheckoutRoute> trebleRoutes(int target) {
    if (target < 2 || target > maxTarget) return const [];
    final routes = <CheckoutRoute>[];
    for (var k = DartThrow.maxBoardNumber; k >= 1; k--) {
      final afterTreble = target - 3 * k;
      final afterSingle = target - k;
      if (!_isBetter(afterTreble) || !_isBetter(afterSingle)) continue;
      routes.add(CheckoutRoute([
        DartThrow(Multiplier.treble, k),
        DartThrow(Multiplier.double, afterTreble ~/ 2),
      ]));
      routes.add(CheckoutRoute([
        DartThrow(Multiplier.single, k),
        DartThrow(Multiplier.double, afterSingle ~/ 2),
      ]));
    }
    return routes;
  }

  static bool _isBetter(int left) =>
      left >= 2 && left.isEven && BetterDoubles.numbers.contains(left ~/ 2);

  /// A single is S1..S20. The outer bull is not one: it is too hard to hit.
  static bool _isSingleOnBoard(int number) =>
      number >= 1 && number <= DartThrow.maxBoardNumber;
}
