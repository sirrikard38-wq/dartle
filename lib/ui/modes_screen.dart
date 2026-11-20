import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// After Start: pick Checkout calculator, Checkout practice or Checkout
/// tutorial.
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
      ariaLabel: '${tr('Checkout tutorial')}: ${tr('Learn what to aim at, and why.')}',
      onPressed: (_) => ctx.showPage(MenuPage.tutorial));
  tutorial.appendChild(el('strong', text: tr('Checkout tutorial')));
  tutorial.appendChild(el('span', text: tr('Learn what to aim at, and why.')));

  return el('main', cls: 'screen modes', children: [
    el('div', cls: 'play-area', children: [
      el('div', cls: 'mode-list', children: [
        for (final mode in GameMode.values) modeButton(mode),
        tutorial,
      ]),
    ]),
  ]);
}
