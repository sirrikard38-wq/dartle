import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

/// Collapsible rules and tips, shown under the input on the game screens.
web.HTMLElement buildHowToPlay(GameController game) {
  final seconds = game.timeLimit.inSeconds;

  web.HTMLElement section(String title, String body) => el('div', cls: 'how-section', children: [
        el('h4', text: title),
        el('p', text: body),
      ]);

  final practice = game.mode.isPractice;

  return el('details', cls: 'how-to', children: [
    el('summary', text: 'How to play'),
    if (practice)
      section(
          game.mode == GameMode.input ? 'Checkout input' : 'Checkout practice',
          'Choose your own darts to check the number out. The big number is what '
          'you still need. Before every dart the board lights up the optimal darts '
          'in grey and fades the rest, so you can see where to aim. Press anywhere '
          'on a number that has one lit area and it counts as that lit dart. When a '
          'number has two lit areas (say the triple and the single), press the '
          'exact area you want. Other numbers count as the exact area you press. '
          'You must finish on a double or Bull with the last of your darts; going '
          'below zero, leaving 1 or checking out with a dart still in hand is a '
          'miss. A two-dart number over 40 can be played with two or three darts: '
          'before your first dart, press the boxes to choose. When a round is over, '
          'Replay checkout plays the same number again and Next checkout moves on. '
          'There is no clock and no score, and nothing is saved.')
    else
      section('The basics',
          'You get a number and always three boxes. A box that is crossed out is a '
          'dart already used, so it cannot be filled. A one-dart number has its '
          'first two boxes crossed out. A two-dart number has its left box '
          'crossed out - but half the time a two-dart number over 40 comes with '
          'all three boxes free. A three-dart number has nothing crossed out. '
          'Every free box has to be used: checking out with a box still free is '
          'a miss. Pick S, D or T (on either side of the board), then tap a '
          'number. The last free box is always a double or Bull. Your answer is '
          'checked the moment it is complete. Not every number can be checked '
          'out: if there is no checkout, press No checkout.'),
    section('Order',
        'The darts before the finisher are a combination: T20 T19 D8 is the same '
        'as T19 T20 D8. Only the last dart has a fixed place.'),
    section('What is optimal',
        'The fewest darts comes first. A single is far easier to hit than a '
        'double or a triple, so with the same number of darts the route with the '
        'most singles wins, and a double as a setup dart is the worst. So 35 is '
        'S15 D10, S3 D16 or S17 D9, and they are all equally optimal. The outer '
        'bull (25) counts as a single. Where no single can do it, triples T15 to '
        'T20 are used.'),
    section('Aim',
        'With two darts left on 20 or more, a first dart is optimal too when '
        'both darts you might hit leave a double: the single and the triple of a '
        'number, or two neighbours on the board. Say 43 is left: T11 leaves D5 '
        'and S11 leaves D16. On 64, T16 leaves D8 and its neighbour T8 leaves '
        'D20. When some aims leave a good double whatever you hit, only those '
        'count; otherwise the ones where at least one does. The same good double '
        'twice counts too (64: D16 D16).'),
    section('Bull safety',
        'With two darts left on 51 to 70, aim at the number that is 50 less than '
        'what is left. Say 57 is left: the single 7 leaves exactly 50, so throw '
        'the triple T7 and then D18, or the single S7 and then the Bull. These '
        'are the optimal routes. If you aim at the triple and hit the single, you '
        'still have the Bull. For three darts the first dart should leave 51 to '
        '70 (119: T19 leaves 62, then T12 D13 or S12 Bull).'),
    section('The board',
        'Pick S, D or T (single, double or triple - the buttons on both sides of '
        'the board are the same, use either hand) and the matching rings of the '
        'board turn grey; everything else goes dark. The board is drawn to real '
        'proportions, so the doubles and triples are thin: press anywhere in a '
        'number\'s wedge and the ring you picked is thrown at that number. Each '
        'press leaves a see-through circle on that ring, so you can see how the '
        'checkout looks on the board.'),
    section('Colours',
        'The boxes stay plain while you play. After the checkout, each dart '
        'flips to a colour: white means it belongs in the best route, light pink '
        'means it does not, and grey means the right dart in the wrong place. '
        'Press "Also optimal" to see the optimal routes on their own boards. A '
        'number with more than six of them only lists the ones that finish on a '
        'good double (or the Bull).'),
    if (game.mode.hasScore) ...[
      section('Score',
          'A correct checkout with time left on the clock scores as many points as '
          'you have checkouts in a row: 1, then 2, then 3. A miss costs nothing but '
          'the count starts again from 0. If the clock has run out, a right answer '
          'scores 0 but keeps your streak. Press the score on the result screen '
          'to see how it was worked out.'),
      section('The clock',
          'You start on ${seconds}s and the clock counts down. Past zero it goes '
          'negative. Replay checkout has no clock and no points.'),
      section('Undo',
          'Undo can be used ${GameController.maxUndos} times in a session. The number '
          'in brackets is how many are left. Choose the game again for '
          '${GameController.maxUndos} more. Once all of them are used, the next miss '
          'ends the session: you see your score, and Replay session starts a new '
          'one from 0.'),
    ],
  ]);
}
