import 'dart:math';

import 'checkout_route.dart';
import 'difficulty.dart';

/// A visit is always three darts. Checkout calculator shows three boxes every
/// time; the boxes of darts that are "already thrown" are blurred out and
/// cannot be used, which tells the player how many darts are left.
abstract final class Visit {
  static const int darts = 3;

  /// How many of the three darts are still free for a number that needs
  /// [fewestDarts] at the least:
  ///
  ///  * 1 dart: always 1 (the first two boxes are blurred);
  ///  * 2 darts: half the time 2 (the first box is blurred), half the time all 3;
  ///  * 3 darts: all 3.
  static int dartsLeft(int fewestDarts, Random random) => switch (fewestDarts) {
        <= 1 => 1,
        2 => random.nextBool() ? 2 : 3,
        _ => darts,
      };
}

/// One playable checkout. By construction it always has a legal solution.
final class Challenge {
  const Challenge({
    required this.target,
    required this.optimalRoute,
    required this.difficulty,
    required this.complexity,
    int? fewestDarts,
    int? dartsLeft,
  })  : _fewestDarts = fewestDarts,
        _dartsLeft = dartsLeft;

  final int target;

  /// The reference solution for the darts the player has. Usually it is a
  /// fewest-darts route; with a spare dart on 51 to 70 it is a three-dart
  /// single, single, double route (see `OptimalRouteService`).
  final CheckoutRoute optimalRoute;
  final DifficultyLevel difficulty;
  final int complexity;

  final int? _fewestDarts;
  final int? _dartsLeft;

  /// The fewest darts that can check [target] out.
  int get dartCount => _fewestDarts ?? optimalRoute.length;

  /// How many of the visit's three darts are free to use. Defaults to the
  /// fewest darts needed (no spare dart).
  int get dartsLeft => _dartsLeft ?? dartCount;

  /// Darts already thrown this visit: this many boxes, from the left, are
  /// blurred out and unusable.
  int get alreadyThrown => Visit.darts - dartsLeft;

  /// The same checkout with [left] darts free and [route] as its reference.
  Challenge dealt(int left, CheckoutRoute route) => Challenge(
        target: target,
        optimalRoute: route,
        difficulty: difficulty,
        complexity: complexity,
        fewestDarts: dartCount,
        dartsLeft: left,
      );

  @override
  bool operator ==(Object other) =>
      other is Challenge && other.target == target && other.dartCount == dartCount;

  @override
  int get hashCode => Object.hash(target, dartCount);
}
