import 'challenge.dart';
import 'choice_advisor.dart';
import 'dart_throw.dart';

/// [finishedEarly]: checked out with darts still in hand - every dart has to be
/// used, so that is a miss.
enum RoundStatus { inProgress, checkedOut, bust, outOfDarts, finishedEarly }

/// One dart in a "Checkout practice" round, with what the advisor said.
class ChoiceStep {
  const ChoiceStep({
    required this.dart,
    required this.remainingBefore,
    required this.remainingAfter,
    required this.dartsLeftBefore,
    required this.quality,
    required this.optimalChoices,
  });

  final DartThrow dart;
  final int remainingBefore;

  /// What is left after the dart. A bust leaves the score where it was.
  final int remainingAfter;
  final int dartsLeftBefore;
  final DartQuality quality;

  /// The equally optimal darts that could have been thrown instead.
  final Set<DartThrow> optimalChoices;

  /// Why this dart busted; null if it did not.
  String? get bustReason {
    if (quality != DartQuality.bust) return null;
    final after = remainingBefore - dart.score;
    if (after < 0) return 'that goes below zero';
    if (after == 1) return 'that leaves 1, which cannot be finished';
    if (after == 0 && dart.isFinishingDart) {
      return 'that checks out with darts still to throw - all of them have to be used';
    }
    return 'the last dart must be a double or Bull';
  }
}

/// A player choosing their own darts for a number, as many as the free boxes
/// of its [layout] allow. Pure state: the advisor decides every rating.
class ChoiceRound {
  ChoiceRound(
    this.target,
    this._advisor, {
    this.layout = BoxLayout.all,
  }) : maxDarts = layout.freeCount;

  final int target;

  /// Which boxes are used (crossed out). The free ones are the darts to throw.
  final BoxLayout layout;
  final int maxDarts;
  final ChoiceAdvisor _advisor;
  final List<ChoiceStep> _steps = [];
  RoundStatus _status = RoundStatus.inProgress;

  List<ChoiceStep> get steps => List.unmodifiable(_steps);
  RoundStatus get status => _status;
  bool get isFinished => _status != RoundStatus.inProgress;
  bool get isCheckedOut => _status == RoundStatus.checkedOut;

  /// The number still to be checked out - the "next number you need".
  int get remaining => _steps.isEmpty ? target : _steps.last.remainingAfter;

  int get dartsLeft => maxDarts - _steps.length;

  /// The equally optimal darts to throw next: the rest of the optimal routes
  /// that the darts so far belong to, using up exactly the darts left (empty
  /// once the round is over).
  Set<DartThrow> get optimalDarts => isFinished ? const {} : _next();

  Set<DartThrow> _next() =>
      _advisor.nextOptimalDarts(target, maxDarts, [for (final s in _steps) s.dart]);

  /// The same round played with [layout]'s darts from now on, the darts thrown
  /// so far kept as they were rated: 68 with three darts, T14 thrown, switched
  /// to two darts leaves 26 with one dart (D13). There must be a dart left.
  ChoiceRound withLayout(BoxLayout layout) {
    assert(_steps.length < layout.freeCount);
    return ChoiceRound(target, _advisor, layout: layout).._steps.addAll(_steps);
  }

  /// Checked out using only equally optimal choices.
  bool get isOptimal =>
      isCheckedOut && _steps.every((s) => s.quality == DartQuality.optimal);

  /// Throws [dart]. Ignored once the round is over.
  void throwDart(DartThrow dart) {
    if (isFinished) return;
    final before = remaining;
    final best = _next();
    final quality = _advisor.rate(
      remaining: before,
      dartsLeft: dartsLeft,
      dart: dart,
      best: best,
    );
    final scored = before - dart.score;
    final step = ChoiceStep(
      dart: dart,
      remainingBefore: before,
      remainingAfter: quality == DartQuality.bust ? before : scored,
      dartsLeftBefore: dartsLeft,
      quality: quality,
      optimalChoices: best,
    );
    _steps.add(step);
    if (quality == DartQuality.bust) {
      // Checking out with a dart still to throw is its own kind of miss.
      _status = scored == 0 && dart.isFinishingDart
          ? RoundStatus.finishedEarly
          : RoundStatus.bust;
    } else if (scored == 0) {
      _status = RoundStatus.checkedOut;
    } else if (dartsLeft == 0) {
      _status = RoundStatus.outOfDarts;
    }
  }

  /// Takes back the last dart (only while the round is still going).
  void undo() {
    if (_steps.isEmpty) return;
    _steps.removeLast();
    _status = RoundStatus.inProgress;
  }

  void reset() {
    _steps.clear();
    _status = RoundStatus.inProgress;
  }
}
