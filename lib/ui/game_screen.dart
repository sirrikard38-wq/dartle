import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
import 'dom.dart';
import 'how_to_play.dart';
import 'keyboard.dart';
import 'tiles.dart';
import 'view_context.dart';

/// Places a dart and, the moment the answer is complete, submits it: the last
/// free box in Checkout calculator, or the end of the round in the practice
/// modes. There is no confirm step: if you missed, you missed.
///
/// [point] is where the board was tapped (null when entered another way); it
/// becomes the translucent mark for that dart.
void enterDart(ViewContext ctx, DartThrow dart, [BoardPoint? point]) {
  final game = ctx.game;
  if (game.phase != GamePhase.playing || game.isHandFull) return;

  // Practice: a number with a lit best dart is worth that dart however it was
  // entered (board or typed). The mark then goes in the middle of the lit area
  // instead of where it was pressed.
  var worth = dart;
  var at = point;
  if (game.mode.isPractice) {
    worth = ChoiceAdvisor.resolveTap(game.choiceHints, dart);
    if (worth != dart) at = null;
  }

  // The mark goes where it was pressed (or mid-area), but a repeat of the same
  // dart in the same area is placed beside the earlier one - sharing about half
  // its area - instead of on top of it. Stored, so it stays put on re-render.
  ctx.syncMarks();
  final placed = markPoints(game.entered, ctx.marks);
  final earlier = [
    for (var i = 0; i < game.entered.length; i++)
      if (game.entered[i] == worth) placed[i],
  ];
  ctx.marks.add(spreadMark(worth, at ?? segmentCenter(worth), earlier, ctx.random));
  game.selectDart(worth); // re-renders
  if (game.isHandFull) game.submit();
}

/// The S / D / T buttons beside the board, Undo and (in Checkout calculator) No
/// checkout. Shared by every game mode.
web.HTMLElement buildEntryPanel(ViewContext ctx) {
  final game = ctx.game;
  final practice = game.mode.isPractice;
  return buildInputPanel(
    multiplier: ctx.activeMultiplier(),
    finalBox: ctx.isFinalBox,
    canUndo: game.canUndo,
    undosLeft: game.undosLeft,
    marks: markPoints(game.entered, ctx.marks),
    // The practice modes have no ring buttons: the area pressed is the dart
    // thrown.
    ringButtons: !practice,
    showNoCheckout: !practice,
    // Practice: light up the best darts before the player chooses.
    lit: practice ? game.choiceHints : null,
    onPickMultiplier: (m, kb, focusKey) {
      ctx.pickedMultiplier = m;
      ctx.keepFocus(kb ? focusKey : null);
      ctx.rerender();
    },
    onDart: (dart, point, kb) {
      ctx.keepFocus(kb ? 'seg-${_keyId(dart)}' : null);
      enterDart(ctx, dart, point); // the chosen mode deliberately stays selected
    },
    onUndo: (kb) {
      ctx.keepFocus(kb ? 'undo' : null);
      game.undo();
    },
    onNoCheckout: (kb) => game.pressNoCheckout(),
  );
}

web.HTMLElement buildGameScreen(ViewContext ctx) {
  if (ctx.game.mode.isPractice) return buildChoiceScreen(ctx);

  final game = ctx.game;
  final challenge = game.challenge!;
  ctx.syncMarks();

  return el('main', cls: 'screen game', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'meta', text: 'Finish on a double or Bull.'),
      el('p', cls: 'target', text: '${challenge.target}', attrs: {
        'aria-label': 'Checkout ${challenge.target}, '
            '${challenge.dartsLeft} ${challenge.dartsLeft == 1 ? 'dart' : 'darts'} left',
      }),
      // Always three boxes. The ones already used are crossed out: only the
      // free boxes can be filled.
      tileRow(game.entered,
          slots: Visit.darts,
          used: challenge.layout.used,
          activeIndex: game.entered.length,
          showDarts: true),
      // The boxes stay plain while you play. The colours (white, grey, light
      // pink) only come on the result screen, next to the optimal examples.
      _remainingLine(challenge.target, game.entered),
      // The clock sits centred between the number that is left and the
      // dartboard (see .clock-gap). A replay has no clock.
      if (game.isReplay)
        el('p', cls: 'hint', text: 'Replay - no clock, no points.')
      else
        el('div', cls: 'clock-gap', children: [timerLine(game)]),
    ]),
    buildEntryPanel(ctx),
    buildHowToPlay(game),
  ]);
}

/// The countdown clock text; the app ticks it without re-rendering.
web.HTMLElement timerLine(GameController game) => el('p',
    cls: 'timer${game.remaining.isNegative ? ' over' : ''}',
    attrs: {'id': 'timer', 'role': 'timer', 'aria-live': 'off'},
    text: formatCountdown(game.remaining));

/// What is left to checkout after the darts entered so far, e.g. "76 left".
/// Just the result - no working shown. The number is centred under the big
/// number above it; the word "left" hangs to its right and does not count (an
/// invisible copy of the word on the left keeps the number in the middle).
web.HTMLElement _remainingLine(int target, List<DartThrow> entered) {
  final left = target - entered.fold<int>(0, (sum, d) => sum + d.score);
  final state = left < 0 ? 'over' : (left == 0 ? 'zero' : '');
  final word = left < 0 ? 'over' : 'left';
  return el('p', cls: 'remaining $state', attrs: {
    'aria-label': left < 0 ? 'Over by ${-left}' : '$left left',
  }, children: [
    el('span', cls: 'left-note ghost', text: word, attrs: {'aria-hidden': 'true'}),
    el('strong', text: '${left.abs()}'),
    el('span', cls: 'left-note', text: word),
  ]);
}

String _keyId(DartThrow dart) =>
    dart.isBull ? 'bull' : (dart.isOuterBull ? '25' : '${dart.number}');
