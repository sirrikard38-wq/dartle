import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'game_screen.dart';
import 'how_to_play.dart';
import 'tiles.dart';
import 'tutorial_screen.dart';
import 'view_context.dart';

/// How a dart's rating shows on its tile (white / grey / pink + marks).
TileState tileStateFor(DartQuality quality) => switch (quality) {
      DartQuality.optimal => TileState.correct,
      DartQuality.fine => TileState.present,
      DartQuality.poor || DartQuality.bust => TileState.absent,
    };

/// Checkout practice: Input | Play | Learn, as in Checkout tutorial. Input types
/// the number to play (at once the one Play and Learn show; a number dealt by
/// Next checkout is in it too). Play: pick your own darts one at a time. The
/// big number is what you still need. Before every choice the board lights up
/// the optimal darts; once you press one it plays out like Checkout calculator
/// - the tile is coloured and your mark is left on the board - and the board
/// then lights up the optimal darts for the new number.
web.HTMLElement buildChoiceScreen(ViewContext ctx) {
  final game = ctx.game;
  final round = game.round!;
  final impossible = game.impossibleNumber;
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

  // A number typed in Input with no checkout: Play says so, with an insult,
  // and Next checkout deals another.
  web.HTMLElement noCheckout(int number) => el('div', cls: 'tab-page play-area', children: [
        el('p', cls: 'target small', text: '$number'),
        el('p', cls: 'impossible-title', text: tr('This number is impossible to checkout.'), attrs: {'role': 'status'}),
        el('p', cls: 'insult', text: game.insult ?? ''),
        button(tr('Next checkout'), cls: 'cta', focusKey: 'next', onPressed: (_) => game.nextCheckout()),
      ]);

  web.HTMLElement play() => impossible != null ? noCheckout(impossible) : el('div', cls: 'tab-page', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'meta', text: tr('Finish on a double or Bull.')),
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

  // Learn: what to aim at on the number on screen with the darts left - the
  // route and a miss, the same boards as Checkout tutorial.
  web.HTMLElement learn() {
    if (impossible != null) {
      return el('div', cls: 'tab-page play-area', children: [
        el('p', cls: 'target', text: '$impossible'),
        el('p', cls: 'hint', text: tr('This number is impossible to checkout.')),
      ]);
    }
    final card = game.tutorial.tutor.card(round.remaining, round.dartsLeft);
    return el('div', cls: 'tab-page play-area', children: [
      el('p', cls: 'target', text: '${round.remaining}'),
      el('p', cls: 'label', text: trn(round.dartsLeft, '{n} dart in hand', '{n} darts in hand')),
      card == null ? el('p', cls: 'hint', text: tr('This number is impossible to checkout.')) : tutorBoards(ctx, card),
    ]);
  }

  return el('main', cls: 'screen game choice', children: [
    swipeTabs(
      ctx,
      name: 'choice',
      labels: [tr('Input'), tr('Play'), tr('Learn')],
      index: ctx.choiceTab,
      fixedHeight: false, // each page as tall as what is in it
      choose: (i) => ctx.choiceTab = i,
      pageOf: (i) => switch (i) {
        0 => el('div',
            cls: 'tutorial-page tab-input',
            children: inputPage(ctx, game.numberInput.digits, onDigit: game.typeDigit, onDelete: game.deleteDigit)),
        2 => learn(),
        _ => play(),
      },
    ),
  ]);
}
