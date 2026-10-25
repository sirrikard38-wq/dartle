import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// The S / D / T buttons on both sides of the board, pinned from the source and
/// the stylesheet (they are drawn in the browser).
void main() {
  final keyboard = File('lib/ui/keyboard.dart').readAsStringSync();
  final game = File('lib/ui/game_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  test('the buttons are just the letters S, D and T, in that order', () {
    expect([for (final m in Multiplier.values) m.prefix], ['S', 'D', 'T']);
    expect(keyboard, contains('m.prefix,'), reason: 'the button text is the letter');
    expect(keyboard, contains('ariaLabel: tr(m.label)'), reason: 'screen readers still hear the whole word');
  });

  test('there is one column on each side of the board, the left one first', () {
    final board = keyboard.indexOf('buildDartboard(');
    final left = keyboard.indexOf('modeColumn(right: false)');
    final right = keyboard.indexOf('modeColumn(right: true)');
    expect(left, greaterThan(0));
    expect(left, lessThan(board), reason: 'left of the board');
    expect(right, greaterThan(board), reason: 'right of the board');
  });

  test('both columns come from the same state, so pressing one lights both', () {
    // One builder for every button; the "selected" look and aria-pressed come from
    // the one chosen multiplier, not from which side was pressed.
    expect(keyboard.split('web.HTMLButtonElement modeKey(').length, 2, reason: 'one builder');
    expect(keyboard, contains("cls: 'key mode side\${m == multiplier ? ' selected' : ''}'"));
    expect(keyboard, contains("'aria-pressed': '\${m == multiplier}'"));
    // Pressing a button picks the ring for everything: the board and both sides.
    expect(game, contains('ctx.pickedMultiplier = m;'));
    expect(game, contains('ctx.rerender();'));
  });

  test('the left and the right button of a ring are different buttons that keep their own focus', () {
    expect(keyboard, contains("'mode-\${m.name}\${right ? '-r' : ''}'"));
    expect(game, contains('ctx.keepFocus(kb ? focusKey : null);'));
  });

  test('the old row of three buttons above the board is gone', () {
    expect(keyboard, isNot(contains("cls: 'mode-row'")));
    expect(keyboard, isNot(contains('m.label.toUpperCase()')));
  });

  test('only the calculator has them: the practice modes press the area itself', () {
    expect(keyboard, contains("board-wrap\${ringButtons ? ' sided' : ''}"));
    expect(keyboard, contains('if (ringButtons) modeColumn(right: false)'));
    expect(keyboard, contains('if (ringButtons) modeColumn(right: true)'));
  });

  test('the finishing box allows only the double, on both sides', () {
    expect(keyboard, contains('disabled: finalBox && m != Multiplier.double'));
  });

  test('the board takes the room between the columns and the columns stay inside the screen', () {
    final board = RegExp(r'\.board-wrap\.sided \.dartboard \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(board, contains('width: var(--board-w)'));
    expect(board, contains('min-width: 0'));
    // The width is what is left of the screen between the columns.
    final token = RegExp(r'--board-w: [^;]*;').firstMatch(css)!.group(0)!;
    expect(token, contains('100vw - 2 * (var(--side-w) + var(--side-gap))'));
    final col = RegExp(r'\.key\.mode\.side \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(col, contains('width: var(--side-w)'));
    expect(col, contains('height: var(--side-w)'));
    // Big enough to press: 44 px, a little less on the narrowest phones.
    final wide = int.parse(RegExp(r'--side-w: (\d+)px').firstMatch(css)!.group(1)!);
    expect(wide, greaterThanOrEqualTo(44));
    expect(css, contains('@media (max-width: 400px)'));
    final narrow = int.parse(
        RegExp(r'max-width: 400px\) \{\s*:root \{ --side-w: (\d+)px').firstMatch(css)!.group(1)!);
    expect(narrow, inInclusiveRange(40, wide));
  });
}
