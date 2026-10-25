import 'dart:math';

import '../content/phrases.dart';
import '../domain/challenge.dart';
import '../domain/challenge_generator.dart';
import '../domain/checkout_engine.dart';
import '../domain/checkout_route.dart';
import '../domain/checkout_validator.dart';
import '../domain/choice_advisor.dart';
import '../domain/choice_round.dart';
import '../domain/dart_throw.dart';
import '../domain/difficulty.dart';
import '../domain/optimal_route_service.dart';
import '../favorites/favorites.dart';
import '../leaderboard/leaderboard_service.dart';
import '../scoring/scoring_service.dart';
import '../stats/attempt_record.dart';
import '../stats/history_repository.dart';
import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';
import '../timing/attempt_timer.dart';
import 'game_mode.dart';

/// menu: away from a checkout. entering: Checkout input is waiting for a
/// number. impossible: the number entered has no checkout. playing / result:
/// a checkout is on screen / has just been answered.
enum GamePhase { menu, entering, impossible, playing, result }

/// What happened to a number typed into Checkout input.
enum NumberEntry { accepted, impossible, outOfRange }

/// Everything the result screen needs to display.
class AttemptResult {
  const AttemptResult({
    required this.challenge,
    required this.validation,
    required this.score,
    required this.elapsed,
    required this.optimalRoutes,
    this.round,
    this.isReplay = false,
    this.encouragement,
  });

  final Challenge challenge;
  final ValidationResult validation;
  final ScoreBreakdown score;
  final Duration elapsed;

  /// Primary optimal route first, then every equally optimal alternative.
  /// Empty for a number with no checkout.
  final List<CheckoutRoute> optimalRoutes;

  /// The darts chosen, with their ratings. Only set in the practice modes.
  final ChoiceRound? round;

  /// A replay: no clock, no score, nothing saved.
  final bool isReplay;

  /// For a right "No checkout": one of the 1000 encouragements.
  final String? encouragement;

  bool get isPractice => round != null;

  bool get isCorrect => validation.isCorrect;
  bool get isOptimal => validation.isOptimal;
  CheckoutRoute get playerRoute => validation.playerRoute;

  /// A right "No checkout" press: the empty-board "Good job" screen.
  bool get isNoCheckoutAnswer => validation.outcome == AttemptOutcome.noCheckoutCorrect;
}

/// Orchestrates one play session: menu -> playing -> result -> next.
/// Holds state only; all rules live in the injected services.
class GameController {
  GameController({
    required ChallengeGenerator generator,
    required CheckoutValidator validator,
    required OptimalRouteService optimal,
    required ChoiceAdvisor advisor,
    required ScoringService scoring,
    required StatisticsService statistics,
    required HistoryRepository history,
    required LeaderboardService leaderboard,
    required StorageService storage,
    AttemptTimer Function()? timerFactory,
    DateTime Function()? now,
    Random? random,
  })  : _generator = generator,
        _validator = validator,
        _optimal = optimal,
        _advisor = advisor,
        _scoring = scoring,
        _statistics = statistics,
        _historyRepo = history,
        _leaderboard = leaderboard,
        _storage = storage,
        _timerFactory = timerFactory ?? AttemptTimer.new,
        _now = now ?? DateTime.now,
        _random = random ?? Random(),
        _timer = (timerFactory ?? AttemptTimer.new)();

  static const String playerNameKey = 'dartle.player.v1';
  static const String defaultPlayerName = 'Player';

  /// Where the leaderboard's own record of attempts is saved. "Reset
  /// statistics" never touches it, so a reset cannot change the leaderboard.
  static const String leaderboardRecordKey = 'dartle.leaderboard-record.v1';

  /// Undo can be used this many times per session in Checkout calculator.
  static const int maxUndos = 3;

  final ChallengeGenerator _generator;
  final CheckoutValidator _validator;
  final OptimalRouteService _optimal;
  final ChoiceAdvisor _advisor;
  final ScoringService _scoring;
  final StatisticsService _statistics;
  final HistoryRepository _historyRepo;
  final LeaderboardService _leaderboard;
  final StorageService _storage;
  final AttemptTimer Function() _timerFactory;
  final DateTime Function() _now;
  final Random _random;

  final List<void Function()> _listeners = [];
  final List<DartThrow> _entered = [];

  /// What the Statistics screen shows; "Reset statistics" clears it.
  List<AttemptRecord> _history = [];

  /// What the leaderboard is worked out from. Separate from [_history], and
  /// never cleared by a reset.
  List<AttemptRecord> _leaderboardRecord = [];
  late final HistoryRepository _leaderboardRecordRepo =
      HistoryRepository(_storage, key: leaderboardRecordKey);

  /// The routes the player marked with the dart icon, saved on this device. A
  /// number with only one optimal route has it as a favorite from the start.
  late final Favorites favorites = Favorites(_storage, defaults: _onlyRoutes());

  /// Every number's only optimal route, for the numbers (and numbers of darts)
  /// that have just one.
  Map<int, List<CheckoutRoute>> _onlyRoutes() {
    final only = <int, List<CheckoutRoute>>{};
    for (var n = CheckoutEngine.minCheckout; n <= CheckoutEngine.maxCheckout; n++) {
      for (final routes in [
        _optimal.optimalRoutes(n),
        if (_optimal.hasThreeDartOption(n)) _optimal.optimalRoutesIn(n, 3),
      ]) {
        if (routes.length == 1) only.putIfAbsent(n, () => []).add(routes.single);
      }
    }
    return only;
  }
  AttemptTimer _timer;

  GamePhase _phase = GamePhase.menu;
  GameMode _mode = GameMode.calculator;
  ChoiceRound? _round;

  /// Null = every checkout number equally likely (the default).
  DifficultyLevel? _difficulty;
  Challenge? _challenge;
  AttemptResult? _result;
  int _sessionId = 0;
  int _sessionPoints = 0;
  int _sessionStreak = 0;
  int _undosLeft = maxUndos;

  /// Checkout calculator: every undo was used and then a checkout was missed,
  /// so the session is over - only Replay session is left.
  bool _sessionOver = false;

  /// True while a checkout is being replayed: no clock, no score, no saving.
  bool _replay = false;

  /// Checkout input: the number that has no checkout, and the insult for it.
  int? _impossibleNumber;
  String? _insult;

  String _playerName = defaultPlayerName;
  bool _needsPlayerName = true;

  /// True until the player has chosen a username (first visit).
  bool get needsPlayerName => _needsPlayerName;

  GamePhase get phase => _phase;
  GameMode get mode => _mode;

  /// The current practice round; null in Checkout calculator.
  ChoiceRound? get round => _round;
  DifficultyLevel? get difficulty => _difficulty;
  Challenge? get challenge => _challenge;
  AttemptResult? get lastResult => _result;
  String get playerName => _playerName;
  int get sessionPoints => _sessionPoints;
  int get sessionStreak => _sessionStreak;
  bool get isReplay => _replay;

  /// Checkout calculator: all the undos of the session were used and then a
  /// checkout was missed. The session is over: the result screen offers only
  /// Replay session, which starts a new one (and a new score).
  bool get isSessionOver => _sessionOver;

  /// Checkout input: the number with no checkout, and the insult shown for it.
  int? get impossibleNumber => _impossibleNumber;
  String? get insult => _insult;

  /// Only Checkout calculator is saved, so this is only its attempts.
  List<AttemptRecord> get history => List.unmodifiable(_history);
  StatisticsService get statistics => _statistics;
  StatsSummary get summary => _statistics.summarize(_history);

  /// Darts entered so far, left to right (one per free box).
  List<DartThrow> get entered => List.unmodifiable(_entered);

  /// Live while playing, frozen on the result screen.
  Duration get elapsed => _timer.elapsed;

  ScoringConfig get scoringConfig => _scoring.config;

  /// How many undos are left this session; null when undo is not limited
  /// (the practice modes and replays).
  int? get undosLeft => _mode.isChallenge && !_replay ? _undosLeft : null;

  /// Practice: the equally best darts to throw next, for the number still to
  /// be checked out. Empty in Checkout calculator or once the round is over.
  Set<DartThrow> get choiceHints => _round?.optimalDarts ?? const {};

  /// True for a number from 2 to 170 that has no checkout at all.
  bool hasNoCheckout(int number) => _generator.isImpossible(number);

  /// True when the number on screen can only be checked out one way.
  bool get hasOnlyOneCheckout {
    final challenge = _challenge;
    return challenge != null &&
        challenge.hasCheckout &&
        _advisor.hasOnlyOneCheckout(challenge.target);
  }

  /// Optimal routes for the checkout on screen, with exactly the darts it is
  /// played with. Empty when no checkout is showing (or the number has none).
  List<CheckoutRoute> get currentOptimalRoutes {
    final challenge = _challenge;
    if (challenge == null) return const [];
    return _optimal.optimalRoutesIn(challenge.target, challenge.darts);
  }

  /// Practice and Checkout input: the number on screen can be played with two
  /// or three darts and no dart has been thrown yet, so pressing the boxes
  /// switches between them.
  bool get canChooseDarts {
    final challenge = _challenge;
    return _mode.isPractice &&
        _phase == GamePhase.playing &&
        _entered.isEmpty &&
        challenge != null &&
        _generator.otherDarts(challenge) != null;
  }

  /// Switches the number on screen between two and three darts (see
  /// [canChooseDarts]).
  void chooseOtherDarts() {
    if (!canChooseDarts) return;
    _begin(_generator.otherDarts(_challenge!)!);
  }

  /// The countdown starts here (30s by default).
  Duration get timeLimit => _scoring.config.timeLimit;

  /// What the clock shows: [timeLimit] minus [elapsed]. Goes negative once
  /// time is up, e.g. 30s limit and 38.33s elapsed shows -8.33s.
  Duration get remaining => timeLimit - elapsed;

  /// Calculator: every free box is filled, or the darts entered already add up
  /// to the number (with boxes still free that is a miss: every dart has to be
  /// used). Practice: the round is over (checked out, bust, or out of darts).
  /// Either way the answer is ready to be judged.
  bool get isHandFull {
    final round = _round;
    if (round != null) return round.isFinished;
    final challenge = _challenge;
    if (challenge == null) return false;
    final total = _entered.fold<int>(0, (sum, d) => sum + d.score);
    return _entered.length >= challenge.dartsLeft ||
        (challenge.hasCheckout && total == challenge.target);
  }

  bool get canUndo =>
      _phase == GamePhase.playing &&
      _entered.isNotEmpty &&
      (undosLeft == null || undosLeft! > 0);

  Future<List<LeaderboardEntry>> leaderboard(LeaderboardSort sort) =>
      _leaderboard.ranked(sort);

  /// True when the last leaderboard shown came from the shared online board.
  bool get leaderboardIsOnline => _leaderboard.isOnline;

  /// This player's id on the online board (to mark their row), if any.
  String? get leaderboardPlayerId => _leaderboard.playerId;

  void addListener(void Function() listener) => _listeners.add(listener);

  Future<void> init() async {
    // Only Checkout calculator is saved; older history may hold practice
    // attempts, which no longer count.
    _history = (await _historyRepo.load())
        .where((r) => r.mode == GameMode.calculator)
        .toList();
    // The leaderboard's record. The first time (no record yet, e.g. after an
    // update) it starts as a copy of the attempts saved so far, so nobody loses
    // their score; from then on a reset leaves it alone.
    final record = await _leaderboardRecordRepo.loadIfSaved();
    if (record == null) {
      _leaderboardRecord = List.of(_history);
      if (_leaderboardRecord.isNotEmpty) {
        await _leaderboardRecordRepo.save(_leaderboardRecord);
      }
    } else {
      _leaderboardRecord = record.where((r) => r.mode == GameMode.calculator).toList();
    }
    final saved = await _storage.read(playerNameKey);
    _needsPlayerName = saved == null || saved.trim().isEmpty;
    _playerName = _needsPlayerName ? defaultPlayerName : saved!;
    await favorites.load();
    _notify();
  }

  /// Marks [route] as a favorite for [target], or takes the mark away.
  /// Returns whether it is a favorite now. Nobody is told: the screen would
  /// redraw (and replay the tile flip on the result screen); the buttons update
  /// themselves, and the Favorites screen reads the list when it opens.
  Future<bool> toggleFavorite(int target, CheckoutRoute route) =>
      favorites.toggle(target, route);

  /// Longest username accepted.
  static const int maxPlayerNameLength = 20;

  /// Saves the username. Blank input keeps the current name.
  Future<void> setPlayerName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _playerName = trimmed.length > maxPlayerNameLength
        ? trimmed.substring(0, maxPlayerNameLength)
        : trimmed;
    _needsPlayerName = false;
    await _storage.write(playerNameKey, _playerName);
    _notify();
  }

  /// Begins a new session in [mode]. Checkout calculator and practice show the
  /// first checkout; Checkout input waits for a number. With no [level] every
  /// checkout number is equally likely.
  void startGame([DifficultyLevel? level, GameMode mode = GameMode.calculator]) {
    _mode = mode;
    _difficulty = level;
    _sessionId = _now().millisecondsSinceEpoch;
    _sessionPoints = 0;
    _sessionStreak = 0;
    _undosLeft = maxUndos; // a fresh session: undo can be used 3 more times
    _sessionOver = false;
    _replay = false;
    _generator.reset();
    if (mode == GameMode.input) {
      _waitForNumber();
    } else {
      _nextChallenge();
    }
  }

  /// Checkout input: the player entered [number]. A number that can be checked
  /// out starts the game on it; one that cannot shows the "impossible" screen;
  /// anything outside 2 to 170 is refused.
  NumberEntry enterNumber(int number) {
    if (_phase != GamePhase.entering) return NumberEntry.outOfRange;
    if (number < CheckoutEngine.minCheckout || number > CheckoutEngine.maxCheckout) {
      return NumberEntry.outOfRange;
    }
    final challenge = _generator.forNumber(number);
    if (challenge == null) {
      _impossibleNumber = number;
      _insult = Phrases.randomInsult(_random);
      _phase = GamePhase.impossible;
      _notify();
      return NumberEntry.impossible;
    }
    _replay = false;
    _begin(challenge);
    return NumberEntry.accepted;
  }

  /// Fills the next free box. Ignored when the hand is full or not playing.
  void selectDart(DartThrow dart) {
    if (_phase != GamePhase.playing || isHandFull) return;
    _entered.add(dart);
    _round?.throwDart(dart);
    _notify();
  }

  /// Takes back the last dart. In Checkout calculator this uses one of the 3
  /// undos of the session.
  void undo() {
    if (!canUndo) return;
    if (undosLeft != null) _undosLeft--;
    _entered.removeLast();
    _round?.undo();
    _notify();
  }

  /// Takes back every dart. Not available where undo is limited, or it would
  /// be a way round the limit.
  void clear() {
    if (_phase != GamePhase.playing || _entered.isEmpty || undosLeft != null) return;
    _entered.clear();
    _round?.reset();
    _notify();
  }

  /// Judges the answer, scores, records and moves to the result screen.
  /// Calculator: needs every free box filled. Practice: needs the round to be
  /// over.
  Future<void> submit() async {
    if (_phase != GamePhase.playing || !isHandFull) return;
    final challenge = _challenge!;
    final elapsed = _timer.stop();
    final round = _round;
    final validation = round != null
        ? _judgeChoice(round)
        : _validator.validate(challenge, _entered);
    await _finish(challenge, validation, elapsed);
  }

  /// Checkout calculator: the player says this number has no checkout.
  Future<void> pressNoCheckout() async {
    if (_phase != GamePhase.playing || !_mode.isChallenge) return;
    final challenge = _challenge!;
    final elapsed = _timer.stop();
    await _finish(challenge, _validator.validateNoCheckout(challenge), elapsed);
  }

  /// Turns a finished practice round into a verdict.
  ValidationResult _judgeChoice(ChoiceRound round) {
    final route = CheckoutRoute(_entered);
    final steps = round.steps;
    switch (round.status) {
      case RoundStatus.checkedOut:
        final sum = steps.map((s) => s.dart.score).join(' + ');
        return ValidationResult(
          outcome: AttemptOutcome.correct,
          playerRoute: route,
          isOptimal: round.isOptimal,
          message: round.isOptimal
              ? '$sum = ${round.target}. Checked out in an optimal way.'
              : '$sum = ${round.target}. Checked out, but not in an optimal way.',
        );
      case RoundStatus.bust:
        final last = steps.last;
        return ValidationResult(
          outcome: AttemptOutcome.bust,
          playerRoute: route,
          isOptimal: false,
          message: 'Bust: ${last.dart.notation} on ${last.remainingBefore} - '
              '${last.bustReason}.',
        );
      case RoundStatus.finishedEarly:
        // An optimal way of fewer darts (74 with three: T14 D16) is good, just
        // not in the given number of darts.
        if (route.isCheckoutFor(round.target) && _optimal.isOptimal(round.target, route)) {
          return ValidationResult(
            outcome: AttemptOutcome.goodButFewerDarts,
            playerRoute: route,
            isOptimal: false,
            message: goodButFewerDartsMessage(route, round.maxDarts),
          );
        }
        return ValidationResult(
          outcome: AttemptOutcome.wrongDartCount,
          playerRoute: route,
          isOptimal: false,
          message: 'Checked out in ${steps.length} '
              '${steps.length == 1 ? 'dart' : 'darts'}, but all ${round.maxDarts} '
              'darts have to be used.',
        );
      case RoundStatus.outOfDarts:
      case RoundStatus.inProgress:
        return ValidationResult(
          outcome: AttemptOutcome.outOfDarts,
          playerRoute: route,
          isOptimal: false,
          message: 'Out of darts with ${round.remaining} left.',
        );
    }
  }

  /// Starts the session again from the beginning: score 0 and 3 undos (the way
  /// on after [isSessionOver]).
  void replaySession() => startGame(_difficulty, _mode);

  /// Continues: the next number (Checkout input: back to typing a number).
  /// Not once the session is over.
  void nextCheckout() {
    if (_phase != GamePhase.result && _phase != GamePhase.impossible) return;
    if (_sessionOver) return;
    _replay = false;
    if (_mode == GameMode.input) {
      _waitForNumber();
    } else {
      _nextChallenge();
    }
  }

  /// Plays the number just finished again from the start. A replay has no
  /// clock, no points and is not saved; Next checkout then carries on normally.
  void replayCheckout() {
    if (_phase != GamePhase.result || _challenge == null || _sessionOver) return;
    _replay = true;
    _begin(_challenge!);
  }

  /// Leaving mid-checkout records nothing.
  void quitToMenu() {
    _timer.stop();
    _phase = GamePhase.menu;
    _challenge = null;
    _round = null;
    _result = null;
    _replay = false;
    _impossibleNumber = null;
    _insult = null;
    _entered.clear();
    _notify();
  }

  /// Clears the statistics. The leaderboard is not touched in any way: its own
  /// record of attempts stays, and nothing is sent to it.
  Future<void> resetStatistics() async {
    _history = [];
    await _historyRepo.clear();
    _notify();
  }

  Future<void> _finish(
    Challenge challenge,
    ValidationResult validation,
    Duration elapsed,
  ) async {
    final round = _round;
    final replay = _replay;
    final scored = _mode.hasScore && !replay;
    final recorded = _mode.isRecorded && !replay;

    final score = scored
        ? _scoring.score(
            correct: validation.isCorrect,
            timeLeft: timeLimit - elapsed,
            streakBefore: _sessionStreak,
          )
        : ScoreBreakdown.none;
    _result = AttemptResult(
      challenge: challenge,
      validation: validation,
      score: score,
      elapsed: elapsed,
      optimalRoutes: challenge.hasCheckout ? currentOptimalRoutes : const [],
      round: round,
      isReplay: replay,
      encouragement: validation.outcome == AttemptOutcome.noCheckoutCorrect
          ? Phrases.randomEncouragement(_random)
          : null,
    );
    if (scored) {
      _sessionPoints += score.total;
      _sessionStreak = score.streakAfter;
      // No undos left and a miss: the session is over.
      if (!validation.isCorrect && _undosLeft == 0) _sessionOver = true;
    }
    if (recorded) {
      final record = AttemptRecord(
        sessionId: _sessionId,
        timestampMs: _now().millisecondsSinceEpoch,
        target: challenge.target,
        dartCount: challenge.dartCount,
        difficulty: challenge.difficulty,
        mode: _mode,
        correct: validation.isCorrect,
        optimal: validation.isOptimal,
        timeMs: elapsed.inMilliseconds,
        points: score.total,
        playerRoute: validation.playerRoute.notation,
        optimalRoute: challenge.optimalRoute.notation,
      );
      _history = [..._history, record];
      _leaderboardRecord = [..._leaderboardRecord, record];
    }
    _phase = GamePhase.result;
    _notify();
    if (recorded) {
      await _historyRepo.save(_history);
      await _leaderboardRecordRepo.save(_leaderboardRecord);
      // The leaderboard is worked out from its own record, not from the
      // statistics (which the player can reset).
      await _leaderboard.submit(_playerName, _statistics.summarize(_leaderboardRecord));
    }
  }

  void _waitForNumber() {
    _challenge = null;
    _round = null;
    _result = null;
    _impossibleNumber = null;
    _insult = null;
    _entered.clear();
    _timer.stop();
    _phase = GamePhase.entering;
    _notify();
  }

  void _nextChallenge() {
    final deal = _mode == GameMode.calculator ? Deal.calculator : Deal.practice;
    _begin(_generator.next(_difficulty, deal));
  }

  void _begin(Challenge challenge) {
    _challenge = challenge;
    _entered.clear();
    _round = _mode.isPractice
        ? ChoiceRound(challenge.target, _advisor, layout: challenge.layout)
        : null;
    _result = null;
    _impossibleNumber = null;
    _insult = null;
    _timer = _timerFactory()..start();
    _phase = GamePhase.playing;
    _notify();
  }

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
