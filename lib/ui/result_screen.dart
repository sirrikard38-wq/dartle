import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
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

  // One more route with a better double, then up to 3 more, shown as boxes.
  final extras = best == null
      ? const <CheckoutRoute>[]
      : BetterDoubles.extras(result.optimalRoutes, best);
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

  final showYours = entered.isNotEmpty;
  final showBest = best != null && !result.isOptimal;
  final yourExtras = !showBest ? extraBoxes() : null;
  final bestExtras = showBest ? extraBoxes() : null;

  return el('main', cls: 'screen result', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'headline ${result.isCorrect ? 'good' : 'bad'}',
          text: '${result.isCorrect ? '✓ ' : '✗ '}$headline',
          attrs: {'role': 'status'}),
      el('p', cls: 'target small', text: '${challenge.target}'),

      // A right "No checkout": good job, and one silly line of encouragement.
      if (noCheckoutRight) ...[
        el('p', cls: 'good-job', text: 'Good job, no checkout here!'),
        el('p', cls: 'encourage', text: result.encouragement ?? ''),
      ],

      // Only these links under the number: the explanations are in popups.
      el('p', cls: 'why-row', children: [
        button('Show why.', cls: 'text-link', focusKey: 'why', onPressed: (_) {
          showModal(title: 'Why', body: [
            for (final line in RouteExplainer.explain(
              challenge: challenge,
              optimalRoutes: result.optimalRoutes,
              playerRoute: result.playerRoute,
              playerCorrect: result.isCorrect,
              playerOptimal: result.isOptimal,
              mistake: result.validation.message,
            ))
              modalLine(line),
          ]);
        }),
        if (result.isPractice && result.optimalRoutes.isNotEmpty)
          button('All possibilities', cls: 'text-link', focusKey: 'all', onPressed: (_) {
            showModal(title: 'All possibilities', body: [
              el('p', cls: 'modal-line', text: 'Every optimal way to check out ${challenge.target}.'),
              el('div', cls: 'possibilities', children: [
                for (final route in result.optimalRoutes)
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
                  ]),
              ]),
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
