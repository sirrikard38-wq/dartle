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

/// Checkout practice: pick your own darts one at a time. The big number is what
/// you still need. Before every choice the board lights up the best darts; once
/// you press one it plays out like Checkout calculator - the tile is coloured
/// and your mark is left on the board - and the board then lights up the best
/// darts for the new number.
web.HTMLElement buildChoiceScreen(ViewContext ctx) {
  final game = ctx.game;
  final round = game.round!;
  final steps = round.steps;
  ctx.syncMarks();

  return el('main', cls: 'screen game choice', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'meta', text: 'Finish on a double or Bull.'),
      el('p', cls: 'target', text: '${round.remaining}', attrs: {
        'aria-label': '${round.remaining} to checkout, ${round.dartsLeft} darts left',
      }),
      el('p', cls: 'hint',
          text: steps.isEmpty
              ? 'The lit areas are the best darts.'
              : 'Started on ${round.target}. The lit areas are the best darts.'),
      tileRow(game.entered,
          slots: round.maxDarts,
          activeIndex: game.entered.length,
          live: true,
          showDarts: true,
          states: steps.isEmpty ? null : [for (final s in steps) tileStateFor(s.quality)]),
    ]),
    buildEntryPanel(ctx),
    buildGiveUp(ctx),
    buildHowToPlay(game),
  ]);
}
