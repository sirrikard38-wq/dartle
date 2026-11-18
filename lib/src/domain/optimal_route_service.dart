import '../board/board_geometry.dart';
import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'checkout_table.dart';
import 'dart_throw.dart';
import 'natural_aim.dart';

/// Answers "what is the optimal way to check out N with these darts?" - from
/// the checkout tables ([CheckoutTable]), for every number and 1, 2 or 3 darts
/// in hand.
///
/// The optimal routes of a row are its route (48 with two darts: S16 D16 and S8
/// D20, one per neighbour) and, for each target almost as good, that target and
/// the route of what it leaves (62 with three darts: T10 D16, and T14 D10 and
/// T18 D4). A route may use fewer darts than are in hand when the table says so
/// (64 with three darts is T16 D8). The setup darts can come in any order.
class OptimalRouteService {
  OptimalRouteService(this._engine);

  final CheckoutEngine _engine;
  final Map<(int, int), List<CheckoutRoute>> _cache = {};

  /// A two-dart number above this can come with three darts in the calculator;
  /// up to it, three darts are a choice in Checkout practice and Checkout input.
  static const int threeDartAbove = 60;

  /// The optimal routes for [target] with [darts] darts in hand, the table's own
  /// route first. Empty when it cannot be checked out with them.
  List<CheckoutRoute> optimalRoutesIn(int target, int darts) =>
      _cache.putIfAbsent((target, darts), () {
        final minimum = _engine.minimumDarts(target);
        if (minimum == null || darts < minimum) return const [];
        return List.unmodifiable(_tableRoutes(target, darts));
      });

  List<CheckoutRoute> _tableRoutes(int target, int darts) {
    final row = CheckoutTable.row(target, darts);
    if (row == null) return const [];
    final routes = <CheckoutRoute>[];
    void add(CheckoutRoute route) {
      if (route.length <= darts &&
          _engine.isLegalRoute(target, route) &&
          !routes.any(route.isEquivalentTo)) {
        routes.add(route);
      }
    }

    CheckoutTable.routes(row, target).forEach(add);
    // A target almost as good, or just as good, then the route the table gives
    // for what it leaves with the darts after it.
    for (final other in [...CheckoutTable.alternatives(row), ..._asGood(target, darts, row)]) {
      final left = target - other.score;
      if (left == 0) add(CheckoutRoute([other]));
      final rest = darts > 1 ? CheckoutTable.row(left, darts - 1) : null;
      if (rest == null) continue;
      for (final route in CheckoutTable.routes(rest, left)) {
        add(CheckoutRoute([other, ...route.darts]));
      }
    }
    return routes;
  }

  /// The darts to aim at on [target] with [darts] darts in hand, all equally
  /// good: the table's target, the first dart of each of its routes (61 with
  /// three darts: the Bull or 25) and the targets almost as good. A setup for
  /// the next visit too, when no checkout is left with these darts.
  ///
  /// The other setup dart of the table's route counts too when its miss leaves
  /// just as much as the table target's miss: then the order makes no difference.
  /// 149 is T20 T19 D16 or T19 T20 D16, as S20 and S19 both leave no checkout.
  /// 127 is T20 first: S20 still leaves T19 Bull.
  Set<DartThrow> aimsIn(int target, int darts) {
    final row = CheckoutTable.row(target, darts);
    if (row == null) return const {};
    final aims = CheckoutTable.aims(row);
    final routes = CheckoutTable.routes(row, target);
    final lit = {
      ...aims,
      for (final route in routes) route.darts.first,
      ...CheckoutTable.alternatives(row),
      ..._asGood(target, darts, row),
    };
    final aimKept = aims.map((aim) => missesKept(target, darts, aim)).reduce((a, b) => a < b ? a : b);
    for (final route in routes) {
      for (final dart in route.setupDarts) {
        if (!lit.contains(dart) && missesKept(target, darts, dart) == aimKept) lit.add(dart);
      }
    }
    return lit;
  }

  /// The darts just as good as the table's target, biggest first: of the same
  /// kind (a single for a single, a treble from T15 for a treble), whose hit
  /// leaves a checkout in no more darts than the target's hit does, and whose
  /// misses leave at least as many checkouts. 25 with two darts: the table's
  /// S17, and S3, S19 and S7 - each leaves a double, and so does a miss into
  /// the next area as often.
  List<DartThrow> _asGood(int target, int darts, CheckoutTableRow row) {
    if (CheckoutTable.routes(row, target).isEmpty) return const [];
    // The darts a hit leaves the checkout in: 0 when it finishes, null when
    // the darts after it cannot.
    int? dartsAfterHit(DartThrow dart) {
      final left = target - dart.score;
      if (left == 0) return dart.isFinishingDart ? 0 : null;
      final fewest = left < 2 ? null : _engine.minimumDarts(left);
      return fewest != null && fewest <= darts - 1 ? fewest : null;
    }

    final aims = CheckoutTable.aims(row);
    int fewest(Iterable<int?> values) => values.whereType<int>().fold(99, (a, b) => a < b ? a : b);
    final aimHit = fewest(aims.map(dartsAfterHit));
    final aimKept = fewest(aims.map((aim) => missesKept(target, darts, aim)));
    // A single is far easier to hit than a treble, so only the same kind counts.
    bool sensible(DartThrow dart) =>
        aims.any((aim) => aim.multiplier == dart.multiplier && aim.isBull == dart.isBull) &&
        (dart.score == target || (dart.multiplier != Multiplier.double && NaturalAim.isNatural(dart)));
    return [
      for (final dart in _candidates)
        if (!aims.contains(dart) && sensible(dart))
          if (dartsAfterHit(dart) case final after? when after <= aimHit)
            if (missesKept(target, darts, dart) >= aimKept) dart,
    ];
  }

  /// Every dart, biggest first.
  static final List<DartThrow> _candidates = [
    DartThrow.bull,
    for (final m in [Multiplier.treble, Multiplier.double, Multiplier.single])
      for (var n = DartThrow.maxBoardNumber; n >= 1; n--) DartThrow(m, n),
  ];

  /// How many of the darts a throw at [dart] most often lands in instead
  /// ([missesOf]) still leave a checkout with the darts after it.
  int missesKept(int target, int darts, DartThrow dart) => missesOf(dart).where((miss) {
        final left = target - miss.score;
        if (left == 0) return miss.isFinishingDart;
        return darts > 1 && left >= 2 && optimalRoutesIn(left, darts - 1).isNotEmpty;
      }).length;

  /// The darts a throw at [dart] most often lands in instead: the single of a
  /// triple or a double, the two neighbouring singles of a single, the outer
  /// bull for the Bull. None for the outer bull.
  static List<DartThrow> missesOf(DartThrow dart) {
    if (dart.isBull) return const [DartThrow.outerBull];
    if (dart.isOuterBull) return const [];
    if (dart.multiplier != Multiplier.single) return [DartThrow(Multiplier.single, dart.number)];
    final i = boardOrder.indexOf(dart.number);
    final n = boardOrder.length;
    return [
      DartThrow(Multiplier.single, boardOrder[(i + n - 1) % n]),
      DartThrow(Multiplier.single, boardOrder[(i + 1) % n]),
    ];
  }

  /// True when [target] is a two-dart number over 60, which can also come with
  /// three darts.
  bool hasThreeDartOption(int target) =>
      _engine.minimumDarts(target) == 2 &&
      target > threeDartAbove &&
      optimalRoutesIn(target, 3).isNotEmpty;

  /// True when [target] is a two-dart number up to 60, which can be played with
  /// three darts by choice in Checkout practice and Checkout input.
  bool hasPracticeThreeDartOption(int target) =>
      _engine.minimumDarts(target) == 2 &&
      target <= threeDartAbove &&
      optimalRoutesIn(target, 3).isNotEmpty;

  /// Whether [route] is optimal for [target] with [darts] darts in hand.
  bool isOptimalIn(int target, int darts, CheckoutRoute route) =>
      route.length <= darts && optimalRoutesIn(target, darts).any(route.isEquivalentTo);

  /// The primary optimal route, or null when [target] is not checkoutable.
  CheckoutRoute? optimalRoute(int target) {
    final routes = optimalRoutes(target);
    return routes.isEmpty ? null : routes.first;
  }

  /// All optimal routes (primary first) for [target] with the fewest darts it
  /// needs; empty if impossible.
  List<CheckoutRoute> optimalRoutes(int target) {
    final minimum = _engine.minimumDarts(target);
    return minimum == null ? const [] : optimalRoutesIn(target, minimum);
  }

  /// Whether [route] is one of the optimal routes for [target] with the fewest
  /// darts. Order of the setup darts is irrelevant.
  bool isOptimal(int target, CheckoutRoute route) =>
      optimalRoutes(target).any(route.isEquivalentTo);

  /// How many of the setup darts are singles. The outer bull is not counted: it
  /// is far too hard to hit to be an easy single.
  static int singles(CheckoutRoute route) => route.setupDarts
      .where((d) => d.multiplier == Multiplier.single && !d.isOuterBull)
      .length;
}
