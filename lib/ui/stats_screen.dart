import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// One row of the all-numbers table. A number with no checkout is in red and
/// says so.
web.HTMLElement _numberRow(GameController game, int n, TargetStats? t) {
  final noCheckout = game.hasNoCheckout(n);
  final success = t == null ? '—' : '${t.successes}/${t.attempts}';
  return el('tr', cls: noCheckout ? 'no-checkout-row' : null, children: [
    el('th', text: '$n', attrs: {'scope': 'row'}),
    el('td', text: success),
    if (noCheckout)
      el('td', cls: 'no-checkout', text: 'no checkout', attrs: {'colspan': '3'})
    else ...[
      el('td', text: formatMsAsSeconds(t?.averageSuccessTimeMs)),
      el('td', text: formatMsAsSeconds(t?.bestTimeMs)),
      el('td', text: t == null ? '—' : '${t.optimalSuccesses}/${t.successes}'),
    ],
  ]);
}

web.HTMLElement buildStatsScreen(ViewContext ctx) {
  final game = ctx.game;
  final s = game.summary;
  final stats = game.statistics.byTarget(game.history);

  web.HTMLElement big(String value, String label) => el('div', cls: 'big-stat', children: [
        el('strong', text: value),
        el('span', text: label),
      ]);

  // The weakest numbers, the largest number at the top.
  final weakest = game.statistics.needsPractice(game.history);

  return el('main', cls: 'screen stats', children: [
    el('div', cls: 'play-area', children: [
      el('h2', text: 'Statistics'),
      el('div', cls: 'big-stats', children: [
        big('${s.totalAttempts}', 'PLAYED'),
        big(s.totalAttempts == 0 ? '0' : '${s.accuracyPercent.round()}', 'ACCURACY %'),
        big(formatMsAsSeconds(s.averageSuccessTimeMs), 'AVG TIME'),
        big('${s.totalPoints}', 'POINTS'),
      ]),
      el('h3', text: 'Needs practice'),
      if (weakest.isEmpty)
        el('p', cls: 'hint', text: 'Nothing yet — play a few rounds.')
      else
        el('ul', cls: 'weak-list', children: [
          for (final t in weakest)
            el('li', children: [
              el('strong', text: '${t.target}'),
              el('span', text: '${t.successes} of ${t.attempts} success'),
            ]),
        ]),
      // The key figures, then every number's own record (no heading of its own).
      el('div', cls: 'more-stats', children: [
        el('dl', cls: 'kv', children: [
          for (final (k, v) in [
            ('Optimal routes', formatPercent(s.optimalPercent)),
            ('Fastest checkout', formatMsAsSeconds(s.fastestSuccessMs)),
            ('Best session', '${s.bestSessionPoints}'),
          ]) ...[el('dt', text: k), el('dd', text: v)],
        ]),
        el('div', cls: 'table-wrap', children: [
          el('table', cls: 'data-table', children: [
            el('caption', text: 'Every number, from 170 down to 2'),
            el('thead', children: [
              el('tr', children: [
                for (final h in ['No.', 'Success', 'Avg', 'Best', 'Optimal'])
                  el('th', text: h, attrs: {'scope': 'col'}),
              ]),
            ]),
            el('tbody', children: [
              for (var n = 170; n >= 2; n--) _numberRow(game, n, stats[n]),
            ]),
          ]),
        ]),
      ]),
      // Reset statistics is the last thing on the screen, against the right edge.
      el('div', cls: 'reset-box', children: [
        button('Reset statistics', cls: 'text-btn reset-stats', onPressed: (_) {
          if (web.window.confirm('Erase all saved statistics?\n\n'
              'The leaderboard is not affected.')) {
            game.resetStatistics();
          }
        }),
        el('p', cls: 'reset-note', text: 'Does not affect the leaderboard'),
      ]),
    ]),
  ]);
}
