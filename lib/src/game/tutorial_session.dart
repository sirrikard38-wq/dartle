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
enum TutorialTab { input, practice, learn, favorites }

/// Checkout tutorial, all about one number: Input (a keypad to type it),
/// Practice (it played out exactly as in Checkout calculator, judged the same
/// way, but with no clock, no score and nothing saved), Learn (it with the
/// darts in hand: the route and a miss on boards) and Favorites (its favorite
/// routes). Next checkout deals a new number, as the calculator does, and it
/// is in Input too.
class TutorialSession {
  TutorialSession(
    this.tutor, {
    required ChallengeGenerator generator,
    required CheckoutValidator validator,
    Random? random,
    DateTime Function()? now,
  })  : _generator = generator,
        _validator = validator,
        _random = random ?? Random(),
        _now = now ?? DateTime.now {
    newQuestion();
  }

  final CheckoutTutor tutor;
  final ChallengeGenerator _generator;
  final CheckoutValidator _validator;
  final Random _random;
  final DateTime Function() _now;

  TutorialTab tab = TutorialTab.practice;

  /// Input: the digits typed (empty for none). Learn: the darts in hand.
  String typedDigits = '';
  int learnDarts = 3;

  /// This long after the last key, the next digit starts a new number instead
  /// of going on the end of the old one.
  static const Duration freshAfter = Duration(seconds: 3);

  /// Practice: the number dealt, the darts thrown at it so far with where each
  /// was pressed on the board (null when typed), and the verdict once it is
  /// played out.
  late Challenge practice;
  final List<DartThrow> thrown = [];
  final List<BoardPoint?> marks = [];
  AttemptResult? result;

  /// The number typed, when the digits make one from 2 to 170.
  int? get typedTarget => _number(typedDigits);

  /// The number Practice plays, Learn shows its card for and Favorites its
  /// favorites: the last one typed from 2 to 170, or dealt.
  int get shownTarget => practice.target;

  static int? _number(String digits) {
    final value = int.tryParse(digits);
    return value != null && value >= CheckoutEngine.minCheckout && value <= CheckoutEngine.maxCheckout
        ? value
        : null;
  }

  /// Input holds a number that was dealt (Next checkout), not typed: the next
  /// digit starts a new number.
  bool _dealt = false;

  /// When a key of Input was last pressed.
  DateTime? _typedAt;

  /// Types a digit of the number (three at the most, no leading zero). After a
  /// dealt number, or [freshAfter] since the last key, it starts a new number.
  /// A number from 2 to 170 is at once the one Practice, Learn and Favorites
  /// show.
  void typeDigit(int digit) {
    final now = _now();
    final last = _typedAt;
    if (_dealt || (last != null && now.difference(last) >= freshAfter)) typedDigits = '';
    _dealt = false;
    _typedAt = now;
    if (typedDigits.length >= 3 || (typedDigits.isEmpty && digit == 0)) return;
    typedDigits += '$digit';
    _showTyped();
  }

  /// Takes the last digit away (UNDO); the number left is the one shown.
  void deleteDigit() {
    _dealt = false;
    _typedAt = _now();
    if (typedDigits.isEmpty) return;
    typedDigits = typedDigits.substring(0, typedDigits.length - 1);
    _showTyped();
  }

  /// The number typed, when it is one from 2 to 170, played in Practice (with
  /// the darts the calculator gives it) and shown in Learn and Favorites.
  void _showTyped() {
    final target = typedTarget;
    if (target == null || target == practice.target) return;
    final challenge = _generator.forNumber(target) ??
        (_generator.isImpossible(target) ? Challenge.noCheckout(target) : null);
    if (challenge != null) _setPractice(challenge);
  }

  /// The card for the number shown, or null when it has no checkout.
  TutorCard? get learnCard =>
      practice.hasCheckout ? tutor.card(practice.target, learnDarts) : null;

  /// A new Practice question, dealt as Checkout calculator deals: any number
  /// from 2 to 170, the few with no checkout too. Input and Learn show it too.
  void newQuestion() => play(_generator.next(null, Deal.calculator));

  /// Plays [challenge] in Practice, from the first dart; Input and Learn show
  /// it too.
  void play(Challenge challenge) {
    _setPractice(challenge);
    typedDigits = '${challenge.target}';
    _dealt = true;
  }

  void _setPractice(Challenge challenge) {
    practice = challenge;
    replay();
    learnDarts = challenge.dartsLeft;
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
