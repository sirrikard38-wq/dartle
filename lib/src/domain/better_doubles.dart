import 'checkout_route.dart';
import 'dart_throw.dart';

/// The doubles that are good to be left on: D20, D18, D16, D14, D12, D10, D8,
/// D6, D5, D4, D2 and D1. They are a *set* of equally good doubles, not a
/// ranking. Every other double (and the Bull) is a worse one to finish on.
abstract final class BetterDoubles {
  static const Set<int> numbers = {20, 18, 16, 14, 12, 10, 8, 6, 5, 4, 2, 1};

  static bool isBetter(DartThrow dart) =>
      dart.multiplier == Multiplier.double && !dart.isBull && numbers.contains(dart.number);

  /// True when [route] finishes on one of the better doubles.
  static bool leavesBetterDouble(CheckoutRoute route) =>
      !route.isEmpty && isBetter(route.darts.last);

  /// The routes to show as "also optimal", from the equally optimal [routes]:
  /// first one more route that finishes on a better double (if there is one),
  /// then up to [more] other equally optimal routes. Nothing in [exclude] (the
  /// routes already on screen - the optimal route shown, and the one the player
  /// entered) is repeated; every optimal route is still in "All possibilities".
  static List<CheckoutRoute> extras(
    List<CheckoutRoute> routes, {
    List<CheckoutRoute> exclude = const [],
    int more = 2,
  }) {
    final others = routes
        .where((r) => !exclude.any(r.isEquivalentTo))
        .toList();
    final result = <CheckoutRoute>[];
    final better = others.where(leavesBetterDouble).toList();
    if (better.isNotEmpty) {
      result.add(better.first);
      others.remove(better.first);
    }
    result.addAll(others.take(more));
    return result;
  }
}
