import 'dart:math';

import 'challenge.dart';
import 'checkout_catalog.dart';
import 'difficulty.dart';

/// Picks the next challenge from the catalog, avoiding recent repeats.
class ChallengeGenerator {
  ChallengeGenerator(this._catalog, {Random? random, this.memory = 8})
      : _random = random ?? Random();

  final CheckoutCatalog _catalog;
  final Random _random;

  /// How many recent targets to avoid (capped so small pools still work).
  final int memory;

  final List<int> _recent = [];

  /// Next challenge. With no [level], every checkoutable number has an equal
  /// chance; with a level, only that difficulty band is drawn from.
  ///
  /// With [dealDarts] (Checkout calculator) the visit's three darts are dealt:
  /// some may already be thrown, see [Visit.dartsLeft]. Without it the
  /// challenge has no spare or used darts.
  Challenge next([DifficultyLevel? level, bool dealDarts = true]) {
    final pool = level == null ? _catalog.all : _catalog.forLevel(level);
    if (pool.isEmpty) {
      throw StateError('No checkouts available for ${level?.name ?? 'any level'}');
    }
    final window = min(memory, pool.length - 1);
    final recent = _recent.length <= window
        ? _recent
        : _recent.sublist(_recent.length - window);
    final candidates =
        pool.where((c) => !recent.contains(c.target)).toList(growable: false);
    final choice = candidates[_random.nextInt(candidates.length)];
    _recent.add(choice.target);
    if (!dealDarts) return choice;
    return _catalog.dealt(choice, Visit.dartsLeft(choice.dartCount, _random));
  }

  /// Forget history, e.g. when the player changes difficulty.
  void reset() => _recent.clear();
}
