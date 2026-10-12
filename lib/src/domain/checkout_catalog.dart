import 'challenge.dart';
import 'checkout_engine.dart';
import 'difficulty.dart';
import 'optimal_route_service.dart';

/// Every playable challenge, built once from the engine and optimal routes
/// and bucketed by difficulty. The generator only ever draws from here, which
/// is what guarantees an impossible target/dart-count pair cannot appear.
class CheckoutCatalog {
  CheckoutCatalog(CheckoutEngine engine, this._optimal) {
    for (final target in engine.checkoutableTargets) {
      final route = _optimal.optimalRoute(target)!;
      final complexity = CheckoutComplexity.rate(route);
      final challenge = Challenge(
        target: target,
        optimalRoute: route,
        difficulty: Difficulties.classify(complexity),
        complexity: complexity,
      );
      _all.add(challenge);
      _byLevel.putIfAbsent(challenge.difficulty, () => []).add(challenge);
    }
  }

  final OptimalRouteService _optimal;
  final List<Challenge> _all = [];
  final Map<DifficultyLevel, List<Challenge>> _byLevel = {};

  List<Challenge> get all => List.unmodifiable(_all);

  List<Challenge> forLevel(DifficultyLevel level) =>
      List.unmodifiable(_byLevel[level] ?? const []);

  Challenge? forTarget(int target) {
    for (final c in _all) {
      if (c.target == target) return c;
    }
    return null;
  }

  /// [base] played with [dartsLeft] of the visit's three darts free. Its
  /// reference route is the optimal one for that many darts, which can differ:
  /// on 51 to 70 with all three free it is single, single, double.
  Challenge dealt(Challenge base, int dartsLeft) => base.dealt(
        dartsLeft,
        _optimal.optimalRoute(base.target, dartsLeft: dartsLeft)!,
      );
}
