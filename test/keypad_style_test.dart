import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';

/// The number keys of Checkout input are grey, not white - pinned from the
/// stylesheet (it is drawn in the browser).
void main() {
  final css = File('web/styles.css').readAsStringSync();

  /// WCAG relative luminance of a #rrggbb colour.
  double luminance(String hex) {
    double channel(int i) {
      final c = int.parse(hex.substring(1 + 2 * i, 3 + 2 * i), radix: 16) / 255;
      return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(0) + 0.7152 * channel(1) + 0.0722 * channel(2);
  }

  String token(String name) => RegExp('--$name: (#[0-9a-fA-F]{6})').firstMatch(css)!.group(1)!;

  test('the keys use the grey, set on the pad keys after the white base key', () {
    final rule = RegExp(r'\.pad-key \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(rule, contains('background: var(--pad-key)'));
    expect(css.indexOf('.pad-key {'), greaterThan(css.indexOf('.key {')),
        reason: 'later, so it wins over the white .key');
  });

  test('the grey is a real grey: not white, not dark', () {
    final grey = token('pad-key');
    final r = int.parse(grey.substring(1, 3), radix: 16);
    final g = int.parse(grey.substring(3, 5), radix: 16);
    final b = int.parse(grey.substring(5, 7), radix: 16);
    expect(r == g && g == b, isTrue, reason: '$grey is neutral grey');
    expect(r, inInclusiveRange(0x80, 0xc0), reason: 'clearly grayer than white (#ffffff)');
  });

  test('the dark digits stay easy to read on it (contrast at least 4.5:1)', () {
    final ratio = (luminance(token('pad-key')) + 0.05) / (luminance(token('ink')) + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });

  test('only the keypad changed: the other keys stay white', () {
    final key = RegExp(r'\.key \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(key, contains('background: var(--white)'));
  });
}
