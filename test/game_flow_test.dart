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
  final catalog = CheckoutCatalog(engine, optimalService);

  GameController build() => GameController(
        generator: ChallengeGenerator(catalog, random: Random(7)),
        validator: CheckoutValidator(engine, optimalService),
        optimal: optimalService,
        advisor: advisor,
        scoring: const ScoringService(),
        statistics: const StatisticsService(),
        history: HistoryRepository(storage),
        leaderboard: LeaderboardService(LocalLeaderboardRepository(storage)),
        storage: storage,
        timerFactory: () => AttemptTimer(() => now),
        random: Random(3),
      );

  /// Starts calculator checkouts until one is dealt that [wanted] accepts.
  void dealUntil(bool Function(Challenge c) wanted, {GameMode mode = GameMode.calculator}) {
    for (var i = 0; i < 5000; i++) {
      game.startGame(null, mode);
      if (wanted(game.challenge!)) return;
    }
    fail('no checkout like that was dealt');
  }

  Future<void> solveOptimally() async {
    for (final d in game.challenge!.optimalRoute.darts) {
      game.selectDart(d);
    }
    await game.submit();
  }

  Future<void> missOnPurpose() async {
    for (var i = 0; i < game.challenge!.dartsLeft; i++) {
      game.selectDart(DartThrow.parse('S1'));
    }
    await game.submit();
  }

  /// Practice: throws whichever equally optimal dart scores most, until the
  /// round ends.
  Future<void> followAdvice() async {
    while (!game.round!.isFinished) {
      final best = game.choiceHints.toList()..sort((a, b) => b.score.compareTo(a.score));
      game.selectDart(best.first);
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
    test('starts a round on the number with the free boxes as its darts', () {
      game.startGame(null, GameMode.choice);
      expect(game.mode, GameMode.choice);
      expect(game.round, isNotNull);
      expect(game.round!.target, game.challenge!.target);
      expect(game.round!.dartsLeft, game.challenge!.dartsLeft);
      expect(game.round!.layout, game.challenge!.layout);
      expect(game.isHandFull, isFalse);
    });

    test('the best darts are offered as hints before every choice', () {
      game.startGame(null, GameMode.choice);
      final first = game.choiceHints;
      expect(first, isNotEmpty);
      expect(first, game.round!.optimalDarts);

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

    test('there are no hints in calculator mode, and no round', () {
      game.startGame();
      expect(game.choiceHints, isEmpty);
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

    test('following the advice checks out optimally - and nothing is saved', () async {
      for (var i = 0; i < 25; i++) {
        game.startGame(null, GameMode.choice);
        await followAdvice();
        final result = game.lastResult!;
        expect(result.isPractice, isTrue);
        expect(result.isCorrect, isTrue, reason: result.validation.message);
        expect(result.isOptimal, isTrue);
      }
      // Practice is for learning: no statistics, no leaderboard.
      expect(game.history, isEmpty);
      expect(game.summary.totalAttempts, 0);
      final board = await game.leaderboard(LeaderboardSort.points);
      expect(board.map((e) => e.playerName), isNot(contains(game.playerName)));
    });

    test('Checkout practice has no score and no clock', () async {
      expect(GameMode.choice.hasScore, isFalse);
      expect(GameMode.choice.isTimed, isFalse);
      expect(GameMode.calculator.hasScore, isTrue);
      expect(GameMode.calculator.isTimed, isTrue);

      game.startGame(null, GameMode.choice);
      now += const Duration(minutes: 3);
      await followAdvice();
      final result = game.lastResult!;
      expect(result.isCorrect, isTrue);
      expect(result.score.kind, ScoreKind.none);
      expect(result.score.total, 0);
      expect(game.sessionPoints, 0);
      expect(game.sessionStreak, 0);
    });

    test('sound, saving and the undo limit belong to Checkout calculator only', () {
      expect(GameMode.calculator.hasSound, isTrue);
      expect(GameMode.calculator.isRecorded, isTrue);
      expect(GameMode.calculator.isChallenge, isTrue);
      for (final mode in [GameMode.choice, GameMode.input]) {
        expect(mode.hasSound, isFalse, reason: mode.name);
        expect(mode.isRecorded, isFalse, reason: mode.name);
        expect(mode.isChallenge, isFalse, reason: mode.name);
        expect(mode.isPractice, isTrue, reason: mode.name);
      }
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
      expect(result.score.total, 0);
      expect([AttemptOutcome.bust, AttemptOutcome.outOfDarts],
          contains(result.validation.outcome));
    });

    test('undo takes back a dart and its effect, with no limit', () {
      game.startGame(null, GameMode.choice);
      final start = game.round!.target;
      expect(game.undosLeft, isNull);
      for (var i = 0; i < 5; i++) {
        game.selectDart(DartThrow.parse('S1'));
        game.undo();
        expect(game.round!.remaining, start);
        expect(game.entered, isEmpty);
      }
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

    test('practice attempts saved by an older version no longer count', () async {
      final repo = HistoryRepository(storage);
      AttemptRecord rec(GameMode mode) => AttemptRecord(
            sessionId: 1, timestampMs: 1, target: 85, dartCount: 2,
            difficulty: DifficultyLevel.medium, correct: true, optimal: true,
            timeMs: 1000, points: 4, playerRoute: 'T17 D17', optimalRoute: 'T17 D17',
            mode: mode,
          );
      await repo.save([rec(GameMode.calculator), rec(GameMode.choice)]);
      final reloaded = build();
      await reloaded.init();
      expect(reloaded.history, hasLength(1));
      expect(reloaded.history.single.mode, GameMode.calculator);
    });
  });

  group('Reset statistics never touches the leaderboard', () {
    /// This player's row on the (local) leaderboard, as the board stores it.
    Future<LeaderboardEntry> myRow() async =>
        (await LocalLeaderboardRepository(storage).fetchEntries())
            .firstWhere((e) => !e.isSample && e.playerName == game.playerName);

    Future<void> playOptimal(int count) async {
      for (var i = 0; i < count; i++) {
        dealUntil((c) => c.hasCheckout);
        await solveOptimally();
      }
    }

    test('the row stays as it was, and keeps adding up afterwards', () async {
      await playOptimal(3);
      final before = await myRow();
      expect(before.attempts, 3);
      expect(before.totalPoints, greaterThan(0));

      await game.resetStatistics();
      expect(game.history, isEmpty);
      expect(game.summary.totalAttempts, 0);
      // Nothing was sent or deleted by the reset itself.
      final after = await myRow();
      expect(after.attempts, 3);
      expect(after.totalPoints, before.totalPoints);

      // The next result adds to the leaderboard totals, it does not restart them.
      await playOptimal(1);
      final next = await myRow();
      expect(next.attempts, 4);
      expect(next.totalPoints, greaterThan(before.totalPoints));
      // ... while the statistics start from zero.
      expect(game.summary.totalAttempts, 1);
    });

    test('also after the app is opened again', () async {
      await playOptimal(2);
      await game.resetStatistics();
      final reopened = build();
      await reopened.init();
      expect(reopened.history, isEmpty);
      game = reopened;
      await playOptimal(1);
      expect((await myRow()).attempts, 3);
      expect(game.summary.totalAttempts, 1);
    });

    test('an older install (statistics only) keeps its score when the record is created', () async {
      await playOptimal(2);
      // As saved by a version from before the leaderboard had its own record.
      await storage.remove(GameController.leaderboardRecordKey);
      final updated = build();
      await updated.init();
      game = updated;
      expect(game.history, hasLength(2));
      await game.resetStatistics();
      await playOptimal(1);
      expect((await myRow()).attempts, 3, reason: 'the two earlier attempts still count');
    });

    test('the leaderboard record is saved apart from the statistics', () async {
      await playOptimal(2);
      expect(await storage.read(GameController.leaderboardRecordKey), isNotNull);
      await game.resetStatistics();
      expect(await storage.read(HistoryRepository.storageKey), isNull);
      expect(await storage.read(GameController.leaderboardRecordKey), isNotNull);
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

  group('Checkout calculator', () {
    test('starts on the menu and enters playing with three boxes, some used', () {
      expect(game.phase, GamePhase.menu);
      game.startGame(DifficultyLevel.hard);
      expect(game.phase, GamePhase.playing);
      final c = game.challenge!;
      expect(c.layout.freeCount + c.layout.used.length, Visit.darts);
      expect(c.dartsLeft, c.optimalRoute.length);
      expect(game.entered, isEmpty);
    });

    test('boxes fill left to right, cap at the free darts, undo works', () {
      game.startGame(DifficultyLevel.medium);
      final n = game.challenge!.dartsLeft;
      for (var i = 0; i < n + 2; i++) {
        game.selectDart(DartThrow.parse('S1'));
      }
      expect(game.entered, hasLength(n));
      expect(game.isHandFull, isTrue);
      game.undo();
      expect(game.entered, hasLength(n - 1));
    });

    test('submit is ignored until every free box is filled', () async {
      game.startGame(DifficultyLevel.hard);
      await game.submit();
      expect(game.phase, GamePhase.playing);
    });

    test('a right answer with time left scores 1, then 2, then 3 in a row', () async {
      game.startGame(DifficultyLevel.easy);
      now += const Duration(milliseconds: 4820);
      await solveOptimally();
      var result = game.lastResult!;
      expect(game.phase, GamePhase.result);
      expect(result.isCorrect && result.isOptimal, isTrue);
      expect(result.elapsed, const Duration(milliseconds: 4820));
      expect(result.score.kind, ScoreKind.counted);
      expect(result.score.total, 1);
      expect(game.sessionPoints, 1);
      expect(game.sessionStreak, 1);

      now += const Duration(seconds: 30); // time after submit must not matter
      expect(game.elapsed, const Duration(milliseconds: 4820));

      game.nextCheckout();
      await solveOptimally();
      expect(game.lastResult!.score.total, 2);
      game.nextCheckout();
      await solveOptimally();
      expect(game.lastResult!.score.total, 3);
      expect(game.sessionPoints, 6);
      expect(game.sessionStreak, 3);

      // Saved: one record per attempt, with the points won.
      expect(game.history, hasLength(3));
      expect(game.history.map((r) => r.points), [1, 2, 3]);
      expect(game.summary.successes, 3);
      expect(game.summary.totalPoints, 6);
    });

    test('a miss scores nothing and the streak starts again from 0', () async {
      game.startGame(DifficultyLevel.easy);
      await solveOptimally();
      game.nextCheckout();
      await solveOptimally();
      expect(game.sessionStreak, 2);
      game.nextCheckout();
      await missOnPurpose();
      final result = game.lastResult!;
      expect(result.isCorrect, isFalse);
      expect(result.score.kind, ScoreKind.miss);
      expect(result.score.total, 0, reason: 'a miss costs nothing');
      expect(game.sessionStreak, 0);
      expect(game.sessionPoints, 3, reason: '1 + 2, nothing taken away');
      expect(game.summary.failures, 1);
      game.nextCheckout();
      await solveOptimally();
      expect(game.lastResult!.score.total, 1, reason: 'the count starts again');
    });

    test('a right answer after the clock ran out scores 0 and keeps the streak', () async {
      game.startGame(DifficultyLevel.easy);
      await solveOptimally();
      expect(game.sessionStreak, 1);
      game.nextCheckout();
      now += const Duration(milliseconds: 38330);
      await solveOptimally();
      final result = game.lastResult!;
      expect(result.isCorrect, isTrue);
      expect(result.elapsed, const Duration(milliseconds: 38330));
      expect(result.score.kind, ScoreKind.late);
      expect(result.score.total, 0);
      expect(game.sessionStreak, 1, reason: 'kept, but it did not grow');
      expect(game.history.last.timeMs, 38330); // not -8330
      // The clock stays frozen on the result screen.
      now += const Duration(seconds: 20);
      expect(game.remaining, const Duration(milliseconds: -8330));
    });

    test('clock counts down from 30s and goes negative past zero', () {
      game.startGame();
      expect(game.timeLimit, const Duration(seconds: 30));
      expect(game.remaining, const Duration(seconds: 30));
      now += const Duration(seconds: 12);
      expect(game.remaining, const Duration(seconds: 18));
      now += const Duration(seconds: 18);
      expect(game.remaining, Duration.zero);
      now += const Duration(milliseconds: 8330);
      expect(game.remaining, const Duration(milliseconds: -8330));
      expect(game.remaining.isNegative, isTrue);
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

    test('leaving mid-checkout records nothing', () async {
      game.startGame();
      game.selectDart(DartThrow.parse('S1'));
      game.quitToMenu();
      expect(game.phase, GamePhase.menu);
      expect(game.challenge, isNull);
      expect(game.entered, isEmpty);
      expect(game.history, isEmpty);
      expect(game.sessionPoints, 0);
    });

    test('history and the leaderboard persist across controller instances', () async {
      game.startGame(DifficultyLevel.hard);
      await solveOptimally();
      final reloaded = build();
      await reloaded.init();
      expect(reloaded.history, hasLength(1));
      expect(reloaded.summary.totalPoints, game.summary.totalPoints);
      final board = await game.leaderboard(LeaderboardSort.points);
      expect(board.map((e) => e.playerName), contains(game.playerName));
    });
  });

  group('Undo: 3 per session in Checkout calculator', () {
    test('three undos, then it cannot be pressed any more', () {
      game.startGame();
      expect(game.undosLeft, 3);
      for (var left = 3; left > 0; left--) {
        game.selectDart(DartThrow.parse('S1'));
        expect(game.canUndo, isTrue);
        game.undo();
        expect(game.undosLeft, left - 1);
      }
      game.selectDart(DartThrow.parse('S1'));
      expect(game.undosLeft, 0);
      expect(game.canUndo, isFalse);
      game.undo(); // ignored
      expect(game.entered, hasLength(1));
      expect(game.undosLeft, 0);
    });

    test('it is shared by all the checkouts of the session', () async {
      game.startGame();
      game.selectDart(DartThrow.parse('S1'));
      game.undo();
      await missOnPurpose();
      game.nextCheckout();
      expect(game.undosLeft, 2, reason: 'still the same session');
    });

    test('choosing the game again gives three more', () {
      game.startGame();
      for (var i = 0; i < 3; i++) {
        game.selectDart(DartThrow.parse('S1'));
        game.undo();
      }
      expect(game.undosLeft, 0);
      game.quitToMenu();
      game.startGame();
      expect(game.undosLeft, 3);
    });

    test('Escape (clear) cannot be used to get round the limit', () {
      game.startGame();
      game.selectDart(DartThrow.parse('S1'));
      game.clear();
      expect(game.entered, hasLength(1));
    });

    test('the practice modes have no limit', () {
      for (final mode in [GameMode.choice]) {
        game.startGame(null, mode);
        expect(game.undosLeft, isNull);
      }
      game.startGame(null, GameMode.input);
      expect(game.enterNumber(85), NumberEntry.accepted);
      expect(game.undosLeft, isNull);
    });
  });

  group('No checkout', () {
    test('numbers with no checkout are dealt, with all three boxes free', () {
      dealUntil((c) => !c.hasCheckout);
      final c = game.challenge!;
      expect(c.layout, BoxLayout.all);
      expect(c.dartsLeft, 3);
      expect(game.currentOptimalRoutes, isEmpty);
    });

    test('the right answer: scored like a checkout, with an encouragement', () async {
      dealUntil((c) => !c.hasCheckout);
      final target = game.challenge!.target;
      now += const Duration(seconds: 4);
      await game.pressNoCheckout();
      final result = game.lastResult!;
      expect(game.phase, GamePhase.result);
      expect(result.isCorrect, isTrue);
      expect(result.isNoCheckoutAnswer, isTrue);
      expect(result.isOptimal, isTrue);
      expect(result.playerRoute.isEmpty, isTrue, reason: 'no darts used');
      expect(result.optimalRoutes, isEmpty);
      expect(result.encouragement, isNotNull);
      expect(Phrases.encouragements, contains(result.encouragement));
      expect(result.score.total, 1);
      expect(game.sessionStreak, 1);
      final saved = game.history.single;
      expect(saved.target, target);
      expect(saved.dartCount, 0);
      expect(saved.correct && saved.optimal, isTrue);
    });

    test('pressed on a number that has a checkout: a miss', () async {
      dealUntil((c) => c.hasCheckout);
      await game.pressNoCheckout();
      final result = game.lastResult!;
      expect(result.isCorrect, isFalse);
      expect(result.validation.outcome, AttemptOutcome.noCheckoutWrong);
      expect(result.encouragement, isNull);
      expect(result.score.kind, ScoreKind.miss);
      expect(game.sessionStreak, 0);
    });

    test('entering darts on a number with no checkout is wrong', () async {
      dealUntil((c) => !c.hasCheckout);
      for (var i = 0; i < 3; i++) {
        game.selectDart(DartThrow.parse('T20'));
      }
      expect(game.isHandFull, isTrue);
      await game.submit();
      expect(game.lastResult!.isCorrect, isFalse);
      expect(game.lastResult!.validation.outcome, AttemptOutcome.noCheckoutMissed);
    });

    test('late is late: a right "No checkout" after the clock ran out scores 0', () async {
      dealUntil((c) => !c.hasCheckout);
      now += const Duration(seconds: 45);
      await game.pressNoCheckout();
      expect(game.lastResult!.isCorrect, isTrue);
      expect(game.lastResult!.score.kind, ScoreKind.late);
      expect(game.lastResult!.score.total, 0);
    });

    test('only in Checkout calculator', () async {
      game.startGame(null, GameMode.choice);
      await game.pressNoCheckout();
      expect(game.phase, GamePhase.playing);
    });
  });

  group('Replay checkout', () {
    test('calculator: the same number and boxes, no points, no clock, nothing saved', () async {
      game.startGame(DifficultyLevel.easy);
      await solveOptimally();
      final before = game.lastResult!.challenge;
      expect(game.sessionPoints, 1);

      game.replayCheckout();
      expect(game.phase, GamePhase.playing);
      expect(game.isReplay, isTrue);
      expect(game.challenge, before);
      expect(game.challenge!.layout, before.layout);
      expect(game.entered, isEmpty);
      expect(game.undosLeft, isNull, reason: 'a replay has no undo limit');

      await solveOptimally();
      final result = game.lastResult!;
      expect(result.isReplay, isTrue);
      expect(result.isCorrect, isTrue);
      expect(result.score.kind, ScoreKind.none);
      expect(result.score.total, 0);
      expect(game.sessionPoints, 1, reason: 'unchanged');
      expect(game.sessionStreak, 1, reason: 'unchanged');
      expect(game.history, hasLength(1), reason: 'nothing saved');
    });

    test('Next checkout after a replay carries on normally', () async {
      game.startGame(DifficultyLevel.easy);
      await solveOptimally();
      game.replayCheckout();
      await solveOptimally();
      game.nextCheckout();
      expect(game.isReplay, isFalse);
      expect(game.phase, GamePhase.playing);
      expect(game.undosLeft, 3);
      await solveOptimally();
      expect(game.lastResult!.isReplay, isFalse);
      expect(game.lastResult!.score.total, 2, reason: 'the streak went on: 1, then 2');
      expect(game.history, hasLength(2));
    });

    test('practice: the same number from the start, again and again', () async {
      game.startGame(null, GameMode.choice);
      final target = game.challenge!.target;
      for (var i = 0; i < 3; i++) {
        await followAdvice();
        expect(game.lastResult!.isCorrect, isTrue);
        game.replayCheckout();
        expect(game.challenge!.target, target);
        expect(game.round!.remaining, target);
        expect(game.round!.dartsLeft, game.challenge!.dartsLeft);
        expect(game.entered, isEmpty);
        expect(game.lastResult, isNull);
      }
    });

    test('works after a miss too, and only on the result screen', () async {
      game.startGame();
      final target = game.challenge!.target;
      game.replayCheckout(); // still playing: ignored
      expect(game.isReplay, isFalse);
      await missOnPurpose();
      game.replayCheckout();
      expect(game.challenge!.target, target);
      expect(game.isReplay, isTrue);
    });
  });

  group('Checkout input', () {
    test('waits for a number, with no checkout on screen', () {
      game.startGame(null, GameMode.input);
      expect(game.phase, GamePhase.entering);
      expect(game.challenge, isNull);
      expect(game.round, isNull);
    });

    test('numbers below 2 and above 170 are refused', () {
      game.startGame(null, GameMode.input);
      for (final n in [-5, 0, 1, 171, 999]) {
        expect(game.enterNumber(n), NumberEntry.outOfRange, reason: '$n');
        expect(game.phase, GamePhase.entering);
      }
    });

    test('a number with a checkout starts a practice round on it', () async {
      game.startGame(null, GameMode.input);
      expect(game.enterNumber(57), NumberEntry.accepted);
      expect(game.phase, GamePhase.playing);
      expect(game.challenge!.target, 57);
      expect(game.round, isNotNull);
      expect(game.round!.target, 57);
      expect(game.choiceHints, isNotEmpty);
      await followAdvice();
      expect(game.lastResult!.isCorrect && game.lastResult!.isOptimal, isTrue);
      expect(game.history, isEmpty, reason: 'nothing is saved in Checkout input');
      expect(game.lastResult!.score.kind, ScoreKind.none);
    });

    test('one-dart numbers are allowed here', () {
      game.startGame(null, GameMode.input);
      expect(game.enterNumber(40), NumberEntry.accepted);
      expect(game.challenge!.dartCount, 1);
      expect(game.round!.dartsLeft, 1);
      expect(game.choiceHints, {DartThrow.parse('D20')});
    });

    test('a number with no checkout shows the impossible screen and an insult', () {
      game.startGame(null, GameMode.input);
      for (final n in [159, 162, 163, 165, 166, 168, 169]) {
        game.startGame(null, GameMode.input);
        expect(game.enterNumber(n), NumberEntry.impossible, reason: '$n');
        expect(game.phase, GamePhase.impossible);
        expect(game.impossibleNumber, n);
        expect(Phrases.insults, contains(game.insult));
        expect(game.challenge, isNull, reason: 'no game is shown');
      }
    });

    test('Next checkout goes back to typing a number, from every screen', () async {
      game.startGame(null, GameMode.input);
      game.enterNumber(169);
      game.nextCheckout();
      expect(game.phase, GamePhase.entering);
      expect(game.impossibleNumber, isNull);

      game.enterNumber(85);
      await followAdvice();
      game.nextCheckout();
      expect(game.phase, GamePhase.entering);
    });

    test('Replay checkout plays the same number again', () async {
      game.startGame(null, GameMode.input);
      game.enterNumber(85);
      await followAdvice();
      game.replayCheckout();
      expect(game.challenge!.target, 85);
      expect(game.round!.remaining, 85);
      expect(game.isReplay, isTrue);
    });

    test('a number is only accepted while waiting for one', () {
      game.startGame(null, GameMode.input);
      game.enterNumber(85);
      expect(game.enterNumber(57), NumberEntry.outOfRange);
      expect(game.challenge!.target, 85);
    });
  });

  test('every mode but the calculator is excluded from statistics and the leaderboard', () async {
    for (final mode in [GameMode.choice, GameMode.input]) {
      game.startGame(null, mode);
      if (mode == GameMode.input) game.enterNumber(72);
      await followAdvice();
    }
    expect(game.history, isEmpty);
    expect(game.summary.totalAttempts, 0);
    expect(game.sessionPoints, 0);
  });
}
