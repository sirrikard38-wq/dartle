import 'checkout_route.dart';
import 'difficulty.dart';

/// Which of the three boxes are "already used" (crossed out). A visit is always
/// three darts; the crossed boxes are darts that were already thrown, so only
/// the other boxes can be filled. The last free box is always the finishing
/// double.
///
/// The layout follows from the darts a number is played with - the fewest it
/// needs, or three for a two-dart number over 40 that comes with three:
///
///  * 1 dart: the first two boxes are used ([leftTwoUsed]);
///  * 2 darts: the left box is used ([leftUsed]);
///  * 3 darts: none ([all]).
enum BoxLayout {
  /// Nothing used: all three darts are free (a three-dart checkout).
  all(<int>{}),

  /// The first dart is used; the finish is in the right box (a two-dart
  /// checkout). For 51 to 70 the bull-safe route is the optimal one (see
  /// `BullSafeFinish`).
  leftUsed(<int>{0}),

  /// A one-dart checkout: the first two boxes are used.
  leftTwoUsed(<int>{0, 1});

  const BoxLayout(this.used);

  final Set<int> used;

  bool isUsed(int box) => used.contains(box);

  /// The boxes that can be filled, left to right.
  List<int> get free => [
        for (var i = 0; i < Visit.darts; i++)
          if (!used.contains(i)) i,
      ];

  int get freeCount => Visit.darts - used.length;

  /// The boxes used for a number that needs [fewestDarts] at the least (all
  /// three are free when there is no checkout).
  static BoxLayout defaultFor(int fewestDarts) => switch (fewestDarts) {
        1 => leftTwoUsed,
        2 => leftUsed,
        _ => all,
      };
}

/// A visit is always three darts. Checkout calculator shows three boxes every
/// time; the boxes of darts that are already used are crossed out.
abstract final class Visit {
  static const int darts = 3;
}

/// One playable number. Normally it has a legal solution; a few numbers
/// ([hasCheckout] false) cannot be checked out at all.
final class Challenge {
  const Challenge({
    required this.target,
    required this.optimalRoute,
    required this.difficulty,
    required this.complexity,
    int? fewestDarts,
    int? darts,
    this.hasCheckout = true,
  })  : _fewestDarts = fewestDarts,
        _darts = darts;

  /// A number with no checkout (159, 162, 163, 165, 166, 168, 169): all three
  /// darts are free, and the right answer is "No checkout".
  factory Challenge.noCheckout(int target) => Challenge(
        target: target,
        optimalRoute: CheckoutRoute(const []),
        difficulty: DifficultyLevel.easy,
        complexity: 0,
        fewestDarts: 0,
        hasCheckout: false,
      );

  final int target;

  /// The primary optimal route (empty when there is no checkout).
  final CheckoutRoute optimalRoute;
  final DifficultyLevel difficulty;
  final int complexity;
  final bool hasCheckout;

  final int? _fewestDarts;
  final int? _darts;

  /// The fewest darts that can check [target] out (0 when impossible).
  int get dartCount => _fewestDarts ?? optimalRoute.length;

  /// How many darts this checkout is played with, all of which have to be
  /// used: normally the fewest, but a two-dart number over 40 can come with
  /// three.
  int get darts => _darts ?? dartCount;

  /// True when it is played with more darts than it needs (a two-dart number
  /// with three darts).
  bool get hasExtraDart => darts > dartCount;

  /// Which boxes are used.
  BoxLayout get layout => BoxLayout.defaultFor(darts);

  /// How many darts can still be thrown.
  int get dartsLeft => layout.freeCount;

  /// The same number played with [darts] darts, [optimalRoute] being its first
  /// optimal route with that many.
  Challenge withDarts(int darts, CheckoutRoute optimalRoute) => Challenge(
        target: target,
        optimalRoute: optimalRoute,
        difficulty: difficulty,
        complexity: complexity,
        fewestDarts: dartCount,
        darts: darts,
        hasCheckout: hasCheckout,
      );

  @override
  bool operator ==(Object other) =>
      other is Challenge &&
      other.target == target &&
      other.dartCount == dartCount &&
      other.darts == darts;

  @override
  int get hashCode => Object.hash(target, dartCount, darts);
}
