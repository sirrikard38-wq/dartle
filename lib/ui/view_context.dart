import 'dart:math' as math;

import '../dartle.dart';

/// The pages shown while the game phase is `menu` (i.e. away from a checkout).
enum MenuPage { welcome, home, favorites, leaderboard, tutorial, felga }

/// What every screen builder needs from the app shell.
class ViewContext {
  ViewContext({
    required this.game,
    required this.rerender,
    required this.showPage,
    required this.keepFocus,
    required this.toast,
  });

  final GameController game;
  final void Function() rerender;
  final void Function(MenuPage page) showPage;

  /// Restore focus to the element with this `data-focus` key after the next
  /// render (keyboard users only).
  final void Function(String? key) keepFocus;

  /// Short message at the top of the screen ([low]: near its foot; [at]: with
  /// its middle on that point of the screen, no wider than [at]'s width).
  final void Function(String message, {bool low, ({double x, double y, double width})? at}) toast;

  /// Multiplier the player explicitly picked for non-final darts; null means
  /// "single". It stays selected across darts until changed.
  Multiplier? pickedMultiplier;

  /// Checkout choice's parts (the part showing, the darts in hand of Learn and
  /// Miss). The part stays from one number to the next; a new game starts on
  /// Choose.
  late final ChoiceParts choice = ChoiceParts(game, marks);

  /// Where each entered dart landed on the board, aligned with
  /// `game.entered`. An entry is null when the dart was not entered by
  /// tapping the board (keyboard); its mark is drawn mid-segment.
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

  /// True when the next dart is the last free box - which must be a double.
  /// Only in Checkout calculator; in the practice modes you pick every dart
  /// freely.
  bool get isFinalBox {
    final challenge = game.challenge;
    return challenge != null &&
        game.mode == GameMode.calculator &&
        game.entered.length == challenge.dartsLeft - 1;
  }

  /// The multiplier the input applies right now. The finishing box is always
  /// a double, so it is forced; earlier darts use the sticky choice.
  Multiplier activeMultiplier() =>
      isFinalBox ? Multiplier.double : (pickedMultiplier ?? Multiplier.single);

  /// Where the Back dart goes: one step back, which is the menu from every
  /// page ([phase] and [page] are where it goes back from): Checkout calculator
  /// opens straight from Start, with no list of game modes in between.
  static MenuPage backTarget(GamePhase phase, [MenuPage? page]) => MenuPage.home;

  /// The multiplier a new checkout starts with: Triple when the best route has
  /// a triple in it, and also for a number with no checkout; otherwise Single
  /// (null).
  static Multiplier? startingMultiplier(Challenge? challenge) {
    if (challenge == null) return null;
    if (!challenge.hasCheckout) return Multiplier.treble;
    return challenge.optimalRoute.trebleCount > 0 ? Multiplier.treble : null;
  }
}
