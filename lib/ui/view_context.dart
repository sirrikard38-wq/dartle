import 'dart:math' as math;

import '../dartle.dart';

/// The pages shown while the game phase is `menu` (i.e. away from a checkout).
enum MenuPage { welcome, home, modes, stats, leaderboard }

/// How darts are entered. Kept as an enum so more looks can be added.
enum InputView {
  board('Board'),
  keys('Keys');

  const InputView(this.label);
  final String label;
}

/// What every screen builder needs from the app shell.
class ViewContext {
  ViewContext({
    required this.game,
    required this.rerender,
    required this.showPage,
    required this.giveUp,
    required this.keepFocus,
    required this.toast,
    required this.setInputView,
    this.inputView = InputView.board,
  });

  final GameController game;
  final void Function() rerender;
  final void Function(MenuPage page) showPage;

  /// Give up: records the skipped attempt, then shows the leaderboard. Closing
  /// the leaderboard goes back to the menu.
  final Future<void> Function() giveUp;

  /// Restore focus to the element with this `data-focus` key after the next
  /// render (keyboard users only).
  final void Function(String? key) keepFocus;

  /// Short message at the top of the screen.
  final void Function(String message) toast;

  /// Switches (and remembers) the input look.
  final void Function(InputView view) setInputView;

  InputView inputView;
  LeaderboardSort leaderboardSort = LeaderboardSort.points;

  /// Multiplier the player explicitly picked for non-final darts; null means
  /// "single". It stays selected across darts until changed.
  Multiplier? pickedMultiplier;

  /// Where each entered dart landed on the board, aligned with
  /// `game.entered`. An entry is null when the dart was not entered by
  /// tapping the board (keypad, keyboard); its mark is drawn mid-segment.
  final List<BoardPoint?> marks = [];

  /// Randomness for placing repeated darts side by side. Positions are stored
  /// in [marks] when a dart is entered, so they never change on a re-render.
  final math.Random random = math.Random();

  /// Keeps [marks] the same length as the darts entered (e.g. after undo,
  /// clear or a new checkout).
  void syncMarks() {
    final count = game.entered.length;
    while (marks.length > count) {
      marks.removeLast();
    }
    while (marks.length < count) {
      marks.add(null);
    }
  }

  /// True when the next dart is the last box - which must be a double. Only in
  /// Checkout calculator; in Checkout practice you pick every dart freely.
  bool get isFinalBox {
    final challenge = game.challenge;
    return challenge != null &&
        game.mode == GameMode.calculator &&
        game.entered.length == challenge.dartsLeft - 1;
  }

  /// The multiplier the input applies right now. The finishing dart is always
  /// a double, so it is forced; earlier darts use the sticky choice.
  Multiplier activeMultiplier() =>
      isFinalBox ? Multiplier.double : (pickedMultiplier ?? Multiplier.single);
}
