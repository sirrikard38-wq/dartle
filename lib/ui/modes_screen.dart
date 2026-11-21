import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// After Start: Checkout calculator (the learning part: Input, Favorites,
/// Practice, Learn, Miss - it was Checkout tutorial) first, then Checkout
/// practice. The timed, scored game is no longer offered (its code and the
/// leaderboard stay).
web.HTMLElement buildModesScreen(ViewContext ctx) {
  final game = ctx.game;

  web.HTMLButtonElement modeButton(GameMode mode) {
    final b = button('',
        cls: 'mode-card',
        focusKey: 'mode-${mode.name}',
        ariaLabel: '${tr(mode.label)}: ${tr(mode.blurb)}',
        onPressed: (_) {
          ctx.choiceTab = 1; // a new game starts on Play
          game.startGame(null, mode);
        });
    b.appendChild(el('strong', text: tr(mode.label)));
    b.appendChild(el('span', text: tr(mode.blurb)));
    return b;
  }

  // Checkout tutorial is not a game: it has its own page.
  final tutorial = button('',
      cls: 'mode-card',
      focusKey: 'mode-tutorial',
      ariaLabel: '${tr('Checkout calculator')}: ${tr('Learn what to aim at, and why.')}',
      onPressed: (_) {
        // It always opens on Practice.
        game.tutorial.tab = TutorialTab.practice;
        ctx.showPage(MenuPage.tutorial);
      });
  tutorial.appendChild(el('strong', text: tr('Checkout calculator')));
  tutorial.appendChild(el('span', text: tr('Learn what to aim at, and why.')));

  return el('main', cls: 'screen modes', children: [
    el('div', cls: 'play-area', children: [
      el('div', cls: 'mode-list', children: [
        tutorial,
        for (final mode in GameMode.values)
          if (mode != GameMode.calculator) modeButton(mode),
      ]),
    ]),
  ]);
}
