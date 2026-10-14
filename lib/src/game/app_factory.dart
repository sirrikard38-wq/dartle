import 'dart:math';

import '../domain/challenge_generator.dart';
import '../domain/choice_advisor.dart';
import '../domain/checkout_catalog.dart';
import '../domain/checkout_engine.dart';
import '../domain/checkout_validator.dart';
import '../domain/optimal_route_service.dart';
import '../leaderboard/leaderboard_service.dart';
import '../scoring/scoring_service.dart';
import '../stats/history_repository.dart';
import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';
import 'game_controller.dart';

/// Composition root: the only place concrete services are wired together.
///
/// With no [leaderboard] the leaderboard stays on this device; pass an
/// [OnlineLeaderboardRepository] to share it with every player.
GameController createGameController(
  StorageService storage, {
  Random? random,
  LeaderboardRepository? leaderboard,
}) {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);
  return GameController(
    generator: ChallengeGenerator(catalog, random: random),
    validator: CheckoutValidator(engine, optimal),
    optimal: optimal,
    advisor: ChoiceAdvisor(engine, optimal),
    scoring: const ScoringService(),
    statistics: const StatisticsService(),
    history: HistoryRepository(storage),
    leaderboard: LeaderboardService(leaderboard ?? LocalLeaderboardRepository(storage)),
    storage: storage,
    random: random,
  );
}
