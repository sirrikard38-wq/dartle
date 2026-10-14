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
          'You must finish on a double or Bull; going below zero or leaving 1 is a '
          'bust. When a round is over, Replay checkout plays the same number again '
          'and Next checkout moves on. There is no clock and no score, and nothing '
          'is saved.')
    else
      section('The basics',
          'You get a number and always three boxes. A box that is crossed out is a '
          'dart already used, so it cannot be filled. A one-dart number has its '
          'first two boxes crossed out. A two-dart number has one box crossed out: '
          'between 51 and 70 it is the left one or the right one (50/50), '
          'otherwise the left one. A three-dart number has nothing crossed out. '
          'Pick Single, Double or Triple, then tap a number. The last free box is '
          'always a double or Bull. Your answer is checked the moment it is '
          'complete. Not every number can be checked out: if there is no checkout, '
          'press No checkout.'),
    section('Order',
        'The darts before the finisher are a combination: T20 T19 D8 is the same '
        'as T19 T20 D8. Only the last dart has a fixed place.'),
    section('What is optimal',
        'The fewest darts comes first. A single is far easier to hit than a '
        'double or a triple, so with the same number of darts the route with the '
        'most singles wins, and a double as a setup dart is the worst. So 35 is '
        'S15 D10, S3 D16 or S17 D9 - never T5 D10 - and they are all equally '
        'optimal. The outer bull (25) counts as a single. Where no single can do '
        'it, triples T15 to T20 are used.'),
    section('Bull safety',
        'With two darts left on 51 to 70 (the left box crossed out), aim at the '
        'number that is 50 less than what is left. Say 57 is left: the single 7 '
        'leaves exactly 50, so throw the triple T7 and then D18, or the single S7 '
        'and then the Bull. If you aim at the triple and hit the single, you still '
        'have the Bull. With the right box crossed out, the usual rule applies '
        'instead: 57 is S17 D20. For three darts the first dart should leave 51 '
        'to 70 (119: T19 leaves 62, then T12 D13 or S12 Bull).'),
    section('The board',
        'Pick Single, Double or Triple and the matching rings of the board turn '
        'grey; everything else goes dark. The board is drawn to real '
        'proportions, so the doubles and triples are thin: press anywhere in a '
        'number\'s wedge and the ring you picked is thrown at that number. Each '
        'press leaves a see-through circle on that ring, so you can see how the '
        'checkout looks on the board.'),
    section('Colours',
        'Each dart is coloured as soon as you enter it. White means it belongs in '
        'the best route. Light pink means it does not. Grey means the right dart '
        'in the wrong place. After the checkout, Show why. explains the route.'),
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
          '${GameController.maxUndos} more.'),
    ],
  ]);
}
