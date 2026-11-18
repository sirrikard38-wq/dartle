import 'dart:math';

import '../board/board_geometry.dart';
import '../content/phrases.dart';
import '../domain/challenge.dart';
import '../domain/challenge_generator.dart';
import '../domain/checkout_engine.dart';
import '../domain/checkout_tutor.dart';
import '../domain/checkout_validator.dart';
import '../domain/dart_throw.dart';
import '../scoring/scoring_service.dart';
import 'game_controller.dart';

/// The parts of Checkout tutorial, in the order they stand on the screen.
enum TutorialTab { practice, learn, favorites }

/// Checkout tutorial: Practice (a number dealt and played out exactly as in
/// Checkout calculator, judged the same way, but with no clock, no score and
/// nothing saved), Learn (a number and the darts in hand, the route and a miss
/// on two boards) and Favorites (the favorite routes of that number).
class TutorialSession {
  TutorialSession(
    this.tutor, {
    required ChallengeGenerator generator,
    required CheckoutValidator validator,
    Random? random,
  })  : _generator = generator,
        _validator = validator,
        _random = random ?? Random() {
    newQuestion();
  }

  final CheckoutTutor tutor;
  final ChallengeGenerator _generator;
  final CheckoutValidator _validator;
  final Random _random;

  TutorialTab tab = TutorialTab.practice;

  /// Learn: the number typed so far (empty for none) and the darts in hand.
  String learnDigits = '';
  int learnDarts = 3;

  /// Practice: the number dealt, the darts thrown at it so far with where each
  /// was pressed on the board (null when typed), and the verdict once it is
  /// played out.
  late Challenge practice;
  final List<DartThrow> thrown = [];
  final List<BoardPoint?> marks = [];
  AttemptResult? result;

  /// The digits the card is shown for. The card waits until the typing stops,
  /// so it does not jump about while a number is typed ([showTypedNumber]).
  String shownDigits = '';

  /// Shows the card for the digits typed so far.
  void showTypedNumber() => shownDigits = learnDigits;

  /// The number typed, when the digits make one from 2 to 170.
  int? get learnTarget => _number(learnDigits);

  /// The number Learn shows its card for (and Favorites its favorites), when
  /// it is one from 2 to 170.
  int? get shownTarget => _number(shownDigits);

  static int? _number(String digits) {
    final value = int.tryParse(digits);
    return value != null && value >= CheckoutEngine.minCheckout && value <= CheckoutEngine.maxCheckout
        ? value
        : null;
  }

  /// Learn holds the Practice question's number, not one typed: the first
  /// digit typed starts a new number instead of adding to it.
  bool _fromPractice = false;

  /// Types a digit of the number to learn about (three at the most, no
  /// leading zero).
  void typeDigit(int digit) {
    if (_fromPractice) {
      _fromPractice = false;
      learnDigits = '';
    }
    if (learnDigits.length >= 3 || (learnDigits.isEmpty && digit == 0)) return;
    learnDigits += '$digit';
  }

  void deleteDigit() {
    _fromPractice = false;
    if (learnDigits.isNotEmpty) learnDigits = learnDigits.substring(0, learnDigits.length - 1);
  }

  /// The card for the number shown ([shownDigits]), or null.
  TutorCard? get learnCard {
    final target = shownTarget;
    return target == null ? null : tutor.card(target, learnDarts);
  }

  /// A new Practice question, dealt as Checkout calculator deals: any number
  /// from 2 to 170, the few with no checkout too. Learn shows it as well.
  void newQuestion() => play(_generator.next(null, Deal.calculator));

  /// Plays [challenge] in Practice, from the first dart; Learn shows it too.
  void play(Challenge challenge) {
    practice = challenge;
    replay();
    learnDigits = shownDigits = '${challenge.target}';
    learnDarts = challenge.dartsLeft;
    _fromPractice = true;
  }

  /// The same question again, from the first dart.
  void replay() {
    thrown.clear();
    marks.clear();
    result = null;
  }

  int get practiceTarget => practice.target;

  /// How many darts the question is played with.
  int get practiceDarts => practice.dartsLeft;

  /// What is left of the practice number after the darts thrown.
  int get practiceLeft => practiceTarget - thrown.fold<int>(0, (sum, d) => sum + d.score);

  /// The question is played out and judged.
  bool get practiceDone => result != null;

  /// As in Checkout calculator: every box is filled, or the darts already add
  /// up to the number.
  bool get _handFull =>
      thrown.length >= practice.dartsLeft || (practice.hasCheckout && practiceLeft == 0);

  /// Throws [dart] at the practice number, [at] where it was pressed; the last
  /// one is judged at once.
  void throwPractice(DartThrow dart, [BoardPoint? at]) {
    if (practiceDone) return;
    thrown.add(dart);
    marks.add(at);
    if (_handFull) _judge(_validator.validate(practice, thrown));
  }

  /// "No checkout": the player says the number cannot be checked out with the
  /// darts given.
  void pressNoCheckout() {
    if (practiceDone) return;
    _judge(_validator.validateNoCheckout(practice));
  }

  /// Takes back the last dart, while the question is still being played.
  void undoPractice() {
    if (thrown.isEmpty || practiceDone) return;
    thrown.removeLast();
    marks.removeLast();
  }

  void _judge(ValidationResult validation) {
    result = AttemptResult(
      challenge: practice,
      validation: validation,
      score: ScoreBreakdown.none,
      elapsed: Duration.zero,
      optimalRoutes: practice.hasCheckout ? tutor.optimalRoutes(practice.target, practice.darts) : const [],
      isReplay: true,
      encouragement: validation.outcome == AttemptOutcome.noCheckoutCorrect
          ? Phrases.randomEncouragement(_random)
          : null,
    );
  }

  /// Checked out on one of the optimal routes; null until it is played out.
  bool? get practiceRight {
    final judged = result;
    return judged == null ? null : judged.isCorrect && judged.isOptimal;
  }
}
