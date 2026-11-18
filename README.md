# Dartle — Darts Checkout Trainer

Wordle-style trainer for 501 checkouts, in three modes and a tutorial:

- **Checkout calculator** - a number and three boxes (a visit). Boxes that are
  crossed out are darts already used; you fill the free ones. Against the
  clock, scored by streak and saved to the leaderboard. All the
  one-dart numbers (21) together come up 2% of the time; every other number, the
  seven with no checkout included, shares the other 98% equally.
- **Checkout practice** - choose your own darts one at a time; the optimal darts
  are lit on the board. No clock, no score, nothing saved.
- **Checkout input** - type any number (2-170) and practise it the same way.
- **Checkout tutorial** - learn what to aim at and why, then practise it: a card
  per number and darts in hand, from the checkout tables.

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
- **Optimal** comes from the **checkout tables** in `data/checkout-tables`
  (`izlazi-1-strelica.csv`, `izlazi-2-strelice.csv`, `izlazi-3-strelice.csv`,
  with `pikado-izlazi-kontekst.md`): for every number from 2 to 170 and 1, 2 or
  3 darts in hand, the target to aim at, the route, and up to two targets almost
  as good. They come from a model of the board with the spread of a real throw,
  so they look at what a miss into the next area leaves: 127 with three darts is
  `T20 T17 D8` (S20 leaves 107, `T19 Bull`), not T19 (S19 leaves 108).
  `dart run tool/checkout_tables.dart` turns them into
  `lib/src/domain/checkout_tables.dart`; `CheckoutTable` reads a row.
  - The optimal routes of a number (`OptimalRouteService`) are its table route
    (`S16/S8 D16/D20` is two routes, `25 D18 ili BULL S3 D4` either) and, for
    each target almost as good, that target and the table route of what it
    leaves (62 with three darts: `T10 D16`, `T14 D10`, `T18 D4`). A target
    just as good counts the same: of the same kind, its hit leaves a checkout in
    no more darts and its misses keep as many checkouts (25 with two darts: the
    table's S17, and S3, S19, S7).
  - A route may finish with a dart still in hand (64 with three darts:
    `T16 D8`): that is the optimal answer, in the calculator too. Checking out
    sooner another way is a miss, unless it is an optimal route of the fewest
    darts ("Good, but not in the given number of darts").
  - Practice and input light, before every dart, the table's target for what
    is left with the darts left, and the targets almost as good
    (`OptimalRouteService.aimsIn`). With no checkout left in the darts in hand
    the table's setup for the next visit is lit (41 with one dart: S9).
  - A two-dart number over 60 comes with three darts half the time in the
    calculator; every two-dart number can be switched to three darts in
    practice and input.
  - The popup and the "Also optimal" boxes list every optimal route.
- **Checkout tutorial** (`CheckoutTutor`, `TutorialSession`,
  `lib/ui/tutorial_screen.dart`): Learn - type a number, choose 1, 2 or 3 darts
  in hand, and read the card: what to aim at, the route, what a hit and a miss
  into the next area leave, and why not the most tempting other target (one
  whose miss leaves fewer checkouts). Practice - a number and darts are given,
  press where you would aim on the board, and the same card says if it was
  right. No clock, no score, nothing saved.
- The first-choice ("Throw") routes from dartscheckoutassistant.com
  (`site_routes.dart`, generated by `tool/site_routes.dart`) are only compared
  with the tables: `docs/site-comparison.md` (`dart run tool/site_report.dart`).
  The chart (`canonical_checkouts.dart`) is kept as data; tests check it is legal.
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
                     (the checkout tables, better doubles, the tutorial
                     cards), box layouts,
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
