import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// After Start: pick Checkout calculator or Checkout practice.
web.HTMLElement buildModesScreen(ViewContext ctx) {
  final game = ctx.game;

  web.HTMLButtonElement modeButton(GameMode mode) {
    final b = button('',
        cls: 'mode-card',
        focusKey: 'mode-${mode.name}',
        ariaLabel: '${mode.label}: ${mode.blurb}',
        onPressed: (_) => game.startGame(null, mode));
    b.appendChild(el('strong', text: mode.label));
    b.appendChild(el('span', text: mode.blurb));
    return b;
  }

  return el('main', cls: 'screen modes', children: [
    el('div', cls: 'play-area', children: [
      el('h2', text: 'Choose a game'),
      el('div', cls: 'mode-list', children: [
        for (final mode in GameMode.values) modeButton(mode),
      ]),
    ]),
  ]);
}
