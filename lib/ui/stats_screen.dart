import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

web.HTMLElement buildStatsScreen(ViewContext ctx) {
  final game = ctx.game;
  final s = game.summary;
  final byTarget = game.statistics.byTarget(game.history).values.toList()
    ..sort((a, b) {
      final byAcc = a.accuracyPercent.compareTo(b.accuracyPercent);
      return byAcc != 0 ? byAcc : b.attempts.compareTo(a.attempts);
    });

  web.HTMLElement big(String value, String label) => el('div', cls: 'big-stat', children: [
        el('strong', text: value),
        el('span', text: label),
      ]);

  // Wordle-style distribution bars for completed checkouts by dart count.
  final maxCount = [1, 2, 3]
      .map((d) => s.successesByDartCount[d] ?? 0)
      .fold<int>(1, (m, v) => v > m ? v : m);
  final bars = el('div', cls: 'bars', children: [
    for (final darts in [1, 2, 3])
      el('div', cls: 'bar-row', children: [
        el('span', text: '$darts'),
        el('div', cls: 'bar', attrs: {
          'style': 'width:${((s.successesByDartCount[darts] ?? 0) * 100 / maxCount).clamp(8, 100)}%',
        }, children: [textNode('${s.successesByDartCount[darts] ?? 0}')]),
      ]),
  ]);

  final weakest = byTarget.where((t) => t.successes < t.attempts).take(5).toList();

  return el('main', cls: 'screen stats', children: [
    el('div', cls: 'play-area', children: [
      el('h2', text: 'Statistics'),
      el('div', cls: 'big-stats', children: [
        big('${s.totalAttempts}', 'PLAYED'),
        big(s.totalAttempts == 0 ? '0' : '${s.accuracyPercent.round()}', 'ACCURACY %'),
        big(formatMsAsSeconds(s.averageSuccessTimeMs), 'AVG TIME'),
        big('${s.totalPoints}', 'POINTS'),
      ]),
      el('h3', text: 'Checkouts by darts'),
      bars,
      el('h3', text: 'Needs practice'),
      if (weakest.isEmpty)
        el('p', cls: 'hint', text: 'Nothing yet — play a few rounds.')
      else
        el('ul', cls: 'weak-list', children: [
          for (final t in weakest)
            el('li', children: [
              el('strong', text: '${t.target}'),
              el('span', text: '${t.successes} of ${t.attempts} right'),
            ]),
        ]),
      el('details', cls: 'more', children: [
        el('summary', text: 'More numbers'),
        el('dl', cls: 'kv', children: [
          for (final (k, v) in [
            ('Optimal routes', formatPercent(s.optimalPercent)),
            ('Fastest checkout', formatMsAsSeconds(s.fastestSuccessMs)),
            ('Best session', '${s.bestSessionPoints}'),
            ('Easy points', '${s.pointsByDifficulty[DifficultyLevel.easy]}'),
            ('Medium points', '${s.pointsByDifficulty[DifficultyLevel.medium]}'),
            ('Hard points', '${s.pointsByDifficulty[DifficultyLevel.hard]}'),
          ]) ...[el('dt', text: k), el('dd', text: v)],
        ]),
        if (byTarget.isNotEmpty)
          el('div', cls: 'table-wrap', children: [
            el('table', cls: 'data-table', children: [
              el('caption', text: 'Every number you have tried'),
              el('thead', children: [
                el('tr', children: [
                  for (final h in ['No.', 'Right', 'Avg', 'Best', 'Optimal'])
                    el('th', text: h, attrs: {'scope': 'col'}),
                ]),
              ]),
              el('tbody', children: [
                for (final t in byTarget)
                  el('tr', children: [
                    el('th', text: '${t.target}', attrs: {'scope': 'row'}),
                    el('td', text: '${t.successes}/${t.attempts}'),
                    el('td', text: formatMsAsSeconds(t.averageSuccessTimeMs)),
                    el('td', text: formatMsAsSeconds(t.bestTimeMs)),
                    el('td', text: '${t.optimalSuccesses}/${t.successes}'),
                  ]),
              ]),
            ]),
          ]),
        button('Reset statistics', cls: 'text-btn', onPressed: (_) {
          if (web.window.confirm('Erase all saved statistics?')) {
            game.resetStatistics();
          }
        }),
      ]),
    ]),
  ]);
}
