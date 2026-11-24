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
        storage: storage,
        timerFactory: () => AttemptTimer(() => now),
        random: Random(3),
      );

  /// Starts calculator checkouts until one is dealt that [wanted] accepts.
  // Checkout practice's Input: types [n] as a new number (Play plays it at once).
  void typeNumber(int n) {
    for (final digit in '$n'.split('')) {
      game.typeDigit(int.parse(digit));
    }
  }

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
      // Practice is for learning: no statistics.
      expect(game.history, isEmpty);
      expect(game.summary.totalAttempts, 0);
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
      for (final mode in [GameMode.choice]) {
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

  test('the record of the leaderboard (no more) is taken off the phone', () async {
    await storage.write(GameController.oldLeaderboardRecordKey, '[]');
    final reopened = build();
    await reopened.init();
    expect(await storage.read(GameController.oldLeaderboardRecordKey), isNull);
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

    test('history persists across controller instances', () async {
      game.startGame(DifficultyLevel.hard);
      await solveOptimally();
      final reloaded = build();
      await reloaded.init();
      expect(reloaded.history, hasLength(1));
      expect(reloaded.summary.totalPoints, game.summary.totalPoints);
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
      game.startGame(null, GameMode.choice);
      typeNumber(85);
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

  group('Checkout practice: Input', () {
    test('the number dealt is in Input too; the next digit starts a new number', () {
      game.startGame(null, GameMode.choice);
      expect(game.numberInput.digits, '${game.challenge!.target}');
      game.typeDigit(5);
      expect(game.numberInput.digits, '5');
    });

    test('numbers below 2 and above 170 change nothing', () {
      game.startGame(null, GameMode.choice);
      final dealt = game.challenge!.target;
      typeNumber(1);
      expect(game.challenge!.target, dealt);
      game.startGame(null, GameMode.choice);
      typeNumber(171);
      expect(game.numberInput.number, isNull);
      expect(game.challenge!.target, 17, reason: 'the last number that could be played');
    });

    test('a number with a checkout is at once the round played', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(57);
      expect(game.phase, GamePhase.playing);
      expect(game.challenge!.target, 57);
      expect(game.round!.target, 57);
      expect(game.choiceHints, isNotEmpty);
      await followAdvice();
      expect(game.lastResult!.isCorrect && game.lastResult!.isOptimal, isTrue);
      expect(game.history, isEmpty, reason: 'nothing is saved in Checkout practice');
      expect(game.lastResult!.score.kind, ScoreKind.none);
    });

    test('one-dart numbers are allowed here', () {
      game.startGame(null, GameMode.choice);
      typeNumber(40);
      expect(game.challenge!.dartCount, 1);
      expect(game.round!.dartsLeft, 1);
      expect(game.choiceHints, {DartThrow.parse('D20')});
    });

    test('a number with no checkout says so, with an insult; Next checkout deals another', () {
      for (final n in [159, 162, 163, 165, 166, 168, 169]) {
        game.startGame(null, GameMode.choice);
        typeNumber(n);
        expect(game.impossibleNumber, n, reason: '$n');
        expect(Phrases.insults, contains(game.insult));
      }
      game.nextCheckout();
      expect(game.impossibleNumber, isNull);
      expect(game.phase, GamePhase.playing);
      expect(game.numberInput.digits, '${game.challenge!.target}');
      // A number that can be played clears it too.
      typeNumber(169);
      for (var i = 0; i < 3; i++) {
        game.deleteDigit(); // UNDO, three times
      }
      typeNumber(85);
      expect(game.impossibleNumber, isNull);
      expect(game.challenge!.target, 85);
    });

    test('Replay checkout plays the same number again', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(85);
      await followAdvice();
      game.replayCheckout();
      expect(game.challenge!.target, 85);
      expect(game.round!.remaining, 85);
      expect(game.isReplay, isTrue);
    });

    test('nothing is typed into Checkout calculator', () {
      game.startGame(null, GameMode.calculator);
      final dealt = game.challenge!.target;
      typeNumber(85);
      expect(game.challenge!.target, dealt);
    });

    test('a number typed while the answer shows is played at once (or says it has no checkout)', () async {
      game.startGame(null, GameMode.choice);
      final other = game.challenge!.target == 57 ? 58 : 57;
      await followAdvice();
      expect(game.phase, GamePhase.result);
      typeNumber(other);
      expect(game.phase, GamePhase.playing);
      expect(game.challenge!.target, other);
      await followAdvice();
      game.nextCheckout(); // a dealt number: the next digit starts a new one
      await followAdvice();
      typeNumber(169);
      expect(game.impossibleNumber, 169);
      expect(game.phase, GamePhase.playing);
      expect(game.lastResult, isNull, reason: 'the answer of the last number is gone');
      game.replayCheckout();
      expect(game.impossibleNumber, 169, reason: 'nothing to play again');
    });

    test('Replay and Next work while a number is played, in Checkout choice only', () {
      game.startGame(null, GameMode.choice);
      typeNumber(85);
      game.selectDart(game.choiceHints.first);
      game.replayCheckout();
      expect(game.phase, GamePhase.playing);
      expect(game.entered, isEmpty);
      expect(game.challenge!.target, 85);
      game.nextCheckout();
      expect(game.entered, isEmpty);
      expect(game.numberInput.digits, '${game.challenge!.target}');
      dealUntil((c) => c.hasCheckout);
      final dealt = game.challenge;
      game.nextCheckout();
      game.replayCheckout();
      expect(identical(game.challenge, dealt), isTrue, reason: 'the calculator plays its number out first');
    });

    test('its parts are about the number played, as in Checkout calculator', () async {
      final parts = ChoiceParts(game, []);
      game.startGame(null, GameMode.choice);
      typeNumber(85);
      expect(parts.shownTarget, 85);
      expect(parts.learnDarts, game.challenge!.dartsLeft);
      parts.learnDarts = 1;
      expect(parts.learnDarts, 1);
      expect(parts.learnCard!.darts, 1);
      expect(parts.practiceReview, isNull, reason: 'not played out yet');
      await followAdvice();
      expect(parts.practiceReview!.kind, ReviewKind.optimal);
      expect(parts.practiceTarget, 85);
      game.nextCheckout();
      expect(parts.learnDarts, game.challenge!.dartsLeft, reason: 'a new number starts with its own darts');
      expect(parts.practiceReview, isNull);
      typeNumber(169);
      expect(parts.shownTarget, 169);
      expect(parts.learnCard, isNull);
    });
  });

  test('every mode but the calculator is excluded from statistics', () async {
    game.startGame(null, GameMode.choice);
    await followAdvice();
    game.startGame(null, GameMode.choice);
    typeNumber(72); // a number typed in Input
    await followAdvice();
    expect(game.history, isEmpty);
    expect(game.summary.totalAttempts, 0);
    expect(game.sessionPoints, 0);
  });

  group('A two-dart number over 60 with three darts', () {
    test('the calculator deals it with all three boxes free and three-dart answers', () async {
      dealUntil((c) => c.hasExtraDart);
      final c = game.challenge!;
      expect(c.dartCount, 2);
      expect(c.target, greaterThan(60));
      expect(c.layout, BoxLayout.all);
      expect(c.dartsLeft, 3);
      expect(game.currentOptimalRoutes, isNotEmpty);
      expect(game.currentOptimalRoutes.every((r) => r.length <= 3), isTrue);
      await solveOptimally();
      expect(game.lastResult!.isCorrect, isTrue);
      expect(game.lastResult!.isOptimal, isTrue);
    });

    // A two-dart number whose two-dart route is not its route with three darts
    // (64: T14 D11 with two, T16 D8 with three).
    bool differsWithThree(Challenge c) =>
        c.hasExtraDart && !optimalService.isOptimalIn(c.target, 3, optimalService.optimalRoute(c.target)!);

    test('checking out in two darts with an optimal route is good, but not in the given number of darts - and it counts', () async {
      dealUntil(differsWithThree);
      final c = game.challenge!;
      final two = optimalService.optimalRoute(c.target)!;
      for (final d in two.darts) {
        game.selectDart(d);
      }
      expect(game.isHandFull, isTrue, reason: 'the number is reached with a box still free');
      await game.submit();
      final result = game.lastResult!;
      expect(result.isCorrect, isTrue);
      expect(result.isOptimal, isFalse, reason: 'not the optimal route of the darts given');
      expect(result.validation.outcome, AttemptOutcome.goodButFewerDarts);
      expect(result.validation.message, contains('Good, but not in the given number of darts'));
      expect(result.validation.message, contains('you were given 3'));
      expect(result.score.total, greaterThan(0), reason: 'a right answer: points');
      expect(game.sessionStreak, 1);
    });

    test('practice: pressing the boxes switches between two and three darts', () {
      game.startGame(null, GameMode.choice);
      typeNumber(64);
      expect(game.challenge!.darts, 2, reason: 'a typed number starts on its fewest darts');
      expect(game.canChooseDarts, isTrue);
      game.chooseOtherDarts();
      expect(game.challenge!.darts, 3);
      expect(game.round!.maxDarts, 3);
      expect(game.choiceHints, {for (final d in ['T16', 'T8', 'T20', 'T18']) DartThrow.parse(d)});
      game.chooseOtherDarts();
      expect(game.challenge!.darts, 2);
      expect(game.choiceHints, {DartThrow.parse('T14')});
      // Not once two darts are thrown.
      game.chooseOtherDarts();
      game.selectDart(DartThrow.parse('S16'));
      game.selectDart(DartThrow.parse('S16'));
      expect(game.canChooseDarts, isFalse);
    });

    test('after the first dart the boxes still switch, and the dart stays', () {
      game.startGame(null, GameMode.choice);
      typeNumber(68);
      game.chooseOtherDarts(); // three darts
      expect(game.choiceHints, {for (final d in ['T12', 'T20', 'T16', 'T18']) DartThrow.parse(d)});
      game.selectDart(DartThrow.parse('T12')); // leaves 32
      expect(game.canChooseDarts, isTrue);
      game.chooseOtherDarts(); // two darts: one left
      expect(game.challenge!.darts, 2);
      expect(game.entered, [DartThrow.parse('T12')]);
      expect(game.round!.remaining, 32);
      expect(game.round!.dartsLeft, 1);
      expect(game.choiceHints, {DartThrow.parse('D16')});
      expect(game.round!.steps.single.quality, DartQuality.optimal, reason: 'kept as rated with three darts');
    });

    test('88: T20 leaves D14 - lit with three darts and with two', () {
      game.startGame(null, GameMode.choice);
      typeNumber(88);
      game.chooseOtherDarts(); // three darts
      game.selectDart(DartThrow.parse('T20'));
      expect(game.choiceHints, {DartThrow.parse('D14')});
      game.chooseOtherDarts(); // two darts: one left
      expect(game.choiceHints, {DartThrow.parse('D14')});
    });

    test('one- and three-dart numbers have no choice; every two-dart number has', () {
      for (final n in [40, 50, 150]) {
        game.startGame(null, GameMode.choice);
        typeNumber(n);
        expect(game.canChooseDarts, isFalse, reason: '$n');
      }
      for (final n in [3, 47, 60, 61]) {
        game.startGame(null, GameMode.choice);
        typeNumber(n);
        expect(game.canChooseDarts, isTrue, reason: '$n');
      }
    });

    test('47 with three darts: S7, then D20 finishes with a dart in hand and is optimal', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(47);
      expect(game.challenge!.darts, 2); // under 60 it starts on two darts
      expect(game.canChooseDarts, isTrue);
      game.chooseOtherDarts();
      expect(game.challenge!.darts, 3);
      expect(game.choiceHints, containsAll([for (final d in ['S7', 'S15', 'S19']) DartThrow.parse(d)]));
      game.selectDart(DartThrow.parse('S7'));
      expect(game.choiceHints, {DartThrow.parse('D20')});
      game.selectDart(DartThrow.parse('D20'));
      await game.submit();
      expect(game.lastResult!.isCorrect, isTrue);
      expect(game.lastResult!.isOptimal, isTrue);
      expect(game.lastResult!.validation.outcome, AttemptOutcome.correct);
      // The popup lists the table's route and those of the targets almost as good.
      expect(game.lastResult!.optimalRoutes.map((r) => r.notation),
          containsAll(['S7 D20', 'S15 D16', 'S19 D14']));
    });

    test('47 with three darts: the double missed into S20, then D10 checks out', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(47);
      game.chooseOtherDarts();
      game.selectDart(DartThrow.parse('S7'));
      game.selectDart(DartThrow.parse('S20'));
      expect(game.choiceHints, {DartThrow.parse('D10')});
      game.selectDart(DartThrow.parse('D10'));
      await game.submit();
      expect(game.lastResult!.isCorrect, isTrue);
      expect(game.lastResult!.isOptimal, isFalse, reason: 'S20 was not the lit D20');
    });

    test('47: three darts back to two after the first dart lights the double of two darts', () {
      game.startGame(null, GameMode.choice);
      typeNumber(47);
      game.chooseOtherDarts();
      game.selectDart(DartThrow.parse('S7'));
      expect(game.canChooseDarts, isTrue);
      game.chooseOtherDarts();
      expect(game.challenge!.darts, 2);
      expect(game.choiceHints, {DartThrow.parse('D20')});
    });

    test('a number under 60 stays on two darts in the calculator', () {
      game.startGame(null, GameMode.calculator);
      expect(game.canChooseDarts, isFalse);
    });

    test('74 with three darts: T14 then D16 with a dart in hand is the table\'s route: optimal', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(74);
      game.chooseOtherDarts();
      expect(game.challenge!.darts, 3);
      expect(game.choiceHints, contains(DartThrow.parse('T14')));
      game.selectDart(DartThrow.parse('T14')); // leaves 32
      expect(game.round!.remaining, 32);
      expect(game.round!.steps.first.quality, DartQuality.optimal);
      game.selectDart(DartThrow.parse('D16'));
      await game.submit();
      final result = game.lastResult!;
      expect(result.validation.outcome, AttemptOutcome.correct);
      expect(result.isOptimal, isTrue);
      expect(result.playerRoute.isCheckoutFor(74), isTrue, reason: 'it can be a favorite');
    });

    test('64 with three darts: the two-dart T14 D11 is good, but not in the given number of darts', () async {
      game.startGame(null, GameMode.choice);
      typeNumber(64);
      game.chooseOtherDarts();
      game.selectDart(DartThrow.parse('T14')); // not lit with three darts: T16 and T8
      game.selectDart(DartThrow.parse('D11'));
      await game.submit();
      expect(game.lastResult!.isCorrect, isTrue);
      expect(game.lastResult!.isOptimal, isFalse);
    });

    test('there is no choosing in the calculator', () {
      dealUntil((c) => c.dartCount == 2 && c.target > 60);
      expect(game.canChooseDarts, isFalse);
    });
  });

  group('Every undo used and then a miss: the session is over', () {
    Future<void> useAllUndos() async {
      for (var i = 0; i < GameController.maxUndos; i++) {
        game.selectDart(DartThrow.parse('S1'));
        game.undo();
      }
      expect(game.undosLeft, 0);
    }

    test('only Replay session is left, which starts a new session', () async {
      dealUntil((c) => c.hasCheckout);
      await solveOptimally();
      final points = game.sessionPoints;
      expect(points, greaterThan(0));
      game.nextCheckout();
      await useAllUndos();
      await missOnPurpose();
      expect(game.isSessionOver, isTrue);
      expect(game.sessionPoints, points, reason: 'the total stays on screen');
      final target = game.challenge!.target;
      game.nextCheckout(); // ignored
      game.replayCheckout(); // ignored
      expect(game.phase, GamePhase.result);
      expect(game.challenge!.target, target);
      game.replaySession();
      expect(game.isSessionOver, isFalse);
      expect(game.phase, GamePhase.playing);
      expect(game.sessionPoints, 0);
      expect(game.undosLeft, 3);
    });

    test('a good-but-fewer-darts finish counts as right, so it does not end the session', () async {
      dealUntil((c) =>
          c.hasExtraDart && !optimalService.isOptimalIn(c.target, 3, optimalService.optimalRoute(c.target)!));
      await useAllUndos();
      for (final d in optimalService.optimalRoute(game.challenge!.target)!.darts) {
        game.selectDart(d);
      }
      await game.submit();
      expect(game.lastResult!.validation.outcome, AttemptOutcome.goodButFewerDarts);
      expect(game.isSessionOver, isFalse);
      game.nextCheckout(); // carries on
      expect(game.phase, GamePhase.playing);
    });

    test('a miss with undos left, or a right answer with none, carries on', () async {
      dealUntil((c) => c.hasCheckout);
      await missOnPurpose();
      expect(game.isSessionOver, isFalse);
      game.nextCheckout();
      await useAllUndos();
      await solveOptimally();
      expect(game.isSessionOver, isFalse);
    });

    test('not in a replay, and not in the practice modes', () async {
      dealUntil((c) => c.hasCheckout);
      await useAllUndos();
      await solveOptimally();
      game.replayCheckout();
      await missOnPurpose();
      expect(game.isSessionOver, isFalse);
      game.startGame(null, GameMode.choice);
      game.selectDart(DartThrow.parse('S1'));
      game.undo();
      expect(game.isSessionOver, isFalse);
    });
  });
}
