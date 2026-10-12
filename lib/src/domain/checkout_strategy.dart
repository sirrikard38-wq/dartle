import 'checkout_route.dart';

/// The single, documented definition of "which legal route is best".
///
/// The canonical chart ([canonicalCheckouts]) is the primary authority. This
/// strategy is the deterministic fallback for any target the chart does not
/// cover, and ranks routes by these criteria, in order:
///
///  1. Fewer darts is better.
///  2. Prefer a finishing double that is easy to follow up on - the order in
///     [preferredFinishers] (D20, D16, D8, D10, ... bull last among equals).
///  3. Prefer treble-heavy set-ups (more trebles = higher-scoring approach).
///  4. Prefer a larger first dart (take the big score first).
///  5. Final tie-break: notation text, so the result is always deterministic.
///
/// Lower rank value is better. Change preferences HERE and nowhere else.
class CheckoutStrategy {
  const CheckoutStrategy();

  /// Doubles in order of preference as a finishing target.
  static const List<int> preferredFinishers = [
    20, 16, 8, 10, 12, 18, 4, 14, 6, 2, 19, 17, 15, 13, 11, 9, 7, 5, 3, 1,
  ];

  /// Best route in [routes] under this strategy, or null if empty.
  CheckoutRoute? best(Iterable<CheckoutRoute> routes) {
    CheckoutRoute? best;
    for (final route in routes) {
      if (best == null || compare(route, best) < 0) best = route;
    }
    return best;
  }

  /// Negative if [a] is preferred over [b].
  int compare(CheckoutRoute a, CheckoutRoute b) {
    final byLength = a.length.compareTo(b.length);
    if (byLength != 0) return byLength;

    final byFinisher = finisherRank(a).compareTo(finisherRank(b));
    if (byFinisher != 0) return byFinisher;

    final byTrebles = b.trebleCount.compareTo(a.trebleCount);
    if (byTrebles != 0) return byTrebles;

    final byFirst = b.darts.first.score.compareTo(a.darts.first.score);
    if (byFirst != 0) return byFirst;

    return a.notation.compareTo(b.notation);
  }

  /// How well the route's finishing double ranks (0 is best).
  int finisherRank(CheckoutRoute route) {
    final finisher = route.finishingDart!;
    if (finisher.isBull) return preferredFinishers.length; // after all doubles
    final index = preferredFinishers.indexOf(finisher.number);
    return index < 0 ? preferredFinishers.length + 1 : index;
  }
}
