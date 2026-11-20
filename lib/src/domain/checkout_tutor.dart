import 'dart:math' as math;

import '../board/board_geometry.dart';
import 'checkout_route.dart';
import 'checkout_table.dart';
import 'choice_advisor.dart';
import 'dart_throw.dart';
import 'optimal_route_service.dart';

/// What one dart leaves on the way to a checkout.
final class DartOutcome {
  const DartOutcome(this.dart, this.left, this.route, {this.bust = false});

  final DartThrow dart;

  /// What is left after the dart (0: checked out).
  final int left;

  /// The table's route for what is left with the darts after this one; null
  /// when there is none.
  final CheckoutRoute? route;

  /// Below zero, 1 left, or zero without a double.
  final bool bust;

  bool get checkedOut => !bust && left == 0;

  /// It checks out, or a checkout is still there with the darts after it.
  bool get hasCheckout => checkedOut || route != null;
}

/// How a Practice checkout went.
enum ReviewKind {
  /// One of the optimal routes.
  optimal,

  /// It checks out, but it is not optimal.
  good,

  /// It does not check out (or "No checkout" on a number that has one).
  wrong,
}

/// Why the optimal routes beat a good one.
enum GoodReason {
  /// They need fewer darts.
  fewerDarts,

  /// The first dart's miss into single still leaves a checkout on an optimal
  /// route, and on the player's it does not.
  missKeepsCheckout,

  /// Nothing as simple to say.
  other,
}

/// What Learn says about the player's checkout in Practice.
final class PracticeReview {
  const PracticeReview({
    required this.kind,
    required this.route,
    this.miss,
    this.reason = GoodReason.other,
    this.fewestDarts = 0,
    this.optimalMiss,
  });

  final ReviewKind kind;

  /// The player's darts (empty for "No checkout").
  final CheckoutRoute route;

  /// What the player's first dart leaves when it misses into single; null when
  /// it is a single (or 25), or nothing was thrown.
  final DartOutcome? miss;

  /// For a good one: why the optimal routes are better.
  final GoodReason reason;

  /// For [GoodReason.fewerDarts]: how many darts the shortest optimal route has.
  final int fewestDarts;

  /// For [GoodReason.missKeepsCheckout]: an optimal route's first-dart miss
  /// into single, which still leaves a checkout.
  final DartOutcome? optimalMiss;
}

/// The tutorial card for a number with some darts in hand: what to aim at, what
/// a hit and a miss into the next area leave, and why not the most tempting
/// other target.
final class TutorCard {
  const TutorCard({
    required this.target,
    required this.darts,
    required this.aims,
    required this.alsoGood,
    required this.route,
    required this.hits,
    required this.misses,
    this.whyNot,
    this.whyNotHit,
    this.whyNotMisses = const [],
  });

  final int target;
  final int darts;

  /// The table's target; two for a pair of neighbours (48: S16 and S8).
  final List<DartThrow> aims;

  /// The targets almost as good, also lit and also right.
  final List<DartThrow> alsoGood;

  /// The whole route if every dart hits; null when no checkout is left with
  /// these darts (then the aim sets up the next visit).
  final CheckoutRoute? route;

  /// One per aim.
  final List<DartOutcome> hits;

  /// The misses into the next area of the aim (none for a pair of neighbours).
  final List<DartOutcome> misses;

  /// A tempting target that is not as good, with its hit and misses.
  final DartThrow? whyNot;
  final DartOutcome? whyNotHit;
  final List<DartOutcome> whyNotMisses;

  /// The miss to show beside the route: one that still leaves a checkout, or
  /// else the first one. Null for a pair of hits (48: S16 or S8).
  DartOutcome? get shownMiss {
    if (misses.isEmpty) return null;
    return misses.firstWhere((miss) => miss.hasCheckout, orElse: () => misses.first);
  }

  /// The whole route of a dart's outcome, from [target]: the dart, then the
  /// route of what it leaves (S20 T20 D10 for a miss into S20 on 100). Null
  /// when it leaves no checkout.
  CheckoutRoute? routeOf(DartOutcome outcome) {
    if (outcome.checkedOut) return CheckoutRoute([outcome.dart]);
    final rest = outcome.route;
    return rest == null ? null : CheckoutRoute([outcome.dart, ...rest.darts]);
  }
}

/// Builds the tutorial cards from the checkout tables ([OptimalRouteService]).
/// 127 with three darts: aim at T20 (67 left, T17 D8); S20 leaves 107, still T19
/// Bull. Not T19: S19 leaves 108, no checkout with two darts.
class CheckoutTutor {
  CheckoutTutor(this._optimal);

  final OptimalRouteService _optimal;

  /// Every dart worth thinking about, best-known first: the trebles, the
  /// singles, the doubles, then the bull.
  static final List<DartThrow> _candidates = [
    for (final m in [Multiplier.treble, Multiplier.single, Multiplier.double])
      for (var n = DartThrow.maxBoardNumber; n >= 1; n--) DartThrow(m, n),
    DartThrow.bull,
    DartThrow.outerBull,
  ];

  /// True when [dart] is one of the right first darts on [target] with [darts]
  /// darts in hand: the table's target or one almost as good.
  bool isRight(int target, int darts, DartThrow dart) => _optimal.aimsIn(target, darts).contains(dart);

  /// Every optimal route of [target] with [darts] darts in hand, the table's
  /// own first ("Also optimal" lists them).
  List<CheckoutRoute> optimalRoutes(int target, int darts) => _optimal.optimalRoutesIn(target, darts);

  /// True when [route] is one of the optimal routes of [target] with [darts]
  /// darts in hand.
  bool isOptimalIn(int target, int darts, CheckoutRoute route) => _optimal.isOptimalIn(target, darts, route);

  /// The darts a throw at [dart] most often lands in instead
  /// ([OptimalRouteService.missesOf]).
  static List<DartThrow> missesOf(DartThrow dart) => OptimalRouteService.missesOf(dart);

  /// What [dart] leaves on [target] with [darts] darts in hand (counting it).
  DartOutcome outcome(int target, int darts, DartThrow dart) {
    final left = target - dart.score;
    if (left < 0 || left == 1 || (left == 0 && !dart.isFinishingDart)) {
      return DartOutcome(dart, target, null, bust: true);
    }
    if (left == 0 || darts <= 1) return DartOutcome(dart, left, null);
    final routes = _optimal.optimalRoutesIn(left, darts - 1);
    return DartOutcome(dart, left, routes.isEmpty ? null : routes.first);
  }

  /// Where a throw at [dart] lands when it misses into single: the single of a
  /// treble or a double, 25 for the Bull. Null for a single or 25.
  static DartThrow? missIntoSingle(DartThrow dart) {
    if (dart.isBull) return DartThrow.outerBull;
    if (dart.isOuterBull || dart.multiplier == Multiplier.single) return null;
    return DartThrow(Multiplier.single, dart.number);
  }

  /// What [route]'s first dart leaves on [target] with [darts] darts in hand
  /// when it misses into single; null when it is a single (or 25).
  DartOutcome? firstMiss(int target, int darts, CheckoutRoute route) {
    if (route.darts.isEmpty) return null;
    final miss = missIntoSingle(route.darts.first);
    return miss == null ? null : outcome(target, darts, miss);
  }

  /// The two singles beside the single [dart] as the board hangs: the one
  /// further left first (16: S8 and S7; 20: S5 and S1). Where both are as far
  /// left (6 and 11), the higher one is first. Null for anything but a single
  /// from 1 to 20.
  static (DartThrow, DartThrow)? sideNeighbours(DartThrow dart) {
    if (dart.multiplier != Multiplier.single || dart.isOuterBull) return null;
    final i = boardOrder.indexOf(dart.number);
    if (i < 0) return null;
    final n = boardOrder.length;
    // Clockwise from the top: x grows to the right, y grows upwards.
    (double, double) at(int slot) {
      final angle = slot * 2 * math.pi / n;
      return (math.sin(angle), math.cos(angle));
    }

    final before = (i + n - 1) % n, after = (i + 1) % n;
    final (bx, by) = at(before);
    final (ax, ay) = at(after);
    final beforeFirst = (bx - ax).abs() < 1e-9 ? by > ay : bx < ax;
    final a = DartThrow(Multiplier.single, boardOrder[before]);
    final b = DartThrow(Multiplier.single, boardOrder[after]);
    return beforeFirst ? (a, b) : (b, a);
  }

  /// What Learn says about [player], the darts thrown in Practice on [target]
  /// with [darts] darts in hand, judged [correct] and [optimal].
  PracticeReview review(int target, int darts, CheckoutRoute player,
      {required bool correct, required bool optimal}) {
    final miss = firstMiss(target, darts, player);
    if (!correct) return PracticeReview(kind: ReviewKind.wrong, route: player, miss: miss);
    if (optimal) return PracticeReview(kind: ReviewKind.optimal, route: player, miss: miss);
    final routes = optimalRoutes(target, darts);
    if (routes.isNotEmpty) {
      final fewest = routes.map((r) => r.length).reduce(math.min);
      if (fewest < player.length) {
        return PracticeReview(
            kind: ReviewKind.good, route: player, miss: miss, reason: GoodReason.fewerDarts, fewestDarts: fewest);
      }
      if (miss != null && !miss.hasCheckout) {
        for (final route in routes) {
          final kept = firstMiss(target, darts, route);
          if (kept != null && kept.hasCheckout) {
            return PracticeReview(
                kind: ReviewKind.good,
                route: player,
                miss: miss,
                reason: GoodReason.missKeepsCheckout,
                optimalMiss: kept);
          }
        }
      }
    }
    return PracticeReview(kind: ReviewKind.good, route: player, miss: miss);
  }

  /// The card for [target] with [darts] darts in hand; null when the tables
  /// have no row for it.
  TutorCard? card(int target, int darts) {
    final row = CheckoutTable.row(target, darts);
    if (row == null) return null;
    final aims = CheckoutTable.aims(row);
    final lit = _optimal.aimsIn(target, darts);
    final routes = _optimal.optimalRoutesIn(target, darts);
    final misses = aims.length == 1
        ? [for (final miss in missesOf(aims.single)) outcome(target, darts, miss)]
        : const <DartOutcome>[];

    // Why not: only where the choice is not the obvious one - the aim's miss
    // still leaves a checkout, and a target of the same kind whose hit checks
    // out just as well leaves none when it is missed (127: S20 leaves T19 Bull,
    // S19 leaves 108). Most numbers have none.
    DartThrow? whyNot;
    if (routes.isNotEmpty && aims.length == 1 && _optimal.missesKept(target, darts, aims.single) > 0) {
      final aim = aims.single;
      for (final dart in _candidates) {
        if (lit.contains(dart) || dart.multiplier != aim.multiplier) continue;
        if (!ChoiceAdvisor.isNaturalAim(dart) && dart.score != target) continue;
        if (!outcome(target, darts, dart).hasCheckout) continue;
        if (missesOf(dart).isNotEmpty && _optimal.missesKept(target, darts, dart) == 0) {
          whyNot = dart;
          break;
        }
      }
    }

    return TutorCard(
      target: target,
      darts: darts,
      aims: aims,
      alsoGood: [for (final dart in lit) if (!aims.contains(dart)) dart],
      route: routes.isEmpty ? null : routes.first,
      hits: [for (final aim in aims) outcome(target, darts, aim)],
      misses: misses,
      whyNot: whyNot,
      whyNotHit: whyNot == null ? null : outcome(target, darts, whyNot),
      whyNotMisses: whyNot == null
          ? const []
          : [for (final miss in missesOf(whyNot)) outcome(target, darts, miss)],
    );
  }
}
