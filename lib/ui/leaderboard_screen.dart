import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

web.HTMLElement buildLeaderboardScreen(ViewContext ctx) {
  final game = ctx.game;
  final sort = ctx.leaderboardSort;
  final list = el('ol', cls: 'rank-list');
  final status = el('p', cls: 'hint', text: 'Loading…');
  final note = el('p', cls: 'hint', text: '');

  String metric(LeaderboardEntry e) => switch (sort) {
        LeaderboardSort.points => '${e.totalPoints}',
        LeaderboardSort.averageTime => formatMsAsSeconds(e.averageTimeMs),
        LeaderboardSort.accuracy => formatPercent(e.accuracyPercent),
        LeaderboardSort.optimalPercent => formatPercent(e.optimalPercent),
      };

  game.leaderboard(sort).then((entries) {
    final online = game.leaderboardIsOnline;
    final myId = game.leaderboardPlayerId;
    // Online rows are told apart by id (two players may share a name); local
    // rows by name.
    bool isMe(LeaderboardEntry e) =>
        e.id != null && myId != null ? e.id == myId : e.playerName == game.playerName;

    status.textContent = entries.isEmpty ? 'No scores yet - be the first!' : '';
    for (final e in entries) {
      list.appendChild(el('li', cls: isMe(e) ? 'me' : null, children: [
        el('span', cls: 'name', text: e.playerName),
        el('strong', text: metric(e)),
      ]));
    }
    // Only the players there are now are listed, but the board shows all its
    // places: the ones nobody has taken yet stay empty (just their number) and
    // fill up as players join. A non-breaking space in each cell keeps their height.
    final blank = String.fromCharCode(0xA0);
    for (var place = entries.length; place < LeaderboardService.boardSize; place++) {
      list.appendChild(el('li', cls: 'empty', attrs: {'aria-hidden': 'true'}, children: [
        el('span', cls: 'name', text: blank),
        el('strong', text: blank),
      ]));
    }
    note.textContent =
        online ? 'Your name and scores are visible to all players.' : 'Scores on this device.';
  });

  return el('main', cls: 'screen leaderboard', children: [
    el('div', cls: 'play-area', children: [
      // The title is in the middle (the style uppercases it).
      el('h2', text: '180 Leaderboard'),
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
      note,
    ]),
  ]);
}
