import 'better_doubles.dart';
import 'bull_safe_finish.dart';
import 'canonical_checkouts.dart';
import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'checkout_strategy.dart';
import 'dart_throw.dart';
import 'natural_aim.dart';
import 'single_leave.dart';
import 'site_routes.dart';

/// Answers "what is the optimal way to check out N?".
///
/// Optimal routes, in order of priority (the first entry is the one shown as
/// "the" answer; every entry is accepted as optimal, in any order of the setup
/// darts):
///
///  1. **Fewest darts.** A number that can be finished in 2 darts is never
///     played (or accepted as optimal) in 3.
///  2. **Bull-safe**, where it applies: two-dart numbers from 51 to 70, and
///     three-dart numbers whose first treble leaves 51 to 70. The treble of the
///     number whose single leaves 50, then the double - or that single, then
///     the Bull. All of them are equal (57: T7 D18, S7 Bull; 119: T19 T12 D13,
///     T19 S12 Bull). See [BullSafeFinish]. A three-dart number also accepts
///     its standard routes. With two darts left on 41 to 60 (a two-dart number,
///     or the last two darts after the first treble of a three-dart number) a
///     single that leaves a better double is as good (57: S17 D20; 60: S20 D20;
///     109: T19 S20 D16), see [SingleLeave].
///  3. **More singles.** It is far easier to hit a single than a double or a
///     treble, so the routes with the most single setup darts win (the outer
///     bull counts as a single): 35 is S15 D10, S3 D16, S17 D9 - never T5 D10.
///  4. **Setup doubles last, then fewer triples.** Only sensible aims are
///     used (singles and T15-T20, see [NaturalAim]).
///
/// [chartOnlyCheckouts] (120) always keep their classic chart route. A chart
/// route is shown first when it is one of the optimal routes. A chart entry
/// that is illegal under the engine is ignored, never taught.
class OptimalRouteService {
  OptimalRouteService(
    this._engine, {
    CheckoutStrategy strategy = const CheckoutStrategy(),
    Map<int, String> canonical = canonicalCheckouts,
    Set<int> chartOnly = chartOnlyCheckouts,
    Map<int, List<String>> siteThrows = siteThrowRoutes,
  })  : _strategy = strategy,
        _canonical = canonical,
        _chartOnly = chartOnly,
        _siteThrows = siteThrows;

  final CheckoutEngine _engine;
  final CheckoutStrategy _strategy;
  final Map<int, String> _canonical;
  final Set<int> _chartOnly;

  /// The first-choice routes of dartscheckoutassistant.com, treated like the
  /// chart: standard routes that are accepted next to the rules' own routes.
  final Map<int, List<String>> _siteThrows;
  final Map<int, List<CheckoutRoute>> _cache = {};

  /// The primary optimal route, or null when [target] is not checkoutable.
  CheckoutRoute? optimalRoute(int target) {
    final routes = optimalRoutes(target);
    return routes.isEmpty ? null : routes.first;
  }

  /// All optimal routes (primary first) for [target]; empty if impossible.
  List<CheckoutRoute> optimalRoutes(int target) {
    final minimum = _engine.minimumDarts(target);
    if (minimum == null) return const [];
    return _cache.putIfAbsent(
      target,
      () => List.unmodifiable(_compute(target, minimum)),
    );
  }

  /// Whether [route] is one of the optimal routes for [target]. Order of the
  /// non-finishing darts is irrelevant. A route longer than the minimum is
  /// never optimal.
  bool isOptimal(int target, CheckoutRoute route) =>
      optimalRoutes(target).any(route.isEquivalentTo);

  /// How many of the setup darts are singles. The outer bull is not counted: it
  /// is far too hard to hit to be an easy single.
  static int singles(CheckoutRoute route) => route.setupDarts
      .where((d) => d.multiplier == Multiplier.single && !d.isOuterBull)
      .length;

  /// How many of the setup darts are doubles (T20 D20 D16 has one).
  static int _setupDoubles(CheckoutRoute route) =>
      route.setupDarts.where((d) => d.multiplier == Multiplier.double).length;

  List<CheckoutRoute> _compute(int target, int minimum) {
    final routes = <CheckoutRoute>[];
    // A route that aims at the outer bull is never optimal; [force] is only for
    // the last resort below, when nothing else exists.
    bool add(CheckoutRoute? route, {bool force = false}) {
      if (route == null) return false;
      if (!_engine.isLegalRoute(target, route) || route.length != minimum) return false;
      if (!force && route.setupDarts.any((d) => d.isOuterBull)) return false;
      if (routes.any(route.isEquivalentTo)) return false;
      routes.add(route);
      return true;
    }

    final chart = _chartRoute(target);
    // The standard routes: the chart's, then the site's first choices.
    final standard = [
      if (chart != null) chart,
      for (final text in _siteThrows[target] ?? const <String>[])
        CheckoutRoute.parse(text),
    ];
    if (_chartOnly.contains(target)) {
      add(chart);
    } else if (minimum == 1) {
      _engine.legalRoutes(target, darts: 1).forEach(add);
    } else {
      final safe = switch (minimum) {
        2 => BullSafeFinish.twoDartRoutes(target),
        3 => BullSafeFinish.threeDartRoutes(target),
        _ => const <CheckoutRoute>[],
      };
      if (safe.isNotEmpty) {
        safe.forEach(add);
        // A single that leaves a better double is as good: with two darts left
        // on 41-60, and for the last two darts after the first treble.
        // These are vetted, so they may use the outer bull (61: 25 D18, 65: 25 D20).
        if (minimum == 2) {
          for (final route in [
            ...SingleLeave.twoDartRoutes(target),
            ...SingleLeave.outerBullRoutes(target),
          ]) {
            add(route, force: true);
          }
        }
        if (minimum == 3) {
          for (final route in SingleLeave.threeDartRoutes(target)) {
            add(route, force: true);
          }
        }
        // A three-dart number also accepts its standard routes.
        if (minimum == 3) standard.forEach(add);
      } else {
        final tier = _tierRoutes(target, minimum);
        // A standard route comes first when it is as good as the best (it has
        // as many singles); one with fewer singles is not optimal.
        if (tier.isNotEmpty) {
          for (final route in standard) {
            if (singles(route) >= singles(tier.first)) add(route);
          }
        }
        tier.forEach(add);
      }
    }

    if (routes.isEmpty) {
      add(_strategy.best(_engine.legalRoutes(target, darts: minimum)), force: true);
    }
    return routes;
  }

  /// Rule 3 and 4: the routes of [minimum] darts with the most singles, made of
  /// sensible aims, best-looking first.
  List<CheckoutRoute> _tierRoutes(int target, int minimum) {
    final legal = _engine.legalRoutes(target, darts: minimum);
    final natural = legal.where(_isSensible).toList();
    final pool = natural.isEmpty ? legal : natural;
    if (pool.isEmpty) return const [];
    final best = pool.map(singles).reduce((a, b) => a > b ? a : b);
    return pool.where((r) => singles(r) == best).toList()..sort(_compare);
  }

  /// Made of sensible aims only (see [NaturalAim]); and a route that has a
  /// double among its setup darts must also finish on a better double (T20 D20
  /// D16, but not T20 D20 Bull or T18 D20 D19).
  static bool _isSensible(CheckoutRoute route) =>
      route.setupDarts.every(NaturalAim.isNatural) &&
      (_setupDoubles(route) == 0 || BetterDoubles.leavesBetterDouble(route));

  /// Best-looking first: a finish on a better double, then the double the
  /// strategy prefers, then fewer triples, then the bigger first dart.
  int _compare(CheckoutRoute a, CheckoutRoute b) {
    final byBetter = (BetterDoubles.leavesBetterDouble(a) ? 0 : 1)
        .compareTo(BetterDoubles.leavesBetterDouble(b) ? 0 : 1);
    if (byBetter != 0) return byBetter;
    final byFinisher = _strategy.finisherRank(a).compareTo(_strategy.finisherRank(b));
    if (byFinisher != 0) return byFinisher;
    final byDoubles = _setupDoubles(a).compareTo(_setupDoubles(b));
    if (byDoubles != 0) return byDoubles;
    final byTrebles = a.trebleCount.compareTo(b.trebleCount);
    if (byTrebles != 0) return byTrebles;
    final byFirst = b.darts.first.score.compareTo(a.darts.first.score);
    return byFirst != 0 ? byFirst : a.notation.compareTo(b.notation);
  }

  CheckoutRoute? _chartRoute(int target) {
    final text = _canonical[target];
    if (text == null) return null;
    final route = CheckoutRoute.parse(text);
    return route.length == _engine.minimumDarts(target) ? route : null;
  }
}
