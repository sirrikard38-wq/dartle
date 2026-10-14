import 'checkout_route.dart';
import 'dart_throw.dart';

/// The "bull-safe" finish. With two darts left on R, aim at the number n where
/// n = R - 50:
///
///  * throw the *treble* n, then the double that is left (R - 3n); or
///  * throw the *single* n, which leaves exactly 50, then the Bull.
///
/// Both are equally good, and missing the treble onto the single still leaves
/// the Bull, so a near miss still has a finish.
///
/// Worked examples:
///   R = 57 -> T7 (21), leaves 36 -> D18; or S7, leaves 50 -> Bull.
///   R = 67 -> T17 (51), leaves 16 -> D8; or S17, then Bull.
///
/// The treble route needs the leftover to be a legal double, which is the range
/// 55..70 (below 55 the remainder would be 42..48 - no such double). The
/// single-and-Bull route works for 51..70.
abstract final class BullSafeFinish {
  static const int bullScore = 50;

  /// Smallest remainder the treble route works for.
  static const int minRemaining = 55;

  /// Smallest remainder the single-and-Bull route works for (over 50).
  static const int minSingleRemaining = 51;
  static const int maxRemaining = 70;

  /// True when [remaining] has a bull-safe finish (51..70).
  static bool covers(int remaining) =>
      remaining >= minSingleRemaining && remaining <= maxRemaining;

  /// The treble finish for [remaining], e.g. 67 -> T17 D8, or null when
  /// [remaining] is outside 55..70.
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

  /// The single-and-Bull finish for [remaining], e.g. 57 -> S7 Bull, or null
  /// when [remaining] is outside 51..70.
  static CheckoutRoute? twoDartSingleBull(int remaining) {
    if (!covers(remaining)) return null;
    final n = remaining - bullScore;
    if (n < 1 || n > DartThrow.maxBoardNumber) return null;
    return CheckoutRoute([DartThrow(Multiplier.single, n), DartThrow.bull]);
  }

  /// Every bull-safe two-dart route for [remaining], the treble one first:
  /// 57 -> [T7 D18, S7 Bull]. Empty outside 51..70.
  static List<CheckoutRoute> twoDartRoutes(int remaining) {
    final treble = twoDartFinish(remaining);
    final single = twoDartSingleBull(remaining);
    return [if (treble != null) treble, if (single != null) single];
  }

  /// Three-dart routes for [target]: a first treble that leaves a bull-safe
  /// two-dart finish (either kind). All are equally optimal (119: T19 S12 Bull
  /// and T19 T12 D13). Highest first treble first.
  static List<CheckoutRoute> threeDartRoutes(int target) {
    final routes = <CheckoutRoute>[];
    for (var k = DartThrow.maxBoardNumber; k >= 1; k--) {
      for (final finish in twoDartRoutes(target - 3 * k)) {
        routes.add(CheckoutRoute([DartThrow(Multiplier.treble, k), ...finish.darts]));
      }
    }
    return routes;
  }
}
