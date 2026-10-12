import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

/// Collapsible rules and tips, shown under the input on the game screen.
web.HTMLElement buildHowToPlay(GameController game) {
  final seconds = game.timeLimit.inSeconds;
  final cfg = game.scoringConfig;

  web.HTMLElement section(String title, String body) => el('div', cls: 'how-section', children: [
        el('h4', text: title),
        el('p', text: body),
      ]);

  return el('details', cls: 'how-to', children: [
    el('summary', text: 'How to play'),
    if (game.mode == GameMode.choice)
      section('Checkout practice',
          'You have three darts to check out the number. Choose each dart '
          'yourself: pick Single, Double or Treble, then tap the board. The big '
          'number is what you still need. The fewest darts is best, and every '
          'route with the fewest darts is equally good: for 85 that is T15 then '
          'D20, T17 then D17 or T19 then D14. Longer routes like 15, 20, Bull '
          'still check out but are not optimal, and odd darts such as T3 are '
          'poor choices. Before every dart the board lights up the best darts '
          'in grey and fades the rest, so you can see where to aim. Trebles come '
          'first; singles are lit only when no treble can do the job; the Bull '
          'and doubles are lit as a setup dart only when they are part of the '
          'standard route. Press '
          'anywhere on a number that has a lit area and it counts as that lit '
          'dart: with T20 lit, any press on the 20 is worth T20. Other numbers '
          'count as the exact area you press, so there are no Single, Double or '
          'Treble buttons here. You must finish on a double or Bull; going '
          'below zero or leaving 1 is a bust. When a round is over, Same checkout '
          'plays the same number again, to try the same route or a different one, '
          'and Next checkout moves on to a new number.')
    else
      section('The basics',
          'You get a number and always three boxes. A box that is blurred out is a '
          'dart you have already thrown, so it cannot be used. A number that can '
          'be done in one dart has its first two boxes blurred. A number that needs '
          'two darts has either just the first box blurred, or all three free. '
          'Pick Single, Double or Treble, then tap a number. The last free box is '
          'always a double or Bull. Your answer is checked the moment the number is '
          'checked out, or when the last free box is filled.'),
    section('Order',
        'The darts before the finisher are a combination: T20 T19 D8 is the same '
        'as T19 T20 D8. Only the last dart has a fixed place.'),
    section('Bull safety',
        'With two darts left on 55 to 70, throw the treble that is 50 less than '
        'what is left. Say 67 is left: throw T17 (51), then D8. If you miss the '
        'treble and hit the single 17 instead, you have exactly 50 left, which is '
        'Bull. So even a near miss still leaves a finish. 61 works the same way: '
        'T11, then D14, and a missed T11 leaves Bull. For bigger numbers, the '
        'first dart takes you into that range (121: T20 first leaves 61). If '
        'all three darts are free on 51 to 70, there is no need for a treble: '
        'single, single, double is better than any treble and double. For 67 '
        'that is S14, S13, D20, and any single, single, double that adds up '
        'counts.'),
    section('The board',
        'Pick Single, Double or Treble and the matching rings of the board turn '
        'grey; everything else goes dark. The board is drawn to real '
        'proportions, so the doubles and trebles are thin: press anywhere in a '
        'number\'s wedge and the ring you picked is thrown at that number. Each '
        'press leaves a see-through circle on that ring, so you can see how the '
        'checkout looks on the board. When boards are compared at the end, only '
        'the circles are lit and the board shows just its dividing lines.'),
    section('Colours',
        'Each dart is coloured as soon as you enter it. White means it belongs in '
        'the best route. Light pink means it does not. Grey means the right dart '
        'in the wrong place. After the checkout you see your darts on a board, '
        'and if you were not optimal, the best route on a second board.'),
    if (game.mode.hasScore)
      section('Points',
          'A correct checkout is worth +${cfg.minBasePoints} for an easy number up '
          'to +${cfg.maxBasePoints} for a hard one. The best route adds '
          '+${cfg.optimalBonus}, and a quick answer up to +${cfg.maxSpeedBonus}. '
          'A wrong or skipped checkout costs what it was worth, so a hard miss can '
          'be as much as −${cfg.maxBasePoints}.')
    else
      section('No score',
          'Checkout practice has no points and no clock, so take your time and '
          'learn the best darts.'),
    // Only the calculator is against the clock.
    if (game.mode.isTimed)
      section('The clock',
          'You start on ${seconds}s and the clock counts down. Past zero it goes '
          'negative, and every ${cfg.overtimeSecondsPerPoint} seconds over costs '
          '1 point, so a very late answer can lose points even when it is right.'),
  ]);
}
