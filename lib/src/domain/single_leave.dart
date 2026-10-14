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
/// The outer bull counts as a single (57 is also S25 D16).
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

  /// Three-dart routes for [target]: a first treble that leaves a bull-safe
  /// number (51 to 70) which is also in 41 to 60 (so 51 to 60), then a single and
  /// a better double. 109 -> T19 S20 D16. Highest first treble first.
  static List<CheckoutRoute> threeDartRoutes(int target) {
    final routes = <CheckoutRoute>[];
    for (var k = DartThrow.maxBoardNumber; k >= 1; k--) {
      final left = target - 3 * k;
      if (!BullSafeFinish.covers(left)) continue;
      for (final finish in twoDartRoutes(left)) {
        routes.add(CheckoutRoute([DartThrow(Multiplier.treble, k), ...finish.darts]));
      }
    }
    return routes;
  }

  /// A single is S1..S20 or the outer bull (S25).
  static bool _isSingleOnBoard(int number) =>
      (number >= 1 && number <= DartThrow.maxBoardNumber) || number == DartThrow.bullNumber;
}
