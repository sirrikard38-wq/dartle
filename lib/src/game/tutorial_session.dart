import 'dart:math';

import '../board/board_geometry.dart';
import '../domain/checkout_engine.dart';
import '../domain/checkout_route.dart';
import '../domain/checkout_tutor.dart';
import '../domain/dart_throw.dart';

/// The two halves of Checkout tutorial, in the order they stand on the screen.
enum TutorialTab { practice, learn }

/// Checkout tutorial: Learn (pick a number and the darts in hand, read the card)
/// and Practice (a number and darts are given, press where you would aim, and
/// the same card says if that was right and why). Pure state, no clock, no
/// score, nothing saved.
class TutorialSession {
  TutorialSession(this.tutor, {Random? random}) : _random = random ?? Random() {
    newQuestion();
  }

  final CheckoutTutor tutor;
  final Random _random;

  TutorialTab tab = TutorialTab.practice;

  /// Learn: the number typed so far (empty for none) and the darts in hand.
  String learnDigits = '';
  int learnDarts = 3;

  /// Practice: the number and darts of the question, and the darts thrown at it
  /// so far, with where each was pressed on the board (null when typed).
  int practiceTarget = 2;
  int practiceDarts = 1;
  final List<DartThrow> thrown = [];
  final List<BoardPoint?> marks = [];

  /// The digits the card is shown for. The card waits until the typing stops,
  /// so it does not jump about while a number is typed ([showTypedNumber]).
  String shownDigits = '';

  /// Shows the card for the digits typed so far.
  void showTypedNumber() => shownDigits = learnDigits;

  /// The number typed, when the digits make one from 2 to 170.
  int? get learnTarget => _number(learnDigits);

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

  /// Learn shows the Practice question: its number with its darts in hand.
  void _learnPracticeQuestion() {
    learnDigits = shownDigits = '$practiceTarget';
    learnDarts = practiceDarts;
    _fromPractice = true;
  }

  /// The card for the number shown ([shownDigits]), or null.
  TutorCard? get learnCard {
    final target = _number(shownDigits);
    return target == null ? null : tutor.card(target, learnDarts);
  }

  /// A new practice question: a number that can be checked out with the darts
  /// given, from one dart up to three. Learn shows it too.
  void newQuestion() {
    thrown.clear();
    marks.clear();
    while (true) {
      final target = CheckoutEngine.minCheckout +
          _random.nextInt(CheckoutEngine.maxCheckout - CheckoutEngine.minCheckout + 1);
      final darts = 1 + _random.nextInt(3);
      final card = tutor.card(target, darts);
      if (card?.route != null) {
        practiceTarget = target;
        practiceDarts = darts;
        _learnPracticeQuestion();
        return;
      }
    }
  }

  /// What is left of the practice number after the darts thrown.
  int get practiceLeft => practiceTarget - thrown.fold<int>(0, (sum, d) => sum + d.score);

  /// The question is played out: every dart is thrown, it is checked out, or
  /// it went bust (below zero, 1 left, or zero without a double).
  bool get practiceDone {
    final left = practiceLeft;
    return thrown.length >= practiceDarts || left <= 1;
  }

  /// Throws [dart] at the practice number, [at] where it was pressed.
  void throwPractice(DartThrow dart, [BoardPoint? at]) {
    if (practiceDone) return;
    thrown.add(dart);
    marks.add(at);
  }

  /// Takes back the last dart, while the question is still being played.
  void undoPractice() {
    if (thrown.isEmpty || practiceDone) return;
    thrown.removeLast();
    marks.removeLast();
  }

  /// The darts thrown as a route.
  CheckoutRoute get practiceRoute => CheckoutRoute(thrown);

  /// Checked out, on a double, with the darts given.
  bool get practiceCheckedOut => practiceRoute.isCheckoutFor(practiceTarget);

  /// Checked out on one of the optimal routes; null until it is played out.
  bool? get practiceRight => practiceDone
      ? practiceCheckedOut && tutor.isOptimalIn(practiceTarget, practiceDarts, practiceRoute)
      : null;

  /// The card for the practice question.
  TutorCard get practiceCard => tutor.card(practiceTarget, practiceDarts)!;
}
