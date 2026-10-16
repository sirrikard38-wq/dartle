import 'dart:io';

import 'package:test/test.dart';

/// The practice screens (Checkout practice and Checkout input): the number keys
/// stay grey, everything else is white - pinned from the stylesheet.
void main() {
  final css = File('web/styles.css').readAsStringSync();
  final rule = RegExp(r'\.screen\.entry \.meta[^{]*\{[^}]*\}').firstMatch(css)!.group(0)!;

  test('the words on the number screen and on the practice board are white, not grey', () {
    expect(rule, contains('color: var(--fg)'));
    for (final selector in [
      '.screen.entry .meta',
      '.screen.entry .hint',
      '.screen.entry .number-display.empty',
      '.screen.entry .how-to summary',
      '.screen.choice .hint',
      '.screen.choice .how-to summary',
    ]) {
      expect(rule, contains(selector), reason: selector);
    }
    final fg = RegExp(r'--fg: (#[0-9a-fA-F]{6})').firstMatch(css)!.group(1)!;
    expect(fg.toLowerCase(), '#ffffff');
  });

  test('the number keys stay grey', () {
    final key = RegExp(r'\.pad-key \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(key, contains('background: var(--pad-key)'));
    expect(RegExp(r'--pad-key: #9a9a9a').hasMatch(css), isTrue);
    // The white rule does not reach the keys (they are buttons, not these words).
    expect(rule, isNot(contains('.pad-key')));
    expect(rule, isNot(contains('.key')));
  });

  test('only the practice screens: the calculator and the other screens keep their grey words', () {
    expect(rule, isNot(contains('.screen.game ')));
    expect(rule, isNot(contains('.screen.menu')));
    expect(RegExp(r'\.tagline, \.hint, \.meta \{ color: var\(--muted\)').hasMatch(css), isTrue,
        reason: 'the general rule is still grey');
  });
}
