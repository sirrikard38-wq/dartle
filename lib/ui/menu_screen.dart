import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'felga_screen.dart';
import 'view_context.dart';

/// Main menu: Start (straight into Checkout calculator, the one game left, on
/// Practice), Favorites, each Felgalizacija and a + for another.
web.HTMLElement buildMenuScreen(ViewContext ctx) {
  final game = ctx.game;

  // Each goes down and up (quickly) before its screen opens.
  late final web.HTMLButtonElement start, favorites;
  start = button(tr('Start'),
      cls: 'menu-btn primary',
      focusKey: 'start',
      onPressed: (_) => pressThen(start, () {
            game.tutorial.tab = TutorialTab.practice;
            ctx.showPage(MenuPage.tutorial);
          }));
  favorites = button(tr('Favorites'),
      cls: 'menu-btn',
      focusKey: 'favorites',
      onPressed: (_) => pressThen(favorites, () => ctx.showPage(MenuPage.favorites)));

  return el('main', cls: 'screen menu', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'greeting', text: tr('Hi, {name}', {'name': game.playerName})),
      el('div', cls: 'menu-list', children: [
        start,
        favorites,
        // The clubs' own pages: names, points and money.
        ...buildFelgaButtons(ctx),
      ]),
    ]),
  ]);
}
