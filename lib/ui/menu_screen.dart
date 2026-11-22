import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'felga_screen.dart';
import 'view_context.dart';

/// Main menu: Start, Favorites, each Felgalizacija and a + for another (the
/// Leaderboard is no longer offered; its page stays).
web.HTMLElement buildMenuScreen(ViewContext ctx) {
  final game = ctx.game;

  return el('main', cls: 'screen menu', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'greeting', text: tr('Hi, {name}', {'name': game.playerName})),
      el('div', cls: 'menu-list', children: [
        button(tr('Start'),
            cls: 'menu-btn primary',
            focusKey: 'start',
            onPressed: (_) => ctx.showPage(MenuPage.modes)),
        button(tr('Favorites'),
            cls: 'menu-btn',
            focusKey: 'favorites',
            onPressed: (_) => ctx.showPage(MenuPage.favorites)),
        // The clubs' own pages: names, points and money.
        ...buildFelgaButtons(ctx),
      ]),
    ]),
  ]);
}
