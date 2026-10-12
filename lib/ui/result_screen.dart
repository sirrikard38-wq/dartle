import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'tiles.dart';
import 'view_context.dart';

/// A stable number from a route's text, so "random" placement is the same on
/// every redraw of the same result.
int _seed(String text) =>
    text.codeUnits.fold<int>(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

web.HTMLElement buildResultScreen(ViewContext ctx) {
  final game = ctx.game;
  final result = game.lastResult!;
  final round = result.round;
  final entered = result.playerRoute.darts;
  final gaveUp = result.validation.outcome == AttemptOutcome.gaveUp;
  // Calculator: one box per dart of the optimal route. Choice: three darts.
  final slots = round?.maxDarts ?? result.challenge.dartCount;

  final String headline;
  if (result.isCorrect && result.isOptimal) {
    headline = 'Optimal!';
  } else if (result.isCorrect) {
    headline = 'Checkout!';
  } else if (gaveUp) {
    headline = 'Skipped';
  } else {
    headline = switch (result.validation.outcome) {
      AttemptOutcome.bust => 'Bust',
      AttemptOutcome.outOfDarts => 'Out of darts',
      _ => 'Not quite',
    };
  }

  // Calculator: compare to the best route. Choice: each dart's own rating.
  final List<TileState>? states = entered.isEmpty
      ? null
      : round != null
          ? [for (final s in round.steps) tileStateFor(s.quality)]
          : TileFeedback.best(entered, result.optimalRoutes);
  final best = result.optimalRoutes.first;

  return el('main', cls: 'screen result', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'headline ${result.isCorrect ? 'good' : 'bad'}',
          text: '${result.isCorrect ? '✓ ' : (gaveUp ? '' : '✗ ')}$headline',
          attrs: {'role': 'status'}),
      el('p', cls: 'target small', text: '${result.challenge.target}'),
      if (!gaveUp) el('p', cls: 'message', text: result.validation.message),

      // The two boards, small and side by side. Each has its own route boxes
      // directly underneath it (taps keep their exact position on the board).
      el('div', cls: 'result-boards', children: [
        if (entered.isNotEmpty)
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
                slots: slots, small: true, states: states, label: 'Your darts'),
          ]),
        // Not optimal (or missed): the best route, marked and boxed the same way.
        if (!result.isOptimal)
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
          ]),
      ]),
      // Choice: every fewest-darts route is equally good - show a few.
      if (!result.isOptimal && round != null && result.optimalRoutes.length > 1)
        el('p', cls: 'equal-routes', children: [
          el('span', text: 'Equally optimal'),
          el('strong', text: result.optimalRoutes.take(5).map((r) => r.notation).join('  ·  ')),
        ]),
      ..._footer(ctx, result),
    ]),
  ]);
}

/// Time, points, breakdown and the next button - the same in both modes.
List<web.HTMLElement> _footer(ViewContext ctx, AttemptResult result) {
  final game = ctx.game;
  final score = result.score;
  // Checkout practice has no clock and no score, so it shows no time and no
  // points at all - just the result and the boards.
  final timed = !result.isChoice;
  final scored = !result.isChoice;
  final timeLeft = game.timeLimit - result.elapsed;

  web.HTMLElement big(String value, String label, {bool negative = false}) =>
      el('div', cls: 'big-stat${negative ? ' negative' : ''}', children: [
        el('strong', text: value),
        el('span', text: label),
      ]);

  return [
    if (timed || scored)
      el('div', cls: 'big-stats', children: [
        if (timed) ...[
          // Where the countdown stopped (negative if you ran over) ...
          big(formatCountdown(timeLeft), 'TIME LEFT', negative: timeLeft.isNegative),
          // ... and the real time taken: 30s down to -8.33s is 38.33s used.
          big(formatSeconds(result.elapsed), 'TIME USED'),
        ],
        if (scored)
          // The session score, with what this attempt gave next to it (+5 or -4).
          el('div', cls: 'big-stat', children: [
            el('div', cls: 'points-row', children: [
              el('strong',
                  cls: game.sessionPoints < 0 ? 'neg' : null,
                  text: formatScore(game.sessionPoints)),
              el('span',
                  cls: 'delta${score.total < 0 ? ' neg' : ''}',
                  text: formatPoints(score.total)),
            ]),
            el('span', text: 'POINTS'),
          ]),
      ]),
    button('Next checkout',
        cls: 'cta',
        focusKey: 'next',
        onPressed: (_) => game.nextCheckout()),
  ];
}
