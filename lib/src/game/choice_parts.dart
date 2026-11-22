import '../board/board_geometry.dart';
import '../domain/challenge.dart';
import '../domain/checkout_tutor.dart';
import 'game_controller.dart';
import 'game_mode.dart';
import 'tutorial_session.dart';

/// Checkout choice's parts, the same as Checkout calculator's: Input,
/// Favorites, Choose (the game: before every dart the board lights up the
/// optimal darts), Learn and Miss, all about the number dealt or typed.
/// [marks] are where the darts of Choose were pressed on the board (the screen
/// keeps them beside the game's darts).
class ChoiceParts implements NumberParts {
  ChoiceParts(this._game, this.marks);

  final GameController _game;

  @override
  final List<BoardPoint?> marks;

  @override
  TutorialTab tab = TutorialTab.practice;

  CheckoutTutor get _tutor => _game.tutorial.tutor;

  @override
  String get typedDigits => _game.numberInput.digits;

  @override
  void typeDigit(int digit) => _game.typeDigit(digit);

  @override
  void deleteDigit() => _game.deleteDigit();

  /// A number typed with no checkout, or the one Choose plays.
  @override
  int get shownTarget => _game.impossibleNumber ?? _game.challenge?.target ?? 0;

  // The darts in hand follow the number: a new one (or the same one switched
  // to the other darts) starts with the darts it is played with.
  Challenge? _dartsOf;
  int _learnDarts = 3;

  void _follow() {
    final challenge = _game.challenge;
    if (identical(challenge, _dartsOf)) return;
    _dartsOf = challenge;
    if (challenge != null) _learnDarts = challenge.dartsLeft;
  }

  @override
  int get learnDarts {
    _follow();
    return _learnDarts;
  }

  @override
  set learnDarts(int value) {
    _follow();
    _learnDarts = value;
  }

  @override
  TutorCard? get learnCard {
    final challenge = _game.challenge;
    if (_game.impossibleNumber != null || challenge == null || !challenge.hasCheckout) return null;
    return _tutor.card(challenge.target, learnDarts);
  }

  /// The answer of Choose, once it is played out.
  AttemptResult? get _played =>
      _game.mode == GameMode.choice && _game.phase == GamePhase.result ? _game.lastResult : null;

  @override
  PracticeReview? get practiceReview {
    final judged = _played;
    if (judged == null || judged.isNoCheckoutAnswer) return null;
    return _tutor.review(judged.challenge.target, judged.challenge.dartsLeft, judged.playerRoute,
        correct: judged.isCorrect, optimal: judged.isOptimal);
  }

  @override
  int get practiceTarget => _game.challenge?.target ?? 0;

  @override
  int get practiceDarts => _game.challenge?.dartsLeft ?? 3;
}
