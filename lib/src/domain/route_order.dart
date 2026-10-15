import 'checkout_route.dart';
import 'dart_throw.dart';

/// How the "All possibilities" popup lists the optimal routes.
abstract final class RouteOrder {
  /// [routes] ordered by the dart they finish on, by value: D1, D2, D3 ... D19,
  /// D20, then the Bull. Routes that finish on the same double go by their setup
  /// darts, the smallest first (T16 T20 before T19 T19 before T20 T20), so the
  /// list is always in the same order.
  static List<CheckoutRoute> byFinisher(Iterable<CheckoutRoute> routes) =>
      routes.toList()..sort(_compare);

  /// The finisher's value: 1 for D1 ... 20 for D20, 25 for the Bull (after D20).
  static int finisherValue(CheckoutRoute route) =>
      route.isEmpty ? 0 : route.darts.last.number;

  static int _compare(CheckoutRoute a, CheckoutRoute b) {
    final byFinisher = finisherValue(a).compareTo(finisherValue(b));
    if (byFinisher != 0) return byFinisher;
    // Same finisher: the setup darts, smallest first.
    final setupA = _ascending(a.setupDarts);
    final setupB = _ascending(b.setupDarts);
    for (var i = 0; i < setupA.length && i < setupB.length; i++) {
      final byDart = _compareDart(setupA[i], setupB[i]);
      if (byDart != 0) return byDart;
    }
    final byLength = setupA.length.compareTo(setupB.length);
    return byLength != 0 ? byLength : a.notation.compareTo(b.notation);
  }

  static List<DartThrow> _ascending(List<DartThrow> darts) =>
      darts.toList()..sort(_compareDart);

  /// Lower score first; the same score: single, double, treble.
  static int _compareDart(DartThrow a, DartThrow b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.multiplier.index.compareTo(b.multiplier.index);
  }
}
