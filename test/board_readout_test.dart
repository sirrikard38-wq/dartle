import 'dart:io';

import 'package:test/test.dart';

/// The number that is left and the clock in the middle of the dartboard of the
/// calculator, pinned from the source and the stylesheet (it is drawn in the
/// browser).
void main() {
  final game = File('lib/ui/game_screen.dart').readAsStringSync();
  final keyboard = File('lib/ui/keyboard.dart').readAsStringSync();
  final app = File('lib/ui/app.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  /// The value of [property] in the first rule that matches [selector].
  String value(String selector, String property) {
    final rule = RegExp('${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;
    return RegExp('$property: ([^;]+);').firstMatch(rule)!.group(1)!;
  }

  test('the number that is left and the clock are handed to the board, not put above it', () {
    final screen = game.substring(game.indexOf('web.HTMLElement buildGameScreen'));
    final playArea = screen.substring(screen.indexOf("cls: 'play-area'"), screen.indexOf('buildEntryPanel(ctx,'));
    expect(playArea, isNot(contains('_remainingLine(')), reason: 'no longer above the board');
    expect(playArea, isNot(contains('timerLine(game)')));
    expect(screen, contains("boardCenter: el('div', cls: 'board-readout'"));
    // Both are in the readout, the clock only when there is one (not in a replay).
    expect(screen, contains('_remainingLine(challenge.target, game.entered)'));
    expect(screen, contains('if (!game.isReplay) timerLine(game)'));
  });

  test('the readout is drawn inside a stack with the board, over its middle', () {
    expect(keyboard, contains("el('div', cls: 'board-stack'"));
    expect(keyboard, contains("el('div', cls: 'board-center', children: [boardCenter])"));
    expect(keyboard.indexOf('buildDartboard('), lessThan(keyboard.indexOf("cls: 'board-center'")),
        reason: 'after the board, so it is drawn on top of it');
    final stack = value('.board-stack', 'position');
    expect(stack, 'relative');
    final center = RegExp(r'\.board-center \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(center, contains('position: absolute'));
    expect(center, contains('inset: 0'), reason: 'the whole board');
    expect(center, contains('align-items: center'));
    expect(center, contains('justify-content: center'), reason: 'exactly in the middle');
  });

  test('presses go through the readout to the board', () {
    final center = RegExp(r'\.board-center \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(center, contains('pointer-events: none'));
  });

  test('the clock keeps its id, so the app can keep ticking it', () {
    expect(game, contains("attrs: {'id': 'timer'"));
    expect(app, contains("getElementById('timer')"));
  });

  test('the readout is white and readable on the board, the clock red when time is up', () {
    expect(value('.board-readout .timer', 'color'), 'var(--fg)');
    expect(value('.board-readout .remaining .left-note', 'color'), 'var(--fg)');
    expect(value('.board-readout .timer.over', 'color'), 'var(--danger)');
    expect(value('.board-readout', 'text-shadow'), contains('#000'));
  });

  test('only the calculator has a readout: the practice board has none', () {
    final choice = File('lib/ui/choice_screen.dart').readAsStringSync();
    expect(choice, isNot(contains('boardCenter')));
    expect(choice, contains('buildEntryPanel(ctx)'));
  });
}
