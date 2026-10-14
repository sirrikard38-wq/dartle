import 'dart:math';

import 'challenge.dart';
import 'checkout_catalog.dart';
import 'difficulty.dart';

/// Who the numbers are drawn for.
enum Deal {
  /// Checkout calculator: every number from 2 to 170 has an equal chance,
  /// including the few that have no checkout.
  calculator,

  /// Checkout practice: numbers that need two or more darts; each one-dart
  /// number has only [ChallengeGenerator.oneDartChancePercent] percent.
  practice,
}

/// Picks the next challenge from the catalog, avoiding recent repeats, and
/// deals which boxes are used.
class ChallengeGenerator {
  ChallengeGenerator(this._catalog, {Random? random, this.memory = 8})
      : _random = random ?? Random();

  /// In practice each one-dart number is drawn with this chance (percent).
  static const double oneDartChancePercent = 1;

  final CheckoutCatalog _catalog;
  final Random _random;

  /// How many recent targets to avoid (capped so small pools still work).
  final int memory;

  final List<int> _recent = [];

  /// Next challenge, with its boxes dealt (see [Visit.deal]). With no [level]
  /// every number has an equal chance (see [Deal]); with a level, only that
  /// difficulty band is drawn from.
  Challenge next([DifficultyLevel? level, Deal deal = Deal.calculator]) {
    final pool = level != null
        ? _catalog.forLevel(level)
        : [..._catalog.all, if (deal == Deal.calculator) ..._catalog.impossible];
    if (pool.isEmpty) {
      throw StateError('No checkouts available for ${level?.name ?? 'any level'}');
    }
    final window = min(memory, pool.length - 1);
    final recent = _recent.length <= window
        ? _recent
        : _recent.sublist(_recent.length - window);
    final candidates =
        pool.where((c) => !recent.contains(c.target)).toList(growable: false);
    final choice = deal == Deal.practice && level == null
        ? _weighted(candidates)
        : candidates[_random.nextInt(candidates.length)];
    _recent.add(choice.target);
    return _deal(choice);
  }

  /// The challenge for a number the player picked, with its boxes dealt. Null
  /// when the number is outside 2 to 170 or cannot be checked out.
  Challenge? forNumber(int target) {
    final base = _catalog.forTarget(target);
    return base == null ? null : _deal(base);
  }

  /// True for a number in 2 to 170 that has no checkout at all.
  bool isImpossible(int target) =>
      _catalog.anyForTarget(target)?.hasCheckout == false;

  Challenge _deal(Challenge base) {
    if (!base.hasCheckout) return base;
    return _catalog.dealt(base, Visit.deal(base.dartCount, base.target, _random));
  }

  /// One-dart numbers get [oneDartChancePercent] each; the rest share what is
  /// left equally.
  Challenge _weighted(List<Challenge> candidates) {
    final oneDart = _catalog.all.where((c) => c.dartCount == 1).length;
    final others = _catalog.all.length - oneDart;
    final otherWeight = (100 - oneDart * oneDartChancePercent) / others;
    double weight(Challenge c) => c.dartCount == 1 ? oneDartChancePercent : otherWeight;
    final total = candidates.fold<double>(0, (sum, c) => sum + weight(c));
    var pick = _random.nextDouble() * total;
    for (final c in candidates) {
      pick -= weight(c);
      if (pick < 0) return c;
    }
    return candidates.last;
  }

  /// Forget history, e.g. when the player changes difficulty.
  void reset() => _recent.clear();
}
