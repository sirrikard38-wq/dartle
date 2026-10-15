import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
import 'dart_icon.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'modal.dart';
import 'tiles.dart';
import 'view_context.dart';

/// A stable number from a route's text, so "random" placement is the same on
/// every redraw of the same result.
int _seed(String text) =>
    text.codeUnits.fold<int>(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

web.HTMLElement buildResultScreen(ViewContext ctx) {
  final game = ctx.game;
  final result = game.lastResult!;
  final challenge = result.challenge;
  final round = result.round;
  final entered = result.playerRoute.darts;
  final noCheckoutRight = result.isNoCheckoutAnswer;

  final String headline;
  if (result.isCorrect && result.isOptimal) {
    headline = 'Optimal!';
  } else if (result.isCorrect) {
    headline = 'Checkout!';
  } else {
    headline = switch (result.validation.outcome) {
      AttemptOutcome.bust => 'Bust',
      AttemptOutcome.outOfDarts => 'Out of darts',
      _ => 'Not quite',
    };
  }

  // Calculator: compare to the best routes. Practice: each dart's own rating.
  final List<TileState>? states = entered.isEmpty
      ? null
      : round != null
          ? [for (final s in round.steps) tileStateFor(s.quality)]
          : TileFeedback.best(entered, result.optimalRoutes);
  final best = result.optimalRoutes.isEmpty ? null : result.optimalRoutes.first;

  final showYours = entered.isNotEmpty;
  final showBest = best != null && !result.isOptimal;

  // One more route with a better double, then up to 2 more, shown as boxes.
  // Never the route you entered or the optimal route already on screen - those
  // (and every other optimal route) are in "All possibilities".
  final extras = best == null
      ? const <CheckoutRoute>[]
      : BetterDoubles.extras(result.optimalRoutes, exclude: [
          if (showBest) best,
          if (showYours) result.playerRoute,
        ]);
  web.HTMLElement? extraBoxes() => extras.isEmpty
      ? null
      : el('div', cls: 'extra-routes', children: [
          el('span', cls: 'extra-title', text: 'Also optimal'),
          for (final route in extras)
            tileRow(route.darts,
                slots: route.length,
                small: true,
                states: List.filled(route.length, TileState.correct),
                label: 'Also optimal: ${route.notation}'),
        ]);

  final yourExtras = !showBest ? extraBoxes() : null;
  final bestExtras = showBest ? extraBoxes() : null;

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
          'aria-label': 'You entered ${result.playerRoute.arithmetic.replaceAll('=', 'which is')}, '
              'not ${challenge.target}',
        }),

      // A right "No checkout": good job, and one silly line of encouragement.
      if (noCheckoutRight) ...[
        el('p', cls: 'good-job', text: 'Good job, no checkout here!'),
        el('p', cls: 'encourage', text: result.encouragement ?? ''),
      ],

      // Only one link under the number, in every mode: every optimal route,
      // each with its marked board and boxes, in a popup. (A number with no
      // checkout has no routes to show.)
      if (result.optimalRoutes.isNotEmpty)
        el('p', cls: 'why-row', children: [
          button('All possibilities', cls: 'text-link', focusKey: 'all', onPressed: (_) {
            web.HTMLElement figureFor(CheckoutRoute route) =>
                el('figure', cls: 'board-figure', children: [
                  buildDartboard(
                    linesOnly: true,
                    marks: spreadMarks(route.darts, const [], math.Random(_seed(route.notation))),
                    label: 'Route ${route.notation}',
                  ),
                  tileRow(route.darts,
                      slots: route.length,
                      small: true,
                      states: List.filled(route.length, TileState.correct),
                      label: route.notation),
                ]);

            // The first few routes, then a little dart with "Shoot more" for the
            // rest (only when there are more than a handful).
            final pages = RoutePages.split(result.optimalRoutes);
            final list = el('div', cls: 'possibilities', children: [
              for (final route in pages.first) figureFor(route),
            ]);
            web.HTMLElement? shootMore;
            if (pages.rest.isNotEmpty) {
              final more = button('',
                  cls: 'shoot-more',
                  ariaLabel: 'Shoot more: ${pages.rest.length} more optimal routes',
                  onPressed: (_) {
                for (final route in pages.rest) {
                  list.appendChild(figureFor(route));
                }
                shootMore?.remove();
                // The button is gone: hand the focus to Close, without scrolling.
                (web.document.querySelector('.modal-close') as web.HTMLElement?)
                    ?.focus(web.FocusOptions(preventScroll: true));
              })
                ..appendChild(dartIcon() as web.Node)
                ..appendChild(el('span', text: 'Shoot more'));
              shootMore = el('div', cls: 'shoot-more-row', children: [more]);
            }
            showModal(title: 'All possibilities', body: [
              el('p', cls: 'modal-line top', text: 'Every optimal way to check out ${challenge.target}.'),
              list,
              if (shootMore != null) shootMore,
            ]);
          }),
        ]),

      // The boards, small and side by side. Each has its route boxes directly
      // underneath it (taps keep their exact position on the board).
      el('div', cls: 'result-boards', children: [
        if (noCheckoutRight)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(linesOnly: true, label: 'Empty board: no darts used'),
            el('figcaption', text: 'No darts used'),
          ]),
        if (showYours)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(
              linesOnly: true,
              // Marks stored when each dart was entered; any missing ones are
              // placed beside earlier marks of the same dart.
              marks: spreadMarks(entered, ctx.marks,
                  math.Random(_seed(result.playerRoute.notation))),
              label: 'Your darts: ${result.playerRoute.notation}',
            ),
            el('figcaption', text: 'Your darts'),
            tileRow(entered,
                slots: Visit.darts,
                used: challenge.layout.used,
                small: true,
                states: states,
                label: 'Your darts'),
            if (yourExtras != null) yourExtras,
          ]),
        // Not optimal (or missed): the best route, marked and boxed the same
        // way, with more optimal routes as boxes.
        if (showBest)
          el('figure', cls: 'board-figure', children: [
            buildDartboard(
              linesOnly: true,
              // A repeated dart (T20 T20) sits side by side in its area. The
              // seed comes from the route, so it looks the same on every redraw.
              marks: spreadMarks(best.darts, const [], math.Random(_seed(best.notation))),
              label: 'Optimal route: ${best.notation}',
            ),
            el('figcaption', text: 'Optimal route'),
            tileRow(best.darts,
                slots: best.length,
                small: true,
                states: List.filled(best.length, TileState.correct),
                label: 'Optimal route'),
            if (bestExtras != null) bestExtras,
          ]),
      ]),
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

  return [
    if (scored)
      el('div', cls: 'big-stats', children: [
        // Where the countdown stopped (negative if you ran over) ...
        big(formatCountdown(timeLeft), 'TIME LEFT', negative: timeLeft.isNegative),
        // ... and the real time taken: 30s down to -8.33s is 38.33s used.
        big(formatSeconds(result.elapsed), 'TIME USED'),
        // The current score, centred, with what this attempt gave small beside
        // it. Press it to see how it was worked out.
        button('', cls: 'big-stat score-stat', focusKey: 'score', ariaLabel:
              'Score ${game.sessionPoints}, ${formatPoints(score.total)} this time. '
              'Press to see how it was worked out.',
            onPressed: (_) {
          showModal(title: 'How the score was worked out', body: [
            for (final line in score.explain()) modalLine(line),
            modalLine('Score now: ${game.sessionPoints}.'),
          ]);
        })
          ..appendChild(el('div', cls: 'points-row', children: [
            el('strong', text: formatScore(game.sessionPoints)),
            el('span', cls: 'delta', text: formatPoints(score.total)),
          ]))
          ..appendChild(el('span', text: 'SCORE')),
      ])
    else if (result.isReplay)
      el('p', cls: 'hint', text: 'Replay - no clock, no points.'),
    button('Next checkout',
        cls: 'cta',
        focusKey: 'next',
        onPressed: (_) => game.nextCheckout()),
    // Play the same number again: no clock, no points, nothing saved.
    button('Replay checkout',
        cls: 'cta secondary',
        focusKey: 'replay',
        onPressed: (_) => game.replayCheckout()),
  ];
}
