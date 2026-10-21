import 'challenge.dart';
import 'checkout_engine.dart';
import 'difficulty.dart';
import 'optimal_route_service.dart';

/// Every playable challenge, built once from the engine and optimal routes
/// and bucketed by difficulty. The generator only ever draws from here, which
/// is what guarantees an impossible target/dart-count pair cannot appear.
class CheckoutCatalog {
  CheckoutCatalog(CheckoutEngine engine, OptimalRouteService optimal) {
    for (final target in engine.checkoutableTargets) {
      final route = optimal.optimalRoute(target)!;
      final complexity = CheckoutComplexity.rate(route);
      final challenge = Challenge(
        target: target,
        optimalRoute: route,
        difficulty: Difficulties.classify(complexity),
        complexity: complexity,
      );
      _all.add(challenge);
      _byLevel.putIfAbsent(challenge.difficulty, () => []).add(challenge);
      // A two-dart number over 40 can also be played with three darts.
      if (optimal.hasThreeDartOption(target)) {
        _threeDart[target] = challenge.withDarts(3, optimal.optimalRoutesIn(target, 3).first);
      }
    }
    // The numbers in range that no checkout exists for (159, 162, ...).
    for (var n = CheckoutEngine.minCheckout; n <= CheckoutEngine.maxCheckout; n++) {
      if (!engine.isCheckoutable(n)) _impossible.add(Challenge.noCheckout(n));
    }
  }

  final List<Challenge> _all = [];
  final List<Challenge> _impossible = [];
  final Map<DifficultyLevel, List<Challenge>> _byLevel = {};
  final Map<int, Challenge> _threeDart = {};

  /// The three-dart version of a two-dart number over 40 (null when it has
  /// none).
  Challenge? threeDartFor(int target) => _threeDart[target];

  /// [challenge]'s number played with the other number of darts it allows:
  /// three darts for a two-dart number that has them, and back. Null when
  /// there is no other choice.
  Challenge? otherDarts(Challenge challenge) =>
      challenge.hasExtraDart ? forTarget(challenge.target) : threeDartFor(challenge.target);

  /// Every number that can be checked out.
  List<Challenge> get all => List.unmodifiable(_all);

  /// The numbers from 2 to 170 that cannot be checked out.
  List<Challenge> get impossible => List.unmodifiable(_impossible);

  List<Challenge> forLevel(DifficultyLevel level) =>
      List.unmodifiable(_byLevel[level] ?? const []);

  /// The challenge for a number that can be checked out (null otherwise).
  Challenge? forTarget(int target) {
    for (final c in _all) {
      if (c.target == target) return c;
    }
    return null;
  }

  /// The challenge for any number from 2 to 170, including the impossible
  /// ones; null outside that range.
  Challenge? anyForTarget(int target) {
    for (final c in _impossible) {
      if (c.target == target) return c;
    }
    return forTarget(target);
  }
}
