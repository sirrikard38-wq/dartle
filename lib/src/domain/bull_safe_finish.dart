import 'checkout_route.dart';
import 'dart_throw.dart';

/// The "bull-safe" finish: with two darts left on R, throw treble n where
/// n = R - 50.
///
/// If you hit the treble you are left with a double (R - 3n). If you miss it
/// and hit the *single* n instead, you are left with R - n = 50, which is the
/// Bull. So a near-miss still leaves a finish.
///
/// Worked examples:
///   R = 67 -> T17 (51), leaves 16 -> D8. Miss to S17 -> 50 left (Bull).
///   R = 61 -> T11 (33), leaves 28 -> D14. Miss to S11 -> 50 left.
///
/// This only works while the treble's remainder is a legal double, which is
/// the range 55..70 (below 55 the remainder would be 42..48 - no such double).
abstract final class BullSafeFinish {
  static const int bullScore = 50;
  static const int minRemaining = 55;
  static const int maxRemaining = 70;

  /// The two-dart bull-safe finish for [remaining], e.g. 67 -> T17 D8, or null
  /// when [remaining] is outside 55..70.
  static CheckoutRoute? twoDartFinish(int remaining) {
    if (remaining < minRemaining || remaining > maxRemaining) return null;
    final n = remaining - bullScore; // treble n; its single leaves exactly 50
    final left = remaining - 3 * n;
    if (n < 1 || n > DartThrow.maxBoardNumber) return null;
    if (left < 2 || left > 40 || left.isOdd) return null;
    return CheckoutRoute([
      DartThrow(Multiplier.treble, n),
      DartThrow(Multiplier.double, left ~/ 2),
    ]);
  }

  /// Three-dart routes for [target]: a first treble that leaves a bull-safe
  /// two-dart finish. All are equally optimal (121: T20 T11 D14, T19 T14 D11,
  /// T18 T17 D8, T17 T20 D5). Highest first treble first.
  static List<CheckoutRoute> threeDartRoutes(int target) {
    final routes = <CheckoutRoute>[];
    for (var k = DartThrow.maxBoardNumber; k >= 1; k--) {
      final finish = twoDartFinish(target - 3 * k);
      if (finish == null) continue;
      routes.add(CheckoutRoute([DartThrow(Multiplier.treble, k), ...finish.darts]));
    }
    return routes;
  }
}
