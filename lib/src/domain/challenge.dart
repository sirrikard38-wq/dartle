import 'dart:math';

import 'checkout_route.dart';
import 'difficulty.dart';

/// Which of the three boxes are "already used" (crossed out). A visit is always
/// three darts; the crossed boxes are darts that were already thrown, so only
/// the other boxes can be filled. The last free box is always the finishing
/// double.
enum BoxLayout {
  /// Nothing used: all three darts are free (a three-dart checkout).
  all(<int>{}),

  /// The first dart is used; the finish is in the right box. For 51 to 70 the
  /// player must aim for the bull-safe route (see `BullSafeFinish`).
  leftUsed(<int>{0}),

  /// The last box is used; the darts go in the left and middle boxes. The
  /// ordinary best route applies (single, then a double).
  rightUsed(<int>{2}),

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

  /// False only when the last box is used: then the ordinary best route
  /// applies instead of the bull-safe one.
  bool get bullSafe => this != rightUsed;

  /// The layout a number gets when nothing is dealt: just enough free boxes.
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

  /// The two-dart numbers that are dealt either way round (left or right box
  /// used): over 50, up to 70.
  static const int splitMin = 51;
  static const int splitMax = 70;

  /// Which boxes are used for a number that needs [fewestDarts] at the least:
  ///
  ///  * 1 dart: the first two boxes;
  ///  * 2 darts, 51 to 70: half the time the left box, half the time the right;
  ///  * any other 2-dart number: the left box;
  ///  * 3 darts: none.
  static BoxLayout deal(int fewestDarts, int target, Random random) {
    if (fewestDarts <= 1) return BoxLayout.leftTwoUsed;
    if (fewestDarts == 2) {
      final split = target >= splitMin && target <= splitMax;
      return split && random.nextBool() ? BoxLayout.rightUsed : BoxLayout.leftUsed;
    }
    return BoxLayout.all;
  }
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
    BoxLayout? layout,
    this.hasCheckout = true,
  })  : _fewestDarts = fewestDarts,
        _layout = layout;

  /// A number with no checkout (159, 162, 163, 165, 166, 168, 169): all three
  /// darts are free, and the right answer is "No checkout".
  factory Challenge.noCheckout(int target) => Challenge(
        target: target,
        optimalRoute: CheckoutRoute(const []),
        difficulty: DifficultyLevel.easy,
        complexity: 0,
        fewestDarts: 0,
        layout: BoxLayout.all,
        hasCheckout: false,
      );

  final int target;

  /// The primary optimal route for the boxes that are free (empty when
  /// there is no checkout).
  final CheckoutRoute optimalRoute;
  final DifficultyLevel difficulty;
  final int complexity;
  final bool hasCheckout;

  final int? _fewestDarts;
  final BoxLayout? _layout;

  /// The fewest darts that can check [target] out (0 when impossible).
  int get dartCount => _fewestDarts ?? optimalRoute.length;

  /// Which boxes are used. Defaults to just enough free boxes.
  BoxLayout get layout => _layout ?? BoxLayout.defaultFor(dartCount);

  /// How many darts can still be thrown.
  int get dartsLeft => layout.freeCount;

  /// The same number with [boxes] crossed out and [route] as its reference.
  Challenge dealt(BoxLayout boxes, CheckoutRoute route) => Challenge(
        target: target,
        optimalRoute: route,
        difficulty: difficulty,
        complexity: complexity,
        fewestDarts: dartCount,
        layout: boxes,
        hasCheckout: hasCheckout,
      );

  @override
  bool operator ==(Object other) =>
      other is Challenge &&
      other.target == target &&
      other.dartCount == dartCount &&
      other.layout == layout;

  @override
  int get hashCode => Object.hash(target, dartCount, layout);
}
