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
/// "Optimal" follows the checkout tables ([OptimalRouteService]): before every
/// dart the table's target for the number and the darts left is lit, with the
/// targets almost as good (62 with three darts: T10, T14 and T18; 48 with two:
/// S16 and S8).
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

  /// The darts that are an equally optimal NEXT throw for [remaining] with the
  /// fewest darts it needs (see [optimalDartsIn]).
  Set<DartThrow> optimalDarts(int remaining) {
    final fewest = _engine.minimumDarts(remaining);
    return fewest == null ? const <DartThrow>{} : optimalDartsIn(remaining, fewest);
  }

  /// The darts to aim at on [remaining] with [darts] darts in hand: the checkout
  /// table's target and the targets almost as good
  /// ([OptimalRouteService.aimsIn]). 62 with three darts: T10, T14 and T18.
  Set<DartThrow> optimalDartsIn(int remaining, int darts) => _optimal.aimsIn(remaining, darts);

  /// The equally optimal next darts for [target] played with [darts] darts,
  /// once [thrown] are in: the table's targets for what is left with the darts
  /// left. 127 with three darts: T20, then 67 with two darts is T17.
  Set<DartThrow> nextOptimalDarts(int target, int darts, List<DartThrow> thrown) {
    final left = darts - thrown.length;
    final remaining = target - thrown.fold<int>(0, (sum, d) => sum + d.score);
    if (left <= 0 || remaining <= 0) return const <DartThrow>{};
    return optimalDartsIn(remaining, left);
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
  /// (counting this one) still to throw. A lit dart is optimal, also a double
  /// that checks out with a dart still in hand (40 with two darts: D20) and a
  /// setup for the next visit when no checkout is left (41 with one dart: S9).
  /// Checking out with an unlit dart and darts still in hand is a miss (a bust).
  /// [best] are the optimal darts at this point when the caller knows them (see
  /// [nextOptimalDarts]).
  DartQuality rate({
    required int remaining,
    required int dartsLeft,
    required DartThrow dart,
    Set<DartThrow>? best,
  }) {
    final after = remaining - dart.score;
    if (after < 0 || after == 1) return DartQuality.bust;
    final lit = best ?? optimalDartsIn(remaining, dartsLeft);
    if (after == 0) {
      final inTime = dartsLeft == 1 || lit.contains(dart);
      return dart.isFinishingDart && inTime ? DartQuality.optimal : DartQuality.bust;
    }
    if (lit.contains(dart)) return DartQuality.optimal;
    if (dartsLeft <= 1 || !_engine.canCheckoutIn(after, dartsLeft - 1)) return DartQuality.poor;
    return isNaturalAim(dart) ? DartQuality.fine : DartQuality.poor;
  }
}
