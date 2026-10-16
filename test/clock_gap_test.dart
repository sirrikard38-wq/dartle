import 'dart:io';

import 'package:test/test.dart';

/// The clock of the calculator sits centred between the number that is left and
/// the dartboard (it is not in the middle of the board). Pinned from the source
/// and the stylesheet (it is drawn in the browser).
void main() {
  final game = File('lib/ui/game_screen.dart').readAsStringSync();
  final keyboard = File('lib/ui/keyboard.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  test('the number that is left, then the clock, above the board - nothing on the board', () {
    final screen = game.substring(game.indexOf('web.HTMLElement buildGameScreen'));
    final playArea = screen.substring(screen.indexOf("cls: 'play-area'"), screen.indexOf('buildEntryPanel(ctx)'));
    final remaining = playArea.indexOf('_remainingLine(challenge.target, game.entered)');
    final clock = playArea.indexOf("el('div', cls: 'clock-gap', children: [timerLine(game)])");
    expect(remaining, greaterThan(0));
    expect(clock, greaterThan(remaining), reason: 'the clock comes after the number that is left');
    // A replay has no clock.
    expect(playArea, contains("if (game.isReplay)"));
    expect(playArea, contains("text: 'Replay - no clock, no points.'"));
  });

  test('nothing is drawn in the middle of the dartboard any more', () {
    for (final gone in ['boardCenter', 'board-center', 'board-stack', 'board-readout']) {
      expect(game, isNot(contains(gone)), reason: gone);
      expect(keyboard, isNot(contains(gone)), reason: gone);
      expect(css, isNot(contains(gone)), reason: gone);
    }
  });

  test('the clock is centred: the same space over it as under it, at every board size', () {
    final rule = RegExp(r'\.clock-gap \.timer \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(rule, contains('margin: calc(13.95px + 0.0264 * var(--board-w)) 0 calc(5.05px - 0.0264 * var(--board-w))'));
    // The clock moves with the board (half of how far the "20" at its top moves),
    // so the room around it stays the same in total: 19 px.
    expect(13.95 + 5.05, closeTo(19, 1e-9));
    // The "20" is 5.28% of the board's width lower on a bigger board; half is 2.64%.
    expect(0.0264 * 2, closeTo(0.0528, 1e-9));
    // The board's width comes from the same variable.
    expect(RegExp(r'\.board-wrap\.sided \.dartboard \{[^}]*width: var\(--board-w\)').hasMatch(css), isTrue);
    expect(RegExp(r'--board-w: min\(').hasMatch(css), isTrue);
  });

  test('on a short screen the number that is left is smaller, so the clock is lower by 5 px', () {
    final media = css.substring(css.indexOf('@media (max-height: 640px)'));
    final rule = media.substring(0, media.indexOf('}\n}') + 2);
    expect(rule, contains('.remaining strong { font-size: 3rem; }'));
    expect(rule, contains('.clock-gap .timer { margin-top: calc(18.95px + 0.0264 * var(--board-w)); }'));
    expect(18.95 - 13.95, closeTo(5, 1e-9));
  });
}
