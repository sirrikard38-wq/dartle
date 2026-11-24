import 'dart:async';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'favorites_ui.dart';
import 'footer.dart';
import 'game_screen.dart';
import 'keyboard.dart';
import 'result_screen.dart';
import 'swipes.dart';
import 'tab_reorder.dart';
import 'tiles.dart';
import 'view_context.dart';

/// Checkout calculator: Input (type a number), Practice (play it out as the
/// timed game did), Learn (the optimal routes and their misses into single),
/// Favorites (its favorite routes) and Miss (a single missed into its
/// neighbours), all for one number.
web.HTMLElement buildTutorialScreen(ViewContext ctx) {
  final session = ctx.game.tutorial;
  return buildPartsScreen(ctx, session, playLabel: tr('Practice'), play: () => _practice(ctx, session));
}

/// The parts of Checkout calculator and Checkout choice, which look the same:
/// Input, Favorites, the game ([playLabel], drawn by [play]: Practice or
/// Choose), Learn and Miss, in the order the player put them in (one order for
/// both). A swipe to the side goes from one to the next. [cls] goes on the
/// screen.
web.HTMLElement buildPartsScreen(ViewContext ctx, NumberParts parts,
    {required String playLabel, required List<web.HTMLElement> Function() play, String cls = ''}) {
  final shared = ctx.game.tutorial;
  _loadOrder(shared);
  final order = shared.order;
  final area = swipeTabs(
    ctx,
    name: 'tutorial',
    labels: [
      for (final which in order)
        switch (which) {
          TutorialTab.input => tr('Input'),
          TutorialTab.practice => playLabel,
          TutorialTab.learn => tr('Learn'),
          TutorialTab.favorites => tr('Favorites'),
          TutorialTab.missing => tr('Miss'),
        },
    ],
    index: order.indexOf(parts.tab),
    choose: (i) => parts.tab = order[i],
    // A long press on a part: they jiggle and can be moved; the order is kept.
    onReorder: (moved) {
      shared.order = [for (final i in moved) order[i]];
      _saveOrder(shared.order);
      ctx.rerender();
    },
    // The links of the foot (Install, Instagram, Email) stand at the foot of
    // every part but the game (whose answer has them under it), so they are
    // always in sight and slide in with the part.
    pageOf: (i) => el('div', cls: 'tutorial-page tab-${order[i].name}', children: switch (order[i]) {
      TutorialTab.input => [..._input(ctx, parts), buildFooter()],
      TutorialTab.learn => [..._learn(ctx, parts), buildFooter()],
      TutorialTab.practice => play(),
      TutorialTab.favorites => [..._favorites(ctx, parts), buildFooter()],
      TutorialTab.missing => [..._missing(ctx, parts), buildFooter()],
    }),
  )..classList.add('play-area');
  return el('main', cls: 'screen tutorial${cls.isEmpty ? '' : ' $cls'}', children: [area]);
}

/// Where the order of the tutorial's parts is kept (this device only).
const String _orderKey = 'dartle.tutorial-order.v1';
bool _orderLoaded = false;

/// The order the player put the parts in, once per visit; the default when
/// none was saved (or it does not name every part once).
void _loadOrder(TutorialSession session) {
  if (_orderLoaded) return;
  _orderLoaded = true;
  try {
    final saved = web.window.localStorage.getItem(_orderKey);
    if (saved == null) return;
    final byName = TutorialTab.values.asNameMap();
    final tabs = [for (final name in saved.split(',')) byName[name]].whereType<TutorialTab>().toList();
    if (tabs.length == TutorialTab.values.length && tabs.toSet().length == tabs.length) session.order = tabs;
  } on Object {
    // The default order.
  }
}

void _saveOrder(List<TutorialTab> order) {
  try {
    web.window.localStorage.setItem(_orderKey, order.map((t) => t.name).join(','));
  } on Object {
    // Kept for this visit only.
  }
}

/// Chips over pages side by side ([labels], the page [index] showing): a press
/// on a chip glides its white fill over and brings the page in, a swipe moves
/// the page with the finger and the fill with it, as in Virulja's food
/// categories. [choose] takes the page to show next; [pageOf] draws a page.
/// Checkout calculator's and Checkout choice's parts have them.
web.HTMLElement swipeTabs(
  ViewContext ctx, {
  required String name,
  required List<String> labels,
  required int index,
  required void Function(int index) choose,
  required web.HTMLElement Function(int index) pageOf,
  bool fixedHeight = true,
  void Function(List<int> order)? onReorder,
}) {
  late final web.HTMLElement row;
  late final SwipeMark mark;
  TabReorder? reorder;
  bool exists(int i) => i >= 0 && i < labels.length;

  // A press glides the fill over to the chip pressed, then the page comes in.
  void show(int which) {
    if (which == index) return;
    final to = row.children.item(which) as web.HTMLElement?;
    animate(const Duration(milliseconds: 160), (progress) => mark.follow(to, progress), () {
      choose(which);
      ctx.rerender();
      slideIn(which > index ? 1 : -1);
    });
  }

  row = el('div', cls: 'chips tutorial-tabs', children: [
    for (var i = 0; i < labels.length; i++)
      button(labels[i],
          cls: 'chip${i == index ? ' selected' : ''}',
          focusKey: '$name-tab-$i',
          attrs: {'aria-pressed': '${i == index}', 'data-i': '$i'},
          onPressed: (kb) {
            // Not while the chips are being moved (a long press).
            if (reorder?.takeClick() ?? false) return;
            ctx.keepFocus(kb ? '$name-tab-$i' : null);
            show(i);
          }),
  ]);
  mark = SwipeMark(row);
  // A long press: the chips jiggle and can be put in another order.
  if (onReorder != null) reorder = TabReorder(row, onDone: onReorder);
  final sliding = el('div', cls: 'slide-page', children: [pageOf(index)]);
  final area = el('div', cls: 'swipe-area', children: [
    row,
    el('div', cls: 'slide-clip', children: [sliding]),
  ]);
  followSwipes(area, sliding, (step) => exists(index + step), (step) {
    choose(index + step);
    ctx.rerender();
  },
      peek: (step) => pageOf(index + step),
      follow: (step, fraction) =>
          mark.follow(exists(index + step) ? row.children.item(index + step) as web.HTMLElement? : null, fraction),
      fixedHeight: fixedHeight,
      // Right on the first part: back to the menu.
      backPastStart: () => ctx.showPage(MenuPage.home));
  return area;
}

/// Input: the number, what it says, and the keypad. A number from 2 to 170 is
/// at once the one Practice, Learn and Favorites show. Three seconds after the
/// last key (or after Next checkout) the next digit starts a new number.
List<web.HTMLElement> _input(ViewContext ctx, NumberParts session) =>
    inputPage(ctx, session.typedDigits, onDigit: session.typeDigit, onDelete: session.deleteDigit);

/// The Input page of Checkout calculator and Checkout choice: the words, the
/// [digits] typed with what they say, and the keypad ([onDigit], [onDelete]).
List<web.HTMLElement> inputPage(ViewContext ctx, String digits,
    {required void Function(int digit) onDigit, required void Function() onDelete}) {
  web.HTMLButtonElement digit(int n) => button('$n',
      cls: 'key pad-key',
      focusKey: 'input-digit-$n',
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'input-digit-$n' : null);
        onDigit(n);
        _typed();
        ctx.rerender();
      });

  final undo = button(tr('UNDO'),
      cls: 'key pad-key pad-undo',
      focusKey: 'input-undo',
      ariaLabel: tr('Delete the last digit'),
      disabled: digits.isEmpty,
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'input-undo' : null);
        onDelete();
        _typed();
        ctx.rerender();
      });
  undo.insertBefore(undoIcon(), undo.firstChild);

  // What the number says: a number outside 2 to 170, or one that cannot be
  // checked out at all.
  final typed = int.tryParse(digits);
  final String line;
  if (typed == null) {
    line = tr('Type a number from 2 to 170.');
  } else if (typed < CheckoutEngine.minCheckout || typed > CheckoutEngine.maxCheckout) {
    line = tr('A number from 2 to 170.');
  } else if (ctx.game.hasNoCheckout(typed)) {
    line = tr('This number is impossible to checkout.');
  } else {
    line = '';
  }

  return [
    el('div', cls: 'input-top', children: [
      el('p', cls: 'input-title', text: tr('Type a number to checkout and learn.')),
      // The number between the words and the keypad, a little above the
      // middle; what it says hangs under it.
      el('div', cls: 'input-number', children: [
        el('div', cls: 'number-wrap', children: [
          el('p', cls: 'target number-display${digits.isEmpty ? ' empty' : ''}${_takenNumber == digits ? ' taken' : ''}',
              text: digits.isEmpty ? '–' : digits,
              attrs: {'aria-label': digits.isEmpty ? tr('No number yet') : tr('Number {n}', {'n': digits})}),
          el('p', cls: 'hint', text: line, attrs: {'role': 'status'}),
        ]),
      ]),
    ]),
    el('div', cls: 'keypad', attrs: {'aria-label': tr('Number pad')}, children: [
      digit(1), digit(2), digit(3),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      undo, digit(0), el('span', cls: 'pad-spacer'),
    ]),
  ];
}

/// The digits whose number was taken: 1.5 s after the last key the frame
/// round the number glows faintly white (it stays so until the next key).
String? _takenNumber;
Timer? _takeTimer;

/// A key of Input was pressed: the frame goes dark and, if no other key comes
/// within 1.5 s, glows for the number then shown (from 2 to 170).
void _typed() {
  _takenNumber = null;
  _takeTimer?.cancel();
  _takeTimer = Timer(const Duration(milliseconds: 1500), () {
    final shown = web.document.querySelector('.tab-input .number-display:not(.empty)');
    final number = int.tryParse(shown?.textContent ?? '');
    if (shown == null || number == null) return;
    if (number < CheckoutEngine.minCheckout || number > CheckoutEngine.maxCheckout) return;
    _takenNumber = shown.textContent;
    shown.classList.add('taken');
  });
}

/// The darts in hand, 3, 2 or 1, for Learn and Miss (one choice for both, and
/// Favorites; Practice or Choose too before its first dart).
web.HTMLElement _dartsChips(ViewContext ctx, NumberParts session, String name) {
  web.HTMLButtonElement darts(int n) => button('$n',
      cls: 'chip${session.learnDarts == n ? ' selected' : ''}',
      focusKey: '$name-darts-$n',
      ariaLabel: trn(n, '{n} dart in hand', '{n} darts in hand'),
      attrs: {'aria-pressed': '${session.learnDarts == n}'},
      onPressed: (kb) {
        ctx.keepFocus(kb ? '$name-darts-$n' : null);
        session.chooseDarts(n);
        ctx.rerender();
      });
  return el('div', cls: 'chips', children: [darts(3), darts(2), darts(1)]);
}

/// Learn's and Miss's number, where Practice's is and as big, and under it
/// "Darts in hand" over 3 2 1, with room under them before the routes.
web.HTMLElement _numberAndDarts(ViewContext ctx, NumberParts session, int target, String name) =>
    el('div', cls: 'number-row', children: [
      el('span'),
      el('p', cls: 'target number-display tab-number', text: '$target', attrs: {'aria-label': tr('Number {n}', {'n': target})}),
      el('div', cls: 'darts-side', children: [
        el('p', cls: 'label', text: tr('Darts in hand')),
        _dartsChips(ctx, session, name),
      ]),
    ]);

/// A number that cannot be checked out at all says so, with one of the
/// insults, as Checkout input does.
web.HTMLElement _impossible(int target) => el('div', cls: 'tutor-card', children: [
      el('p', cls: 'impossible-title', text: tr('This number is impossible to checkout.'), attrs: {'role': 'status'}),
      el('p', cls: 'insult', text: Phrases.randomInsult(math.Random(target))),
    ]);

/// Learn: the number (typed in Input, or the Practice question), the darts in
/// hand, what the Practice checkout was worth, then the optimal routes, each
/// beside what its first dart leaves when it misses into single.
List<web.HTMLElement> _learn(ViewContext ctx, NumberParts session) {
  final target = session.shownTarget;
  final card = session.learnCard;
  final review = session.learnDarts == session.practiceDarts ? session.practiceReview : null;

  return [
    el('div', cls: 'learn-top', children: [
      _numberSpacer(),
      _numberAndDarts(ctx, session, target, 'learn'),
      if (review != null) _reviewBox(ctx, session, review),
      if (ctx.game.hasNoCheckout(target))
        _impossible(target)
      else if (card != null)
        card.route == null ? tutorBoards(ctx, card) : _learnRoutes(ctx, card),
    ]),
  ];
}

/// Above the routes in Learn: the Practice checkout on its board, and why it
/// is optimal, good or wrong.
web.HTMLElement _reviewBox(ViewContext ctx, NumberParts session, PracticeReview review) {
  final target = session.practiceTarget;
  final darts = review.route.darts;
  final lines = <String>[];
  String? headline;
  switch (review.kind) {
    case ReviewKind.optimal:
      headline = tr('Optimal!');
      if (review.miss case final miss?) {
        lines.add(_ifMissed(miss, session.practiceDarts));
      } else if (darts.length > 1) {
        lines.add(tr('Your first dart is a single: Missing shows its neighbours.'));
      }
    case ReviewKind.good:
      headline = tr('Good, but not optimal.');
      switch (review.reason) {
        case GoodReason.fewerDarts:
          lines.add(trn(review.fewestDarts, 'The optimal routes need only {n} dart.', 'The optimal routes need only {n} darts.'));
        case GoodReason.missKeepsCheckout:
          final kept = review.optimalMiss!;
          lines.add(trn(
              session.practiceDarts - 1,
              'The optimal routes are better: if the first dart misses into single, you can still check out with {n} dart ({dart} leaves {left}: {route}).',
              'The optimal routes are better: if the first dart misses into single, you can still check out with {n} darts ({dart} leaves {left}: {route}).',
              {'dart': kept.dart.notation, 'left': kept.left, 'route': kept.route?.notation ?? ''}));
          if (review.miss case final miss?) lines.add(_ifMissed(miss, session.practiceDarts));
        case GoodReason.other:
          lines.add(tr('The optimal routes are below.'));
      }
    case ReviewKind.wrong:
      headline = tr('Wrong.');
      lines.add(darts.isEmpty
          ? trn(session.practiceDarts, '{target} can be checked out with {n} dart.',
              '{target} can be checked out with {n} darts.', {'target': target})
          : tr('These darts do not check out {n}.', {'n': target}));
  }

  final state = switch (review.kind) {
    ReviewKind.optimal => TileState.correct,
    ReviewKind.good => TileState.present,
    ReviewKind.wrong => TileState.absent,
  };
  return el('div', cls: 'learn-review ${review.kind.name}', children: [
    el('p', cls: 'label', text: session is TutorialSession ? tr('Your darts in Practice') : tr('Your darts in Choose')),
    if (darts.isNotEmpty)
      el('figure', cls: 'board-figure', children: [
        buildDartboard(
          linesOnly: true,
          marks: spreadMarks(darts, session.marks, math.Random(routeSeed(review.route.notation))),
          label: tr('Your darts: {route}', {'route': review.route.notation}),
        ),
        tileRow(darts,
            slots: darts.length,
            small: true,
            states: List.filled(darts.length, state),
            label: review.route.notation,
            lefts: leftsAfter(target, darts)),
      ]),
    el('p', cls: 'review-headline', text: headline),
    for (final line in lines) el('p', cls: 'card-line', text: line),
  ]);
}

/// "If you miss into single (S20), 107 is left and you can still check out:
/// T19 Bull." - what a first dart's miss into single leaves, [darts] in hand.
String _ifMissed(DartOutcome miss, int darts) {
  final dart = miss.dart.notation;
  if (miss.bust) return tr('If you miss into single ({dart}), it is a bust.', {'dart': dart});
  if (miss.route case final route?) {
    return tr('If you miss into single ({dart}), {left} is left and you can still check out: {route}.',
        {'dart': dart, 'left': miss.left, 'route': route.notation});
  }
  if (darts <= 1) {
    return tr('If you miss into single ({dart}), {left} is left for the next visit.', {'dart': dart, 'left': miss.left});
  }
  return trn(darts - 1, 'If you miss into single ({dart}), {left} is left: no checkout with {n} dart.',
      'If you miss into single ({dart}), {left} is left: no checkout with {n} darts.', {'dart': dart, 'left': miss.left});
}

/// Every optimal route Learn shows, in order: the table's route, the other
/// hit of a pair (48: S16 or S8), then all the others (those with a better
/// double first, as the result screen picks them).
List<CheckoutRoute> _learnRouteList(TutorCard card, List<CheckoutRoute> all) {
  final shown = <CheckoutRoute>[card.route!];
  if (card.aims.length == 2 && card.hits.length == 2) {
    final other = card.routeOf(card.hits[1]);
    if (other != null && !shown.any(other.isEquivalentTo)) shown.add(other);
  }
  shown.addAll(BetterDoubles.extras(all, exclude: shown));
  for (final route in all) {
    if (!shown.any(route.isEquivalentTo)) shown.add(route);
  }
  return shown;
}

/// Learn's routes: every optimal route in the column "Optimal route", and
/// beside each what its first dart leaves when it lands in the other bed of
/// its number - the single of a treble or double (T18: S18), the treble of a
/// single (S18: T18), 25 for the Bull.
web.HTMLElement _learnRoutes(ViewContext ctx, TutorCard card) {
  final target = card.target;
  final tutor = ctx.game.tutorial.tutor;
  final all = tutor.optimalRoutes(target, card.darts);
  final grid = el('div', cls: 'route-grid two', children: [
    el('p', cls: 'label grid-head', text: tr('Optimal route')),
    el('p', cls: 'label grid-head', text: tr('Miss: single or triple')),
  ]);
  _fillRows(grid, [
    for (final route in _learnRouteList(card, all))
      () => [
            routeFigure(ctx, target, route, showLeft: true),
            _outcomeCell(ctx, card,
                tutor.outcome(target, card.darts, CheckoutTutor.singleOrTriple(route.darts.first))),
          ],
  ]);
  return el('div', cls: 'tutor-card', children: [
    grid,
    if (all.length == 1) el('p', cls: 'hint only-one', text: tr('Only possibility')),
  ]);
}

/// Adds [rows] (each draws its cells) to [grid]: the first few at once, the
/// rest a few at a time while it is on the screen, so a number with many
/// routes (102 with three darts has 32) does not hold the page up.
void _fillRows(web.HTMLElement grid, List<List<web.HTMLElement> Function()> rows) {
  const firstBatch = 6;
  const nextBatch = 4;
  void fill(int from) {
    if (from > 0 && !grid.isConnected) return;
    final to = math.min(from + (from == 0 ? firstBatch : nextBatch), rows.length);
    for (var i = from; i < to; i++) {
      for (final cell in rows[i]()) {
        grid.append(cell);
      }
    }
    if (to < rows.length) Timer(const Duration(milliseconds: 16), () => fill(to));
  }

  fill(0);
}

/// A board for what a missed dart leaves: the dart and the route after it
/// (any checkout there is, optimal or not), what is left under each dart.
web.HTMLElement _outcomeCell(ViewContext ctx, TutorCard card, DartOutcome miss) {
  final route = card.routeOf(miss);
  if (route == null) return _deadEnd(card, miss);
  return routeFigure(ctx, card.target, route, showLeft: true);
}

/// Missing: for every first dart of the optimal routes (any bed of 1 to 20:
/// single, double or treble; not 25 or the Bull), a route with it in the
/// middle, the singles beside its number to the left and right, and under it
/// the single of the same number (for a treble or a double) - each with what
/// it leaves and any checkout there is. The darts in hand as in Learn.
List<web.HTMLElement> _missing(ViewContext ctx, NumberParts session) {
  final target = session.shownTarget;
  final card = session.learnCard;
  final tutor = ctx.game.tutorial.tutor;
  web.HTMLElement body;
  // Over the boards (only when there are boards): what they answer.
  var asks = false;
  if (ctx.game.hasNoCheckout(target)) {
    body = _impossible(target);
  } else if (card == null || card.route == null) {
    body = el('p', cls: 'hint', text: trn(session.learnDarts, 'No checkout with {n} dart.', 'No checkout with {n} darts.'));
  } else {
    // One row for each first dart: its misses are the same whatever follows.
    final byFirst = <DartThrow, CheckoutRoute>{};
    for (final route in _learnRouteList(card, tutor.optimalRoutes(target, card.darts))) {
      if (CheckoutTutor.sideNeighbours(route.darts.first) != null) byFirst.putIfAbsent(route.darts.first, () => route);
    }
    if (byFirst.isEmpty) {
      body = el('p', cls: 'hint', text: tr('Every optimal route starts at the bull, so there is no neighbour to miss into.'));
    } else {
      final grid = el('div', cls: 'route-grid three', children: [
        el('p', cls: 'label grid-head', text: tr('Miss left')),
        el('p', cls: 'label grid-head', text: tr('Optimal route')),
        el('p', cls: 'label grid-head', text: tr('Miss right')),
      ]);
      web.HTMLElement outcome(DartThrow dart) => _outcomeCell(ctx, card, tutor.outcome(target, card.darts, dart));
      _fillRows(grid, [
        for (final MapEntry(key: first, value: route) in byFirst.entries)
          if (CheckoutTutor.sideNeighbours(first) case (final left, final right))
            () => [
                  outcome(left),
                  routeFigure(ctx, target, route, showLeft: true),
                  outcome(right),
                  // A treble or a double can also land in its own single.
                  if (first.multiplier != Multiplier.single) ...[
                    el('span', cls: 'grid-gap'),
                    el('div', cls: 'same-number', children: [
                      el('p', cls: 'label grid-head', text: tr('Same number')),
                      outcome(DartThrow(Multiplier.single, first.number)),
                    ]),
                    el('span', cls: 'grid-gap'),
                  ],
                ],
      ]);
      body = grid;
      asks = true;
    }
  }
  return [
    el('div', cls: 'learn-top missing-top', children: [
      _numberSpacer(),
      _numberAndDarts(ctx, session, target, 'missing'),
      if (asks) el('p', cls: 'miss-question', text: tr('What happens if you miss into a neighbouring number?')),
      body,
    ]),
  ];
}

/// Favorites: the favorite routes of the number (typed in Input, or the
/// Practice question), as the Favorites popup shows
/// them: a page for 2 darts and one for 3 (and 1 when there is one), swiped
/// left and right or chosen at the top.
List<web.HTMLElement> _favorites(ViewContext ctx, NumberParts session) {
  final target = session.shownTarget;
  final number = el('div', cls: 'tab-number-wrap', children: [
    _numberSpacer(),
    el('p', cls: 'target tab-number', text: '$target'),
  ]);
  if (ctx.game.hasNoCheckout(target)) {
    return [number, el('p', cls: 'hint', text: tr('This number is impossible to checkout.'))];
  }
  final counts = {
    ...ctx.game.favorites.dartCountsFor(target),
    for (final darts in [2, 3])
      // Only real routes of that many darts: with three in hand, a number
      // with a two-dart checkout still plays two (no empty 3 Darts page).
      if (ctx.game.tutorial.tutor.optimalRoutes(target, darts).any((r) => r.length == darts)) darts,
  }.toList()
    ..sort();
  // The page of the darts in hand; another chosen is the darts in hand of
  // every part.
  final (names, pages) = favoritePages(ctx, target, counts,
      swipe: false, selected: session.learnDarts, onSelect: session.chooseDarts);
  return [number, names, pages];
}

/// Above the number of Learn, Miss and Favorites: Practice's line ("Finish on
/// a double or Bull."), unseen, so the number stands where Practice's does
/// and a swipe from one to the other does not move it.
web.HTMLElement _numberSpacer() =>
    el('p', cls: 'meta tab-spacer', text: tr('Finish on a double or Bull.'), attrs: {'aria-hidden': 'true'});

/// Practice: Checkout calculator without the clock. A number is dealt as the
/// calculator deals it - now and then one with no checkout, for the "No
/// checkout" button - and played the same way: the boxes, what is left, the
/// board with S, D and T, Undo. The last dart is judged at once and the answer
/// shows as on the calculator's result screen, with Replay and Next - which
/// are not there while it is played: the board has their room. No points and
/// nothing saved.
List<web.HTMLElement> _practice(ViewContext ctx, TutorialSession session) {
  final challenge = session.practice;

  void again(void Function() change) {
    change();
    ctx.keepFocus(null);
    ctx.rerender();
  }

  // At the foot of the answer: this number again from the first dart, or
  // another one.
  final actions = el('div', cls: 'practice-actions', children: [
    button(tr('Replay'), cls: 'cta secondary', focusKey: 'replay', onPressed: (_) => again(session.replay)),
    button(tr('Next'), cls: 'cta', focusKey: 'next', onPressed: (_) => again(session.newQuestion)),
  ]);

  final judged = session.result;
  if (judged != null) {
    return [
      el('div', cls: 'practice-result', children: resultView(ctx, judged, session.marks, learnMore: () {
        session.tab = TutorialTab.learn;
        ctx.keepFocus(null);
        ctx.rerender();
        slideIn(1);
      })),
      actions,
      // The links of the foot right under the answer, on the screen with it.
      buildFooter(),
    ];
  }

  final finalBox = session.thrown.length == challenge.dartsLeft - 1;
  return [
    el('p', cls: 'meta', text: tr('Finish on a double or Bull.')),
    el('p', cls: 'target', text: '${challenge.target}', attrs: {
      'aria-label': trn(challenge.dartsLeft, 'Checkout {target}, {n} dart left', 'Checkout {target}, {n} darts left',
          {'target': challenge.target}),
    }),
    // A number with two darts or three: a press on the boxes switches,
    // before the first dart. The line above them says so.
    dartsHint(show: session.canChooseDarts),
    if (session.canChooseDarts)
      button('',
          cls: 'dart-count-toggle',
          focusKey: 'practice-darts',
          ariaLabel: tr('Play {target} with {n} darts',
              {'target': challenge.target, 'n': challenge.dartsLeft == 3 ? 2 : 3}),
          onPressed: (kb) {
            session.chooseOtherDarts();
            ctx.keepFocus(kb ? 'practice-darts' : null);
            ctx.rerender();
          })
        ..appendChild(tileRow(session.thrown,
            slots: Visit.darts, used: challenge.layout.used, activeIndex: session.thrown.length, showDarts: true))
    else
      tileRow(session.thrown,
          slots: Visit.darts, used: challenge.layout.used, activeIndex: session.thrown.length, showDarts: true),
    remainingLine(challenge.target, session.thrown),
    buildInputPanel(
      multiplier: finalBox ? Multiplier.double : (ctx.pickedMultiplier ?? Multiplier.single),
      finalBox: finalBox,
      canUndo: session.thrown.isNotEmpty,
      marks: markPoints(session.thrown, session.marks),
      ringButtons: true,
      showNoCheckout: true,
      onPickMultiplier: (m, kb, focusKey) {
        ctx.pickedMultiplier = m;
        ctx.keepFocus(kb ? focusKey : null);
        ctx.rerender();
      },
      onDart: (dart, point, kb) {
        // A repeat of the same dart sits beside the earlier one, as in the
        // calculator.
        final placed = markPoints(session.thrown, session.marks);
        final earlier = [
          for (var i = 0; i < session.thrown.length; i++)
            if (session.thrown[i] == dart) placed[i],
        ];
        final at = spreadMark(dart, point ?? segmentCenter(dart), earlier, ctx.random);
        session.throwPractice(dart, at);
        ctx.rerender();
      },
      onUndo: (kb) {
        ctx.keepFocus(kb ? 'undo' : null);
        session.undoPractice();
        ctx.rerender();
      },
      onNoCheckout: (kb) => again(session.pressNoCheckout),
    ),
  ];
}

/// Over the boxes of Practice and Choose: "Press the darts to choose 2 or 3
/// darts." for a number that can be played with two darts or three; for any
/// other the line keeps its room unseen, so nothing under it moves.
web.HTMLElement dartsHint({required bool show}) => el('p',
    cls: 'hint darts-hint${show ? '' : ' unseen'}',
    text: tr('Press the darts to choose 2 or 3 darts.'),
    attrs: show ? const {} : const {'aria-hidden': 'true'});

/// What to aim at, then two boards side by side: the route, and a miss into
/// the next area with what it leaves (for a pair of hits, the other hit). Each
/// board can be made a favorite. Then "Also optimal" for all of them and,
/// where a miss changes everything, why not the tempting other target.
web.HTMLElement tutorBoards(ViewContext ctx, TutorCard card) {
  final aims = card.aims;
  final route = card.route;
  final target = card.target;

  web.HTMLElement titled(String title, web.HTMLElement figure) =>
      el('div', cls: 'tutor-fig', children: [el('p', cls: 'label', text: title), figure]);

  final String aim;
  if (aims.length == 2) {
    aim = aims.contains(DartThrow.bull)
        ? tr('Aim at the bull: {a} or {b}.', {'a': aims[0].notation, 'b': aims[1].notation})
        : tr('Aim at {a} or {b}.', {'a': aims[0].notation, 'b': aims[1].notation});
  } else {
    aim = tr('Aim at {dart}.', {'dart': aims.first.notation});
  }

  final all = route == null ? const <CheckoutRoute>[] : ctx.game.tutorial.tutor.optimalRoutes(target, card.darts);
  final boards = <web.HTMLElement>[];
  if (route != null) {
    boards.add(titled(tr('Optimal route'), routeFigure(ctx, target, route)));
    if (aims.length == 2 && card.hits.length == 2) {
      final other = card.routeOf(card.hits[1]);
      if (other != null) {
        boards.add(titled(tr('Or'), routeFigure(ctx, target, other)));
      }
    } else if (card.shownMiss case final miss?) {
      final title = tr('Miss into {dart}', {'dart': miss.dart.notation});
      final missRoute = card.routeOf(miss);
      boards.add(titled(title, missRoute != null ? routeFigure(ctx, target, missRoute) : _deadEnd(card, miss)));
    }
  }

  return el('div', cls: 'tutor-card', children: [
    // The boards show where to aim; only a setup, with no board, says it.
    if (route == null) ...[
      el('p', cls: 'card-aim', text: aim),
      el('p', cls: 'card-line', text: trn(card.darts, 'No checkout with {n} dart.', 'No checkout with {n} darts.')),
      el('p', cls: 'card-line', text: tr('Aim for a good number to leave.')),
    ],
    if (boards.isNotEmpty) el('div', cls: 'result-boards tutor-boards', children: boards),
    // As on the result screen: "Also optimal" opens every optimal route, or
    // the one route there is says so.
    if (route != null)
      if (all.length > 1)
        button(tr('Also optimal'),
            cls: 'text-link extra-title tutor-all',
            focusKey: 'tutor-all',
            ariaLabel: tr('Also optimal: show every optimal way to check out {n}', {'n': target}),
            onPressed: (_) => showAllOptimal(ctx, target, all))
      else
        el('p', cls: 'hint only-one', text: tr('Only possibility')),
    if (card.whyNot case final other?) ...[
      el('p', cls: 'card-why', text: tr('Why not {dart}?', {'dart': other.notation})),
      for (final miss in card.whyNotMisses)
        el('p', cls: 'card-line', text: _outcome(card, tr('Miss into {dart}', {'dart': miss.dart.notation}), miss)),
    ],
  ]);
}

/// A miss that leaves no checkout: just that dart on its board, and why.
web.HTMLElement _deadEnd(TutorCard card, DartOutcome miss) => el('figure', cls: 'board-figure', children: [
      buildDartboard(
        linesOnly: true,
        marks: spreadMarks([miss.dart], const [], math.Random(routeSeed(miss.dart.notation))),
        label: tr('Miss into {dart}', {'dart': miss.dart.notation}),
      ),
      tileRow([miss.dart],
          slots: 1,
          small: true,
          states: const [TileState.absent],
          label: miss.dart.notation,
          lefts: [card.target - miss.dart.score]),
      el('p', cls: 'hint', text: _deadEndWhy(card, miss)),
    ]);

/// Why a miss is a dead end: a bust, nothing left to throw, or no checkout
/// with the darts after it.
String _deadEndWhy(TutorCard card, DartOutcome miss) {
  if (miss.bust) return tr('Bust');
  final after = card.darts - 1;
  if (after == 0) return tr('Left for the next visit.');
  return trn(after, 'No checkout with {n} dart.', 'No checkout with {n} darts.');
}

/// One line for what a dart leaves, each dart with what is left after it:
/// "S19 (108) --> no checkout with 2 darts".
String _outcome(TutorCard card, String what, DartOutcome outcome) {
  if (outcome.bust) return tr('{what}: bust.', {'what': what});
  if (outcome.checkedOut) return tr('{what}: checked out.', {'what': what});
  final route = outcome.route;
  if (route != null) return '$what (${outcome.left}) --> ${_chain(route, outcome.left)}';
  final after = card.darts - 1;
  if (after == 0) return tr('{what} ({left}) --> next visit', {'what': what, 'left': outcome.left});
  return trn(after, '{what} ({left}) --> no checkout with {n} dart', '{what} ({left}) --> no checkout with {n} darts',
      {'what': what, 'left': outcome.left});
}

/// [route] from [start], every dart but the last with what is left after it:
/// "T17 (16) --> D8".
String _chain(CheckoutRoute route, int start) {
  var left = start;
  final parts = <String>[];
  for (var i = 0; i < route.length; i++) {
    final dart = route.darts[i];
    left -= dart.score;
    parts.add(i < route.length - 1 ? '${dart.notation} ($left)' : dart.notation);
  }
  return parts.join(' --> ');
}
