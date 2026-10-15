import 'dart:io';

import 'package:test/test.dart';

/// The "76 left" line of the calculator, pinned from the source (it is drawn in
/// the browser): the number is centred under the big number, the word "left"
/// hangs to its right.
void main() {
  final screen = File('lib/ui/game_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  test('an invisible copy of the word on the left keeps the number in the middle', () {
    final line = screen.substring(screen.indexOf('web.HTMLElement _remainingLine'));
    final ghost = line.indexOf("cls: 'left-note ghost'");
    final number = line.indexOf("el('strong'");
    final word = line.indexOf("cls: 'left-note', text: word");
    expect(ghost, greaterThan(0));
    expect(number, greaterThan(ghost), reason: 'ghost word, then the number');
    expect(word, greaterThan(number), reason: 'then the real word on the right');
    expect(line, contains("'aria-hidden': 'true'"));
  });

  test('the copy is invisible, the same size as the real word', () {
    expect(css, contains('.remaining .left-note.ghost { visibility: hidden; }'));
    expect(css, contains('.remaining .left-note { color: var(--muted); font-size: 1.1rem; }'));
  });

  test('"over" is mirrored the same way as "left"', () {
    final line = screen.substring(screen.indexOf('web.HTMLElement _remainingLine'));
    expect(line, contains("final word = left < 0 ? 'over' : 'left';"));
  });
}
