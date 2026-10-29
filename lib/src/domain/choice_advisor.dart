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

  /// The optimal routes for [remaining] with exactly [darts] darts, all of
  /// which have to be used (see [OptimalRouteService.optimalRoutesIn]).
  List<CheckoutRoute> optimalRoutesIn(int remaining, int darts) =>
      _optimal.optimalRoutesIn(remaining, darts);

  /// The darts that are an equally optimal NEXT throw for [remaining]: the
  /// setup darts of every optimal route, or just the finishing double when one
  /// dart finishes it. The order of the setup darts does not matter, so any of
  /// them can be thrown first.
  Set<DartThrow> optimalDarts(int remaining) => _nextDarts(optimalRoutes(remaining));

  /// Like [optimalDarts], with exactly [darts] darts still to throw.
  Set<DartThrow> optimalDartsIn(int remaining, int darts) =>
      _nextDarts(optimalRoutesIn(remaining, darts));

  /// The equally optimal next darts for [target] played with exactly [darts]
  /// darts, once [thrown] are in: the rest of every optimal route that has the
  /// darts thrown so far among its setup darts (in any order) - on 85 with three
  /// darts, S15 is followed by T10 (T10 S15 D20). After a dart that is in none
  /// of them, the optimal darts for what is left.
  Set<DartThrow> nextOptimalDarts(int target, int darts, List<DartThrow> thrown) {
    final left = darts - thrown.length;
    final remaining = target - thrown.fold<int>(0, (sum, d) => sum + d.score);
    if (left <= 0 || remaining <= 0) return const <DartThrow>{};
    final next = <DartThrow>{};
    for (final route in optimalRoutesIn(target, darts)) {
      final rest = _rest(route, thrown);
      if (rest == null) continue;
      next.addAll(rest.length == 1 ? rest : rest.sublist(0, rest.length - 1));
    }
    return next.isEmpty
        ? optimalDartsIn(remaining, left)
        : Set<DartThrow>.unmodifiable(next);
  }

  /// [route] without [thrown] (taken from its setup darts), or null when they
  /// are not all among them.
  static List<DartThrow>? _rest(CheckoutRoute route, List<DartThrow> thrown) {
    final setup = route.setupDarts.toList();
    for (final dart in thrown) {
      if (!setup.remove(dart)) return null;
    }
    return [...setup, route.darts.last];
  }

  static Set<DartThrow> _nextDarts(List<CheckoutRoute> routes) {
    if (routes.isEmpty) return const <DartThrow>{};
    if (routes.first.length == 1) {
      return Set<DartThrow>.unmodifiable({for (final r in routes) r.darts.first});
    }
    return Set<DartThrow>.unmodifiable({for (final r in routes) ...r.setupDarts});
  }

  /// Rates throwing [dart] with [remaining] left and [dartsLeft] darts
  /// (counting this one) still to throw. Every dart has to be used: checking
  /// out with darts still in hand is wrong (a bust). [best] are the optimal
  /// darts at this point when the caller knows them (see [nextOptimalDarts]).
  DartQuality rate({
    required int remaining,
    required int dartsLeft,
    required DartThrow dart,
    Set<DartThrow>? best,
  }) {
    final after = remaining - dart.score;
    if (after < 0 || after == 1) return DartQuality.bust;
    if (after == 0) {
      return dart.isFinishingDart && dartsLeft == 1 ? DartQuality.optimal : DartQuality.bust;
    }
    if (dartsLeft <= 1 || !_engine.canCheckoutIn(after, dartsLeft - 1)) return DartQuality.poor;
    if ((best ?? optimalDartsIn(remaining, dartsLeft)).contains(dart)) {
      return DartQuality.optimal;
    }
    return isNaturalAim(dart) ? DartQuality.fine : DartQuality.poor;
  }
}
