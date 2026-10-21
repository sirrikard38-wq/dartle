import 'challenge.dart';
import 'checkout_engine.dart';
import 'checkout_route.dart';
import 'dart_throw.dart';
import 'optimal_route_service.dart';

enum AttemptOutcome {
  /// Legal checkout of the right length that hits the target.
  correct,
  wrongDartCount,
  wrongTotal,
  invalidFinish,

  /// "No checkout" was pressed on a number that really has no checkout.
  noCheckoutCorrect,

  /// "No checkout" was pressed on a number that can be checked out.
  noCheckoutWrong,

  /// Darts were entered for a number that has no checkout.
  noCheckoutMissed,

  /// Checkout practice: went below zero, left 1, or hit zero without a double.
  bust,

  /// Checkout practice: all darts thrown and the number is not checked out.
  outOfDarts,
}

class ValidationResult {
  const ValidationResult({
    required this.outcome,
    required this.playerRoute,
    required this.message,
    required this.isOptimal,
  });

  final AttemptOutcome outcome;
  final CheckoutRoute playerRoute;

  /// Human explanation, e.g. "60 + 10 = 70. Incorrect - checkout does not equal 72."
  final String message;

  /// True only for a correct checkout that matches an optimal route (and for
  /// a right "No checkout": using no darts is the best there is).
  final bool isOptimal;

  bool get isCorrect =>
      outcome == AttemptOutcome.correct || outcome == AttemptOutcome.noCheckoutCorrect;
}

/// Pure rule checking. Contains no scoring or UI concerns.
class CheckoutValidator {
  CheckoutValidator(this._engine, this._optimal);

  final CheckoutEngine _engine;
  final OptimalRouteService _optimal;

  /// The player pressed "No checkout".
  ValidationResult validateNoCheckout(Challenge challenge) {
    final route = CheckoutRoute(const []);
    if (!challenge.hasCheckout) {
      return ValidationResult(
        outcome: AttemptOutcome.noCheckoutCorrect,
        playerRoute: route,
        message: '${challenge.target} cannot be checked out. Good job!',
        isOptimal: true,
      );
    }
    return ValidationResult(
      outcome: AttemptOutcome.noCheckoutWrong,
      playerRoute: route,
      message: '${challenge.target} can be checked out: '
          '${challenge.optimalRoute.notation}.',
      isOptimal: false,
    );
  }

  ValidationResult validate(Challenge challenge, List<DartThrow> darts) {
    final route = CheckoutRoute(darts);
    final target = challenge.target;

    ValidationResult fail(AttemptOutcome outcome, String message) =>
        ValidationResult(
          outcome: outcome,
          playerRoute: route,
          message: message,
          isOptimal: false,
        );

    if (!challenge.hasCheckout) {
      return fail(
        AttemptOutcome.noCheckoutMissed,
        '$target cannot be checked out - the answer was "No checkout".',
      );
    }

    // Reaching the number without a double is never a checkout.
    if (route.total == target && !route.endsOnDouble) {
      return fail(
        AttemptOutcome.invalidFinish,
        'Invalid checkout — the final dart must be a double or Bull.',
      );
    }

    // Exactly the free darts of the visit: all of them have to be used.
    if (route.length != challenge.dartsLeft) {
      final left = challenge.dartsLeft;
      return fail(
        AttemptOutcome.wrongDartCount,
        route.total == target
            ? 'Checked out in ${route.length} ${route.length == 1 ? 'dart' : 'darts'}, '
                'but all $left darts have to be used.'
            : 'This checkout needs exactly $left '
                '${left == 1 ? 'dart' : 'darts'}, but you entered ${route.length}.',
      );
    }

    if (route.total != target) {
      return fail(
        AttemptOutcome.wrongTotal,
        '${route.arithmetic.split(' = ').first} = ${route.total}. '
        'Incorrect — checkout does not equal $target.',
      );
    }

    if (!route.endsOnDouble) {
      return fail(
        AttemptOutcome.invalidFinish,
        'Invalid checkout — the final dart must be a double or Bull.',
      );
    }

    // Defensive: the engine is the final authority on legality.
    assert(_engine.isLegalRoute(target, route));

    return ValidationResult(
      outcome: AttemptOutcome.correct,
      playerRoute: route,
      message: '${route.arithmetic}. Correct!',
      isOptimal: _optimal.isOptimalIn(target, challenge.darts, route),
    );
  }
}
