import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'view_context.dart';

/// A small "step back" arrow, drawn so it never depends on a font.
web.Element _undoIcon() => svg('svg', cls: 'undo-icon', attrs: {
      'viewBox': '0 0 24 24',
      'aria-hidden': 'true',
      'focusable': 'false',
    }, children: [
      svg('path', attrs: {
        'd': 'M9 6 L3 12 L9 18 M3 12 H15 C19 12 21 14 21 18',
        'fill': 'none',
        'stroke': 'currentColor',
        'stroke-width': '2.4',
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
      }),
    ]);

/// The dart-entry panel: ring toggle (Single / Double / Treble), then either
/// the tappable dartboard or a plain number keypad.
///
/// The finishing box is always a double, so while it is active the other rings
/// (and the outer bull) are disabled and Double is selected for the player.
web.HTMLElement buildInputPanel({
  required InputView view,
  required Multiplier multiplier,
  required bool finalBox,
  required bool canUndo,
  required List<BoardPoint> marks,

  /// Show the Single / Double / Treble buttons on the board view. Off in
  /// Checkout practice: the area you press on the board is the dart you throw.
  required bool ringButtons,

  /// Darts to light up on the board as the best choices (Checkout practice).
  Set<DartThrow>? lit,
  required void Function(Multiplier m, bool viaKeyboard) onPickMultiplier,

  /// [point] is where the board was tapped; null for keypad entry.
  required void Function(DartThrow dart, BoardPoint? point, bool viaKeyboard) onDart,
  required void Function(bool viaKeyboard) onUndo,
  required void Function(InputView view) onChangeView,
}) {
  web.HTMLElement row(List<web.Node> keys, {String? cls}) =>
      el('div', cls: 'key-row ${cls ?? ''}', children: keys);

  web.HTMLButtonElement modeKey(Multiplier m) => button(
        m.label.toUpperCase(),
        cls: 'key mode${m == multiplier ? ' selected' : ''}',
        focusKey: 'mode-${m.name}',
        disabled: finalBox && m != Multiplier.double,
        attrs: {'aria-pressed': '${m == multiplier}'},
        onPressed: (kb) => onPickMultiplier(m, kb),
      );

  web.HTMLButtonElement numberKey(int n) {
    final dart = DartThrow(multiplier, n);
    return button('$n',
        cls: 'key',
        ariaLabel: dart.spokenName,
        focusKey: 'seg-$n',
        onPressed: (kb) => onDart(dart, null, kb));
  }

  // A drawn arrow, not the "⌫" character: many fonts lack that glyph and show
  // an empty box instead.
  final undoKey = button('UNDO',
      cls: 'key wide undo',
      ariaLabel: 'Undo last dart',
      focusKey: 'undo',
      disabled: !canUndo,
      onPressed: onUndo);
  undoKey.insertBefore(_undoIcon(), undoKey.firstChild);

  final other = view == InputView.board ? InputView.keys : InputView.board;
  final viewToggle = button('Switch to ${other.label.toLowerCase()} input',
      cls: 'text-btn view-toggle',
      focusKey: 'view-toggle',
      onPressed: (_) => onChangeView(other));

  final modeRow = row([for (final m in Multiplier.values) modeKey(m)], cls: 'mode-row');

  if (view == InputView.board) {
    return el('div', cls: 'keyboard board-view', attrs: {'aria-label': 'Dart input'}, children: [
      if (ringButtons) modeRow,
      el('div', cls: 'board-wrap', children: [
        buildDartboard(
          mode: ringButtons ? multiplier : null,
          byArea: !ringButtons,
          marks: marks,
          lit: lit,
          animateLastMark: true,
          onDart: (dart, point, kb) => onDart(dart, point, kb),
        ),
      ]),
      row([undoKey]),
      viewToggle,
    ]);
  }

  return el('div', cls: 'keyboard', attrs: {'aria-label': 'Dart input'}, children: [
    // Checkout practice has no ring buttons: a number is worth its lit best dart,
    // or a single when none is lit.
    if (ringButtons) modeRow,
    row([for (var n = 1; n <= 7; n++) numberKey(n)]),
    row([for (var n = 8; n <= 14; n++) numberKey(n)]),
    row([for (var n = 15; n <= 20; n++) numberKey(n)]),
    row([
      undoKey,
      button('25',
          cls: 'key',
          ariaLabel: DartThrow.outerBull.spokenName,
          focusKey: 'seg-25',
          disabled: finalBox,
          onPressed: (kb) => onDart(DartThrow.outerBull, null, kb)),
      button('BULL',
          cls: 'key',
          ariaLabel: DartThrow.bull.spokenName,
          focusKey: 'seg-bull',
          onPressed: (kb) => onDart(DartThrow.bull, null, kb)),
    ]),
    viewToggle,
  ]);
}
