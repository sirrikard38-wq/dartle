import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'game_screen.dart';
import 'how_to_play.dart';
import 'tiles.dart';
import 'view_context.dart';

/// How a dart's rating shows on its tile (white / grey / pink + marks).
TileState tileStateFor(DartQuality quality) => switch (quality) {
      DartQuality.optimal => TileState.correct,
      DartQuality.fine => TileState.present,
      DartQuality.poor || DartQuality.bust => TileState.absent,
    };

/// Checkout practice and Checkout input: pick your own darts one at a time.
/// The big number is what you still need. Before every choice the board lights
/// up the optimal darts; once you press one it plays out like Checkout
/// calculator - the tile is coloured and your mark is left on the board - and
/// the board then lights up the optimal darts for the new number.
web.HTMLElement buildChoiceScreen(ViewContext ctx) {
  final game = ctx.game;
  final round = game.round!;
  final steps = round.steps;
  ctx.syncMarks();

  final boxes = tileRow(game.entered,
      slots: Visit.darts,
      used: round.layout.used,
      activeIndex: game.entered.length,
      // Plain boxes while you play: each dart's rating colour (white,
      // grey, light pink) only shows on the result screen.
      showDarts: true);
  // A two-dart number over 60 can be played with three darts: before the first
  // dart, pressing the boxes switches between two and three.
  final choose = game.canChooseDarts;
  final other = round.maxDarts == 3 ? 2 : 3;

  return el('main', cls: 'screen game choice', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'meta', text: tr('Finish on a double or Bull in the chosen number of darts.')),
      el('p', cls: 'target', text: '${round.remaining}', attrs: {
        'aria-label': trn(round.dartsLeft, '{target} to checkout, {n} dart left',
            '{target} to checkout, {n} darts left', {'target': round.remaining}),
      }),
      if (steps.isEmpty && game.hasOnlyOneCheckout)
        el('p', cls: 'hint only-one', text: tr('Only possible checkout.')),
      el('p', cls: 'hint',
          text: steps.isEmpty
              ? tr('The lit areas are the optimal darts.')
              : tr('Started on {target}. The lit areas are the optimal darts.',
                  {'target': round.target})),
      if (choose)
        button('',
            cls: 'dart-count-toggle',
            focusKey: 'darts',
            ariaLabel: tr('Play {target} with {n} darts', {'target': round.target, 'n': other}),
            onPressed: (_) => game.chooseOtherDarts())
          ..appendChild(boxes)
      else
        boxes,
      if (choose) el('p', cls: 'hint darts-hint', text: tr('Press the darts to choose 2 or 3 darts.')),
      if (game.isReplay) el('p', cls: 'hint', text: tr('Replay - the same number again.')),
    ]),
    buildEntryPanel(ctx),
    buildHowToPlay(game),
  ]);
}
