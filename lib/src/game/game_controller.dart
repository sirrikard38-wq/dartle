import '../domain/challenge.dart';
import '../domain/challenge_generator.dart';
import '../domain/checkout_route.dart';
import '../domain/checkout_validator.dart';
import '../domain/choice_advisor.dart';
import '../domain/choice_round.dart';
import '../domain/dart_throw.dart';
import '../domain/difficulty.dart';
import '../domain/optimal_route_service.dart';
import '../leaderboard/leaderboard_service.dart';
import '../scoring/scoring_service.dart';
import '../stats/attempt_record.dart';
import '../stats/history_repository.dart';
import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';
import '../timing/attempt_timer.dart';
import 'game_mode.dart';

enum GamePhase { menu, playing, result }

/// Everything the result screen needs to display.
class AttemptResult {
  const AttemptResult({
    required this.challenge,
    required this.validation,
    required this.score,
    required this.elapsed,
    required this.optimalRoutes,
    this.round,
  });

  final Challenge challenge;
  final ValidationResult validation;
  final ScoreBreakdown score;
  final Duration elapsed;

  /// Primary optimal route first, then every equally optimal alternative
  /// (the chart/bull-safe routes in Checkout calculator; all fewest-darts
  /// routes of sensible aims in Checkout practice).
  final List<CheckoutRoute> optimalRoutes;

  /// The darts chosen, with their ratings. Only set in Checkout practice.
  final ChoiceRound? round;

  bool get isChoice => round != null;

  bool get isCorrect => validation.isCorrect;
  bool get isOptimal => validation.isOptimal;
  CheckoutRoute get playerRoute => validation.playerRoute;
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
        _timer = (timerFactory ?? AttemptTimer.new)();

  static const String playerNameKey = 'dartle.player.v1';
  static const String defaultPlayerName = 'Player';

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

  final List<void Function()> _listeners = [];
  final List<DartThrow> _entered = [];
  List<AttemptRecord> _history = [];
  AttemptTimer _timer;

  GamePhase _phase = GamePhase.menu;

  /// True while a give-up is being saved before returning to the menu.
  bool _leaving = false;
  GameMode _mode = GameMode.calculator;
  ChoiceRound? _round;

  /// Null = every checkout number equally likely (the default).
  DifficultyLevel? _difficulty;
  Challenge? _challenge;
  AttemptResult? _result;
  int _sessionId = 0;
  int _sessionPoints = 0;
  int _sessionStreak = 0;
  String _playerName = defaultPlayerName;
  bool _needsPlayerName = true;

  /// True until the player has chosen a username (first visit).
  bool get needsPlayerName => _needsPlayerName;

  GamePhase get phase => _phase;
  GameMode get mode => _mode;

  /// The current Checkout practice round; null in Checkout calculator.
  ChoiceRound? get round => _round;
  DifficultyLevel? get difficulty => _difficulty;
  Challenge? get challenge => _challenge;
  AttemptResult? get lastResult => _result;
  String get playerName => _playerName;
  int get sessionPoints => _sessionPoints;
  int get sessionStreak => _sessionStreak;
  List<AttemptRecord> get history => List.unmodifiable(_history);
  StatisticsService get statistics => _statistics;
  StatsSummary get summary => _statistics.summarize(_history);

  /// Darts entered so far, left to right.
  List<DartThrow> get entered => List.unmodifiable(_entered);

  /// Live while playing, frozen on the result screen.
  Duration get elapsed => _timer.elapsed;

  ScoringConfig get scoringConfig => _scoring.config;

  /// Checkout practice: the equally best darts to throw next, for the number
  /// still to be checked out. Empty in Checkout calculator or once the round
  /// is over.
  Set<DartThrow> get choiceHints {
    final round = _round;
    if (round == null || round.isFinished) return const {};
    return _advisor.optimalDarts(round.remaining);
  }

  /// Optimal routes for the checkout on screen, used to colour each dart as
  /// it is entered. Empty when no checkout is showing.
  List<CheckoutRoute> get currentOptimalRoutes {
    final challenge = _challenge;
    if (challenge == null) return const [];
    return _optimal.optimalRoutes(challenge.target);
  }

  /// The countdown starts here (30s by default).
  Duration get timeLimit => _scoring.config.timeLimit;

  /// What the clock shows: [timeLimit] minus [elapsed]. Goes negative once
  /// time is up, e.g. 30s limit and 38.33s elapsed shows -8.33s.
  Duration get remaining => timeLimit - elapsed;

  /// Calculator: every box is filled. Choice: the round is over (checked out,
  /// bust, or out of darts). Either way the answer is ready to be judged.
  bool get isHandFull {
    final round = _round;
    if (round != null) return round.isFinished;
    return _challenge != null && _entered.length >= _challenge!.dartCount;
  }

  bool get canUndo => _phase == GamePhase.playing && _entered.isNotEmpty;

  Future<List<LeaderboardEntry>> leaderboard(LeaderboardSort sort) =>
      _leaderboard.ranked(sort);

  void addListener(void Function() listener) => _listeners.add(listener);

  Future<void> init() async {
    _history = await _historyRepo.load();
    final saved = await _storage.read(playerNameKey);
    _needsPlayerName = saved == null || saved.trim().isEmpty;
    _playerName = _needsPlayerName ? defaultPlayerName : saved!;
    _notify();
  }

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

  /// Begins a new session in [mode] and shows the first checkout. With no
  /// [level] every checkout number is equally likely.
  void startGame([DifficultyLevel? level, GameMode mode = GameMode.calculator]) {
    _mode = mode;
    _difficulty = level;
    _sessionId = _now().millisecondsSinceEpoch;
    _sessionPoints = 0;
    _sessionStreak = 0;
    _generator.reset();
    _nextChallenge();
  }

  /// Fills the next free box. Ignored when the hand is full or not playing.
  void selectDart(DartThrow dart) {
    if (_phase != GamePhase.playing || isHandFull || _leaving) return;
    _entered.add(dart);
    _round?.throwDart(dart);
    _notify();
  }

  void undo() {
    if (!canUndo) return;
    _entered.removeLast();
    _round?.undo();
    _notify();
  }

  void clear() {
    if (_phase != GamePhase.playing || _entered.isEmpty) return;
    _entered.clear();
    _round?.reset();
    _notify();
  }

  /// Judges the answer, scores, records and moves to the result screen.
  /// Calculator: needs every box filled. Choice: needs the round to be over.
  Future<void> submit() async {
    if (_phase != GamePhase.playing || !isHandFull || _leaving) return;
    final challenge = _challenge!;
    final elapsed = _timer.stop();
    final round = _round;
    final validation = round != null
        ? _judgeChoice(round)
        : _validator.validate(challenge, _entered);
    await _finish(challenge, validation, elapsed);
  }

  /// Turns a finished Checkout practice round into a verdict.
  ValidationResult _judgeChoice(ChoiceRound round) {
    final route = CheckoutRoute(_entered);
    final steps = round.steps;
    switch (round.status) {
      case RoundStatus.checkedOut:
        final fewest = _advisor.optimalRoutes(round.target).first.length;
        final sum = steps.map((s) => s.dart.score).join(' + ');
        return ValidationResult(
          outcome: AttemptOutcome.correct,
          playerRoute: route,
          isOptimal: round.isOptimal,
          message: round.isOptimal
              ? '$sum = ${round.target}. Checked out in the fewest darts.'
              : '$sum = ${round.target}. Checked out, but it can be done in '
                  '$fewest ${fewest == 1 ? 'dart' : 'darts'}.',
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

  /// Abandons the attempt; recorded as a failure so stats stay honest.
  ///
  /// With [toMenu] the run ends instead of showing the result: the attempt is
  /// saved and the leaderboard updated first, then the game returns to the menu
  /// phase so the caller can open the leaderboard with an up-to-date row.
  Future<void> giveUp({bool toMenu = false}) async {
    if (_phase != GamePhase.playing || _leaving) return;
    final challenge = _challenge!;
    final elapsed = _timer.stop();
    final validation = ValidationResult(
      outcome: AttemptOutcome.gaveUp,
      playerRoute: CheckoutRoute(_entered),
      message: 'You skipped this checkout.',
      isOptimal: false,
    );
    await _finish(challenge, validation, elapsed, showResult: !toMenu);
  }

  void nextCheckout() {
    if (_phase != GamePhase.result) return;
    _nextChallenge();
  }

  void quitToMenu() {
    _timer.stop();
    _phase = GamePhase.menu;
    _challenge = null;
    _round = null;
    _result = null;
    _entered.clear();
    _notify();
  }

  Future<void> resetStatistics() async {
    _history = [];
    await _historyRepo.clear();
    _notify();
  }

  Future<void> _finish(
    Challenge challenge,
    ValidationResult validation,
    Duration elapsed, {
    bool showResult = true,
  }) async {
    if (!showResult) _leaving = true; // no more input while it is being saved
    final round = _round;
    // Choice counts the darts actually thrown; calculator the boxes shown.
    final dartsUsed = round != null ? _entered.length : challenge.dartCount;
    // Checkout practice is not scored: no points won or lost, ever.
    final score = !_mode.hasScore
        ? ScoreBreakdown.zero
        : _scoring.score(
            correct: validation.isCorrect,
            complexity: challenge.complexity,
            darts: dartsUsed < 1 ? 1 : dartsUsed,
            optimal: validation.isOptimal,
            elapsed: elapsed,
            timed: _mode.isTimed,
          );
    _result = AttemptResult(
      challenge: challenge,
      validation: validation,
      score: score,
      elapsed: elapsed,
      optimalRoutes: round != null
          ? _advisor.optimalRoutes(challenge.target)
          : _optimal.optimalRoutes(challenge.target),
      round: round,
    );
    _sessionPoints += score.total;
    _sessionStreak = validation.isCorrect ? _sessionStreak + 1 : 0;
    _history = [
      ..._history,
      AttemptRecord(
        sessionId: _sessionId,
        timestampMs: _now().millisecondsSinceEpoch,
        target: challenge.target,
        dartCount: round != null ? _entered.length : challenge.dartCount,
        difficulty: challenge.difficulty,
        mode: _mode,
        correct: validation.isCorrect,
        optimal: validation.isOptimal,
        timeMs: elapsed.inMilliseconds,
        points: score.total,
        playerRoute: validation.playerRoute.notation,
        optimalRoute: challenge.optimalRoute.notation,
      ),
    ];
    if (showResult) {
      _phase = GamePhase.result;
      _notify();
      await _historyRepo.save(_history);
      await _leaderboard.submit(_playerName, summary);
      return;
    }
    // Leaving without a result screen: save first, so whatever is opened next
    // (the leaderboard) already has this attempt in it.
    await _historyRepo.save(_history);
    await _leaderboard.submit(_playerName, summary);
    _leaving = false;
    quitToMenu();
  }

  void _nextChallenge() {
    _challenge = _generator.next(_difficulty);
    _entered.clear();
    _round = _mode == GameMode.choice
        ? ChoiceRound(_challenge!.target, _advisor)
        : null;
    _result = null;
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
