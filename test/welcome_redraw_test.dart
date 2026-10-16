import 'dart:io';

import 'package:test/test.dart';

/// The welcome screen plays its intro once: DARTLE, then Welcome. It used to
/// start over (DARTLE again) a few seconds later, every time the app opened.
/// Pinned from the source (it is drawn in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final welcome = File('lib/ui/welcome_screen.dart').readAsStringSync();
  final reload = File('lib/ui/update_reload.dart').readAsStringSync();
  final main = File('web/main.dart').readAsStringSync();
  final render = app.substring(app.indexOf('void render()'), app.indexOf('web.HTMLElement _buildHeader()'));

  test('the welcome screen is never drawn again while it is on screen', () {
    // The guard is before anything is built, so no timers or animations restart.
    final guard = render.indexOf("_root.querySelector('.screen.welcome') != null");
    final build = render.indexOf('final screen = switch');
    expect(guard, greaterThan(0));
    expect(guard, lessThan(build));
    expect(render, contains('if (fullScreen && screenKey == _lastScreen'));
    // ... and it returns without touching the page.
    expect(render.substring(guard, build), contains('return;'));
  });

  test('the browser offering to install the app is one thing that redraws the app', () {
    // watchForInstall(render) redraws when the offer arrives (a few seconds after
    // opening): exactly what the guard above is for.
    expect(app, contains('watchForInstall(render)'));
  });

  test('every other screen is still drawn again when something changes', () {
    // The guard is only for the welcome screen.
    expect(render, isNot(contains('if (screenKey == _lastScreen) return')));
    expect(render, contains('_root.textContent = \'\';'));
    expect(render, contains('final fullScreen = _game.phase == GamePhase.menu && _page == MenuPage.welcome;'));
  });

  test('after the app reloads itself for an update, the welcome screen skips its intro', () {
    expect(reload, contains("const String skipIntroKey = 'dartle.skip-intro'"));
    expect(reload, contains('sessionStorage.setItem(skipIntroKey'));
    expect(reload.indexOf('setItem'), lessThan(reload.indexOf('location.reload()')),
        reason: 'the flag is set before the reload');
    expect(reload, contains('storage.removeItem(skipIntroKey)'), reason: 'used once');
    expect(main, contains('reloadForUpdate()'));
    expect(welcome, contains('if (takeSkipIntro())'));
    expect(welcome, contains("screen.classList.add('skip')"));
  });
}
