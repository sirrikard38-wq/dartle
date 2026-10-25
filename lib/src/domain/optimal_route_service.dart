import 'aim_pairs.dart';
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
///     three-dart numbers whose first treble leaves 55 to 70 (not 51 to 54: no
///     tiny single before the Bull, 109 is not T19 S2 Bull). The treble of the
///     number whose single leaves 50, then the double - or that single, then
///     the Bull. All of them are equal (57: T7 D18, S7 Bull; 119: T19 T12 D13,
///     T19 S12 Bull). See [BullSafeFinish]. A three-dart number also accepts
///     its standard routes. With two darts left on 41 to 60 (a two-dart number,
///     or the last two darts after the first treble of a three-dart number) a
///     single that leaves a better double is as good (57: S17 D20; 60: S20 D20;
///     109: T19 S20 D16), see [SingleLeave].
///  3. **More singles.** It is far easier to hit a single than a double or a
///     treble, so the routes with the most single setup darts win (the outer
///     bull counts as a single): 35 is S15 D10, S3 D16, S17 D9.
///  4. **Setup doubles last, then fewer triples.** Only sensible aims are
///     used (singles and T15-T20, see [NaturalAim]).
///  5. **Aims**, with two darts left on 20 or more: a first dart whose two
///     possible hits (the single and triple of a number, or two neighbours on
///     the board) each leave a double is as good (43: T11 D5, S11 D16; 64: T16
///     D8, T8 D20), from the best group only; and the same better double twice
///     (64: D16 D16). See [AimPairs].
///
/// A two-dart number over 40 can also be played with three darts; its optimal
/// routes are then [AimPairs.threeDartRoutes] (see [optimalRoutesIn]).
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
  final Map<(int, int), List<CheckoutRoute>> _cacheIn = {};

  /// The optimal routes for [target] played with exactly [darts] darts (all of
  /// them have to be used). With the fewest darts it needs that is
  /// [optimalRoutes]; a two-dart number over 60 with three darts uses
  /// [AimPairs.threeDartRoutes] and the [_followUps]; anything else that has to
  /// use more darts than it needs (after a dart that was not optimal) gets the
  /// routes with the most singles. Empty when it cannot be done in exactly
  /// [darts].
  List<CheckoutRoute> optimalRoutesIn(int target, int darts) {
    final minimum = _engine.minimumDarts(target);
    if (minimum == null || darts < minimum || !_engine.canCheckoutIn(target, darts)) {
      return const [];
    }
    if (darts == minimum) return optimalRoutes(target);
    return _cacheIn.putIfAbsent((target, darts), () {
      if (minimum == 2 && darts == 3 && target > AimPairs.threeDartAbove) {
        final routes = <CheckoutRoute>[];
        for (final route in [...AimPairs.threeDartRoutes(target), ..._followUps(target)]) {
          if (!routes.any(route.isEquivalentTo)) routes.add(route);
        }
        if (routes.isNotEmpty) return List.unmodifiable(routes);
      }
      final tier = _tierRoutes(target, darts);
      return List.unmodifiable(tier.isEmpty ? _engine.legalRoutes(target, darts: darts) : tier);
    });
  }

  /// The lowest single [_followUps] starts with.
  static const int followUpLowestSingle = 15;

  /// A two-dart number played with three darts is also optimal when the first
  /// dart is a high single (S15 to S20) that leaves a two-dart number over 60,
  /// and the last two darts are an optimal route of that number: 93 with S19
  /// leaves 74, whose T20 D7 gives S19 T20 D7. Limited to high singles and to
  /// leftovers over 60 because every single and every leftover gave far too
  /// many routes (142 on 61). Biggest single first.
  List<CheckoutRoute> _followUps(int target) {
    final routes = <CheckoutRoute>[];
    for (var n = DartThrow.maxBoardNumber; n >= followUpLowestSingle; n--) {
      final left = target - n;
      if (left <= AimPairs.threeDartAbove || _engine.minimumDarts(left) != 2) continue;
      for (final route in optimalRoutes(left)) {
        final full = CheckoutRoute([DartThrow(Multiplier.single, n), ...route.darts]).normalized;
        if (!routes.any(full.isEquivalentTo)) routes.add(full);
      }
    }
    return routes;
  }

  /// True when [target] is a two-dart number over 60 that can also be played
  /// with three darts.
  bool hasThreeDartOption(int target) =>
      _engine.minimumDarts(target) == 2 &&
      target > AimPairs.threeDartAbove &&
      optimalRoutesIn(target, 3).isNotEmpty;

  /// Whether [route] is optimal for [target] played with exactly [darts] darts.
  bool isOptimalIn(int target, int darts, CheckoutRoute route) =>
      route.length == darts && optimalRoutesIn(target, darts).any(route.isEquivalentTo);

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

    // Two darts left: a first dart whose two possible hits each leave a double
    // is as good (43: T11 D5, S11 D16; 64: T16 D8, T8 D20), and so is the same
    // better double twice (64: D16 D16). On 20 to 60 every single/triple pair
    // of a number stays optimal too, whatever its doubles (35: T5 D10).
    if (minimum == 2) {
      for (final route in [
        ...AimPairs.twoDartRoutes(target),
        ...AimPairs.sameNumberRoutes(target),
        ...AimPairs.neighbourSingleRoutes(target),
        if (AimPairs.sameDoubleTwice(target) case final twice?) twice,
      ]) {
        add(route, force: true);
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
