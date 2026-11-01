# Dartle — Darts Checkout Trainer

Wordle-style trainer for 501 checkouts, in three modes:

- **Checkout calculator** - a number and three boxes (a visit). Boxes that are
  crossed out are darts already used; you fill the free ones. Against the
  clock, scored by streak and saved to the leaderboard. All the
  one-dart numbers (21) together come up 2% of the time; every other number, the
  seven with no checkout included, shares the other 98% equally.
- **Checkout practice** - choose your own darts one at a time; the optimal darts
  are lit on the board. No clock, no score, nothing saved.
- **Checkout input** - type any number (2-170) and practise it the same way.

Pure Dart, compiled to JS; the only runtime dependency is `package:web`.

## Run

```
dart pub get
dart test                      # domain + game-flow tests (VM, no browser)
dart run tool/build.dart       # compiles web/ into build/
dart run tool/serve.dart       # http://localhost:8080
```

Every push to `main` is tested, built and published to GitHub Pages by
`.github/workflows/pages.yml`.

## Install on a phone (Android and iPhone)

Dartle is an installable web app (a PWA): it gets its own icon, opens full
screen without the browser bars, and works offline once it has been opened.

- **Android (Chrome):** open the site, then tap **Install** in the row of links at
  the bottom of any screen (or the browser menu, then *Install app* / *Add to Home
  screen*).
- **iPhone / iPad (Safari):** open the site, tap **Share**, then **Add to Home
  Screen**.

Pieces: `web/manifest.webmanifest` (name, colours, icons), `web/icons/` (made by
`tool/make_icons.ps1`), `web/sw.js` (offline cache, stamped per build by
`tool/build.dart`), the safe-area CSS for notches and home bars, and
`lib/ui/install.dart` and `lib/ui/footer.dart` (the row of links at the end of
every screen: Install, Instagram, Email). Scores are saved
on the device; on iPhone the home-screen app keeps its own copy, separate from
the Safari tab. Store versions (Google Play, App Store) are not built.

## Android app (.apk)

`.github/workflows/android.yml` wraps the same site as an Android app
(Capacitor, in `android-app/`), builds the `.apk` and publishes it as the
`android-latest` release on every push to `main`:

https://github.com/sirrikard38-wq/dartle/releases/download/android-latest/dartle.apk

Download it on the phone and open it; Android asks once to allow installing
from that source. The app holds every file itself, so it needs no connection.
The Android project is generated in the build (only the settings, artwork and
`tool/patch_android.dart` are in git). The signing key is a debug key kept in the
build cache so each download can update the last; it is not a Play Store key.
There is no iPhone app file: that needs a paid Apple developer account.

## Online leaderboard

The leaderboard can be shared by every player through a free Firebase Realtime
Database (anonymous sign-in, rules in `firebase/database.rules.json`). Setup is
in [docs/online-leaderboard.md](docs/online-leaderboard.md): fill in
`web/online.json`. Until it is filled in, or when there is no connection, the
leaderboard shows the scores on the device, as before.

## Rules chosen (documented, not assumed)

- Checkout = 1–3 darts summing exactly to the target; **last dart must be a
  double D1–D20 or Bull (50)**. Outer bull (25) is a single and a legal
  non-finishing dart.
- Checkoutable totals: 2–170 except 159, 162, 163, 165, 166, 168, 169
  (computed by exhaustive search, never hand-listed). Those seven are dealt in
  the calculator too; the right answer is the **No checkout** button.
- A number's dart count = the fewest darts it needs. The calculator always shows
  three boxes (`Visit`, `BoxLayout`): a **1-dart** number has its first two
  boxes crossed out; a **2-dart** number has its left box crossed out (the
  right box is never crossed); a **3-dart** number has none crossed out. Free
  darts always equal the fewest darts.
- **Optimal** (see `OptimalRouteService`). A **two-dart number up to 70** has one
  rule of its own:
  - up to 60 the first dart is a **single that leaves a better double**. When
    two neighbouring singles both do, only those count, as that is where you aim.
    With no such pair every such single counts. The near misses of those singles
    count too: their triple or double when it leaves a better double. 48 is
    `S8 D20`, `S16 D16`, `T8 D12`, `D16 D8`, `D8 D16`; 58 is `S18 D20`, `T18 D2`;
    57 is only `S17 D20` (`AimPairs.goodSingleRoutes`);
  - 61 to 70 is the **bull-safe** finish and nothing else: the triple of the
    number whose single leaves 50, then the double, *or* that single, then the
    Bull (61: `T11 D14`, `S11 Bull`).

  Every other number goes by these, in order:
  1. the fewest darts;
  2. **bull-safe** where it applies - 3-dart numbers whose first triple leaves
     55-70 (not 51-54: no tiny single before the Bull, so 109 is not
     `T19 S2 Bull`): the same two ways, after the first triple (119: `T19 T12
     D13`, `T19 S12 Bull`). A three-dart number also accepts its chart route.
     After a first triple that leaves 51-60, a single that leaves a better double
     is as good: 109 is also `T19 S20 D16` (`SingleLeave`);
  3. otherwise the **most singles** (they are far easier to hit; the outer bull
     is **not** a single and hardly ever an aim - it is far too hard to hit; the
     one exception is `25 D20` with 65 left and `25 D18` with 61 left, after a
     first triple), then setup doubles last, then fewer triples, using only
     sensible aims (singles, T15-T20, and the better doubles as setup darts when
     the route also finishes on a better double). 132 is `T20 T20 D6` =
     `T20 D20 D16` = `T20 T16 D12`..., never `T19 25 Bull`;
  4. **aims**, with two darts left (`AimPairs`): a first dart whose two possible
     hits - the single and triple of a number, or two neighbours on the board
     (single/single or triple/triple) - each leave a double is as good. Only the
     best group counts: aims with a better double whatever is hit, else those
     with at least one, else the rest.

  What follows the first of three darts over 60 keeps the routes two darts had
  before their rule up to 70 (`OptimalRouteService._olderTwoDartRoutes`), so that
  rule takes nothing away from three darts: the bull-safe routes on 51-70 with the
  singles that leave a better double, the aims (43: `T11 D5`, 64: `T16 D8`,
  `T8 D20`), every single/triple pair of a number that leaves a double on 20 to 60
  (35: `T5 D10`, `S5 D15`; `AimPairs.sameNumberRoutes`), two neighbouring singles
  then a double on 41 to 60 (42: `S8 D17`, `S16 D13`;
  `AimPairs.neighbourSingleRoutes`) and the same better double twice
  (64: `D16 D16`).

  A two-dart number **over 60** can come with three darts (50% in the
  calculator and in practice; the player chooses in practice and input). Then
  all three darts must be used (checking out sooner is a miss, unless it is an
  optimal route of fewer darts: that counts as right and says "Good, but not in
  the given number of darts", 74 with T14
  D16) and the optimal routes are (0) the **aims**: the single or the triple of
  a number whose triple leaves a double and whose single leaves a two-dart
  finish, then an optimal two-dart route of what is left (68: `T14` leaves
  D13, `S14` leaves 54; `OptimalRouteService.threeDartAims`). Only the aims
  are lit for the first dart, all the same (`threeDartFirstDarts`); the best
  one, whose single leaves a double too, comes first (68: `S18` leaves the
  Bull, `T18` leaves D7, so 68 starts with `S18 S10 D20`). When the triple
  leaves a double whose single leaves a double too, only that route follows:
  88 is `T20 S14 D7` (aim at D14; hit S14 and D7 is left), not `T20 S4 D12`
  (`AimPairs.missedDoubleRoute`, 37 of the 43 numbers have at least one). An
  odd double or the Bull has no such backup, so only a single that leaves a
  better double follows the triple: 88 is `T18 S18 D8`, not `T18 S4 D15`, and
  110 is `T20 S10 D20`, not `T20 S12 D19`
  (`AimPairs.twoDartsOnDoubleRoutes`). A route that can start with an aim's
  single is free of this (88: `S16 T18 D9`, as S16 leaves 72). (1) two setup darts
  from one aim - neighbours, the single and triple of a number, one of each,
  or the same number twice - and a double: 64 is `S16 S16 D16`, `S8 S16 D20`
  ... (only better doubles when there are any, then the most singles;
  `AimPairs.threeDartRoutes`), and (2) a high single (S15 to S20) that leaves a
  number with a two-dart finish, then one of that number's optimal routes with
  two darts: 93 is `S19 T20 D7`, as S19 leaves 74
  (`OptimalRouteService._followUps`; with every single 97 had 52 routes and 61
  had 147, with S15-S20 only 97 had 23; with the aims (0) it has 4). And
  (3) the single and the triple of
  one number then any double (74: `S14 T14 D9`, 64: `S14 T14 D4`;
  `AimPairs.sameNumberThreeDartRoutes`). And (4) when two singles and the triple
  of a number each leave a double, any double, a dart of that number and a dart
  of it or of a neighbour, at most one triple (64: `S16 S16 D16`, `S16 S8 D20`,
  `S16 T8 D12`; `AimPairs.twoSinglesRoutes`). Routes (1) to (4) count only when
  one of their setup darts is an aim, as every route has to start with one
  (68 loses `S19 S11 D19`, `S17 S1 Bull`, `T11 S11 D12`; 74 `S10 T10 D17`), and
  a triple keeps to the darts that may follow it (64 is not `T18 S4 D3`).
  A two-dart number **under 60** can be played with three darts too, by choice in
  practice and input only: it starts on two darts and never comes with three
  (not 3, and not 60, which stays on two darts). The aims are the numbers whose
  triple leaves a double and whose single, or two of its singles, leave one too
  (47: `S7` leaves D20, `T7` leaves D13; 48: `S4 S4` leaves D20, `T4` leaves D18;
  `AimPairs.underSixtyAims`). After any first dart that leaves a double, that
  double is lit, and its single when that leaves a double too
  (`AimPairs.doubleAndItsSingle`). Here a lit double may finish with a dart left
  and is rated optimal: 47 is `S7 D20`, or `S7 S20 D10` when the double is missed
  (`AimPairs.underSixtyRoutes`, the one list with routes of two darts in a
  three-dart round). A single that leaves no double goes on with (4).
  The popup and the "Also optimal" boxes list every optimal route - the same
  as Checkout input lights up, however many (61 with three darts has over a
  hundred).
  Equal routes are all optimal, in any order of the setup darts. 120 stays
  `T20 S20 D20`. The chart (`canonical_checkouts.dart`) only decides which
  equal route is shown first; tests verify every chart entry is legal and
  minimal.
- The first-choice ("Throw") routes from dartscheckoutassistant.com
  (`site_routes.dart`, routes only, generated by `tool/site_routes.dart`) are
  accepted next to the chart routes wherever they have the fewest darts and as
  many singles as the best routes. Where they disagree with the rules above, the
  rules win; every difference is listed in `docs/site-comparison.md`
  (`dart run tool/site_report.dart`).
- **Better doubles** are a set: D20 D18 D16 D14 D12 D10 D8 D6 D5 D4 D2 D1. The
  result screen shows one more optimal route on one of them, plus up to two
  more, as boxes, and an **All possibilities** popup (every optimal route with
  its marked board and boxes) in every mode.
- **Score** (calculator only): a right answer with time left on the 30 s clock
  scores the streak length (1st = 1, 2nd = 2, ... 10th = 10); a right answer
  after the clock ran out scores 0 and keeps the streak; a miss costs nothing
  and resets the streak. Undo: 3 per session; once all 3 are used, the next
  miss ends the session (the result shows "Score: N" and only Replay session,
  which starts a new one).
- **Favorites**: the dart in the corner of each board in the "Also optimal"
  popup marks that route as a favorite (filled white) for its number and
  number of darts; favorites come first in that popup. The menu's Favorites
  screen lists 170 down to 2 (white = has favorites) and opens a popup per
  number with "2 Darts" / "3 Darts" pages to swipe between. A number with only
  one optimal route (for its number of darts) has it as a favorite from the
  start - 40 of them, 170 to 2 - until it is unmarked. The player's own
  checkout under "Your darts" can be marked too when it ends on a double and
  adds up to the number, optimal or not. Saved on the device
  (`Favorites`, key `dartle.favorites.v1`).
- Difficulty is a data-driven complexity band (`difficulty.dart`):
  `(darts-1) + trebles + (bull?1:0) + (target>=100?1:0)`.

## Languages

The little box next to the sound icon at the top (EN, HR) switches the whole app
between English and Croatian; the choice is saved on the device. Every text of
the app is written in English in the code and goes through `tr('...')`
(`trn(count, one, other)` when it depends on a count, `{pieces}` for the parts
that change); the Croatian version is looked up in `lib/src/i18n/croatian.dart`
under the English wording, and a text with no translation shows in English.
The silly insults and praise lines have a Croatian word bank of their own
(`lib/src/content/phrases_hr.dart`, with the gender of every noun).

To add a language: add it to `Language` in `lib/src/i18n/i18n.dart` (two letters
and its own name), write its catalog next to `croatian.dart`, and list it in
`I18n.catalogs`. `test/translations_test.dart` reads every `tr(...)` out of the
source and fails until the catalog has each text (with the same `{pieces}`) and
nothing that is no longer used.

## Layout

```
lib/src/domain       DartThrow, CheckoutRoute, CheckoutEngine, optimal routes
                     (bull-safe, better doubles, explainer), box layouts,
                     catalog, generator, validator
lib/src/content      the 1000 insults and the five praise lines, contact links
lib/src/scoring      ScoringService (streak points)
lib/src/timing       AttemptTimer (monotonic, idempotent start)
lib/src/stats        AttemptRecord, HistoryRepository, StatisticsService
lib/src/favorites    Favorites (the routes marked with the dart icon)
lib/src/i18n         Language, tr(), the Croatian catalog
lib/src/leaderboard  LeaderboardRepository (+ local impl), LeaderboardService
lib/src/storage      StorageService interface (+ in-memory impl)
lib/src/game         GameController + composition root
lib/ui, web          DOM views (package:web), localStorage adapter, CSS
```

To add a backend: implement `StorageService` and/or `LeaderboardRepository`
and pass them into `createGameController`.
