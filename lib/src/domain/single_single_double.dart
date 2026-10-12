import 'bull_safe_finish.dart';
import 'checkout_route.dart';
import 'checkout_strategy.dart';

/// The safe way to play 51 to 70 when all three darts are free: single, single,
/// double. It beats every treble-double route, because no dart has to hit a
/// thin treble.
///
/// With only two darts left (the first box blurred) the bull-safe treble finish
/// stays the answer instead - see [BullSafeFinish].
abstract final class SingleSingleDouble {
  /// "Over 50, up to 70".
  static const int minTarget = BullSafeFinish.bullScore + 1;
  static const int maxTarget = BullSafeFinish.maxRemaining;

  static bool covers(int target) => target >= minTarget && target <= maxTarget;

  static bool isSingleSingleDouble(CheckoutRoute route) =>
      route.length == 3 &&
      route.darts[0].multiplier.factor == 1 &&
      route.darts[1].multiplier.factor == 1 &&
      route.endsOnDouble;

  /// The single, single, double routes among [threeDartRoutes], the best-looking
  /// one first: a double that is easy to follow up on (D20, D16, D8 ...), then
  /// the most even pair of singles (10 and 10 before 19 and 1).
  ///
  /// Every route returned is equally optimal; the order only decides which one
  /// is shown as the example.
  static List<CheckoutRoute> from(Iterable<CheckoutRoute> threeDartRoutes) {
    const strategy = CheckoutStrategy();
    int gap(CheckoutRoute r) => (r.darts[0].score - r.darts[1].score).abs();
    return threeDartRoutes.where(isSingleSingleDouble).toList()
      ..sort((a, b) {
        final byFinisher = strategy.finisherRank(a).compareTo(strategy.finisherRank(b));
        if (byFinisher != 0) return byFinisher;
        final byGap = gap(a).compareTo(gap(b));
        return byGap != 0 ? byGap : a.notation.compareTo(b.notation);
      });
  }
}
