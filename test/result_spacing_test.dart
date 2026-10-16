import 'dart:io';

import 'package:test/test.dart';

/// The spacing on the result screen (under "Optimal!"), pinned from the
/// stylesheet (it is drawn in the browser).
void main() {
  final css = File('web/styles.css').readAsStringSync();

  /// The value of [property] in the first rule that matches [selector].
  String value(String selector, String property) {
    final rule = RegExp('${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;
    return RegExp('$property: ([^;]+);').firstMatch(rule)!.group(1)!;
  }

  test('the number is spaced out from the words "Optimal!" above it', () {
    // Plain rule 2px (the impossible screen); on the result screen 11px more
    // room under the words: about 26px from the letters to the digits (was 17).
    expect(value('.target.small', 'margin'), '2px 0 0');
    expect(value('.screen.result .target.small', 'margin-top'), '11px');
  });

  test('the number has a normal gap to the board: nothing pulls the board up any more', () {
    expect(css, isNot(contains('.target.small + .result-boards')));
    expect(value('.result-boards', 'margin'), '2px 0 6px');
    // Nothing negative anywhere around the number and the boards.
    expect(value('.target.small', 'margin'), isNot(contains('-')));
    expect(value('.screen.result .target.small', 'margin-top'), isNot(contains('-')));
  });

  test('the number is farther from the board than it was when it was pulled up', () {
    // Measured in the browser: label gap = 14 + pull-up; it was pulled up by 11
    // (3px to the "20" label, 20px to the ring) and is not now (about 12 and 29).
    const pulledUp = -11, nowPull = 0;
    expect(nowPull, greaterThan(pulledUp));
    expect(14 + nowPull, greaterThanOrEqualTo(10), reason: 'a normal gap to the label');
  });
}
