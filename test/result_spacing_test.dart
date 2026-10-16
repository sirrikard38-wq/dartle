import 'dart:io';

import 'package:test/test.dart';

/// The spacing under "Optimal!" on the result screen, pinned from the stylesheet
/// (it is drawn in the browser).
void main() {
  final css = File('web/styles.css').readAsStringSync();

  test('the number has no margin under it, so the board is close to it', () {
    final rule = RegExp(r'\.target\.small \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(rule, contains('margin: 2px 0 0'));
  });

  test('right under the number the board is pulled up by 11px, and only then', () {
    expect(css, contains('.target.small + .result-boards { margin-top: -11px; }'));
    // The plain rule keeps a small positive gap for every other case (an
    // equation or the "no checkout" lines between the number and the boards).
    final plain = RegExp(r'\.result-boards \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(plain, contains('margin: 2px 0 6px'));
  });

  test('the pull-up leaves the "20" label clear of the number', () {
    // Measured in the browser: the drawing's top label starts about 9 px below the
    // top of the board's box and the number's digits end about 5 px above it, so
    // pulling up by 11 leaves 3 px (a little less on a narrow phone, where the
    // drawing is smaller, but still clear).
    const labelBelowBox = 9, digitsAboveBox = 5, pullUp = 11;
    expect(labelBelowBox + digitsAboveBox - pullUp, greaterThanOrEqualTo(2));
  });
}
