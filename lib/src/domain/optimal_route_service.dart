import 'bull_safe_finish.dart';
import 'canonical_checkouts.dart';
import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'checkout_strategy.dart';
import 'single_single_double.dart';

/// Answers "what is the optimal way to check out N (in D darts)?".
///
/// Optimal sets, in priority order (first entry is the one shown as "the"
/// answer; every entry is accepted as optimal, in any order of the setup darts):
///
///  * Minimum-dart, 2 darts, target 55..70: the bull-safe finish only
///    (67 -> T17 D8). See [BullSafeFinish].
///  * Minimum-dart, 3 darts: every bull-safe route (first treble, then the
///    bull-safe finish; 121 has four), then the canonical chart route and its
///    approved alternates.
///  * Everything else at minimum darts: the canonical chart route (+ alternates),
///    falling back to [CheckoutStrategy].
///  * [chartOnlyCheckouts] (120) always keep their classic chart route.
///
/// Only the minimum number of darts is ever optimal: a number that can be
/// finished in 2 darts is never played (or accepted as optimal) in 3 - with one
/// exception. On 51 to 70, when all three darts are free, single, single,
/// double is better than any treble-double route and is the optimal one. See
/// [SingleSingleDouble].
///
/// A chart entry that is illegal under the engine is ignored, never taught.
class OptimalRouteService {
  OptimalRouteService(
    this._engine, {
    CheckoutStrategy strategy = const CheckoutStrategy(),
    Map<int, String> canonical = canonicalCheckouts,
    Map<int, List<String>> alternates = alternateOptimalCheckouts,
    Set<int> chartOnly = chartOnlyCheckouts,
  })  : _strategy = strategy,
        _canonical = canonical,
        _alternates = alternates,
        _chartOnly = chartOnly;

  final CheckoutEngine _engine;
  final CheckoutStrategy _strategy;
  final Map<int, String> _canonical;
  final Map<int, List<String>> _alternates;
  final Set<int> _chartOnly;
  final Map<int, List<CheckoutRoute>> _cache = {};
  final Map<int, List<CheckoutRoute>> _spareDartCache = {};

  /// The primary optimal route, or null when [target] is not checkoutable.
  CheckoutRoute? optimalRoute(int target, {int? dartsLeft}) {
    final routes = optimalRoutes(target, dartsLeft: dartsLeft);
    return routes.isEmpty ? null : routes.first;
  }

  /// All optimal routes (primary first) for [target]; empty if impossible.
  ///
  /// [dartsLeft] is how many darts the player can still throw. Left out, it is
  /// the fewest darts the number needs. With a spare dart (all three free on
  /// 51 to 70) the optimal routes are the single, single, double ones.
  List<CheckoutRoute> optimalRoutes(int target, {int? dartsLeft}) {
    final minimum = _engine.minimumDarts(target);
    if (minimum == null) return const [];
    if (_hasSingleSingleDouble(target, minimum, dartsLeft)) {
      return _spareDartCache.putIfAbsent(target, () {
        final routes = SingleSingleDouble.from(_engine.legalRoutes(target, darts: 3));
        return List.unmodifiable(
            routes.isEmpty ? _compute(target, minimum) : routes);
      });
    }
    return _cache.putIfAbsent(
      target,
      () => List.unmodifiable(_compute(target, minimum)),
    );
  }

  /// Whether [route] is one of the optimal routes for [target]. Order of the
  /// non-finishing darts is irrelevant. A route longer than the minimum is
  /// never optimal - except single, single, double on 51 to 70 when all three
  /// darts are free ([dartsLeft] 3).
  bool isOptimal(int target, CheckoutRoute route, {int? dartsLeft}) =>
      optimalRoutes(target, dartsLeft: dartsLeft).any(route.isEquivalentTo);

  bool _hasSingleSingleDouble(int target, int minimum, int? dartsLeft) =>
      dartsLeft != null &&
      dartsLeft > minimum &&
      minimum == 2 &&
      SingleSingleDouble.covers(target) &&
      !_chartOnly.contains(target);

  List<CheckoutRoute> _compute(int target, int minimum) {
    final routes = <CheckoutRoute>[];
    void add(CheckoutRoute? route) {
      if (route == null) return;
      if (!_engine.isLegalRoute(target, route) || route.length != minimum) return;
      if (!routes.any(route.isEquivalentTo)) routes.add(route);
    }

    final bullSafe = !_chartOnly.contains(target);
    if (bullSafe && minimum == 2) {
      add(BullSafeFinish.twoDartFinish(target));
    } else if (bullSafe && minimum == 3) {
      BullSafeFinish.threeDartRoutes(target).forEach(add);
    }
    // The chart only decides when the bull-safe rule does not cover it
    // (2 darts), and is an accepted extra for 3 darts and 1 dart.
    if (minimum != 2 || routes.isEmpty) {
      add(_chartRoute(target));
      for (final text in _alternates[target] ?? const <String>[]) {
        add(CheckoutRoute.parse(text));
      }
    }

    if (routes.isEmpty) {
      add(_strategy.best(_engine.legalRoutes(target, darts: minimum)));
    }
    return routes;
  }

  CheckoutRoute? _chartRoute(int target) {
    final text = _canonical[target];
    if (text == null) return null;
    final route = CheckoutRoute.parse(text);
    return route.length == _engine.minimumDarts(target) ? route : null;
  }
}
