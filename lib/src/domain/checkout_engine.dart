import 'checkout_route.dart';
import 'dart_throw.dart';

/// Knows every legal checkout in standard 501-style darts.
///
/// Rules implemented (and documented, not assumed):
///  * A checkout is 1-3 darts whose scores sum exactly to the target.
///  * The final dart must be a double D1-D20 or the bull (50).
///  * Outer bull (25), singles and trebles can never finish.
///  * No misses/busts are modelled - every dart scores.
///
/// Routes are derived by exhaustive search, never hand-listed, so the set of
/// legal routes cannot disagree with the rules. The result is cached.
class CheckoutEngine {
  CheckoutEngine() {
    _buildIndex();
  }

  static const int minCheckout = 2;
  static const int maxCheckout = 170;
  static const int maxDarts = 3;

  /// target -> darts -> legal checkouts (one entry per combination).
  final Map<int, Map<int, List<CheckoutRoute>>> _index = {};

  void _buildIndex() {
    final finishers = DartThrow.allSegments.where((d) => d.isFinishingDart);
    final setup = DartThrow.allSegments;

    void add(List<DartThrow> darts) {
      final route = CheckoutRoute(darts);
      if (route.total > maxCheckout) return;
      _index
          .putIfAbsent(route.total, () => {})
          .putIfAbsent(route.length, () => [])
          .add(route);
    }

    // Setup darts are a combination, not a permutation: only the canonical
    // ordering (highest first) of each set is indexed, so T19 T20 D8 is not
    // listed separately from T20 T19 D8.
    for (final f in finishers) {
      add([f]);
      for (final a in setup) {
        add([a, f]);
        for (final b in setup) {
          if (CheckoutRoute.compareDarts(a, b) <= 0) add([a, b, f]);
        }
      }
    }
  }

  /// All checkoutable targets in ascending order.
  List<int> get checkoutableTargets => (_index.keys.toList()..sort());

  bool isCheckoutable(int target) => _index.containsKey(target);

  /// Fewest darts that can finish [target], or null if impossible.
  int? minimumDarts(int target) {
    final byLength = _index[target];
    if (byLength == null) return null;
    return byLength.keys.reduce((a, b) => a < b ? a : b);
  }

  /// Whether [target] can be finished in exactly [darts] darts.
  bool canCheckoutIn(int target, int darts) =>
      _index[target]?.containsKey(darts) ?? false;

  /// Every legal route for [target]; optionally only those of [darts] length.
  List<CheckoutRoute> legalRoutes(int target, {int? darts}) {
    final byLength = _index[target];
    if (byLength == null) return const [];
    if (darts != null) return List.unmodifiable(byLength[darts] ?? const []);
    return List.unmodifiable([
      for (final length in (byLength.keys.toList()..sort())) ...byLength[length]!,
    ]);
  }

  /// Whether [route] is a legal checkout for [target] (any length 1-3).
  bool isLegalRoute(int target, CheckoutRoute route) =>
      route.length >= 1 &&
      route.length <= maxDarts &&
      route.endsOnDouble &&
      route.total == target;
}
