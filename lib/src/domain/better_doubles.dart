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

  /// A two-dart route that starts on a treble and finishes on a better double,
  /// where the single of that treble leaves a better double as well: aiming at
  /// the treble is safe either way. 43 is T11 D5 (T11 leaves D5, S11 leaves
  /// D16), but 52 is not T14 D5 (S14 leaves D19).
  static bool isSafeTreble(CheckoutRoute route) {
    if (route.length != 2) return false;
    final first = route.darts.first;
    final last = route.darts.last;
    return first.isTreble && isBetter(last) && numbers.contains(first.number + last.number);
  }

  /// A number with more optimal routes than this only lists the ones that
  /// finish on a better double (see [listed]).
  static const int listEverythingUpTo = 6;

  /// The equally optimal [routes] that "Also optimal" and its popup list. A
  /// number with up to [listEverythingUpTo] routes lists them all (76 keeps
  /// T18 D11 even though D11 is not a better double). A number with more
  /// leaves out the routes that finish on a double that is not a better one
  /// (35 has no S17 D9 in the list), so poor finishes do not fill the popup.
  /// Two kinds always stay: a finish on the Bull (S7 Bull belongs to the
  /// bull-safe finish) and the first route, the one shown as the answer.
  /// Every route is still accepted as optimal and still lights up its darts.
  static List<CheckoutRoute> listed(List<CheckoutRoute> routes) {
    if (routes.length <= listEverythingUpTo) return routes;
    return [
      for (var i = 0; i < routes.length; i++)
        if (i == 0 || leavesBetterDouble(routes[i]) || routes[i].darts.last.isBull) routes[i],
    ];
  }

  /// The routes to show as "also optimal", from the equally optimal [routes]
  /// (the [listed] ones): first one more route that finishes on a better double
  /// (if there is one), then up to [more] other equally optimal routes. Nothing
  /// in [exclude] (the routes already on screen - the optimal route shown, and
  /// the one the player entered) is repeated; every listed route is still in
  /// the popup.
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
    // A treble whose single leaves a better double too (43: T11 D5) is worth
    // showing as well.
    final treble = others.where(isSafeTreble).toList();
    var room = more;
    if (treble.isNotEmpty) {
      result.add(treble.first);
      others.remove(treble.first);
      room--;
    }
    result.addAll(others.take(room));
    return result;
  }
}
