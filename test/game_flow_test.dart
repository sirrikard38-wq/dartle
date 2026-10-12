import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryStorageService storage;
  late GameController game;
  late Duration now;

  final engine = CheckoutEngine();
  final optimalService = OptimalRouteService(engine);
  final advisor = ChoiceAdvisor(engine, optimalService);

  GameController build() => GameController(
        generator: ChallengeGenerator(
          CheckoutCatalog(engine, optimalService),
          random: Random(7),
        ),
        validator: CheckoutValidator(engine, optimalService),
        optimal: optimalService,
        advisor: advisor,
        scoring: const ScoringService(),
        statistics: const StatisticsService(),
        history: HistoryRepository(storage),
        leaderboard: LeaderboardService(LocalLeaderboardRepository(storage)),
        storage: storage,
        timerFactory: () => AttemptTimer(() => now),
      );

  Future<void> solveOptimally() async {
    for (final d in game.challenge!.optimalRoute.darts) {
      game.selectDart(d);
    }
    await game.submit();
  }

  setUp(() async {
    storage = InMemoryStorageService();
    now = const Duration(seconds: 10);
    game = build();
    await game.init();
  });

  group('Checkout practice mode', () {
    /// Throws whichever equally optimal dart scores most, until the round ends.
    Future<void> followAdvice() async {
      while (!game.round!.isFinished) {
        final best = advisor.optimalDarts(game.round!.remaining).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        game.selectDart(best.first);
      }
      await game.submit();
    }

    test('starts a round on the number, with three darts and no calculator boxes', () {
      game.startGame(null, GameMode.choice);
      expect(game.mode, GameMode.choice);
      expect(game.round, isNotNull);
      expect(game.round!.target, game.challenge!.target);
      expect(game.round!.dartsLeft, 3);
      expect(game.isHandFull, isFalse);
    });

    test('the best darts are offered as hints before every choice', () {
      game.startGame(null, GameMode.choice);
      final first = game.choiceHints;
      expect(first, isNotEmpty);
      expect(first, advisor.optimalDarts(game.round!.remaining));

      // Throwing an optimal dart moves on to hints for the new number.
      final pick = first.toList()..sort((a, b) => b.score.compareTo(a.score));
      final before = game.round!.remaining;
      game.selectDart(pick.first);
      if (!game.round!.isFinished) {
        expect(game.round!.remaining, before - pick.first.score);
        expect(game.choiceHints, advisor.optimalDarts(game.round!.remaining));
      } else {
        expect(game.choiceHints, isEmpty);
      }
    });

    test('there are no hints in calculator mode', () {
      game.startGame();
      expect(game.choiceHints, isEmpty);
    });

    test('calculator mode has no round', () {
      game.startGame();
      expect(game.mode, GameMode.calculator);
      expect(game.round, isNull);
    });

    test('the remaining number updates after every dart', () {
      game.startGame(null, GameMode.choice);
      final start = game.round!.target;
      final dart = DartThrow.parse('S1');
      game.selectDart(dart);
      expect(game.round!.remaining, start - 1 < 0 ? start : start - 1);
      expect(game.entered, [dart]);
    });

    test('following the advice checks out optimally and is recorded as choice', () async {
      for (var i = 0; i < 25; i++) {
        game.startGame(null, GameMode.choice);
        await followAdvice();
        final result = game.lastResult!;
        expect(result.isChoice, isTrue);
        expect(result.isCorrect, isTrue, reason: result.validation.message);
        expect(result.isOptimal, isTrue);
      }
      expect(game.history.every((r) => r.mode == GameMode.choice), isTrue);
      expect(game.summary.successes, 25);
    });

    test('Checkout practice has no score: nothing won, nothing lost, nothing added', () async {
      expect(GameMode.choice.hasScore, isFalse);
      expect(GameMode.calculator.hasScore, isTrue);

      // A perfect round earns nothing ...
      game.startGame(null, GameMode.choice);
      await followAdvice();
      var result = game.lastResult!;
      expect(result.isCorrect && result.isOptimal, isTrue);
      expect(result.score.total, 0);
      expect(game.sessionPoints, 0);

      // ... and a miss and a skip cost nothing.
      game.nextCheckout();
      await game.giveUp();
      result = game.lastResult!;
      expect(result.isCorrect, isFalse);
      expect(result.score.total, 0);
      expect(game.sessionPoints, 0);

      // The saved attempts carry zero points, so they add nothing to the totals.
      expect(game.history, hasLength(2));
      expect(game.history.every((r) => r.points == 0), isTrue);
      expect(game.summary.totalPoints, 0);
    });

    test('Checkout practice has no clock: no overtime penalty however long it takes', () async {
      game.startGame(null, GameMode.choice);
      now += const Duration(minutes: 3);
      await followAdvice();
      final result = game.lastResult!;
      expect(result.isCorrect, isTrue);
      expect(result.score.timePenalty, 0);
      expect(result.score.speedBonus, 0);
      expect(GameMode.choice.isTimed, isFalse);
      expect(GameMode.calculator.isTimed, isTrue);
    });

    test('the calculator is still scored', () async {
      game.startGame();
      for (final d in game.challenge!.optimalRoute.darts) {
        game.selectDart(d);
      }
      await game.submit();
      expect(game.lastResult!.score.total, greaterThan(0));
      expect(game.sessionPoints, game.lastResult!.score.total);
    });

    test('sound belongs to Checkout calculator only', () {
      expect(GameMode.calculator.hasSound, isTrue);
      expect(GameMode.choice.hasSound, isFalse);
    });

    test('a bust ends the attempt as a miss with a reason', () async {
      game.startGame(null, GameMode.choice);
      // Keep throwing T20 until the round is over: it must end in a bust or out of darts.
      while (!game.round!.isFinished) {
        game.selectDart(DartThrow.parse('T20'));
      }
      await game.submit();
      final result = game.lastResult!;
      if (result.isCorrect) return; // a number that T20s happen to finish: nothing to check
      expect(result.score.total, 0); // practice is not scored
      expect([AttemptOutcome.bust, AttemptOutcome.outOfDarts],
          contains(result.validation.outcome));
    });

    test('undo takes back a dart and its effect on the remaining number', () {
      game.startGame(null, GameMode.choice);
      final start = game.round!.target;
      game.selectDart(DartThrow.parse('S1'));
      game.undo();
      expect(game.round!.remaining, start);
      expect(game.entered, isEmpty);
    });

    test('old saved history without a mode still loads as calculator', () {
      final record = AttemptRecord.fromJson({
        'sessionId': 1, 'timestampMs': 2, 'target': 40, 'dartCount': 1,
        'difficulty': 'easy', 'correct': true, 'optimal': true, 'timeMs': 900,
        'points': 3, 'playerRoute': 'D20', 'optimalRoute': 'D20',
      });
      expect(record.mode, GameMode.calculator);
      expect(AttemptRecord.fromJson(record.toJson()).mode, GameMode.calculator);
    });
  });

  test('first visit needs a username; it is saved and remembered', () async {
    expect(game.needsPlayerName, isTrue);
    await game.setPlayerName('   '); // blank is ignored
    expect(game.needsPlayerName, isTrue);
    await game.setPlayerName('  Phil  ');
    expect(game.playerName, 'Phil');
    expect(game.needsPlayerName, isFalse);

    final returning = build();
    await returning.init();
    expect(returning.needsPlayerName, isFalse);
    expect(returning.playerName, 'Phil');
  });

  test('usernames are capped in length', () async {
    await game.setPlayerName('x' * 60);
    expect(game.playerName.length, GameController.maxPlayerNameLength);
  });

  test('starts on the menu and enters playing with the right box count', () {
    expect(game.phase, GamePhase.menu);
    game.startGame(DifficultyLevel.hard);
    expect(game.phase, GamePhase.playing);
    expect(game.challenge!.dartCount, game.challenge!.optimalRoute.length);
    expect(game.entered, isEmpty);
  });

  test('boxes fill left to right, cap at the free darts, undo and clear work', () {
    game.startGame(DifficultyLevel.medium);
    final n = game.challenge!.dartsLeft;
    for (var i = 0; i < n + 2; i++) {
      game.selectDart(DartThrow.parse('S1'));
    }
    expect(game.entered, hasLength(n));
    expect(game.isHandFull, isTrue);
    game.undo();
    expect(game.entered, hasLength(n - 1));
    game.clear();
    expect(game.entered, isEmpty);
  });

  group('three boxes, some already thrown', () {
    /// Starts checkouts until one is dealt that [wanted] accepts.
    void dealUntil(bool Function(Challenge c) wanted) {
      for (var i = 0; i < 5000; i++) {
        game.startGame();
        if (wanted(game.challenge!)) return;
      }
      fail('no checkout like that was dealt');
    }

    test('every checkout has three boxes: free ones plus the blurred ones', () {
      for (var i = 0; i < 60; i++) {
        game.startGame();
        final c = game.challenge!;
        expect(c.dartsLeft + c.alreadyThrown, Visit.darts);
        expect(c.dartsLeft, greaterThanOrEqualTo(c.dartCount));
      }
    });

    test('a checkout can finish with fewer darts than are free', () async {
      // A two-dart number dealt with all three darts free.
      dealUntil((c) =>
          c.dartCount == 2 && c.dartsLeft == 3 && !SingleSingleDouble.covers(c.target));
      final route = game.challenge!.optimalRoute; // two darts, e.g. T20 D20
      expect(route.length, 2);
      game.selectDart(route.darts[0]);
      expect(game.isHandFull, isFalse);
      game.selectDart(route.darts[1]);
      expect(game.isHandFull, isTrue, reason: 'checked out on the second of three darts');
      await game.submit();
      expect(game.lastResult!.isCorrect && game.lastResult!.isOptimal, isTrue);
      expect(game.phase, GamePhase.result);
    });

    test('with all three free on 51 to 70, treble-double is correct but not optimal', () async {
      dealUntil((c) =>
          SingleSingleDouble.covers(c.target) && c.dartCount == 2 && c.dartsLeft == 3);
      final target = game.challenge!.target;
      expect(SingleSingleDouble.isSingleSingleDouble(game.challenge!.optimalRoute), isTrue);
      // The classic bull-safe finish, which is two darts, checks the number out ...
      final twoDart = optimalService.optimalRoute(target, dartsLeft: 2)!;
      for (final d in twoDart.darts) {
        game.selectDart(d);
      }
      await game.submit();
      expect(game.lastResult!.isCorrect, isTrue);
      // ... but with all three free, single, single, double is the better route.
      expect(game.lastResult!.isOptimal, isFalse);
      expect(SingleSingleDouble.isSingleSingleDouble(game.lastResult!.optimalRoutes.first),
          isTrue);
    });

    test('with the first dart already thrown on 51 to 70, the bull-safe finish is optimal', () async {
      dealUntil((c) => c.target >= 55 && c.target <= 70 && c.dartsLeft == 2);
      expect(game.challenge!.alreadyThrown, 1);
      expect(game.challenge!.optimalRoute.notation,
          BullSafeFinish.twoDartFinish(game.challenge!.target)!.notation);
      for (final d in game.challenge!.optimalRoute.darts) {
        game.selectDart(d);
      }
      await game.submit();
      expect(game.lastResult!.isCorrect && game.lastResult!.isOptimal, isTrue);
    });
  });

  group('Same checkout (Checkout practice)', () {
    test('replays the number just finished, from the start', () async {
      game.startGame(null, GameMode.choice);
      final target = game.challenge!.target;
      game.selectDart(DartThrow.parse('S1'));
      await game.giveUp();
      expect(game.phase, GamePhase.result);

      game.sameCheckout();
      expect(game.phase, GamePhase.playing);
      expect(game.challenge!.target, target);
      expect(game.round!.target, target);
      expect(game.round!.remaining, target);
      expect(game.round!.dartsLeft, 3);
      expect(game.entered, isEmpty);
      expect(game.lastResult, isNull);
    });

    test('after a checkout, and it can be played again and again', () async {
      game.startGame(null, GameMode.choice);
      final target = game.challenge!.target;
      for (var i = 0; i < 3; i++) {
        while (!game.round!.isFinished) {
          final best = advisor.optimalDarts(game.round!.remaining).toList()
            ..sort((a, b) => b.score.compareTo(a.score));
          game.selectDart(best.first);
        }
        await game.submit();
        expect(game.lastResult!.isCorrect, isTrue);
        game.sameCheckout();
        expect(game.challenge!.target, target);
      }
      expect(game.history, hasLength(3));
    });

    test('is for Checkout practice only, and only on the result screen', () async {
      // Calculator: ignored.
      game.startGame();
      await game.giveUp();
      final calcTarget = game.challenge!.target;
      game.sameCheckout();
      expect(game.phase, GamePhase.result);
      expect(game.challenge!.target, calcTarget);

      // Practice, but still playing: ignored.
      game.startGame(null, GameMode.choice);
      final target = game.challenge!.target;
      game.selectDart(DartThrow.parse('S1'));
      game.sameCheckout();
      expect(game.phase, GamePhase.playing);
      expect(game.entered, hasLength(1));
      expect(game.challenge!.target, target);
    });

    test('Next checkout still moves on to a different number', () async {
      game.startGame(null, GameMode.choice);
      final target = game.challenge!.target;
      await game.giveUp();
      game.nextCheckout();
      expect(game.challenge!.target, isNot(target));
    });
  });

  test('submit is ignored until every box is filled', () async {
    game.startGame(DifficultyLevel.hard);
    await game.submit();
    expect(game.phase, GamePhase.playing);
  });

  test('optimal solve scores points, records history and stops the timer', () async {
    game.startGame(DifficultyLevel.easy);
    now += const Duration(milliseconds: 4820);
    await solveOptimally();
    final result = game.lastResult!;
    expect(game.phase, GamePhase.result);
    expect(result.isCorrect && result.isOptimal, isTrue);
    expect(result.elapsed, const Duration(milliseconds: 4820));
    expect(result.score.total, greaterThan(0));
    expect(game.sessionPoints, result.score.total);

    now += const Duration(seconds: 30); // time after submit must not matter
    expect(game.elapsed, const Duration(milliseconds: 4820));

    expect(game.history, hasLength(1));
    expect(game.summary.successes, 1);
    expect(game.summary.totalPoints, result.score.total);
  });

  test('clock counts down from 30s and goes negative past zero', () async {
    game.startGame();
    expect(game.timeLimit, const Duration(seconds: 30));
    expect(game.remaining, const Duration(seconds: 30));
    now += const Duration(seconds: 12);
    expect(game.remaining, const Duration(seconds: 18));
    now += const Duration(seconds: 18);
    expect(game.remaining, Duration.zero);
    // 30s -> -8.33s is 38.33s of real time.
    now += const Duration(milliseconds: 8330);
    expect(game.remaining, const Duration(milliseconds: -8330));
    expect(game.remaining.isNegative, isTrue);
  });

  test('overtime records the real elapsed time and costs points', () async {
    game.startGame();
    now += const Duration(milliseconds: 38330);
    await solveOptimally();
    final result = game.lastResult!;
    expect(result.elapsed, const Duration(milliseconds: 38330));
    expect(result.score.timePenalty, greaterThan(0));
    expect(game.history.single.timeMs, 38330); // not -8330
    // The clock stays frozen on the result screen.
    now += const Duration(seconds: 20);
    expect(game.remaining, const Duration(milliseconds: -8330));
  });

  test('wrong answer scores zero and counts as a failure', () async {
    game.startGame(DifficultyLevel.easy);
    for (var i = 0; i < game.challenge!.dartCount; i++) {
      game.selectDart(DartThrow.parse('S1'));
    }
    await game.submit();
    expect(game.lastResult!.isCorrect, isFalse);
    expect(game.lastResult!.score.total, lessThan(0)); // a miss costs points
    expect(game.sessionPoints, game.lastResult!.score.total);
    expect(game.summary.failures, 1);
    expect(game.sessionStreak, 0);
  });

  test('giveUp records a failed attempt', () async {
    game.startGame(DifficultyLevel.easy);
    await game.giveUp();
    expect(game.lastResult!.validation.outcome, AttemptOutcome.gaveUp);
    expect(game.lastResult!.score.total, lessThan(0)); // skipping is not free
    expect(game.summary.failures, 1);
  });

  group('give up to the menu', () {
    test('records the skip, updates the leaderboard, then returns to the menu', () async {
      game.startGame();
      await game.setPlayerName('Phil');
      await game.giveUp(toMenu: true);

      // No result screen: straight back to the menu phase.
      expect(game.phase, GamePhase.menu);
      expect(game.challenge, isNull);
      expect(game.lastResult, isNull);
      expect(game.entered, isEmpty);

      // The skipped attempt was saved (a failure, with its penalty) ...
      expect(game.history, hasLength(1));
      expect(game.history.single.correct, isFalse);
      expect(game.history.single.points, lessThan(0));

      // ... and the leaderboard already has the player's up-to-date row.
      final board = await game.leaderboard(LeaderboardSort.points);
      final me = board.firstWhere((e) => e.playerName == 'Phil');
      expect(me.attempts, 1);
      expect(me.totalPoints, game.history.single.points);
    });

    test('is persisted: a reloaded game still has the skipped attempt', () async {
      game.startGame();
      await game.giveUp(toMenu: true);
      final reloaded = build();
      await reloaded.init();
      expect(reloaded.history, hasLength(1));
    });

    test('practice mode: recorded with no points, and still leaves for the menu', () async {
      game.startGame(null, GameMode.choice);
      await game.giveUp(toMenu: true);
      expect(game.phase, GamePhase.menu);
      expect(game.history.single.points, 0);
      expect(game.sessionPoints, 0);
    });

    test('giving up the normal way still shows the result', () async {
      game.startGame();
      await game.giveUp();
      expect(game.phase, GamePhase.result);
      expect(game.lastResult!.validation.outcome, AttemptOutcome.gaveUp);
    });

    test('a second press while leaving is ignored', () async {
      game.startGame();
      final first = game.giveUp(toMenu: true);
      final second = game.giveUp(toMenu: true);
      await Future.wait([first, second]);
      expect(game.history, hasLength(1));
    });
  });

  test('nextCheckout starts a fresh attempt with a fresh timer', () async {
    game.startGame(DifficultyLevel.easy);
    now += const Duration(seconds: 5);
    await solveOptimally();
    game.nextCheckout();
    expect(game.phase, GamePhase.playing);
    expect(game.entered, isEmpty);
    expect(game.elapsed, Duration.zero);
    now += const Duration(seconds: 1);
    expect(game.elapsed, const Duration(seconds: 1));
  });

  test('history persists across controller instances', () async {
    game.startGame(DifficultyLevel.easy);
    await solveOptimally();
    final reloaded = build();
    await reloaded.init();
    expect(reloaded.history, hasLength(1));
    expect(reloaded.summary.totalPoints, game.summary.totalPoints);
  });

  test('result shows up on the leaderboard', () async {
    game.startGame(DifficultyLevel.hard);
    await solveOptimally();
    final board = await game.leaderboard(LeaderboardSort.points);
    expect(board.map((e) => e.playerName), contains(game.playerName));
  });
}
