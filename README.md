# Dartle — Darts Checkout Trainer

Wordle-style trainer for 501 checkouts. A number appears, empty boxes show how
many darts the checkout takes, and you fill them with S/D/T/Bull buttons.
Pure Dart, compiled to JS; the only runtime dependency is `package:web`.

## Run

```
dart pub get
dart test                      # domain + game-flow tests (VM, no browser)
dart run tool/build.dart       # compiles web/ into build/
dart run tool/serve.dart       # http://localhost:8080
```

## Rules chosen (documented, not assumed)

- Checkout = 1–3 darts summing exactly to the target; **last dart must be a
  double D1–D20 or Bull (50)**. Outer bull (25) is a legal non-finishing dart.
- No misses/busts are modelled.
- Checkoutable totals: 2–170 except 159, 162, 163, 165, 166, 168, 169.
  Computed by exhaustive search, never hand-listed.
- A challenge's dart count = length of its optimal route = the minimum darts.
  So 140/150/160/167/170 are always 3 darts; the generator cannot produce an
  impossible target/dart-count pair because it only draws from the catalog.
- **Optimal** = the canonical chart route (`canonical_checkouts.dart`) plus a
  few approved alternates. Fallback for any uncovered number is
  `CheckoutStrategy` (fewer darts → preferred finisher → trebles → big first
  dart). `72` is charted as `T20 D6` per the product spec (`T16 D12` is an
  approved alternate). Tests verify every chart entry is legal and minimal.
- Difficulty is a data-driven complexity band (`difficulty.dart`):
  `(darts-1) + trebles + (bull?1:0) + (target>=100?1:0)`.
  Easy 0–1, Medium 2–4, Hard 5+.

## Layout

```
lib/src/domain       DartThrow, CheckoutRoute, CheckoutEngine, optimal routes,
                     difficulty, catalog, generator, validator
lib/src/scoring      ScoringService (base + difficulty + optimal + speed)
lib/src/timing       AttemptTimer (monotonic, idempotent start)
lib/src/stats        AttemptRecord, HistoryRepository, StatisticsService
lib/src/leaderboard  LeaderboardRepository (+ local impl), LeaderboardService
lib/src/storage      StorageService interface (+ in-memory impl)
lib/src/game         GameController + composition root
lib/ui, web          DOM views (package:web), localStorage adapter, CSS
```

To add a backend: implement `StorageService` and/or `LeaderboardRepository`
and pass them into `createGameController`.
