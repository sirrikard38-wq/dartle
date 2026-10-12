import 'checkout_route.dart';

enum DifficultyLevel { easy, medium, hard }

/// Data describing one difficulty level. The UI and scoring read this; nothing
/// else hardcodes difficulty behaviour.
class DifficultyConfig {
  const DifficultyConfig({
    required this.level,
    required this.label,
    required this.description,
    required this.minComplexity,
    required this.maxComplexity,
    required this.bonusPercent,
  });

  final DifficultyLevel level;
  final String label;
  final String description;

  /// Inclusive complexity band (see [CheckoutComplexity]) this level draws from.
  final int minComplexity;
  final int maxComplexity;

  /// Extra points, as a percentage of base score, awarded on this level.
  final int bonusPercent;

  bool includes(int complexity) =>
      complexity >= minComplexity && complexity <= maxComplexity;
}

/// Rates how hard an optimal route is to *know*. Higher = harder.
///
///   (darts - 1)         each extra dart adds a step to remember
/// + trebles             each treble is a harder, less obvious set-up
/// + 1 if bull is used   bull routes are non-intuitive (e.g. 82, 107)
/// + 1 if target >= 100  big numbers need real chart knowledge
abstract final class CheckoutComplexity {
  static const int bigTargetThreshold = 100;

  static int rate(CheckoutRoute optimal) =>
      (optimal.length - 1) +
      optimal.trebleCount +
      (optimal.usesBull ? 1 : 0) +
      (optimal.total >= bigTargetThreshold ? 1 : 0);
}

abstract final class Difficulties {
  static const List<DifficultyConfig> all = [
    DifficultyConfig(
      level: DifficultyLevel.easy,
      label: 'Easy',
      description: 'Common doubles and simple single + double finishes.',
      minComplexity: 0,
      maxComplexity: 1,
      bonusPercent: 0,
    ),
    DifficultyConfig(
      level: DifficultyLevel.medium,
      label: 'Medium',
      description: 'Treble + double routes and standard three-dart finishes.',
      minComplexity: 2,
      maxComplexity: 4,
      bonusPercent: 50,
    ),
    DifficultyConfig(
      level: DifficultyLevel.hard,
      label: 'Hard',
      description: 'Big checkouts that demand exact chart knowledge.',
      minComplexity: 5,
      maxComplexity: 99,
      bonusPercent: 150,
    ),
  ];

  static DifficultyConfig of(DifficultyLevel level) =>
      all.firstWhere((c) => c.level == level);

  /// The level whose band contains [complexity].
  static DifficultyLevel classify(int complexity) =>
      all.firstWhere((c) => c.includes(complexity)).level;
}
