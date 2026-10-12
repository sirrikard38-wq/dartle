import '../domain/difficulty.dart';
import '../game/game_mode.dart';

/// One finished (or abandoned) attempt, as persisted in game history.
class AttemptRecord {
  const AttemptRecord({
    required this.sessionId,
    required this.timestampMs,
    required this.target,
    required this.dartCount,
    required this.difficulty,
    required this.correct,
    required this.optimal,
    required this.timeMs,
    required this.points,
    required this.playerRoute,
    required this.optimalRoute,
    this.mode = GameMode.calculator,
  });

  factory AttemptRecord.fromJson(Map<String, Object?> json) => AttemptRecord(
        sessionId: json['sessionId'] as int,
        timestampMs: json['timestampMs'] as int,
        target: json['target'] as int,
        dartCount: json['dartCount'] as int,
        difficulty: DifficultyLevel.values.byName(json['difficulty'] as String),
        correct: json['correct'] as bool,
        optimal: json['optimal'] as bool,
        timeMs: json['timeMs'] as int,
        points: json['points'] as int,
        playerRoute: json['playerRoute'] as String,
        optimalRoute: json['optimalRoute'] as String,
        // Older saved history has no mode: it was all Checkout calculator.
        mode: GameMode.values.asNameMap()[json['mode']] ?? GameMode.calculator,
      );

  /// Groups attempts from one play session (a run from "Start" to "Quit").
  final int sessionId;
  final int timestampMs;
  final int target;
  final int dartCount;
  final DifficultyLevel difficulty;
  final bool correct;
  final bool optimal;
  final int timeMs;
  final int points;
  final String playerRoute;
  final String optimalRoute;
  final GameMode mode;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'sessionId': sessionId,
        'timestampMs': timestampMs,
        'target': target,
        'dartCount': dartCount,
        'difficulty': difficulty.name,
        'correct': correct,
        'optimal': optimal,
        'timeMs': timeMs,
        'points': points,
        'playerRoute': playerRoute,
        'optimalRoute': optimalRoute,
      };
}
