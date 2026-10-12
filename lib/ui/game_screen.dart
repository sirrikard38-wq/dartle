import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'choice_screen.dart';
import 'dom.dart';
import 'how_to_play.dart';
import 'keyboard.dart';
import 'tiles.dart';
import 'view_context.dart';

/// Places a dart and, the moment the answer is complete, submits it: the last
/// box in Checkout calculator, or the end of the round in Checkout practice.
/// There is no confirm step: if you missed, you missed.
///
/// [point] is where the board was tapped (null when entered another way); it
/// becomes the translucent mark for that dart.
void enterDart(ViewContext ctx, DartThrow dart, [BoardPoint? point]) {
  final game = ctx.game;
  if (game.phase != GamePhase.playing || game.isHandFull) return;

  // Checkout practice: a number with a lit best dart is worth that dart however
  // it was entered (board, keypad or typed). The mark then goes in the middle
  // of the lit area instead of where it was pressed.
  var worth = dart;
  var at = point;
  if (game.mode == GameMode.choice) {
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

/// "Give up", at the end of the screen just above How to play. It ends the run
/// and shows the leaderboard.
web.HTMLElement buildGiveUp(ViewContext ctx) => el('div', cls: 'give-up', children: [
      button('Give up',
          cls: 'text-btn', focusKey: 'skip', onPressed: (_) => ctx.giveUp()),
    ]);

/// The Single / Double / Treble toggle with the board or keypad. Shared by both
/// game modes.
web.HTMLElement buildEntryPanel(ViewContext ctx) {
  final game = ctx.game;
  return buildInputPanel(
    view: ctx.inputView,
    multiplier: ctx.activeMultiplier(),
    finalBox: ctx.isFinalBox,
    canUndo: game.canUndo,
    marks: markPoints(game.entered, ctx.marks),
    // Checkout practice has no ring buttons: the area pressed is the dart thrown.
    ringButtons: game.mode != GameMode.choice,
    // Checkout practice: light up the best darts before the player chooses.
    lit: game.mode == GameMode.choice ? game.choiceHints : null,
    onChangeView: ctx.setInputView,
    onPickMultiplier: (m, kb) {
      ctx.pickedMultiplier = m;
      ctx.keepFocus(kb ? 'mode-${m.name}' : null);
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
  );
}

web.HTMLElement buildGameScreen(ViewContext ctx) {
  if (ctx.game.mode == GameMode.choice) return buildChoiceScreen(ctx);

  final game = ctx.game;
  final challenge = game.challenge!;
  ctx.syncMarks();

  return el('main', cls: 'screen game', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'meta', text: 'Finish on a double or Bull.'),
      el('p', cls: 'target', text: '${challenge.target}', attrs: {
        'aria-label': 'Checkout ${challenge.target}, '
            '${challenge.dartCount} ${challenge.dartCount == 1 ? 'dart' : 'darts'}',
      }),
      tileRow(game.entered,
          slots: challenge.dartCount,
          activeIndex: game.entered.length,
          live: true,
          showDarts: true,
          // Colour each dart right away: white if it belongs in the best
          // route, light pink if not.
          states: game.entered.isEmpty
              ? null
              : TileFeedback.best(game.entered, game.currentOptimalRoutes)),
      _remainingLine(challenge.target, game.entered),
      timerLine(game),
    ]),
    buildEntryPanel(ctx),
    buildGiveUp(ctx),
    buildHowToPlay(game),
  ]);
}

/// The countdown clock text; the app ticks it without re-rendering.
web.HTMLElement timerLine(GameController game) => el('p',
    cls: 'timer${game.remaining.isNegative ? ' over' : ''}',
    attrs: {'id': 'timer', 'role': 'timer', 'aria-live': 'off'},
    text: formatCountdown(game.remaining));

/// What is left to checkout after the darts entered so far, e.g. "76 left".
/// Just the result - no working shown.
web.HTMLElement _remainingLine(int target, List<DartThrow> entered) {
  final left = target - entered.fold<int>(0, (sum, d) => sum + d.score);
  final state = left < 0 ? 'over' : (left == 0 ? 'zero' : '');
  return el('p', cls: 'remaining $state', attrs: {
    'aria-label': left < 0 ? 'Over by ${-left}' : '$left left',
  }, children: [
    el('strong', text: '${left.abs()}'),
    el('span', cls: 'left-note', text: left < 0 ? 'over' : 'left'),
  ]);
}

String _keyId(DartThrow dart) =>
    dart.isBull ? 'bull' : (dart.isOuterBull ? '25' : '${dart.number}');
