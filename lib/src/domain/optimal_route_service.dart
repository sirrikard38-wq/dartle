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
  /// up to it, three darts are a choice in Checkout practice.
  static const int threeDartAbove = 60;

  /// The optimal routes for [target] with [darts] darts in hand, the table's own
  /// route first. Empty when it cannot be checked out with them.
  List<CheckoutRoute> optimalRoutesIn(int target, int darts) =>
      _cache.putIfAbsent((target, darts), () {
        final minimum = _engine.minimumDarts(target);
        if (minimum == null || darts < minimum) return const [];
        return List.unmodifiable(_tableRoutes(target, darts));
      });

  /// The most darts a route may use: two on a number two darts can check out,
  /// even with three in hand ([CheckoutTable.row]).
  int _mostDarts(int target, int darts) {
    final minimum = _engine.minimumDarts(target);
    return darts == 3 && minimum != null && minimum <= 2 ? 2 : darts;
  }

  /// From 120 to 130 with three darts in hand the first dart decides it all:
  /// see [bestFirstDart].
  static const int bestFirstFrom = 120, bestFirstTo = 130;

  /// From 120 to 130 with three darts in hand: the one first dart to aim at -
  /// the one whose miss (into its single) still leaves a checkout with the two
  /// darts after it most often, of those whose hit leaves one; the biggest
  /// of them when several do (127: T20, as S20 leaves 107 = T19 Bull - T17
  /// would too, S17 leaving 110, but T20 is bigger; 126: T19, S19 leaving
  /// 107). Null for every other number and number of darts.
  DartThrow? bestFirstDart(int target, int darts) {
    if (darts != 3 || target < bestFirstFrom || target > bestFirstTo) return null;
    DartThrow? best;
    var bestKept = -1;
    for (final dart in _candidates) {
      final left = target - dart.score;
      if (left < 2 || optimalRoutesIn(left, 2).isEmpty) continue;
      final kept = missesKept(target, darts, dart);
      if (kept > bestKept || (kept == bestKept && dart.score > best!.score)) {
        best = dart;
        bestKept = kept;
      }
    }
    return best;
  }

  List<CheckoutRoute> _tableRoutes(int target, int darts) {
    // 120 to 130: the best first dart, then every optimal finish of what it leaves.
    if (bestFirstDart(target, darts) case final first?) {
      final routes = <CheckoutRoute>[];
      for (final finish in optimalRoutesIn(target - first.score, 2)) {
        final route = CheckoutRoute([first, ...finish.darts]);
        if (_engine.isLegalRoute(target, route) && !routes.any(route.isEquivalentTo)) routes.add(route);
      }
      return routes;
    }
    final row = CheckoutTable.row(target, darts);
    if (row == null) return const [];
    final most = _mostDarts(target, darts);
    final routes = <CheckoutRoute>[];
    void add(CheckoutRoute route) {
      if (route.length <= most &&
          _engine.isLegalRoute(target, route) &&
          !routes.any(route.isEquivalentTo)) {
        routes.add(route);
      }
    }

    final tableRoutes = CheckoutTable.routes(row, target)..forEach(add);
    // The first dart of a table route, a target almost as good, or one just as
    // good - then any optimal way to finish what it leaves with the darts after
    // it, the remainder's own alternatives too. 116 with three darts: T20 (the
    // table's alternative) leaves 56, which is S16 D20 or S20 D18 - so T20 S20
    // D18 is optimal: aim at T20, and S20 still leaves 96, T20 D18.
    final firsts = <DartThrow>{
      for (final route in tableRoutes) route.darts.first,
      ...CheckoutTable.alternatives(row),
      ..._asGood(target, darts, row),
    };
    for (final first in firsts) {
      final left = target - first.score;
      if (left == 0) add(CheckoutRoute([first]));
      // What it leaves, with the darts still allowed (51 with three darts: S1
      // leaves 50, then the Bull - not S18 D16).
      if (most < 2 || left < 2) continue;
      for (final route in optimalRoutesIn(left, most - 1)) {
        add(CheckoutRoute([first, ...route.darts]));
      }
    }
    // Three darts in hand on a number two darts can check out: the first dart
    // of a two-dart route (a treble or a double) missed into its single, then
    // any optimal two-dart finish of what that leaves, counts too - the three
    // darts are there for it. 92: T20 D16, or S20 and then 72 with two darts:
    // S20 T18 D9, S20 T16 D12 ... Not the Bull into 25 (82 stays Bull D16).
    if (darts == 3 && most == 2) {
      final firsts = {for (final route in List.of(routes)) if (route.length == 2) route.darts.first};
      for (final first in firsts) {
        if (first.number == DartThrow.bullNumber || first.multiplier == Multiplier.single) continue;
        final single = DartThrow(Multiplier.single, first.number);
        final left = target - single.score;
        if (left < 2) continue;
        for (final route in optimalRoutesIn(left, 2)) {
          final missed = CheckoutRoute([single, ...route.darts]);
          if (_engine.isLegalRoute(target, missed) && !routes.any(missed.isEquivalentTo)) routes.add(missed);
        }
      }
    }
    // A number from 130 up with only a few ways out: every one of them is
    // optimal (164: T20 T18 Bull and T19 T19 Bull).
    for (final route in _fewOptimal(target, darts)) {
      if (!routes.any(route.isEquivalentTo)) routes.add(route);
    }
    return routes;
  }

  /// A number with this many ways to check it out (or fewer), with the darts
  /// in hand, has every one of them optimal - from [fewOptimalFrom] up.
  static const int fewRoutes = 5;

  /// The rule of [fewRoutes] holds from this number up (130 included).
  static const int fewOptimalFrom = 130;

  /// The routes the rule of [fewRoutes] makes optimal: none under 130.
  List<CheckoutRoute> _fewOptimal(int target, int darts) =>
      target < fewOptimalFrom ? const [] : fewRoutesIn(target, darts) ?? const [];

  final Map<(int, int), List<CheckoutRoute>?> _fewCache = {};

  /// Every way to check out [target] with [darts] darts in hand - the same
  /// darts in another order counted once - when there are at most
  /// [fewRoutes] of them; null when there are more.
  List<CheckoutRoute>? fewRoutesIn(int target, int darts) => _fewCache.putIfAbsent((target, darts), () {
        final out = <CheckoutRoute>[];
        for (final route in _engine.legalRoutes(target)) {
          if (route.length > darts || out.any(route.isEquivalentTo)) continue;
          out.add(route);
          if (out.length > fewRoutes) return null;
        }
        return List.unmodifiable(out);
      });

  /// There is just one way at all to check out [target] with [darts] darts in
  /// hand ("Only possibility") - not just one optimal way (130 with three
  /// darts is T20 T20 D5, but T20 S20 Bull checks it out too).
  bool onlyPossibility(int target, int darts) => fewRoutesIn(target, darts)?.length == 1;

  /// From 120 to 130: one optimal route, the best of the many ways out ("The
  /// best optimal route" - not "Only possibility"; 127 is T20 T17 D8).
  bool isBestRoute(int target, int darts) =>
      bestFirstDart(target, darts) != null &&
      optimalRoutesIn(target, darts).length == 1 &&
      !onlyPossibility(target, darts);

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
    // 120 to 130: the best first dart and nothing else.
    if (bestFirstDart(target, darts) case final first?) return {first};
    final row = CheckoutTable.row(target, darts);
    if (row == null) return const {};
    final aims = CheckoutTable.aims(row);
    final routes = CheckoutTable.routes(row, target);
    final lit = {
      ...aims,
      for (final route in routes) route.darts.first,
      ...CheckoutTable.alternatives(row),
      ..._asGood(target, darts, row),
      // Only a few ways out, all optimal: each of their darts to set up with
      // (any order), or the one double.
      for (final route in _fewOptimal(target, darts))
        ...(route.length == 1 ? route.darts : route.setupDarts),
    };
    // On a number two darts can check out, a target counts only when a
    // two-dart route starts with it.
    if (_mostDarts(target, darts) < darts) {
      final starts = {for (final route in optimalRoutesIn(target, darts)) route.darts.first};
      lit.retainWhere(starts.contains);
    }
    // The outer bull has no next area to miss into: it says nothing here.
    final measured = aims.where((aim) => missesOf(aim).isNotEmpty);
    if (measured.isEmpty) return lit;
    final aimKept = measured.map((aim) => missesKept(target, darts, aim)).reduce((a, b) => a < b ? a : b);
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
    final aimKept = fewest([
      for (final aim in aims)
        if (missesOf(aim).isNotEmpty) missesKept(target, darts, aim),
    ]);
    // A single is far easier to hit than a treble, so only the same kind counts;
    // and the bull is a kind of its own.
    bool bullArea(DartThrow dart) => dart.number == DartThrow.bullNumber;
    bool sensible(DartThrow dart) =>
        aims.any((aim) => aim.multiplier == dart.multiplier && bullArea(aim) == bullArea(dart)) &&
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
  /// three darts by choice in Checkout practice.
  bool hasPracticeThreeDartOption(int target) =>
      _engine.minimumDarts(target) == 2 &&
      target <= threeDartAbove &&
      optimalRoutesIn(target, 3).isNotEmpty;

  /// Whether [route] is optimal for [target] with [darts] darts in hand.
  /// From 120 to 130 the first dart must be the best one ([bestFirstDart]):
  /// 127 is T20 T17 D8, and T17 T20 D8 is not.
  bool isOptimalIn(int target, int darts, CheckoutRoute route) =>
      route.length <= darts &&
      (bestFirstDart(target, darts) == null || route.darts.first == bestFirstDart(target, darts)) &&
      optimalRoutesIn(target, darts).any(route.isEquivalentTo);

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
