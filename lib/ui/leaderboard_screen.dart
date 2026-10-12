import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

web.HTMLElement buildLeaderboardScreen(ViewContext ctx) {
  final game = ctx.game;
  final sort = ctx.leaderboardSort;
  final list = el('ol', cls: 'rank-list');
  final status = el('p', cls: 'hint', text: 'Loading…');

  String metric(LeaderboardEntry e) => switch (sort) {
        LeaderboardSort.points => '${e.totalPoints}',
        LeaderboardSort.averageTime => formatMsAsSeconds(e.averageTimeMs),
        LeaderboardSort.accuracy => formatPercent(e.accuracyPercent),
        LeaderboardSort.optimalPercent => formatPercent(e.optimalPercent),
      };

  game.leaderboard(sort).then((entries) {
    status.textContent = '';
    for (final e in entries) {
      final isMe = e.playerName == game.playerName;
      list.appendChild(el('li', cls: isMe ? 'me' : null, children: [
        el('span', cls: 'name', text: e.playerName),
        el('strong', text: metric(e)),
      ]));
    }
  });

  return el('main', cls: 'screen leaderboard', children: [
    el('div', cls: 'play-area', children: [
      el('h2', text: 'Leaderboard'),
      el('div', cls: 'chips', attrs: {'role': 'group', 'aria-label': 'Rank by'}, children: [
        for (final option in LeaderboardSort.values)
          button(option.label,
              cls: 'chip${option == sort ? ' selected' : ''}',
              attrs: {'aria-pressed': '${option == sort}'},
              onPressed: (_) {
                ctx.leaderboardSort = option;
                ctx.rerender();
              }),
      ]),
      status,
      list,
      el('p', cls: 'hint', text: 'Local scores plus sample players. Online ranking comes later.'),
    ]),
  ]);
}
