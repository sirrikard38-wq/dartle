import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'how_to_play.dart';
import 'keyboard.dart';
import 'view_context.dart';

/// The longest number that can be typed (170 has three digits).
const int _maxDigits = 3;

/// Types a digit into the number being entered. Returns true if it was taken.
bool typeNumberDigit(ViewContext ctx, String digit) {
  if (ctx.numberBuffer.length >= _maxDigits) return false;
  if (ctx.numberBuffer.isEmpty && digit == '0') return false; // no leading zero
  ctx.numberBuffer += digit;
  ctx.rerender();
  return true;
}

/// Takes back the last digit typed.
void deleteNumberDigit(ViewContext ctx) {
  if (ctx.numberBuffer.isEmpty) return;
  ctx.numberBuffer = ctx.numberBuffer.substring(0, ctx.numberBuffer.length - 1);
  ctx.rerender();
}

/// Is the typed number one that can be played (2 to 170)?
bool numberIsReady(ViewContext ctx) {
  final value = int.tryParse(ctx.numberBuffer);
  return value != null &&
      value >= CheckoutEngine.minCheckout &&
      value <= CheckoutEngine.maxCheckout;
}

/// Enters the typed number: starts the game on it, or shows that it cannot be
/// checked out.
void submitNumber(ViewContext ctx) {
  if (!numberIsReady(ctx)) return;
  final value = int.parse(ctx.numberBuffer);
  ctx.numberBuffer = '';
  ctx.game.enterNumber(value);
}

/// Checkout input: a calculator-style keypad (0-9, undo, enter) to type the
/// number to be checked out next.
web.HTMLElement buildNumberEntryScreen(ViewContext ctx) {
  final text = ctx.numberBuffer;
  final ready = numberIsReady(ctx);

  web.HTMLButtonElement digit(int n) => button('$n',
      cls: 'key pad-key',
      focusKey: 'digit-$n',
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'digit-$n' : null);
        typeNumberDigit(ctx, '$n');
      });

  final undo = button('UNDO',
      cls: 'key pad-key pad-undo',
      focusKey: 'pad-undo',
      ariaLabel: 'Delete the last digit',
      disabled: text.isEmpty,
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'pad-undo' : null);
        deleteNumberDigit(ctx);
      });
  undo.insertBefore(undoIcon(), undo.firstChild);

  final enter = button('ENTER',
      cls: 'key pad-key pad-enter',
      focusKey: 'pad-enter',
      disabled: !ready,
      onPressed: (_) => submitNumber(ctx));

  final String hint;
  if (text.isEmpty) {
    hint = 'See the possibilities, enter a number.';
  } else if (ready) {
    hint = 'Press ENTER to play it.';
  } else {
    hint = 'A number from 2 to 170.';
  }

  return el('main', cls: 'screen entry', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'target number-display${text.isEmpty ? ' empty' : ''}',
          text: text.isEmpty ? '–' : text,
          attrs: {'aria-label': text.isEmpty ? 'No number yet' : 'Number $text'}),
      el('p', cls: 'hint', text: hint),
    ]),
    el('div', cls: 'keypad', attrs: {'aria-label': 'Number pad'}, children: [
      digit(1), digit(2), digit(3),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      undo, digit(0), enter,
    ]),
    buildHowToPlay(ctx.game),
  ]);
}
