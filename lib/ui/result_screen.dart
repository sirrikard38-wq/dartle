import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'favorites_ui.dart';
import 'modal.dart';
import 'tiles.dart';
import 'view_context.dart';

web.HTMLElement buildResultScreen(ViewContext ctx) {
  final game = ctx.game;
  final result = game.lastResult!;
  final challenge = result.challenge;
  final round = result.round;
  final entered = result.playerRoute.darts;
  final noCheckoutRight = result.isNoCheckoutAnswer;

  // An optimal route of fewer darts than were given: a right answer, but not in
  // the given number of darts.
  final goodButFewer = result.validation.outcome == AttemptOutcome.goodButFewerDarts;

  final String headline;
  if (goodButFewer) {
    headline = tr('Good, but not in the given number of darts');
  } else if (result.isCorrect && result.isOptimal) {
    headline = tr('Optimal!');
  } else if (result.isCorrect) {
    headline = tr('Checkout!');
  } else {
    headline = switch (result.validation.outcome) {
      AttemptOutcome.bust => tr('Bust'),
      AttemptOutcome.outOfDarts => tr('Out of darts'),
      _ => tr('Not quite'),
    };
  }

  // Calculator: compare to the best routes. Practice: each dart's own rating.
  final List<TileState>? states = entered.isEmpty
      ? null
      : goodButFewer
          ? List.filled(entered.length, TileState.correct)
          : round != null
              ? [for (final s in round.steps) tileStateFor(s.quality)]
              : TileFeedback.best(entered, result.optimalRoutes);
  final best = result.optimalRoutes.isEmpty ? null : result.optimalRoutes.first;

  final showYours = entered.isNotEmpty;
  final showBest = best != null && !result.isOptimal;

  // Every optimal route, each with its marked board and boxes, in a popup: all
  // of them, the same as Checkout input lights up. It opens from "Also optimal"
  // (there is no separate link and the popup has no title of its own). Each
  // board has the favorite dart in its corner.
  void openPossibilities() {
    // Every optimal route at once. The boards are centred, so a last row with
    // fewer boards sits in the middle.
    showModal(title: tr('Every optimal way to check out {n}', {'n': challenge.target}), showTitle: false, body: [
      el('p', cls: 'modal-line top', text: tr('Every optimal way to check out')),
      // The number under it, in the middle of the popup, above all the boards.
      el('p', cls: 'modal-number', text: '${challenge.target}'),
      // The favorites first. Then in order of the dart they finish on: D1, D2 ...
      // D20, then the Bull - but a Bull finish sits right next to the route with
      // the treble of its single (T7 D18 and S7 Bull).
      routeGrid(
          ctx,
          challenge.target,
          favoritesFirst(game.favorites, challenge.target, result.optimalRoutes,
              RouteOrder.forPopup(result.optimalRoutes))),
    ]);
  }

  // One more route with a better double, then up to 2 more, shown as boxes under
  // "Also optimal". Never the route you entered or the optimal route already on
  // screen - those (and every other optimal route) are in the popup that
  // "Also optimal" opens.
  final extras = best == null
      ? const <CheckoutRoute>[]
      : BetterDoubles.extras(result.optimalRoutes, exclude: [
          if (showBest) best,
          if (showYours) result.playerRoute,
        ]);
  web.HTMLElement? extraBoxes() => extras.isEmpty
      ? null
      : el('div', cls: 'extra-routes', children: [
          // The words "Also optimal" are the button that opens the popup.
          button(tr('Also optimal'),
              cls: 'text-link extra-title',
              focusKey: 'all',
              ariaLabel: tr('Also optimal: show every optimal way to check out {n}', {'n': challenge.target}),
              onPressed: (_) => openPossibilities()),
          for (final route in extras)
            tileRow(route.darts,
                slots: route.length,
                small: true,
                states: List.filled(route.length, TileState.correct),
                label: tr('Also optimal: {route}', {'route': route.notation})),
        ]);

  // A number with just one optimal route has nothing to list: it says so.
  final onlyPossibility = result.optimalRoutes.length == 1
      ? el('p', cls: 'hint only-one', text: tr('Only possibility'))
      : null;

  // "Also optimal" with its boxes (or "Only possibility"): in the middle under
  // the boards - after a miss under both of them, otherwise under the one board.
  final more = extraBoxes() ?? onlyPossibility;

  return el('main', cls: 'screen result', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'headline ${result.isCorrect ? 'good' : 'bad'}',
          text: '${result.isCorrect ? '✓ ' : '✗ '}$headline',
          attrs: {'role': 'status'}),
      el('p', cls: 'target small', text: '${challenge.target}'),

      // A miscount: show what the darts you entered really add up to, e.g.
      // "60 + 60 + 32 = 152" on 142. Only when the total was wrong.
      if (result.validation.outcome == AttemptOutcome.wrongTotal)
        el('p', cls: 'equation', text: result.playerRoute.arithmetic, attrs: {
          'aria-label': tr('You entered {sum}, not {target}', {
            'sum': result.playerRoute.arithmetic.replaceAll('=', tr('which is')),
            'target': challenge.target,
          }),
        }),

      // A right "No checkout": good job, and one silly line of encouragement.
      if (noCheckoutRight) ...[
        el('p', cls: 'good-job', text: tr('Good job, no checkout here!')),
        el('p', cls: 'encourage', text: result.encouragement ?? ''),
      ],

      // The boards, small and side by side. Each has its route boxes directly
      // underneath it (taps keep their exact position on the board).
      el('div', cls: 'result-boards', children: [
        if (noCheckoutRight)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(linesOnly: true, label: tr('Empty board: no darts used')),
            el('figcaption', text: tr('No darts used')),
          ]),
        if (showYours)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(
              linesOnly: true,
              // Marks stored when each dart was entered; any missing ones are
              // placed beside earlier marks of the same dart.
              marks: spreadMarks(entered, ctx.marks,
                  math.Random(routeSeed(result.playerRoute.notation))),
              label: tr('Your darts: {route}', {'route': result.playerRoute.notation}),
            ),
            el('figcaption', text: tr('Your darts')),
            tileRow(entered,
                slots: Visit.darts,
                used: challenge.layout.used,
                small: true,
                states: states,
                label: tr('Your darts')),
            // Your own checkout can be a favorite when it ends on a double and
            // adds up to the number, optimal or not.
            if (favoriteForYourRoute(ctx, challenge.target, result.playerRoute) case final fav?) fav,
          ]),
        // Not optimal (or missed): the best route, marked and boxed the same way.
        if (showBest)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(
              linesOnly: true,
              // A repeated dart (T20 T20) sits side by side in its area. The
              // seed comes from the route, so it looks the same on every redraw.
              marks: spreadMarks(best.darts, const [], math.Random(routeSeed(best.notation))),
              label: tr('Optimal route: {route}', {'route': best.notation}),
            ),
            el('figcaption', text: tr('Optimal route')),
            tileRow(best.darts,
                slots: best.length,
                small: true,
                states: List.filled(best.length, TileState.correct),
                label: tr('Optimal route')),
          ]),
      ]),
      // In the middle, under the board or boards; "Also optimal" opens the popup
      // with every optimal route.
      if (more != null) el('div', cls: 'result-more', children: [more]),
      ..._footer(ctx, result),
    ]),
  ]);
}

/// Time, score and the buttons.
List<web.HTMLElement> _footer(ViewContext ctx, AttemptResult result) {
  final game = ctx.game;
  final score = result.score;
  // The practice modes have no clock and no score. A replay has neither.
  final scored = game.mode.hasScore && !result.isReplay;
  final timeLeft = game.timeLimit - result.elapsed;

  web.HTMLElement big(String value, String label, {bool negative = false}) =>
      el('div', cls: 'big-stat${negative ? ' negative' : ''}', children: [
        el('strong', text: value),
        el('span', text: label),
      ]);

  // Every undo used, then a miss: the session is over. Only the total score
  // and Replay session, which starts a new session (and a new score).
  if (game.isSessionOver) {
    return [
      el('p', cls: 'session-score',
          text: tr('Score: {points}', {'points': formatScore(game.sessionPoints)})),
      el('p', cls: 'hint session-over', text: tr('No undos left, so the session is over.')),
      button(tr('Replay session'),
          cls: 'cta',
          focusKey: 'replay-session',
          onPressed: (_) => game.replaySession()),
    ];
  }

  return [
    if (scored)
      el('div', cls: 'big-stats', children: [
        // Where the countdown stopped (negative if you ran over) ...
        big(formatCountdown(timeLeft), tr('TIME LEFT'), negative: timeLeft.isNegative),
        // ... and the real time taken: 30s down to -8.33s is 38.33s used.
        big(formatSeconds(result.elapsed), tr('TIME USED')),
        // The current score, centred, with what this attempt gave small beside
        // it. Press it to see how it was worked out.
        button('', cls: 'big-stat score-stat', focusKey: 'score', ariaLabel:
              tr('Score {total}, {points} this time. Press to see how it was worked out.', {
                'total': game.sessionPoints,
                'points': formatPoints(score.total),
              }),
            onPressed: (_) {
          showModal(title: tr('How the score was worked out'), body: [
            for (final line in score.explain()) modalLine(line),
            modalLine(tr('Score now: {total}.', {'total': game.sessionPoints})),
          ]);
        })
          ..appendChild(el('div', cls: 'points-row', children: [
            el('strong', text: formatScore(game.sessionPoints)),
            el('span', cls: 'delta', text: formatPoints(score.total)),
          ]))
          ..appendChild(el('span', text: tr('SCORE'))),
      ])
    else if (result.isReplay)
      el('p', cls: 'hint', text: tr('Replay - no clock, no points.')),
    button(tr('Next checkout'),
        cls: 'cta',
        focusKey: 'next',
        onPressed: (_) => game.nextCheckout()),
    // Play the same number again: no clock, no points, nothing saved.
    button(tr('Replay checkout'),
        cls: 'cta secondary',
        focusKey: 'replay',
        onPressed: (_) => game.replayCheckout()),
  ];
}
