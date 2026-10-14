/// Platform-independent core of the Dartle checkout trainer.
///
/// Nothing exported here touches the DOM, so everything is unit-testable on
/// the Dart VM.
library;

export 'src/board/board_geometry.dart';
export 'src/content/phrases.dart';
export 'src/domain/better_doubles.dart';
export 'src/domain/bull_safe_finish.dart';
export 'src/domain/canonical_checkouts.dart';
export 'src/domain/challenge.dart';
export 'src/domain/choice_advisor.dart';
export 'src/domain/choice_round.dart';
export 'src/domain/challenge_generator.dart';
export 'src/domain/checkout_catalog.dart';
export 'src/domain/checkout_engine.dart';
export 'src/domain/checkout_route.dart';
export 'src/domain/checkout_strategy.dart';
export 'src/domain/checkout_validator.dart';
export 'src/domain/dart_throw.dart';
export 'src/domain/difficulty.dart';
export 'src/domain/natural_aim.dart';
export 'src/domain/optimal_route_service.dart';
export 'src/domain/route_explainer.dart';
export 'src/domain/site_routes.dart';
export 'src/domain/tile_feedback.dart';
export 'src/game/app_factory.dart';
export 'src/game/game_controller.dart';
export 'src/game/game_mode.dart';
export 'src/leaderboard/leaderboard_service.dart';
export 'src/scoring/scoring_service.dart';
export 'src/stats/attempt_record.dart';
export 'src/stats/history_repository.dart';
export 'src/stats/statistics_service.dart';
export 'src/storage/storage_service.dart';
export 'src/timing/attempt_timer.dart';
