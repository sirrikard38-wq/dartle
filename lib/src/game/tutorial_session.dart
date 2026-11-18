import 'dart:math';

import '../domain/checkout_engine.dart';
import '../domain/checkout_tutor.dart';
import '../domain/dart_throw.dart';

/// The two halves of Checkout tutorial.
enum TutorialTab { learn, practice }

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

  TutorialTab tab = TutorialTab.learn;

  /// Learn: the number typed so far (empty for none) and the darts in hand.
  String learnDigits = '';
  int learnDarts = 3;

  /// Practice: the number and darts of the question, and the dart pressed.
  int practiceTarget = 2;
  int practiceDarts = 1;
  DartThrow? answer;

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

  /// Types a digit of the number to learn about (three at the most, no
  /// leading zero).
  void typeDigit(int digit) {
    if (learnDigits.length >= 3 || (learnDigits.isEmpty && digit == 0)) return;
    learnDigits += '$digit';
  }

  void deleteDigit() {
    if (learnDigits.isNotEmpty) learnDigits = learnDigits.substring(0, learnDigits.length - 1);
  }

  /// The card for the number shown ([shownDigits]), or null.
  TutorCard? get learnCard {
    final target = _number(shownDigits);
    return target == null ? null : tutor.card(target, learnDarts);
  }

  /// A new practice question: a number that can be checked out with the darts
  /// given, from one dart up to three.
  void newQuestion() {
    answer = null;
    while (true) {
      final target = CheckoutEngine.minCheckout +
          _random.nextInt(CheckoutEngine.maxCheckout - CheckoutEngine.minCheckout + 1);
      final darts = 1 + _random.nextInt(3);
      final card = tutor.card(target, darts);
      if (card?.route != null) {
        practiceTarget = target;
        practiceDarts = darts;
        return;
      }
    }
  }

  /// Practice: the dart pressed for the question (only the first press counts).
  void pressAnswer(DartThrow dart) => answer ??= dart;

  /// Whether the answer was right; null before it is given.
  bool? get answerRight {
    final dart = answer;
    return dart == null ? null : tutor.isRight(practiceTarget, practiceDarts, dart);
  }

  /// The card for the practice question.
  TutorCard get practiceCard => tutor.card(practiceTarget, practiceDarts)!;
}
