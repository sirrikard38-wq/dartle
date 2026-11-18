import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

/// Collapsible rules and tips, shown under the input on the game screens. Every
/// text goes through [tr], so the Croatian version is in
/// `lib/src/i18n/croatian.dart` under the English wording used here.
web.HTMLElement buildHowToPlay(GameController game) {
  final seconds = game.timeLimit.inSeconds;

  web.HTMLElement section(String title, String body) => el('div', cls: 'how-section', children: [
        el('h4', text: title),
        el('p', text: body),
      ]);

  final practice = game.mode.isPractice;

  return el('details', cls: 'how-to', children: [
    el('summary', text: tr('How to play')),
    if (practice)
      section(
          tr(game.mode == GameMode.input ? 'Checkout input' : 'Checkout practice'),
          tr('Choose your own darts to check the number out. The big number is what '
              'you still need. Before every dart the board lights up the optimal darts '
              'in grey and fades the rest, so you can see where to aim. Press anywhere '
              'on a number that has one lit area and it counts as that lit dart. When a '
              'number has two lit areas (say the triple and the single), press the '
              'exact area you want. Other numbers count as the exact area you press. '
              'You must finish on a double or Bull with the last of your darts; going '
              'below zero, leaving 1 or checking out with a dart still in hand is a '
              'miss, unless that double is lit. Every two-dart number can be played with '
              'two or three darts: before your second dart, press the boxes to choose. '
              'When a round is over, Replay checkout plays the same number again and '
              'Next checkout moves on. There is no clock and no score, and nothing is '
              'saved.'))
    else
      section(
          tr('The basics'),
          tr('You get a number and always three boxes. A box that is crossed out is a '
              'dart already used, so it cannot be filled. A one-dart number has its '
              'first two boxes crossed out. A two-dart number has its left box '
              'crossed out - but half the time a two-dart number over 60 comes with '
              'all three boxes free. A three-dart number has nothing crossed out. '
              'Every free box has to be used, unless the optimal route itself finishes '
              'sooner (64 with three darts is T16 D8). Checking out sooner another way '
              'is a miss - unless it is an optimal route of fewer darts, which counts as '
              'right: "Good, but not in the given number of darts". Pick S, D or T (on '
              'either side of the board), then tap a number. The last free box is '
              'always a double or Bull. Your answer is checked the moment it is '
              'complete. Not every number can be checked out: if there is no checkout, '
              'press No checkout.')),
    section(
        tr('Order'),
        tr('The darts before the finisher are a combination: T20 T19 D8 is the same '
            'as T19 T20 D8. Only the last dart has a fixed place.')),
    section(
        tr('What is optimal'),
        tr('The optimal dart comes from checkout tables for every number from 2 to '
            '170 with 1, 2 or 3 darts in hand. They are worked out on a real board with '
            'the spread of a real throw, so they look at what a miss into the next area '
            'leaves, not only at a hit: 127 with three darts is T20, as a miss into S20 '
            'leaves 107 (T19 Bull), while T19 missed into S19 leaves 108, no checkout. '
            'Targets almost as good count too and are lit as well (62 with three darts: '
            'T10, T14 or T18), and so does any target of the same kind that leaves a '
            'checkout just as soon, with a miss just as good (25 with two darts: S17, '
            'S3, S19 or S7). The route may finish with a dart still in hand (64 with '
            'three darts: T16 D8). Checkout tutorial shows the card of every number.')),
    section(
        tr('Aim'),
        tr('When the table aims between two neighbours, both are lit (48: S16 or S8, '
            'then D16 or D20). Before every dart the table of what is left with the '
            'darts left is lit (127: T20, then 67 with two darts is T17). With no '
            'checkout left in the darts in hand, the table aims for a good number to '
            'leave for the next visit (41 with one dart: S9 leaves 32).')),
    section(
        tr('The board'),
        tr('Pick S, D or T (single, double or triple - the buttons on both sides of '
            'the board are the same, use either hand) and the matching rings of the '
            'board turn grey; everything else goes dark. The board is drawn to real '
            'proportions, so the doubles and triples are thin: press anywhere in a '
            'number\'s wedge and the ring you picked is thrown at that number. Each '
            'press leaves a see-through circle on that ring, so you can see how the '
            'checkout looks on the board.')),
    section(
        tr('Colours'),
        tr('The boxes stay plain while you play. After the checkout, each dart '
            'flips to a colour: white means it belongs in the best route, light pink '
            'means it does not, and grey means the right dart in the wrong place. '
            'Press "Also optimal" to see every optimal route on its own board. '
            'Press the little dart in the corner of a board to make that route a '
            'favorite: it fills in white, comes first next time, and is kept under '
            'Favorites in the menu. A number with only one optimal route has it as a '
            'favorite from the start. Your own checkout under "Your darts" can be a '
            'favorite too, when it ends on a double and adds up to the number - '
            'optimal or not.')),
    if (game.mode.hasScore) ...[
      section(
          tr('Score'),
          tr('A correct checkout with time left on the clock scores as many points as '
              'you have checkouts in a row: 1, then 2, then 3. A miss costs nothing but '
              'the count starts again from 0. If the clock has run out, a right answer '
              'scores 0 but keeps your streak. Press the score on the result screen '
              'to see how it was worked out.')),
      section(
          tr('The clock'),
          tr('You start on {seconds}s and the clock counts down. Past zero it goes '
              'negative. Replay checkout has no clock and no points.',
              {'seconds': seconds})),
      section(
          tr('Undo'),
          tr('Undo can be used {max} times in a session. The number in brackets is how '
              'many are left. Choose the game again for {max} more. Once all of them are '
              'used, the next miss ends the session: you see your score, and Replay '
              'session starts a new one from 0.',
              {'max': GameController.maxUndos})),
    ],
  ]);
}
