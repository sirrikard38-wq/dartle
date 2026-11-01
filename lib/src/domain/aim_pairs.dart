import '../board/board_geometry.dart';
import 'better_doubles.dart';
import 'checkout_route.dart';
import 'dart_throw.dart';

/// One place to aim at and the two darts it can turn into: the single and the
/// triple of a number (S11 or T11), or two neighbours on the board, each a
/// single or a triple (aiming where 16 and 8 meet you hit S16 or S8, T16 or T8,
/// or one of each).
final class Aim {
  const Aim(this.first, this.second);

  final DartThrow first;
  final DartThrow second;

  @override
  String toString() => '${first.notation}/${second.notation}';
}

/// The "aim" routes: darts you can aim at knowing that either of the two
/// possible hits still leaves a checkout.
///
///  * Two darts left: the first dart is an [Aim] and each of its two hits leaves
///    one dart to finish. 43: S11 leaves D16 and T11 leaves D5, so T11 D5 and
///    S11 D16; 64: T16 leaves D8 and T8 leaves D20.
///  * Three darts on a two-dart number over 40: the two setup darts are the two
///    hits of one aim - neighbours (64: S8 S16 D20), the single and the triple
///    of a number, or the same number twice (64: S16 S16 D16) - and the third
///    dart is the double.
///
/// The better doubles decide which aims count: when some aims leave a better
/// double whatever is hit, only those are used; otherwise the aims where at
/// least one hit leaves a better double; otherwise all of them.
abstract final class AimPairs {
  /// The lowest two-dart number the two-dart aims are used for.
  static const int minTwoDartTarget = 20;

  /// A two-dart number above this can come with three darts. Below it three
  /// darts are a choice in Checkout practice and Checkout input
  /// ([underSixtyRoutes]). This number itself is only ever two darts.
  static const int threeDartAbove = 60;

  /// The highest two-dart number [goodSingleRoutes] is used for.
  static const int maxGoodSingleTarget = 60;

  /// The two-dart numbers [neighbourSingleRoutes] is used for, 41 to 60.
  static const int minNeighbourSingleTarget = 41;
  static const int maxNeighbourSingleTarget = 60;

  /// True when [a] and [b] are next to each other on the board (20 and 1, 16
  /// and 8, 5 and 20).
  static bool areNeighbours(int a, int b) {
    final i = boardOrder.indexOf(a);
    final j = boardOrder.indexOf(b);
    if (i < 0 || j < 0) return false;
    final gap = (i - j).abs();
    return gap == 1 || gap == boardOrder.length - 1;
  }

  /// Every pair of neighbours once: (20, 1), (1, 18) ... (5, 20).
  static List<(int, int)> get neighbourPairs => [
        for (var i = 0; i < boardOrder.length; i++)
          (boardOrder[i], boardOrder[(i + 1) % boardOrder.length]),
      ];

  static DartThrow _s(int n) => DartThrow(Multiplier.single, n);
  static DartThrow _d(int n) => DartThrow(Multiplier.double, n);
  static DartThrow _t(int n) => DartThrow(Multiplier.treble, n);

  /// The aims for the first of two darts: the single and triple of every
  /// number, and for every pair of neighbours single and single or triple and
  /// triple.
  static final List<Aim> firstDartAims = List.unmodifiable([
    for (var n = 1; n <= DartThrow.maxBoardNumber; n++) Aim(_s(n), _t(n)),
    for (final (a, b) in neighbourPairs) ...[
      Aim(_s(a), _s(b)),
      Aim(_t(a), _t(b)),
    ],
  ]);

  /// The pairs of setup darts for three darts: [firstDartAims], neighbours with
  /// one single and one triple (S8 T16), and the same number twice (S16 S16,
  /// T16 T16).
  static final List<Aim> setupPairs = List.unmodifiable([
    ...firstDartAims,
    for (final (a, b) in neighbourPairs) ...[
      Aim(_s(a), _t(b)),
      Aim(_t(a), _s(b)),
    ],
    for (var n = 1; n <= DartThrow.maxBoardNumber; n++) ...[
      Aim(_s(n), _s(n)),
      Aim(_t(n), _t(n)),
    ],
  ]);

  /// The one dart that finishes [left]: D1 to D20, or the Bull on 50. Null
  /// when no single dart does.
  static DartThrow? finisherFor(int left) {
    if (left == 2 * DartThrow.bullNumber) return DartThrow.bull;
    if (left < 2 || left.isOdd || left > 2 * DartThrow.maxBoardNumber) return null;
    return DartThrow(Multiplier.double, left ~/ 2);
  }

  /// The one dart that finishes [left] when it is a better double. Null when
  /// none does (the Bull is not a better double).
  static DartThrow? _betterFinisherFor(int left) {
    final finisher = finisherFor(left);
    return finisher != null && BetterDoubles.isBetter(finisher) ? finisher : null;
  }

  /// Two darts on a two-dart number up to 60: the first dart is a single that
  /// leaves a better double. When two neighbouring singles both do, only those
  /// count: you aim where they meet. Without such a pair every single that
  /// leaves a better double counts. Then the near misses of those singles: their
  /// triple or double counts when it leaves a better double too.
  ///
  /// 48: S8 and S16 are neighbours, so S16 D16 and S8 D20, with T8 D12, D16 D8
  /// and D8 D16. 58 has no pair: S18 D20, with T18 D2.
  static List<CheckoutRoute> goodSingleRoutes(int target) {
    final singles = [
      for (var n = DartThrow.maxBoardNumber; n >= 1; n--)
        if (_betterFinisherFor(target - n) != null) n,
    ];
    final pairs = [
      for (final n in singles)
        if (singles.any((m) => areNeighbours(n, m))) n,
    ];
    final aims = pairs.isEmpty ? singles : pairs;
    return [
      for (final n in aims) CheckoutRoute([_s(n), _betterFinisherFor(target - n)!]),
      for (final n in aims)
        for (final miss in [_t(n), _d(n)])
          if (_betterFinisherFor(target - miss.score) case final finisher?)
            CheckoutRoute([miss, finisher]),
    ];
  }

  /// True when the triple of [n] and two of its singles each leave a double,
  /// whatever the doubles: on 64, T16 leaves D8 and S16 S16 leaves D16.
  static bool _twoSinglesAndTripleLeaveDoubles(int target, int n) =>
      finisherFor(target - 3 * n) != null && finisherFor(target - 2 * n) != null;

  /// Three darts on a two-dart number under 60: the numbers to aim the first dart
  /// at, biggest first. The triple leaves a double and so does the single (58:
  /// S18 leaves D20, T18 leaves D2), or two of the single (58: S16 S16 leaves
  /// D13, T16 leaves D5).
  static List<int> underSixtyAims(int target) => [
        for (var n = DartThrow.maxBoardNumber; n >= 1; n--)
          if (_twoSinglesAndTripleLeaveDoubles(target, n) ||
              (finisherFor(target - n) != null && finisherFor(target - 3 * n) != null))
            n,
      ];

  /// What to aim at with two darts left on [left] on a number under 60: the
  /// double, and its single when that leaves a double too, so you see what a
  /// miss does (40: D20 and S20). An odd double or the Bull is just itself (26:
  /// D13). Empty for any other number.
  static Set<DartThrow> doubleAndItsSingle(int left) {
    final finisher = finisherFor(left);
    if (finisher == null) return const {};
    return {finisher, ...?missedDoubleRoute(left)?.setupDarts};
  }

  /// The three-dart routes that start with [first]: a dart of the same number
  /// or of a neighbour on the board, at most one triple, then any double. 64
  /// with S16: S16 D16, S8 D20 or T8 D12.
  static List<CheckoutRoute> sameOrNeighbourRoutes(int target, DartThrow first) {
    final routes = <CheckoutRoute>[];
    for (var n = DartThrow.maxBoardNumber; n >= 1; n--) {
      if (n != first.number && !areNeighbours(n, first.number)) continue;
      for (final second in [_s(n), _t(n)]) {
        if (first.isTreble && second.isTreble) continue;
        final finisher = finisherFor(target - first.score - second.score);
        if (finisher != null) routes.add(CheckoutRoute([first, second, finisher]).normalized);
      }
    }
    return routes;
  }

  /// Three darts on a two-dart number over 60: [sameOrNeighbourRoutes] of every
  /// number whose triple and two singles each leave a double (64: 16 has S16 S16
  /// D16, S16 S8 D20, S16 T8 D12 ...). Biggest number first.
  static List<CheckoutRoute> twoSinglesRoutes(int target) => [
        for (var n = DartThrow.maxBoardNumber; n >= 1; n--)
          if (_twoSinglesAndTripleLeaveDoubles(target, n)) ...[
            ...sameOrNeighbourRoutes(target, _s(n)),
            ...sameOrNeighbourRoutes(target, _t(n)),
          ],
      ];

  /// Three darts on a two-dart number under 60, thrown from [underSixtyAims]:
  /// a first dart that leaves a double is followed by that double, even with a
  /// dart left (47: S7 D20), or by its single and the next double when the
  /// double is missed (S7 S20 D10). A single that leaves no double has the
  /// [sameOrNeighbourRoutes] (48: S4 S4 D20). The finishes on a better double
  /// come first, then the other finishes, then the routes of all three darts.
  static List<CheckoutRoute> underSixtyRoutes(int target) {
    final finishes = <CheckoutRoute>[];
    final others = <CheckoutRoute>[];
    for (final n in underSixtyAims(target)) {
      for (final first in [_s(n), _t(n)]) {
        final left = target - first.score;
        final finisher = finisherFor(left);
        if (finisher == null) {
          others.addAll(sameOrNeighbourRoutes(target, first));
          continue;
        }
        finishes.add(CheckoutRoute([first, finisher]));
        if (missedDoubleRoute(left) case final backup?) {
          others.add(CheckoutRoute([first, ...backup.darts]).normalized);
        }
      }
    }
    return _unique([...finishes.where(BetterDoubles.leavesBetterDouble), ...finishes, ...others]);
  }

  /// Two darts left on a double whose single leaves a double too: you aim at
  /// the double, and if you hit its single the next double still finishes. 28
  /// is S14 D7, as D14 missed into S14 leaves D7 (and 88 is T20 S14 D7, not T20
  /// S4 D12). Null for anything else: 14 has no backup (S7 leaves 7), nor has
  /// the Bull.
  static CheckoutRoute? missedDoubleRoute(int left) {
    if (left % 4 != 0) return null;
    final double = finisherFor(left);
    final backup = finisherFor(left ~/ 2);
    if (double == null || backup == null) return null;
    return CheckoutRoute([_s(double.number), backup]);
  }

  /// Two darts left on a double or the Bull: the routes that may follow a triple.
  /// A double with a backup has that one ([missedDoubleRoute]). An odd double or
  /// the Bull has none, so a single sets up a better double: 34 (88 after T18) is
  /// S18 D8, S14 D10, S10 D12, S6 D14 or S2 D16. Empty for any other number.
  static List<CheckoutRoute> twoDartsOnDoubleRoutes(int left) {
    if (finisherFor(left) == null) return const [];
    if (missedDoubleRoute(left) case final backup?) return [backup];
    return [
      for (var n = DartThrow.maxBoardNumber; n >= 1; n--)
        if (finisherFor(left - n) case final finisher? when BetterDoubles.isBetter(finisher))
          CheckoutRoute([_s(n), finisher]),
    ];
  }

  /// Two darts left on [target] (a two-dart number of 20 or more): both routes
  /// of every aim whose two hits each leave a finish, from the best group only
  /// (see the class comment). 43 has T11 D5 and S11 D16; 64 has T16 D8 and T8
  /// D20.
  static List<CheckoutRoute> twoDartRoutes(int target) {
    if (target < minTwoDartTarget) return const [];
    final byBetter = <int, List<CheckoutRoute>>{};
    for (final aim in firstDartAims) {
      final first = finisherFor(target - aim.first.score);
      final second = finisherFor(target - aim.second.score);
      if (first == null || second == null) continue;
      final better = [first, second].where(BetterDoubles.isBetter).length;
      byBetter.putIfAbsent(better, () => [])
        ..add(CheckoutRoute([aim.first, first]))
        ..add(CheckoutRoute([aim.second, second]));
    }
    if (byBetter.isEmpty) return const [];
    final best = byBetter.keys.reduce((a, b) => a > b ? a : b);
    return _unique(byBetter[best]!);
  }

  /// Two darts left on 41 to 60: aim between two neighbouring singles and finish
  /// whichever you hit - both routes of every pair of neighbours whose two
  /// singles each leave a double, whatever the doubles are. 42: 8 and 16 are
  /// neighbours, S8 leaves D17 and S16 leaves D13, so S8 D17 and S16 D13 are
  /// both optimal. Still two darts: a pair of singles is a bigger area to hit
  /// than a triple.
  static List<CheckoutRoute> neighbourSingleRoutes(int target) {
    if (target < minNeighbourSingleTarget || target > maxNeighbourSingleTarget) {
      return const [];
    }
    final routes = <CheckoutRoute>[];
    for (final (a, b) in neighbourPairs) {
      final first = finisherFor(target - a);
      final second = finisherFor(target - b);
      if (first == null || second == null) continue;
      routes
        ..add(CheckoutRoute([_s(a), first]))
        ..add(CheckoutRoute([_s(b), second]));
    }
    return _unique(routes);
  }

  /// The highest two-dart number [sameNumberRoutes] is used for.
  static const int maxSameNumberTarget = 60;

  /// Two darts left on 20 to 60: both routes of the single and the triple of
  /// every number whose two hits each leave a finish, whatever the doubles are
  /// (35: T5 D10 and S5 D15; 52: T14 D5 and S14 D19). These were optimal
  /// before the groups of [twoDartRoutes] came in, and they stay optimal.
  static List<CheckoutRoute> sameNumberRoutes(int target) {
    if (target < minTwoDartTarget || target > maxSameNumberTarget) return const [];
    final routes = <CheckoutRoute>[];
    for (var n = DartThrow.maxBoardNumber; n >= 1; n--) {
      final afterTreble = finisherFor(target - 3 * n);
      final afterSingle = finisherFor(target - n);
      if (afterTreble == null || afterSingle == null) continue;
      routes
        ..add(CheckoutRoute([_t(n), afterTreble]))
        ..add(CheckoutRoute([_s(n), afterSingle]));
    }
    return routes;
  }

  /// The same better double twice, when that is exactly [target]: 64 is D16
  /// D16 (aim at the double you finish on). Null otherwise.
  static CheckoutRoute? sameDoubleTwice(int target) {
    if (target % 4 != 0) return null;
    final number = target ~/ 4;
    if (!BetterDoubles.numbers.contains(number)) return null;
    final dart = DartThrow(Multiplier.double, number);
    return CheckoutRoute([dart, dart]);
  }

  /// Three darts on a two-dart number over 40: the two setup darts of one aim
  /// (or the same number twice) and a double. Only the routes that finish on a
  /// better double when there are any, and of those the ones with the most
  /// singles (a single is far easier to hit than a triple). 64: S8 S16 D20,
  /// S16 S16 D16, S12 S12 D20 ... Routes with the same number as the double
  /// come first (S16 S16 D16), then the neighbours. Empty when there is none.
  static List<CheckoutRoute> threeDartRoutes(int target) {
    if (target <= threeDartAbove) return const [];
    final all = <CheckoutRoute>[];
    for (final pair in setupPairs) {
      final finisher = finisherFor(target - pair.first.score - pair.second.score);
      if (finisher == null) continue;
      all.add(CheckoutRoute([pair.first, pair.second, finisher]).normalized);
    }
    if (all.isEmpty) return const [];
    final better = all.where(BetterDoubles.leavesBetterDouble).toList();
    final pool = better.isEmpty ? all : better;
    int singles(CheckoutRoute r) =>
        r.setupDarts.where((d) => d.multiplier == Multiplier.single).length;
    final most = pool.map(singles).reduce((a, b) => a > b ? a : b);
    final routes = _unique(pool.where((r) => singles(r) == most));
    routes.sort(_threeDartOrder);
    return routes;
  }

  /// Three darts on a two-dart number over 60: the single and the triple of the
  /// same number, then a double, whatever the double is (74: S14 T14 D9, S10
  /// T10 D17 ...). [threeDartRoutes] keeps only the better doubles; these stay
  /// optimal next to them. Biggest number first.
  static List<CheckoutRoute> sameNumberThreeDartRoutes(int target) {
    if (target <= threeDartAbove) return const [];
    final routes = <CheckoutRoute>[];
    for (var n = DartThrow.maxBoardNumber; n >= 1; n--) {
      final finisher = finisherFor(target - 4 * n);
      if (finisher == null) continue;
      routes.add(CheckoutRoute([_s(n), _t(n), finisher]).normalized);
    }
    return routes;
  }

  /// Same number as the double first (S16 S16 D16), then neighbours, then the
  /// rest; within that the bigger double first.
  static int _threeDartOrder(CheckoutRoute a, CheckoutRoute b) {
    int kind(CheckoutRoute r) {
      final finish = r.darts.last.number;
      final numbers = r.setupDarts.map((d) => d.number).toSet();
      if (numbers.length == 1 && numbers.first == finish) return 0;
      if (numbers.length == 2) return 1;
      return 2;
    }

    final byKind = kind(a).compareTo(kind(b));
    if (byKind != 0) return byKind;
    final byDouble = b.darts.last.score.compareTo(a.darts.last.score);
    return byDouble != 0 ? byDouble : a.notation.compareTo(b.notation);
  }

  static List<CheckoutRoute> _unique(Iterable<CheckoutRoute> routes) {
    final result = <CheckoutRoute>[];
    for (final route in routes) {
      if (!result.any(route.isEquivalentTo)) result.add(route);
    }
    return result;
  }
}
