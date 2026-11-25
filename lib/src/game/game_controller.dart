import 'dart:math';

import '../content/phrases.dart';
import '../domain/challenge.dart';
import '../domain/challenge_generator.dart';
import '../domain/checkout_engine.dart';
import '../domain/checkout_route.dart';
import '../domain/checkout_tutor.dart';
import '../domain/checkout_validator.dart';
import '../domain/choice_advisor.dart';
import '../domain/choice_round.dart';
import '../domain/dart_throw.dart';
import '../domain/difficulty.dart';
import '../domain/optimal_route_service.dart';
import '../favorites/favorites.dart';
import '../i18n/i18n.dart';
import '../scoring/scoring_service.dart';
import '../stats/attempt_record.dart';
import '../stats/history_repository.dart';
import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';
import '../timing/attempt_timer.dart';
import 'game_mode.dart';
import 'number_input.dart';
import 'tutorial_session.dart';

/// menu: away from a checkout. playing / result: a checkout is on screen / has
/// just been answered.
enum GamePhase { menu, playing, result }

/// Everything the result screen needs to display.
class AttemptResult {
  const AttemptResult({
    required this.challenge,
    required this.validation,
    required this.score,
    required this.elapsed,
    required this.optimalRoutes,
    this.onlyPossibility = false,
    this.bestRoute = false,
    this.round,
    this.isReplay = false,
    this.encouragement,
  });

  /// There is just one way at all to check the number out with these darts
  /// ("Only possibility") - not merely one optimal way.
  final bool onlyPossibility;

  /// One optimal route, the best of many ways out ("The best optimal route",
  /// 120 to 130).
  final bool bestRoute;

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
        _storage = storage,
        _timerFactory = timerFactory ?? AttemptTimer.new,
        _now = now ?? DateTime.now,
        _random = random ?? Random(),
        _timer = (timerFactory ?? AttemptTimer.new)();

  static const String playerNameKey = 'dartle.player.v1';
  static const String defaultPlayerName = 'Player';

  /// Where the leaderboard (no more) kept its record of attempts: taken off
  /// the phone at the start.
  static const String oldLeaderboardRecordKey = 'dartle.leaderboard-record.v1';

  /// Undo can be used this many times per session in Checkout calculator.
  static const int maxUndos = 3;

  final ChallengeGenerator _generator;
  final CheckoutValidator _validator;
  final OptimalRouteService _optimal;
  final ChoiceAdvisor _advisor;
  final ScoringService _scoring;
  final StatisticsService _statistics;
  final HistoryRepository _historyRepo;
  final StorageService _storage;
  final AttemptTimer Function() _timerFactory;
  final DateTime Function() _now;
  final Random _random;

  final List<void Function()> _listeners = [];
  final List<DartThrow> _entered = [];

  /// What the Statistics screen shows; "Reset statistics" clears it.
  List<AttemptRecord> _history = [];

  /// Checkout tutorial: the cards and the state of Learn and Practice.
  late final TutorialSession tutorial =
      TutorialSession(CheckoutTutor(_optimal), generator: _generator, validator: _validator, random: _random);

  /// The routes the player marked with the dart icon, saved on this device. A
  /// number with only one optimal route has it as a favorite from the start.
  late final Favorites favorites = Favorites(_storage, defaults: _onlyRoutes());

  /// Every number's only optimal route, for the numbers (and numbers of darts)
  /// that have just one.
  Map<int, List<CheckoutRoute>> _onlyRoutes() {
    final only = <int, List<CheckoutRoute>>{};
    for (var n = CheckoutEngine.minCheckout; n <= CheckoutEngine.maxCheckout; n++) {
      final fewest = _optimal.fewestDarts(n);
      for (final darts in [if (fewest != null) fewest, if (_optimal.hasThreeDartOption(n)) 3]) {
        // A route right only as a dart missed into its single does not count
        // (67: T17 D8 alone, S17 Bull is the T17 missed).
        final routes = [
          for (final route in _optimal.optimalRoutesIn(n, darts))
            if (!_optimal.isMissRoute(n, darts, route)) route,
        ];
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

  /// Checkout practice: a number typed in Input that has no checkout, and the
  /// insult for it.
  int? _impossibleNumber;
  String? _insult;

  /// Checkout practice's Input keypad.
  late final NumberInput numberInput = NumberInput(now: _now);

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

  /// Checkout practice: a number typed in Input with no checkout (Play says so,
  /// with the insult), or null.
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

  /// Practice: the number on screen can be played with two
  /// or three darts and at most one dart has been thrown, so pressing the boxes
  /// switches between them (after a dart, the darts thrown stay).
  bool get canChooseDarts {
    final challenge = _challenge;
    return _mode.isPractice &&
        _phase == GamePhase.playing &&
        _entered.length <= 1 &&
        challenge != null &&
        _generator.otherDarts(challenge) != null;
  }

  /// Switches the number on screen between two and three darts (see
  /// [canChooseDarts]). A dart already thrown keeps its place and rating: 68
  /// with three darts, T14 thrown, switched to two darts lights D13.
  void chooseOtherDarts() {
    if (!canChooseDarts) return;
    final other = _generator.otherDarts(_challenge!)!;
    if (_entered.isEmpty) {
      _begin(other);
      return;
    }
    _challenge = other;
    _round = _round!.withLayout(other.layout);
    _notify();
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

  void addListener(void Function() listener) => _listeners.add(listener);

  Future<void> init() async {
    // Only Checkout calculator is saved; older history may hold practice
    // attempts, which no longer count.
    _history = (await _historyRepo.load())
        .where((r) => r.mode == GameMode.calculator)
        .toList();
    // There is no leaderboard any more: its record goes.
    await _storage.remove(oldLeaderboardRecordKey);
    final saved = await _storage.read(playerNameKey);
    _needsPlayerName = saved == null || saved.trim().isEmpty;
    _playerName = _needsPlayerName ? defaultPlayerName : saved!;
    await favorites.load();
    await I18n.load(_storage);
    _notify();
  }

  /// Switches the whole app to [language] and remembers it.
  Future<void> setLanguage(Language language) async {
    await I18n.choose(_storage, language);
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

  /// Begins a new session in [mode] with its first checkout. With no [level]
  /// every checkout number is equally likely.
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
    _nextChallenge();
  }

  /// Checkout choice's Input: types a digit ([NumberInput.type]). A number
  /// from 2 to 170 is at once the one Choose plays, with the darts it would be
  /// dealt with (also from the answer of the last one); one with no checkout
  /// says so in Choose, with an insult.
  void typeDigit(int digit) {
    if (_mode != GameMode.choice || _phase == GamePhase.menu) return;
    numberInput.type(digit);
    _playTyped();
  }

  /// Checkout choice's Input: takes the last digit away (UNDO).
  void deleteDigit() {
    if (_mode != GameMode.choice || _phase == GamePhase.menu) return;
    numberInput.delete();
    _playTyped();
  }

  void _playTyped() {
    final number = numberInput.number;
    if (number == null || number == (_impossibleNumber ?? _challenge?.target)) {
      _notify();
      return;
    }
    final challenge = _generator.forNumber(number);
    if (challenge == null) {
      _impossibleNumber = number;
      _insult = Phrases.randomInsult(_random);
      // From the answer of the last number too: Choose now says so.
      _result = null;
      _phase = GamePhase.playing;
      _notify();
      return;
    }
    _replay = false;
    _begin(challenge);
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

  /// Continues: the next number (also from a typed number with no checkout,
  /// and in Checkout choice at any time). Not once the session is over.
  void nextCheckout() {
    if (_phase != GamePhase.result && _impossibleNumber == null && !_choosing) return;
    if (_sessionOver) return;
    _replay = false;
    _nextChallenge();
  }

  /// Plays the number just finished again from the start (in Checkout choice
  /// also the one being played). A replay has no clock, no points and is not
  /// saved; Next checkout then carries on normally.
  void replayCheckout() {
    if ((_phase != GamePhase.result && !_choosing) || _challenge == null || _sessionOver) return;
    // A typed number with no checkout has nothing to play again.
    if (_impossibleNumber != null) return;
    _replay = true;
    _begin(_challenge!);
  }

  /// Checkout choice, a number being played: Replay and Next are always there.
  bool get _choosing => _mode == GameMode.choice && _phase == GamePhase.playing;

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

  /// Clears the statistics.
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
      onlyPossibility: challenge.hasCheckout && _optimal.onlyPossibility(challenge.target, challenge.darts),
      bestRoute: challenge.hasCheckout && _optimal.isBestRoute(challenge.target, challenge.darts),
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
    }
    _phase = GamePhase.result;
    _notify();
    if (recorded) await _historyRepo.save(_history);
  }

  void _nextChallenge() {
    final deal = _mode == GameMode.calculator ? Deal.calculator : Deal.practice;
    final challenge = _generator.next(_difficulty, deal);
    // Checkout practice: the number dealt is in Input too.
    if (_mode == GameMode.choice) numberInput.show(challenge.target);
    _begin(challenge);
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
