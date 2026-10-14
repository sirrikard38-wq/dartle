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
    // The numbers in range that no checkout exists for (159, 162, ...).
    for (var n = CheckoutEngine.minCheckout; n <= CheckoutEngine.maxCheckout; n++) {
      if (!engine.isCheckoutable(n)) _impossible.add(Challenge.noCheckout(n));
    }
  }

  final OptimalRouteService _optimal;
  final List<Challenge> _all = [];
  final List<Challenge> _impossible = [];
  final Map<DifficultyLevel, List<Challenge>> _byLevel = {};

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

  /// [base] played with [layout] boxes used. Its reference route is the optimal
  /// one for the darts that are free, which can differ: on 51 to 70 with the
  /// right box used the ordinary route applies, not the bull-safe one.
  Challenge dealt(Challenge base, BoxLayout layout) {
    if (!base.hasCheckout) return base;
    final route = _optimal.optimalRoute(base.target, twoDartBullSafe: layout.bullSafe)!;
    return base.dealt(layout, route);
  }
}
