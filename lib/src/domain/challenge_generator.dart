import 'dart:math';

import 'challenge.dart';
import 'checkout_catalog.dart';
import 'difficulty.dart';

/// Who the numbers are drawn for.
enum Deal {
  /// Checkout calculator: every number from 2 to 170, including the few that
  /// have no checkout. All the one-dart numbers together have
  /// [ChallengeGenerator.calculatorOneDartTotalPercent] percent; all the
  /// others share the rest (98%) equally.
  calculator,

  /// Checkout practice: numbers that need two or more darts; each one-dart
  /// number has only [ChallengeGenerator.oneDartChancePercent] percent.
  practice,
}

/// Picks the next challenge from the catalog, avoiding recent repeats.
class ChallengeGenerator {
  ChallengeGenerator(this._catalog, {Random? random, this.memory = 8})
      : _random = random ?? Random();

  /// In practice each one-dart number is drawn with this chance (percent).
  static const double oneDartChancePercent = 1;

  /// In the calculator all the one-dart numbers together are drawn with this
  /// chance (percent), shared equally between them.
  static const double calculatorOneDartTotalPercent = 2;

  final CheckoutCatalog _catalog;
  final Random _random;

  /// How many recent targets to avoid (capped so small pools still work).
  final int memory;

  final List<int> _recent = [];

  /// Next challenge. With no [level] the numbers are weighted as [Deal] says;
  /// with a level, only that difficulty band is drawn from, all equally.
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
    final choice = level == null
        ? _weighted(pool, candidates, _oneDartPercentEach(pool, deal))
        : candidates[_random.nextInt(candidates.length)];
    _recent.add(choice.target);
    return choice;
  }

  /// The challenge for a number the player picked. Null when the number is
  /// outside 2 to 170 or cannot be checked out.
  Challenge? forNumber(int target) => _catalog.forTarget(target);

  /// True for a number in 2 to 170 that has no checkout at all.
  bool isImpossible(int target) =>
      _catalog.anyForTarget(target)?.hasCheckout == false;

  /// What each one-dart number of [pool] gets (percent): in the calculator the
  /// total share split between them, in practice a fixed amount each.
  static double _oneDartPercentEach(List<Challenge> pool, Deal deal) {
    final oneDart = pool.where((c) => c.dartCount == 1).length;
    if (oneDart == 0) return 0;
    return switch (deal) {
      Deal.calculator => calculatorOneDartTotalPercent / oneDart,
      Deal.practice => oneDartChancePercent,
    };
  }

  /// One-dart numbers get [oneDartEach] percent each; the rest of [pool] shares
  /// what is left equally. Only [candidates] (the pool without the recent
  /// numbers) can be picked.
  Challenge _weighted(List<Challenge> pool, List<Challenge> candidates, double oneDartEach) {
    final oneDart = pool.where((c) => c.dartCount == 1).length;
    final others = pool.length - oneDart;
    final otherWeight = (100 - oneDart * oneDartEach) / others;
    double weight(Challenge c) => c.dartCount == 1 ? oneDartEach : otherWeight;
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
