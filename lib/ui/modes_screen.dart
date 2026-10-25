import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// After Start: pick Checkout calculator, Checkout practice or Checkout input.
web.HTMLElement buildModesScreen(ViewContext ctx) {
  final game = ctx.game;

  web.HTMLButtonElement modeButton(GameMode mode) {
    final b = button('',
        cls: 'mode-card',
        focusKey: 'mode-${mode.name}',
        ariaLabel: '${tr(mode.label)}: ${tr(mode.blurb)}',
        onPressed: (_) => game.startGame(null, mode));
    b.appendChild(el('strong', text: tr(mode.label)));
    b.appendChild(el('span', text: tr(mode.blurb)));
    return b;
  }

  return el('main', cls: 'screen modes', children: [
    el('div', cls: 'play-area', children: [
      el('div', cls: 'mode-list', children: [
        for (final mode in GameMode.values) modeButton(mode),
      ]),
    ]),
  ]);
}
