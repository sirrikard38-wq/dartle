import '../board/board_geometry.dart';
import 'checkout_route.dart';
import 'checkout_table.dart';
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

    // Why not: a target that is not lit, whose hit checks out as well, but whose
    // miss leaves fewer checkouts than the aim's miss does. None when there is
    // no such target.
    DartThrow? whyNot;
    if (routes.isNotEmpty) {
      int kept(List<DartOutcome> outcomes) => outcomes.where((o) => o.hasCheckout).length;
      final aimKept = aims.length == 1 ? kept(misses) : 2;
      final tempting = [
        for (final dart in _candidates)
          if (!lit.contains(dart) && outcome(target, darts, dart).hasCheckout) dart,
      ];
      int rank(DartThrow dart) => dart.multiplier == aims.first.multiplier ? 0 : 1;
      tempting.sort((a, b) {
        final byKind = rank(a).compareTo(rank(b));
        return byKind != 0 ? byKind : b.score.compareTo(a.score);
      });
      for (final dart in tempting) {
        final theirs = [for (final miss in missesOf(dart)) outcome(target, darts, miss)];
        if (theirs.isNotEmpty && kept(theirs) < aimKept) {
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
