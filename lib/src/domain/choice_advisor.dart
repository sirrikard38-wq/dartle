import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'checkout_strategy.dart';
import 'dart_throw.dart';
import 'optimal_route_service.dart';

/// How good a dart was, given what was left and how many darts remained.
enum DartQuality {
  /// Starts a fewest-darts route - one of the equally best choices.
  optimal,

  /// Still finishes in the darts you have, but not in the fewest.
  fine,

  /// A silly aim (a low treble, a non-finishing double) or a dart that makes
  /// the finish impossible with the darts left.
  poor,

  /// Went below zero, left 1, or reached zero without a double.
  bust,
}

/// Rates the darts a player chooses in "Checkout practice".
///
/// "Optimal" means the FEWEST darts. Every route with the minimum number of
/// darts is equally optimal, so 85 (two darts) has T15 D20, T17 D17 and T19 D14
/// all equally good. Setup darts count only if they are sensible aims (see
/// [isNaturalAim]) - T3 is never a good first dart, even if it adds up -
/// except where the bull-safe/chart route for the number uses it.
class ChoiceAdvisor {
  ChoiceAdvisor(
    this._engine,
    this._optimal, {
    CheckoutStrategy strategy = const CheckoutStrategy(),
  }) : _strategy = strategy;

  final CheckoutEngine _engine;
  final OptimalRouteService _optimal;
  final CheckoutStrategy _strategy;

  final Map<int, List<CheckoutRoute>> _routeCache = {};
  final Map<int, Set<DartThrow>> _dartCache = {};

  /// The lowest treble anyone sensibly aims at as a setup dart.
  static const int lowestSensibleTreble = 15;

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

  /// The standard (chart / bull-safe) optimal routes: "really popular and
  /// optimal". Whatever they use is always allowed, Bull and doubles included.
  List<CheckoutRoute> _standardRoutes(int remaining) =>
      _optimal.optimalRoutes(remaining);

  /// Every other fewest-darts route for [remaining] that is made of sensible
  /// aims, best first. The Bull is not a sensible SETUP dart here - it is a
  /// double - so it only appears through the standard routes.
  List<CheckoutRoute> _otherRoutes(int remaining) {
    final minimum = _engine.minimumDarts(remaining);
    if (minimum == null) return const [];
    return _engine
        .legalRoutes(remaining, darts: minimum)
        .where((r) => r.setupDarts.every((d) => isNaturalAim(d) && !d.isBull))
        .toList()
      ..sort(_strategy.compare);
  }

  /// Every equally optimal route for [remaining], best-looking first: the
  /// standard routes, then the other fewest-darts routes of sensible aims
  /// (trebles first, as the strategy prefers). Empty if [remaining] cannot be
  /// checked out.
  List<CheckoutRoute> optimalRoutes(int remaining) {
    return _routeCache.putIfAbsent(remaining, () {
      if (_engine.minimumDarts(remaining) == null) return const <CheckoutRoute>[];
      final routes = <CheckoutRoute>[];
      void add(CheckoutRoute route) {
        if (!routes.any(route.isEquivalentTo)) routes.add(route);
      }

      _standardRoutes(remaining).forEach(add);
      _otherRoutes(remaining).forEach(add);
      return List<CheckoutRoute>.unmodifiable(routes);
    });
  }

  /// The darts that are an equally optimal NEXT throw for [remaining], in this
  /// order of preference:
  ///
  ///  1. Trebles come first: every treble that starts a fewest-darts route.
  ///  2. Singles (and the 25) only when no treble can do the job.
  ///  3. Doubles and the Bull as a setup dart only when the standard route
  ///     uses them (really popular and optimal) - never otherwise.
  ///
  /// When one dart finishes [remaining], it is just that finishing double.
  Set<DartThrow> optimalDarts(int remaining) {
    return _dartCache.putIfAbsent(remaining, () {
      final minimum = _engine.minimumDarts(remaining);
      if (minimum == null) return const <DartThrow>{};

      if (minimum == 1) {
        return Set<DartThrow>.unmodifiable({
          for (final route in optimalRoutes(remaining)) route.darts.first,
        });
      }

      final standard = <DartThrow>{
        for (final route in _standardRoutes(remaining)) ...route.setupDarts,
      };
      final others = <DartThrow>{
        for (final route in _otherRoutes(remaining)) ...route.setupDarts,
      };

      final darts = <DartThrow>{...standard, ...others.where((d) => d.isTreble)};
      if (!darts.any((d) => d.isTreble)) {
        darts.addAll(others.where((d) => d.multiplier == Multiplier.single));
      }
      return Set<DartThrow>.unmodifiable(darts);
    });
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
    if (optimalDarts(remaining).contains(dart)) return DartQuality.optimal;
    return isNaturalAim(dart) ? DartQuality.fine : DartQuality.poor;
  }
}
