import 'checkout_route.dart';
import 'difficulty.dart';

/// One playable checkout. By construction it always has a legal solution.
final class Challenge {
  const Challenge({
    required this.target,
    required this.optimalRoute,
    required this.difficulty,
    required this.complexity,
  });

  final int target;

  /// Reference solution. Its length is the number of boxes shown.
  final CheckoutRoute optimalRoute;
  final DifficultyLevel difficulty;
  final int complexity;

  int get dartCount => optimalRoute.length;

  @override
  bool operator ==(Object other) =>
      other is Challenge && other.target == target && other.dartCount == dartCount;

  @override
  int get hashCode => Object.hash(target, dartCount);
}
