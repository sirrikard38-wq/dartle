import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';

/// A small "step back" arrow, drawn so it never depends on a font.
web.Element undoIcon() => svg('svg', cls: 'undo-icon', attrs: {
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

/// The dart-entry panel: the tappable dartboard with the ring buttons S, D and T
/// on both sides of it, then Undo (and, in Checkout calculator, No checkout).
///
/// The same three buttons are on the left and on the right of the board, so
/// either hand can press them: pressing one lights up the same letter on the
/// other side too (both sides show the one chosen ring) and switches the board
/// to that ring.
///
/// The finishing box is always a double, so while it is active the other rings
/// are disabled and Double is selected for the player.
web.HTMLElement buildInputPanel({
  required Multiplier multiplier,
  required bool finalBox,
  required bool canUndo,
  required List<BoardPoint> marks,

  /// Undos left in the session, shown in brackets next to the word Undo; null
  /// when undo is not limited.
  int? undosLeft,

  /// Show the Single / Double / Triple buttons. Off in the practice modes: the
  /// area you press on the board is the dart you throw.
  required bool ringButtons,

  /// Show the "No checkout" button (Checkout calculator).
  bool showNoCheckout = false,

  /// Darts to light up on the board as the best choices (practice modes).
  Set<DartThrow>? lit,
  /// [focusKey] names the button that was pressed (the left and the right one of
  /// the same ring are different buttons), to give it the focus back.
  required void Function(Multiplier m, bool viaKeyboard, String focusKey) onPickMultiplier,

  /// [point] is where the board was tapped.
  required void Function(DartThrow dart, BoardPoint? point, bool viaKeyboard) onDart,
  required void Function(bool viaKeyboard) onUndo,
  void Function(bool viaKeyboard)? onNoCheckout,
}) {
  web.HTMLElement row(List<web.Node> keys, {String? cls}) =>
      el('div', cls: 'key-row ${cls ?? ''}', children: keys);

  /// One ring button: just the letter (S, D or T). The left and the right
  /// column are built from the same state, so they always agree.
  web.HTMLButtonElement modeKey(Multiplier m, {required bool right}) {
    final focusKey = 'mode-${m.name}${right ? '-r' : ''}';
    return button(
      m.prefix,
      cls: 'key mode side${m == multiplier ? ' selected' : ''}',
      ariaLabel: m.label,
      focusKey: focusKey,
      disabled: finalBox && m != Multiplier.double,
      attrs: {'aria-pressed': '${m == multiplier}'},
      onPressed: (kb) => onPickMultiplier(m, kb, focusKey),
    );
  }

  web.HTMLElement modeColumn({required bool right}) => el('div',
      cls: 'mode-col ${right ? 'right' : 'left'}',
      attrs: {'role': 'group', 'aria-label': right ? 'Ring, right side' : 'Ring, left side'},
      children: [for (final m in Multiplier.values) modeKey(m, right: right)]);

  // A drawn arrow, not the "⌫" character: many fonts lack that glyph and show
  // an empty box instead.
  final undoKey = button('UNDO${undosLeft == null ? '' : ' ($undosLeft)'}',
      cls: 'key wide undo',
      ariaLabel: undosLeft == null
          ? 'Undo last dart'
          : 'Undo last dart, $undosLeft ${undosLeft == 1 ? 'undo' : 'undos'} left',
      focusKey: 'undo',
      disabled: !canUndo,
      onPressed: onUndo);
  undoKey.insertBefore(undoIcon(), undoKey.firstChild);

  // Next to Undo, in the same plain style.
  final noCheckoutKey = button('NO CHECKOUT',
      cls: 'key wide undo no-checkout',
      ariaLabel: 'No checkout: this number cannot be checked out',
      focusKey: 'no-checkout',
      onPressed: (kb) => onNoCheckout?.call(kb));

  return el('div', cls: 'keyboard board-view', attrs: {'aria-label': 'Dart input'}, children: [
    // The ring buttons are a column on each side of the board (S, D, T from the
    // top), so either hand can reach them.
    el('div', cls: 'board-wrap${ringButtons ? ' sided' : ''}', children: [
      if (ringButtons) modeColumn(right: false),
      buildDartboard(
        mode: ringButtons ? multiplier : null,
        byArea: !ringButtons,
        marks: marks,
        lit: lit,
        animateLastMark: true,
        onDart: (dart, point, kb) => onDart(dart, point, kb),
      ),
      if (ringButtons) modeColumn(right: true),
    ]),
    row([undoKey, if (showNoCheckout) noCheckoutKey], cls: 'action-row'),
  ]);
}
