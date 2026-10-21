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

  /// Only a two-dart number above this can be played with three darts.
  static const int threeDartAbove = 40;

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
