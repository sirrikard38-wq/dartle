import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// The header while a game is played: only the word DARTLE, with nothing written
/// under it, and the leaderboard title in the middle. Pinned from the source and the
/// stylesheet (they are drawn in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();
  final leaderboard = File('lib/ui/leaderboard_screen.dart').readAsStringSync();

  group('nothing under the word DARTLE while a game is played', () {
    final header = app.substring(
        app.indexOf('web.HTMLElement _buildHeader()'), app.indexOf('web.HTMLElement _buildBackDart()'));

    test('the header is just the back dart, the title and the actions', () {
      expect(header, contains("el('div', cls: 'title', text: 'DARTLE')"));
      expect(header, contains("el('header', cls: 'app-header', children: ["));
      // The game mode is not written in it.
      expect(header, isNot(contains('_game.mode.label')));
      expect(header, isNot(contains('title-sub')));
      expect(header, isNot(contains('title-block')));
      expect(header, isNot(contains('has-sub')));
    });

    test('the stylesheet has nothing left of it, and the header is one height', () {
      for (final gone in ['.title-sub', '.title-block', 'has-sub']) {
        expect(css, isNot(contains(gone)), reason: gone);
      }
      final rule = RegExp(r'\.app-header \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('height: calc(52px + env(safe-area-inset-top, 0px));'));
    });

    test('the message that pops up sits just under the header again', () {
      final toast = RegExp(r'\.toast \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(toast, contains('top: calc(64px + env(safe-area-inset-top, 0px));'));
    });

    test('the modes keep their names, which the menus and the buttons use', () {
      expect(GameMode.values.map((m) => m.label),
          ['Checkout calculator', 'Checkout practice', 'Checkout input']);
    });
  });

  group('the leaderboard title', () {
    test('"180 LEADERBOARD" is in the middle, not at the right edge', () {
      expect(leaderboard, contains("el('h2', text: '180 Leaderboard')"));
      expect(leaderboard, isNot(contains('screen-title-right')));
      expect(css, isNot(contains('screen-title-right')));
      // The heading style centres it (the screen's text is centred and uppercased).
      final h2 = RegExp(r'\bh2 \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(h2, contains('text-transform: uppercase'));
      expect(css, contains('text-align: center;'));
    });
  });
}
