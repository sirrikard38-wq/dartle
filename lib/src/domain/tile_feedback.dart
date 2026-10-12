import 'checkout_route.dart';
import 'dart_throw.dart';

/// Wordle-style verdict for one dart in the player's answer.
enum TileState {
  /// Same dart in the same position as the reference route.
  correct,

  /// The dart is in the reference route, but in another position.
  present,

  /// The dart is not (or no longer) in the reference route.
  absent,
}

/// Wordle's two-pass algorithm, so repeated darts (T20 T20) are counted right.
///
/// Only the finishing dart has a fixed position. The darts before it are a
/// combination, so T19 T20 D8 scores the same as T20 T19 D8: a setup dart is
/// "correct" whenever it belongs to the answer's setup darts, in any slot.
abstract final class TileFeedback {
  static List<TileState> evaluate(List<DartThrow> guess, CheckoutRoute answer) {
    final states = List.filled(guess.length, TileState.absent);
    final setupPool = <DartThrow, int>{}; // answer setup darts not yet matched
    final leftover = <DartThrow, int>{}; // everything unmatched, for "present"

    for (final d in answer.setupDarts) {
      setupPool[d] = (setupPool[d] ?? 0) + 1;
    }

    // Pass 1: exact matches. Finisher by position, setup darts by membership.
    final finisherIndex = answer.length - 1;
    var finisherMatched = false;
    for (var i = 0; i < guess.length; i++) {
      // The finisher slot is the answer's last position; every other slot is
      // part of the (unordered) setup.
      final isGuessFinisher = i == finisherIndex;
      if (isGuessFinisher && guess[i] == answer.darts[finisherIndex]) {
        states[i] = TileState.correct;
        finisherMatched = true;
      } else if (!isGuessFinisher && (setupPool[guess[i]] ?? 0) > 0) {
        states[i] = TileState.correct;
        setupPool[guess[i]] = setupPool[guess[i]]! - 1;
      }
    }

    // Whatever the guess did not match is available for "present".
    setupPool.forEach((dart, count) {
      if (count > 0) leftover[dart] = (leftover[dart] ?? 0) + count;
    });
    if (!finisherMatched && !answer.isEmpty) {
      final f = answer.darts[finisherIndex];
      leftover[f] = (leftover[f] ?? 0) + 1;
    }

    // Pass 2: right dart, wrong role (e.g. the answer's finisher thrown early).
    for (var i = 0; i < guess.length; i++) {
      if (states[i] == TileState.correct) continue;
      final left = leftover[guess[i]] ?? 0;
      if (left > 0) {
        states[i] = TileState.present;
        leftover[guess[i]] = left - 1;
      }
    }
    return states;
  }

  /// Evaluates against each acceptable route and keeps the closest match, so a
  /// player on an approved alternate route is not marked down against the
  /// primary one.
  static List<TileState> best(List<DartThrow> guess, List<CheckoutRoute> answers) {
    List<TileState>? best;
    var bestScore = -1;
    for (final answer in answers) {
      final states = evaluate(guess, answer);
      final score = states.fold<int>(
        0,
        (sum, s) => sum + switch (s) {
          TileState.correct => 2,
          TileState.present => 1,
          TileState.absent => 0,
        },
      );
      if (score > bestScore) {
        bestScore = score;
        best = states;
      }
    }
    return best ?? List.filled(guess.length, TileState.absent);
  }
}
