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
/// Two-dart numbers up to 70 have one rule each: up to 60 a single that leaves
/// a better double, with its near misses ([AimPairs.goodSingleRoutes]); 61 to 70
/// the bull-safe finish and nothing else (61: T11 D14, S11 Bull). A standard
/// route comes first when it is one of them.
///
/// Every other number goes by these, in order of priority (the first entry is
/// the one shown as "the" answer; every entry is accepted as optimal, in any
/// order of the setup darts):
///
///  1. **Fewest darts.** A number that can be finished in 2 darts is never
///     played (or accepted as optimal) in 3.
///  2. **Bull-safe**, where it applies: three-dart numbers whose first treble
///     leaves 55 to 70 (not 51 to 54: no tiny single before the Bull, 109 is not
///     T19 S2 Bull). The treble of the number whose single leaves 50, then the
///     double - or that single, then the Bull. All of them are equal (119: T19
///     T12 D13, T19 S12 Bull). See [BullSafeFinish]. A three-dart number also
///     accepts its standard routes. With two darts left on 41 to 60 after the
///     first treble, a single that leaves a better double is as good (109: T19
///     S20 D16), see [SingleLeave].
///  3. **More singles.** It is far easier to hit a single than a double or a
///     treble, so the routes with the most single setup darts win (the outer
///     bull counts as a single).
///  4. **Setup doubles last, then fewer triples.** Only sensible aims are
///     used (singles and T15-T20, see [NaturalAim]).
///  5. **Aims**, with two darts left: a first dart whose two possible hits (the
///     single and triple of a number, or two neighbours on the board) each leave
///     a double is as good, from the best group only. See [AimPairs].
///
/// A two-dart number over 60 can also be played with three darts, a two-dart
/// number under 60 only in Checkout practice and Checkout input; see
/// [optimalRoutesIn]. Three darts over 60 are built from [_olderTwoDartRoutes]:
/// up to 70 those are the rules above, so the one rule of a two-dart number
/// takes nothing away from its three-dart routes (74: S14 T10 D15, as 60 was
/// T10 D15).
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
  final Map<int, List<CheckoutRoute>> _cacheOlder = {};
  final Map<(int, int), List<CheckoutRoute>> _cacheIn = {};

  /// The optimal routes for [target] played with exactly [darts] darts (all of
  /// them have to be used). With the fewest darts it needs that is
  /// [optimalRoutes]; a two-dart number over 60 with three darts uses
  /// [AimPairs.threeDartRoutes] and the [_followUps]; a two-dart number under 60
  /// with three darts uses [AimPairs.underSixtyRoutes], the one case that also
  /// has routes of two darts (a lit double that finishes with a dart left);
  /// anything else that has to use more darts than it needs (after a dart that
  /// was not optimal) gets the routes with the most singles. Empty when it
  /// cannot be done in exactly [darts].
  List<CheckoutRoute> optimalRoutesIn(int target, int darts) {
    final minimum = _engine.minimumDarts(target);
    if (minimum == null || darts < minimum || !_engine.canCheckoutIn(target, darts)) {
      return const [];
    }
    if (darts == minimum) return optimalRoutes(target);
    return _cacheIn.putIfAbsent((target, darts), () {
      if (minimum == 2 && darts == 3 && target != AimPairs.threeDartAbove) {
        final routes = target > AimPairs.threeDartAbove
            ? _threeDartRoutes(target)
            : AimPairs.underSixtyRoutes(target);
        if (routes.isNotEmpty) return List.unmodifiable(routes);
      }
      // A double with a backup and two darts has that one route: 28 is S14 D7.
      if (minimum == 1 && darts == 2) {
        final backup = AimPairs.missedDoubleRoute(target);
        if (backup != null) return List.unmodifiable([backup]);
      }
      final tier = _tierRoutes(target, darts);
      final routes = <CheckoutRoute>[...(tier.isEmpty ? _engine.legalRoutes(target, darts: darts) : tier)];
      // A one-dart number (50) with two darts: the aims count here too, so after
      // S14 on 64 the 50 left is T14 D4 (S14 D18 if T14 is missed).
      if (minimum == 1 && darts == 2) {
        for (final route in _aimRoutes(target)) {
          if (_engine.isLegalRoute(target, route) && !routes.any(route.isEquivalentTo)) {
            routes.add(route);
          }
        }
      }
      return List.unmodifiable(routes);
    });
  }

  /// A two-dart number over 60 played with three darts: the numbers to aim the
  /// first dart at. Its triple leaves a double that can still be finished with
  /// the two darts left, and its single leaves a two-dart finish (68: T14
  /// leaves D13, S14 leaves 54). The aims whose single leaves a double too
  /// come first - on 68 that is 18 (S18 leaves the Bull, T18 leaves D7), the
  /// best one - then those whose triple leaves a double with a backup (see
  /// [AimPairs.missedDoubleRoute]), then the rest; biggest number first. Under
  /// 60 they are [AimPairs.underSixtyAims].
  List<int> threeDartAims(int target) {
    if (_engine.minimumDarts(target) != 2 || target == AimPairs.threeDartAbove) return const [];
    if (target < AimPairs.threeDartAbove) return AimPairs.underSixtyAims(target);
    final aims = [
      for (var n = DartThrow.maxBoardNumber; n >= 1; n--)
        if (AimPairs.finisherFor(target - 3 * n) != null &&
            _engine.canCheckoutIn(target - 3 * n, 2) &&
            _engine.canCheckoutIn(target - n, 2))
          n,
    ];
    int rank(int n) {
      if (AimPairs.finisherFor(target - n) != null) return 0;
      return AimPairs.missedDoubleRoute(target - 3 * n) != null ? 1 : 2;
    }

    return [
      for (final r in [0, 1, 2]) ...aims.where((n) => rank(n) == r),
    ];
  }

  /// The darts lit before the first of three darts on a two-dart number, all the
  /// same: the single and triple of every [threeDartAims] number (68: S18 T18,
  /// S20 T20, S16 T16, S14 T14, S12 T12, S10 T10, S6 T6). Empty for any other
  /// number.
  Set<DartThrow> threeDartFirstDarts(int target) => {
        for (final n in threeDartAims(target)) ...[
          DartThrow(Multiplier.single, n),
          DartThrow(Multiplier.treble, n),
        ],
      };

  /// The three-dart routes of a two-dart number over 60: the aim routes (the
  /// best aims first), the older rules' routes and [AimPairs.twoSinglesRoutes] -
  /// each only when it can start with one of the [threeDartFirstDarts] (68: S19
  /// S9 D20 and T11 S11 D12 cannot, see [_canStart]). When none can, the older
  /// routes as they are.
  List<CheckoutRoute> _threeDartRoutes(int target) {
    final first = threeDartFirstDarts(target);
    final older = _olderThreeDartRoutes(target);
    final routes = <CheckoutRoute>[];
    for (final route in [
      ..._aimFirstRoutes(target, threeDartAims(target)),
      ...older,
      ...AimPairs.twoSinglesRoutes(target),
    ]) {
      if (_canStart(target, route, first) && !routes.any(route.isEquivalentTo)) routes.add(route);
    }
    return routes.isEmpty ? older : routes;
  }

  /// The only darts that may come after [first] on [target] with three darts,
  /// empty when any dart may. Over 60 a dart that leaves a double is followed by
  /// the start of [AimPairs.twoDartsOnDoubleRoutes] (88: S14 after T20; S18 S14
  /// S10 S6 S2 after T18), and a single is free, also when it leaves the Bull
  /// (64: S14, then T14 D4). Under 60 any first dart that leaves a double is
  /// followed by [AimPairs.doubleAndItsSingle] (47: D20 and S20 after S7).
  Set<DartThrow> dartsAfter(int target, DartThrow first) {
    final left = target - first.score;
    if (target < AimPairs.threeDartAbove) return AimPairs.doubleAndItsSingle(left);
    if (first.multiplier == Multiplier.single) return const {};
    return {for (final route in AimPairs.twoDartsOnDoubleRoutes(left)) route.darts.first};
  }

  /// Can [route] be thrown with one of [first] as its first dart, followed by a
  /// dart that may come after it ([dartsAfter])? 88 is T20 S14 D7, not T20 S4
  /// D12 - but T20 S16 D6 stays, as it can start with S16 (S16 leaves 72, then
  /// T20 D6).
  bool _canStart(int target, CheckoutRoute route, Set<DartThrow> first) {
    for (final (a, b) in _setupOrders(route)) {
      if (!first.contains(a)) continue;
      final after = dartsAfter(target, a);
      if (after.isEmpty || after.contains(b)) return true;
    }
    return false;
  }

  /// The routes of the older three-dart rules: the two setup darts of one aim
  /// ([AimPairs.threeDartRoutes]), the single and the triple of one number
  /// ([AimPairs.sameNumberThreeDartRoutes]) and the [_followUps].
  List<CheckoutRoute> _olderThreeDartRoutes(int target) {
    final routes = <CheckoutRoute>[];
    for (final route in [
      ...AimPairs.threeDartRoutes(target),
      ...AimPairs.sameNumberThreeDartRoutes(target),
      ..._followUps(target),
    ]) {
      if (!routes.any(route.isEquivalentTo)) routes.add(route);
    }
    return routes;
  }

  /// Both orders of a three-dart route's two setup darts.
  static List<(DartThrow, DartThrow)> _setupOrders(CheckoutRoute route) {
    final setup = route.setupDarts.toList();
    if (setup.length != 2) return const [];
    return [(setup[0], setup[1]), (setup[1], setup[0])];
  }

  /// Every route that starts with the single or the triple of one of [aims],
  /// followed by an optimal two-dart route of what is left (68: S14 S14 D20,
  /// T14 S10 D8 ...).
  List<CheckoutRoute> _aimFirstRoutes(int target, List<int> aims) {
    final routes = <CheckoutRoute>[];
    void add(DartThrow first) {
      for (final rest in _twoDartsAfterFirst(target - first.score)) {
        final full = CheckoutRoute([first, ...rest.darts]).normalized;
        if (!routes.any(full.isEquivalentTo)) routes.add(full);
      }
    }

    for (final n in aims) {
      final single = DartThrow(Multiplier.single, n);
      final treble = DartThrow(Multiplier.treble, n);
      // A triple with a backup goes first: 88 starts with T20 S14 D7.
      final backup = AimPairs.missedDoubleRoute(target - treble.score) != null;
      add(backup ? treble : single);
      add(backup ? single : treble);
    }
    return routes;
  }

  /// The lowest single a three-dart follow-up route starts with (S15 to S20).
  static const int followUpLowestSingle = 15;

  /// A first dart whose two possible hits each leave a finish, and the same
  /// better double twice: the aim routes of two darts (see [AimPairs]).
  List<CheckoutRoute> _aimRoutes(int target) => [
        ...AimPairs.twoDartRoutes(target),
        ...AimPairs.sameNumberRoutes(target),
        ...AimPairs.neighbourSingleRoutes(target),
        if (AimPairs.sameDoubleTwice(target) case final twice?) twice,
      ];

  /// A two-dart number played with three darts is also optimal when the first
  /// dart is a single that leaves a number with a two-dart finish, and the last
  /// two darts are an optimal route of that number with two darts: 93 with S19
  /// leaves 74, whose T20 D7 gives S19 T20 D7. Only the high singles S15 to S20
  /// start one (with every single, 97 had 50 of them and 61 over a hundred).
  /// Biggest single first.
  List<CheckoutRoute> _followUps(int target) {
    final routes = <CheckoutRoute>[];
    for (var n = DartThrow.maxBoardNumber; n >= followUpLowestSingle; n--) {
      final left = target - n;
      if (!_engine.canCheckoutIn(left, 2)) continue;
      for (final route in _twoDartsAfterFirst(left)) {
        final full = CheckoutRoute([DartThrow(Multiplier.single, n), ...route.darts]).normalized;
        if (!routes.any(full.isEquivalentTo)) routes.add(full);
      }
    }
    return routes;
  }

  /// What may follow the first of three darts over 60 with [left] to go: its
  /// routes with two darts, the older ones for a two-dart number.
  List<CheckoutRoute> _twoDartsAfterFirst(int left) =>
      _engine.minimumDarts(left) == 2 ? _olderTwoDartRoutes(left) : optimalRoutesIn(left, 2);

  /// True when [target] is a two-dart number over 60 that can also be played
  /// with three darts.
  bool hasThreeDartOption(int target) =>
      _engine.minimumDarts(target) == 2 &&
      target > AimPairs.threeDartAbove &&
      optimalRoutesIn(target, 3).isNotEmpty;

  /// True when [target] is a two-dart number under 60 that can be played with
  /// three darts, by choice, in Checkout practice and Checkout input.
  bool hasPracticeThreeDartOption(int target) =>
      target < AimPairs.threeDartAbove &&
      threeDartAims(target).isNotEmpty &&
      _engine.canCheckoutIn(target, 3);

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
    return _cache.putIfAbsent(target, () {
      final byRule = minimum == 2 ? _twoDartRuleRoutes(target) : const <CheckoutRoute>[];
      return List.unmodifiable(byRule.isEmpty ? _compute(target, minimum) : byRule);
    });
  }

  /// A two-dart number up to 70 has one rule: [AimPairs.goodSingleRoutes] up to
  /// 60, with a standard route first when it is one of them, and the bull-safe
  /// finish on 61 to 70. Empty for any other number.
  List<CheckoutRoute> _twoDartRuleRoutes(int target) {
    if (target > AimPairs.maxGoodSingleTarget) {
      return target > BullSafeFinish.maxRemaining ? const [] : BullSafeFinish.twoDartRoutes(target);
    }
    final rule = AimPairs.goodSingleRoutes(target);
    final routes = <CheckoutRoute>[];
    for (final route in [..._standardRoutes(target).where((r) => rule.any(r.isEquivalentTo)), ...rule]) {
      if (!routes.any(route.isEquivalentTo)) routes.add(route);
    }
    return routes;
  }

  /// The routes of a two-dart number by the rules that come before the ones up
  /// to 70 ([_twoDartRuleRoutes]). What follows the first of three darts over 60
  /// still goes by these (74: S20 T10 D12).
  List<CheckoutRoute> _olderTwoDartRoutes(int target) =>
      _cacheOlder.putIfAbsent(target, () => List.unmodifiable(_compute(target, 2)));

  /// The standard routes of [target]: the chart's, then the site's first choices.
  List<CheckoutRoute> _standardRoutes(int target) {
    final chart = _chartRoute(target);
    return [
      if (chart != null) chart,
      for (final text in _siteThrows[target] ?? const <String>[])
        CheckoutRoute.parse(text),
    ];
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
    final standard = _standardRoutes(target);
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
      _aimRoutes(target).forEach((route) => add(route, force: true));
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
