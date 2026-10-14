import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// A small stylised dart pointing right. Drawn in the current text colour.
web.Element _dartIcon() => svg('svg', cls: 'dart-icon', attrs: {
      'viewBox': '0 0 72 28',
      'aria-hidden': 'true',
      'focusable': 'false',
    }, children: [
      // Flight (the two fins), shaft, barrel and tip.
      svg('path', attrs: {'d': 'M2 3 L11 3 L19 14 L11 25 L2 25 L8 14 Z', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '18', 'y': '12', 'width': '16', 'height': '4', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '32', 'y': '8', 'width': '24', 'height': '12', 'rx': '3', 'fill': 'currentColor'}),
      svg('path', attrs: {'d': 'M56 11 L70 14 L56 17 Z', 'fill': 'currentColor'}),
    ]);

/// Shown every time the app opens: DARTLE and "Checkout calculator by PK
/// Normal" fade in one after another, then give way to "Welcome" with a name
/// box. Enter (or the dart button) continues to the menu. Tap to skip.
web.HTMLElement buildWelcomeScreen(ViewContext ctx) {
  final game = ctx.game;

  final input = el('input', cls: 'name-input big', attrs: {
    'id': 'welcome-name',
    'type': 'text',
    'maxlength': '${GameController.maxPlayerNameLength}',
    'autocomplete': 'nickname',
    'autocapitalize': 'words',
    'spellcheck': 'false',
    'placeholder': 'Enter your name...',
    'aria-label': 'Your name',
    'data-focus': 'name',
    'value': game.needsPlayerName ? '' : game.playerName,
  }) as web.HTMLInputElement;

  void submit() {
    if (input.value.trim().isEmpty) {
      ctx.toast('Enter your name to continue');
      input.focus();
      return;
    }
    game.setPlayerName(input.value); // saves in the background
    ctx.showPage(MenuPage.home);
  }

  web.EventStreamProviders.keyDownEvent.forElement(input).listen((event) {
    if (event.key == 'Enter') {
      event.preventDefault();
      submit();
    }
  });

  final screen = el('main', cls: 'screen welcome', children: [
    // Fade in from nothing, one after the other; no movement.
    el('div', cls: 'intro', children: [
      el('h1', cls: 'i1', text: 'DARTLE'),
      el('p', cls: 'i2', text: 'Checkout calculator by PK Normal'),
    ]),
    el('div', cls: 'form', children: [
      el('h2', text: 'Welcome'),
      el('div', cls: 'name-row', children: [
        input,
        button('',
            cls: 'dart-go',
            ariaLabel: 'Continue',
            focusKey: 'go',
            onPressed: (_) => submit())
          ..appendChild(_dartIcon() as web.Node),
      ]),
    ]),
  ]);

  // Tap anywhere during the intro to skip straight to the name box.
  final focusTimer = Timer(const Duration(milliseconds: 3200), () {
    if (!screen.classList.contains('skip')) input.focus();
  });
  screen.onClick.listen((event) {
    final target = event.target;
    final onControl = target != null &&
        target.isA<web.Element>() &&
        ((target as web.Element).closest('input') != null ||
            target.closest('button') != null);
    if (onControl || screen.classList.contains('skip')) return;
    focusTimer.cancel();
    screen.classList.add('skip');
    input.focus();
  });

  return screen;
}
