import 'dart_throw.dart';

/// A sequence of darts as thrown. The last dart is the finisher and is
/// special; the darts before it are a *combination* - T20 T19 D8 and
/// T19 T20 D8 are the same checkout (see [isEquivalentTo]).
final class CheckoutRoute {
  CheckoutRoute(Iterable<DartThrow> darts) : darts = List.unmodifiable(darts);

  /// Parses space separated notation, e.g. "T20 D6".
  factory CheckoutRoute.parse(String text) => CheckoutRoute(
        text.trim().split(RegExp(r'\s+')).map(DartThrow.parse),
      );

  final List<DartThrow> darts;

  int get length => darts.length;
  bool get isEmpty => darts.isEmpty;

  int get total => darts.fold(0, (sum, d) => sum + d.score);

  DartThrow? get finishingDart => darts.isEmpty ? null : darts.last;

  /// True when the final dart is a double or bull.
  bool get endsOnDouble => finishingDart?.isFinishingDart ?? false;

  /// True when this is a checkout of [target]: it ends on a double (or the
  /// Bull) and its darts add up to [target]. Optimal or not, any number of darts
  /// up to three.
  bool isCheckoutFor(int target) =>
      !isEmpty && length <= 3 && endsOnDouble && total == target;

  int get trebleCount => darts.where((d) => d.isTreble).length;
  bool get usesBull => darts.any((d) => d.isBull);

  /// "T20 D6"
  String get notation => darts.map((d) => d.notation).join(' ');

  /// "60 + 12 = 72"
  String get arithmetic => '${darts.map((d) => d.score).join(' + ')} = $total';

  /// The darts before the finisher (order irrelevant).
  List<DartThrow> get setupDarts =>
      darts.isEmpty ? const [] : darts.sublist(0, darts.length - 1);

  /// Same checkout regardless of the order of the non-finishing darts.
  /// The finisher must match exactly.
  bool isEquivalentTo(CheckoutRoute other) =>
      length == other.length &&
      !isEmpty &&
      finishingDart == other.finishingDart &&
      _sortedKey(setupDarts) == _sortedKey(other.setupDarts);

  /// Same darts with the setup darts in a fixed order (highest first), so
  /// equivalent routes share one representation.
  CheckoutRoute get normalized => isEmpty
      ? this
      : CheckoutRoute([...(setupDarts.toList()..sort(compareDarts)), darts.last]);

  /// Highest score first, then a stable tie-break.
  static int compareDarts(DartThrow a, DartThrow b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byRing = b.multiplier.index.compareTo(a.multiplier.index);
    return byRing != 0 ? byRing : b.number.compareTo(a.number);
  }

  static String _sortedKey(List<DartThrow> darts) =>
      (darts.toList()..sort(compareDarts)).map((d) => d.notation).join(' ');

  @override
  bool operator ==(Object other) {
    if (other is! CheckoutRoute || other.length != length) return false;
    for (var i = 0; i < length; i++) {
      if (other.darts[i] != darts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(darts);

  @override
  String toString() => notation;
}
