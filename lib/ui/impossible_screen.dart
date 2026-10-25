import 'dart:async';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// When the Next checkout button can be used: 2 seconds after the insult
/// appears (the insult is 1 second after the words). Keep this in step with
/// `.fade-2` and `.fade-3` in styles.css.
const Duration _nextAfter = Duration(seconds: 3);

/// Checkout input, for a number that cannot be checked out: the words fade in
/// smoothly, 1 second later a silly insult fades in under them, and 2 seconds
/// after that the Next checkout button appears.
web.HTMLElement buildImpossibleScreen(ViewContext ctx) {
  final game = ctx.game;
  final next = button(tr('Next checkout'),
      cls: 'cta fade fade-3',
      focusKey: 'next',
      disabled: true, // until it has faded in
      onPressed: (_) => game.nextCheckout());
  Timer(_nextAfter, () => next.disabled = false);

  return el('main', cls: 'screen impossible', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'target small', text: '${game.impossibleNumber}'),
      el('p', cls: 'impossible-title fade fade-1',
          text: tr('This number is impossible to checkout.'),
          attrs: {'role': 'status'}),
      el('p', cls: 'insult fade fade-2', text: game.insult ?? ''),
      next,
    ]),
  ]);
}
