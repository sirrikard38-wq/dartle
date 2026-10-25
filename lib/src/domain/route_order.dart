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

  /// The order the popup uses: [byFinisher], with each Bull finish that has a
  /// treble partner moved right next to that partner (see
  /// [withBullPairsTogether]), and then each two-dart treble route right next to
  /// the single of the same number (see [withTreblesNextToTheirSingle]).
  /// Everything else stays in the same order.
  static List<CheckoutRoute> forPopup(Iterable<CheckoutRoute> routes) =>
      withTreblesNextToTheirSingle(withBullPairsTogether(byFinisher(routes)));

  /// In an already ordered list, puts every two-dart route that starts on a
  /// treble (`T5 D4`) straight after the two-dart route that starts on the
  /// single of the same number (`S5 D9`): aiming at the 5, either is a hit, so
  /// they belong together. A treble with no such single stays where it was, and
  /// a pair that is already side by side (`T7 D18`, `S7 Bull`) is left alone.
  static List<CheckoutRoute> withTreblesNextToTheirSingle(List<CheckoutRoute> ordered) {
    final result = [...ordered];
    for (final treble in ordered) {
      if (treble.length != 2 || !treble.darts.first.isTreble) continue;
      final number = treble.darts.first.number;
      bool isSingle(CheckoutRoute r) =>
          r.length == 2 &&
          r.darts.first.multiplier == Multiplier.single &&
          r.darts.first.number == number;
      final at = result.indexOf(treble);
      final single = result.indexWhere(isSingle);
      if (single < 0 || (single - at).abs() == 1) continue;
      result.removeAt(at);
      result.insert(result.indexWhere(isSingle) + 1, treble);
    }
    return result;
  }

  /// In an already ordered list, puts every route that finishes on the Bull and
  /// has a single among its other darts straight after the route that has the
  /// treble of that single instead - the pair that belong together, because
  /// missing the treble onto the single still leaves the Bull: `T7 D18` and
  /// `S7 Bull`, `T19 T12 D13` and `T19 S12 Bull`. A Bull finish with no such
  /// partner stays where it was, and the rest keeps its order.
  static List<CheckoutRoute> withBullPairsTogether(List<CheckoutRoute> ordered) {
    final result = [...ordered];
    for (final bull in ordered) {
      if (bull.isEmpty || !bull.darts.last.isBull) continue;
      if (!result.any((r) => _isTreblePartner(bull, r))) continue;
      result.remove(bull);
      final partnerAt = result.indexWhere((r) => _isTreblePartner(bull, r));
      result.insert(partnerAt + 1, bull);
    }
    return result;
  }

  /// True when [other] is [bull] with one of its single darts made a treble of
  /// the same number, finishing on a double instead of the Bull.
  static bool _isTreblePartner(CheckoutRoute bull, CheckoutRoute other) {
    if (other.isEmpty || other.length != bull.length) return false;
    final finisher = other.darts.last;
    if (finisher.isBull || finisher.multiplier != Multiplier.double) return false;
    final wanted = _key(other.setupDarts);
    for (var i = 0; i < bull.setupDarts.length; i++) {
      final dart = bull.setupDarts[i];
      if (dart.multiplier != Multiplier.single || dart.isOuterBull) continue;
      final swapped = bull.setupDarts.toList()..[i] = DartThrow(Multiplier.treble, dart.number);
      if (_key(swapped) == wanted) return true;
    }
    return false;
  }

  /// The setup darts in a fixed order, so the order they were thrown in is ignored.
  static String _key(List<DartThrow> darts) =>
      (darts.toList()..sort(CheckoutRoute.compareDarts)).map((d) => d.notation).join(' ');

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
