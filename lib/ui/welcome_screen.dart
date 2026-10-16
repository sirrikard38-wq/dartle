import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dart_shot.dart';
import 'dom.dart';
import 'update_reload.dart';
import 'view_context.dart';

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

  late final web.HTMLElement stage;
  var shooting = false;
  Future<void> submit() async {
    if (shooting) return; // the dart is already on its way
    if (input.value.trim().isEmpty) {
      ctx.toast('Enter your name to continue');
      input.focus();
      return;
    }
    shooting = true;
    final name = input.value;
    await playDartShot(stage); // the dart sticks in the circle and wiggles ...
    game.setPlayerName(name); // saves in the background
    ctx.showPage(MenuPage.home); // ... and then the next screen
  }

  // The dart sits under the name box. In front of its tip is a tiny circle that
  // appears when the dart is pressed (see playDartShot).
  stage = buildDartStage(label: 'Continue', focusKey: 'go', onPressed: submit);

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
      el('div', cls: 'name-row', children: [input]),
      stage,
    ]),
  ]);

  // After the app reloaded itself for a newer version there is no intro to sit
  // through again: straight to the name box.
  if (takeSkipIntro()) {
    screen.classList.add('skip');
    Timer(const Duration(milliseconds: 300), () => input.focus());
  }

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
