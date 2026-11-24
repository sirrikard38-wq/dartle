/// The three ways to play.
enum GameMode {
  calculator(
    'Checkout calculator',
    'Fill the boxes with the optimal checkout for the darts you have left.',
  ),
  choice(
    'Checkout choice',
    'Choose your own optimal route.',
  );

  const GameMode(this.label, this.blurb);

  final String label;
  final String blurb;

  /// Checkout choice: you choose your own darts, the best ones are lit up,
  /// and there is no clock and no score.
  bool get isPractice => this != GameMode.calculator;

  /// Only Checkout calculator is against the clock.
  bool get isTimed => this == GameMode.calculator;

  /// Only Checkout calculator is scored.
  bool get hasScore => this == GameMode.calculator;

  /// Only Checkout calculator plays the celebration sound.
  bool get hasSound => this == GameMode.calculator;

  /// Only Checkout calculator is saved (statistics). The
  /// other mode is just for learning.
  bool get isRecorded => this == GameMode.calculator;

  /// Only Checkout calculator limits undo (3 per session) and has the
  /// "No checkout" button.
  bool get isChallenge => this == GameMode.calculator;
}
