import 'dart:io';

import 'package:test/test.dart';

/// The welcome screen's look, pinned from the stylesheet (it is drawn in the
/// browser): "Welcome" is centred over the name box, and the dart flies a
/// little further when it is pressed.
void main() {
  final css = File('web/styles.css').readAsStringSync();

  test('"Welcome" is centred over the name box, not over the box and the dart', () {
    final h2 = RegExp(r'\.welcome \.form h2 \{[^}]*\}').firstMatch(css)!.group(0)!;
    // It leaves exactly the dart's width and the gap free on the right, as the row does.
    expect(h2, contains('padding-right: calc(var(--dart-w) + var(--row-gap))'));
    expect(css, contains('width: var(--dart-w)'));
    expect(css, contains('gap: var(--row-gap)'));
    expect(css, contains('--dart-w: 84px'));
  });

  test('pressed, the dart moves half a centimetre further than the old 12px', () {
    expect(css, contains('.dart-go:active { transform: translateX(calc(12px + 0.5cm)); }'));
  });

  test('the press cannot make the welcome screen scroll sideways', () {
    final welcome = RegExp(r'\.screen\.welcome \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(welcome, contains('overflow-x: clip'));
  });
}
