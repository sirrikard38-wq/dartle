import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'dart_throw.dart';
import 'natural_aim.dart';
import 'optimal_route_service.dart';

/// How good a dart was, given what was left and how many darts remained.
enum DartQuality {
  /// Starts an optimal route - one of the equally best choices.
  optimal,

  /// Still finishes in the darts you have, but not in an optimal way.
  fine,

  /// A silly aim (a low treble, a non-finishing double) or a dart that makes
  /// the finish impossible with the darts left.
  poor,

  /// Went below zero, left 1, or reached zero without a double.
  bust,
}

/// Rates the darts a player chooses in "Checkout practice" and lights up the
/// best ones.
///
/// "Optimal" follows [OptimalRouteService]: the fewest darts, then the
/// bull-safe routes where they apply, then the routes with the most singles.
/// So a lit dart is a setup dart of an optimal route: 57 with the first box
/// used lights T7 and S7 (the treble and the single that leaves the Bull);
/// 35 lights the singles.
class ChoiceAdvisor {
  ChoiceAdvisor(this._engine, this._optimal);

  final CheckoutEngine _engine;
  final OptimalRouteService _optimal;

  /// The lowest treble anyone sensibly aims at as a setup dart.
  static const int lowestSensibleTreble = NaturalAim.lowestTreble;

  /// Singles (any), the outer bull, the bull and trebles T15-T20 are sensible
  /// aims. A non-finishing double and a low treble (like T3) are not.
  static bool isNaturalAim(DartThrow dart) {
    if (dart.isBull || dart.isOuterBull) return true;
    return switch (dart.multiplier) {
      Multiplier.single => true,
      Multiplier.treble => dart.number >= lowestSensibleTreble,
      Multiplier.double => false,
    };
  }

  /// True when [target] has exactly one legal checkout (170 is just
  /// T20 T20 Bull): "Only possible checkout."
  bool hasOnlyOneCheckout(int target) => _engine.legalRoutes(target).length == 1;

  /// Every equally optimal route for [remaining], best-looking first. Empty
  /// if [remaining] cannot be checked out.
  List<CheckoutRoute> optimalRoutes(int remaining) =>
      _optimal.optimalRoutes(remaining);

  /// The darts that are an equally optimal NEXT throw for [remaining]: the
  /// setup darts of every optimal route, or just the finishing double when one
  /// dart finishes it. The order of the setup darts does not matter, so any of
  /// them can be thrown first.
  Set<DartThrow> optimalDarts(int remaining) {
    final routes = optimalRoutes(remaining);
    if (routes.isEmpty) return const <DartThrow>{};
    if (routes.first.length == 1) {
      return Set<DartThrow>.unmodifiable({for (final r in routes) r.darts.first});
    }
    return Set<DartThrow>.unmodifiable({for (final r in routes) ...r.setupDarts});
  }

  /// What a press on the board is worth when the [best] darts are highlighted.
  ///
  /// Pressing anywhere in a number's wedge counts as the highlighted best dart
  /// of that number: with T20 highlighted, a press on the 20 - single, treble,
  /// double, anywhere - is worth T20. If the tapped area is itself highlighted
  /// it is used as is. A number with no highlighted dart is worth exactly what
  /// was tapped.
  static DartThrow resolveTap(Set<DartThrow> best, DartThrow tapped) {
    if (best.contains(tapped)) return tapped;
    final sameNumber = best.where((d) => d.number == tapped.number).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return sameNumber.isEmpty ? tapped : sameNumber.first;
  }

  /// Rates throwing [dart] with [remaining] left and [dartsLeft] darts
  /// (counting this one) still to throw.
  DartQuality rate({
    required int remaining,
    required int dartsLeft,
    required DartThrow dart,
  }) {
    final after = remaining - dart.score;
    if (after < 0 || after == 1) return DartQuality.bust;
    if (after == 0) {
      return dart.isFinishingDart ? DartQuality.optimal : DartQuality.bust;
    }
    final needed = _engine.minimumDarts(after);
    if (needed == null || needed > dartsLeft - 1) return DartQuality.poor;
    if (optimalDarts(remaining).contains(dart)) {
      return DartQuality.optimal;
    }
    return isNaturalAim(dart) ? DartQuality.fine : DartQuality.poor;
  }
}
