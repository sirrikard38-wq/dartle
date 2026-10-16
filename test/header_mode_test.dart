import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// The game mode under "DARTLE", and the leaderboard title in the middle. Pinned
/// from the source and the stylesheet (they are drawn in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();
  final leaderboard = File('lib/ui/leaderboard_screen.dart').readAsStringSync();
  final entry = File('lib/ui/number_entry_screen.dart').readAsStringSync();

  /// The value of [property] in the first rule that matches [selector].
  String value(String selector, String property) {
    final rule = RegExp('${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;
    return RegExp('$property: ([^;]+);').firstMatch(rule)!.group(1)!;
  }

  group('the game mode under DARTLE', () {
    test('the three modes are named exactly as they are to be written', () {
      expect(GameMode.values.map((m) => m.label),
          ['Checkout calculator', 'Checkout practice', 'Checkout input']);
    });

    test('the header writes the mode of the game being played, and nothing in the menus', () {
      final header = app.substring(app.indexOf('web.HTMLElement _buildHeader()'));
      expect(header, contains('final mode = inMenu ? null : _game.mode.label;'));
      expect(header, contains("if (mode != null) el('div', cls: 'title-sub', text: mode)"));
      // Under the title, in the same block.
      expect(header.indexOf("cls: 'title'"), lessThan(header.indexOf("cls: 'title-sub'")));
      expect(header, contains("cls: 'title-block'"));
    });

    test('it is small and grey, the same as the byline on the first screen', () {
      expect(value('.title-sub', 'font-size'), value('.welcome .i2', 'font-size'));
      expect(value('.title-sub', 'font-size'), '0.9rem');
      expect(value('.title-sub', 'color'), value('.welcome .i2', 'color'));
      expect(value('.title-sub', 'color'), 'var(--muted)');
      expect(value('.title-sub', 'text-align'), 'center');
    });

    test('the header has room for it', () {
      final plain = int.parse(RegExp(r'height: calc\((\d+)px').firstMatch(
              RegExp(r'\.app-header \{[^}]*\}').firstMatch(css)!.group(0)!)!.group(1)!);
      final withSub = int.parse(RegExp(r'height: calc\((\d+)px').firstMatch(
              RegExp(r'\.app-header\.has-sub \{[^}]*\}').firstMatch(css)!.group(0)!)!.group(1)!);
      expect(withSub, greaterThan(plain));
      expect(app, contains("'app-header\${mode == null ? '' : ' has-sub'}'"));
    });

    test('Checkout input does not write its name twice: the number screen has no line of its own', () {
      expect(entry, isNot(contains("text: 'Checkout input'")));
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
