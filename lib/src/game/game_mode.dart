/// The two ways to play.
enum GameMode {
  calculator(
    'Checkout calculator',
    'A number and one box per dart. Fill them with the best checkout.',
  ),
  choice(
    'Checkout practice',
    'Pick your own darts one at a time. The fewest darts wins.',
  );

  const GameMode(this.label, this.blurb);

  final String label;
  final String blurb;

  /// Checkout calculator is against the clock; Checkout practice has no timer,
  /// no speed bonus and no overtime penalty.
  bool get isTimed => this == GameMode.calculator;

  /// Only Checkout calculator is scored. Checkout practice has no points at
  /// all: nothing is won or lost and the session score is untouched.
  bool get hasScore => this == GameMode.calculator;

  /// The celebration sound plays in Checkout calculator only. Checkout practice
  /// (the practice mode) is silent and has no sound button.
  bool get hasSound => this == GameMode.calculator;
}
