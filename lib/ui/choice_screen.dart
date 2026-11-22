import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'footer.dart';
import 'game_screen.dart';
import 'result_screen.dart';
import 'swipes.dart';
import 'tiles.dart';
import 'tutorial_screen.dart';
import 'view_context.dart';

/// How a dart's rating shows on its tile (white / grey / pink + marks).
TileState tileStateFor(DartQuality quality) => switch (quality) {
      DartQuality.optimal => TileState.correct,
      DartQuality.fine => TileState.present,
      DartQuality.poor || DartQuality.bust => TileState.absent,
    };

/// Checkout choice: the same parts as Checkout calculator - Input, Favorites,
/// Choose, Learn and Miss - with Choose in Practice's place, while a number is
/// played and once it is played out.
web.HTMLElement buildChoiceScreen(ViewContext ctx) {
  ctx.syncMarks();
  return buildPartsScreen(ctx, ctx.choice, playLabel: tr('Choose'), play: () => _choose(ctx), cls: 'choice');
}

/// Choose: laid out as Practice - the number, the boxes, what is left, the
/// board, Replay and Next - but you pick your own darts: before every dart the
/// board lights up the optimal darts. Once it is played out the answer shows
/// here as in Practice, with "Go to Learn" and the links of the foot.
List<web.HTMLElement> _choose(ViewContext ctx) {
  final game = ctx.game;

  // The game draws the screen again itself.
  void again(void Function() change) {
    ctx.keepFocus(null);
    change();
  }

  web.HTMLElement actions({bool replay = true}) => el('div', cls: 'practice-actions', children: [
        if (replay) button(tr('Replay'), cls: 'cta secondary', focusKey: 'replay', onPressed: (_) => again(game.replayCheckout)),
        button(tr('Next'), cls: 'cta', focusKey: 'next', onPressed: (_) => again(game.nextCheckout)),
      ]);

  // A number typed in Input with no checkout: Choose says so, with an insult.
  if (game.impossibleNumber case final number?) {
    return [
      el('p', cls: 'meta', text: tr('Finish on a double or Bull.')),
      el('p', cls: 'target', text: '$number'),
      el('p', cls: 'impossible-title', text: tr('This number is impossible to checkout.'), attrs: {'role': 'status'}),
      el('p', cls: 'insult', text: game.insult ?? ''),
      actions(replay: false),
    ];
  }

  final judged = game.lastResult;
  if (game.phase == GamePhase.result && judged != null) {
    return [
      el('div', cls: 'practice-result', children: resultView(ctx, judged, ctx.marks, learnMore: () {
        ctx.choice.tab = TutorialTab.learn;
        ctx.keepFocus(null);
        ctx.rerender();
        slideIn(1);
      })),
      actions(),
      // The links of the foot right under the answer, on the screen with it.
      buildFooter(),
    ];
  }

  final challenge = game.challenge!;
  final round = game.round!;
  final boxes = tileRow(game.entered,
      slots: Visit.darts,
      used: round.layout.used,
      activeIndex: game.entered.length,
      // Plain boxes while you play: each dart's rating colour shows with the
      // answer.
      showDarts: true);
  return [
    el('p', cls: 'meta', text: tr('Finish on a double or Bull.')),
    el('p', cls: 'target', text: '${challenge.target}', attrs: {
      'aria-label': trn(round.dartsLeft, '{target} to checkout, {n} dart left', '{target} to checkout, {n} darts left',
          {'target': round.remaining}),
    }),
    // A number with two darts or three: a press on the boxes switches (a dart
    // already thrown keeps its place). The line above them says so.
    dartsHint(show: game.canChooseDarts),
    if (game.canChooseDarts)
      button('',
          cls: 'dart-count-toggle',
          focusKey: 'practice-darts',
          ariaLabel: tr('Play {target} with {n} darts', {'target': challenge.target, 'n': round.maxDarts == 3 ? 2 : 3}),
          onPressed: (kb) {
            ctx.keepFocus(kb ? 'practice-darts' : null);
            game.chooseOtherDarts();
          })
        ..appendChild(boxes)
    else
      boxes,
    remainingLine(challenge.target, game.entered),
    buildEntryPanel(ctx),
    actions(),
  ];
}
