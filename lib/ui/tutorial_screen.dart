import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'favorites_ui.dart';
import 'game_screen.dart';
import 'keyboard.dart';
import 'result_screen.dart';
import 'swipes.dart';
import 'tiles.dart';
import 'view_context.dart';

/// Checkout tutorial: Input (type a number), Practice (play it out as in
/// Checkout calculator), Learn (the optimal routes and their misses into
/// single), Favorites (its favorite routes) and Missing (a single missed into
/// its neighbours), all for one number. A
/// swipe to the side goes from one to the next.
web.HTMLElement buildTutorialScreen(ViewContext ctx) {
  final session = ctx.game.tutorial;
  // In the order of [TutorialTab]: Input, Practice, Learn, Favorites, Missing.
  final area = swipeTabs(
    ctx,
    name: 'tutorial',
    labels: [
      for (final which in TutorialTab.values)
        switch (which) {
          TutorialTab.input => tr('Input'),
          TutorialTab.practice => tr('Practice'),
          TutorialTab.learn => tr('Learn'),
          TutorialTab.favorites => tr('Favorites'),
          TutorialTab.missing => tr('Missing'),
        },
    ],
    index: session.tab.index,
    choose: (i) => session.tab = TutorialTab.values[i],
    pageOf: (i) => el('div', cls: 'tutorial-page tab-${TutorialTab.values[i].name}', children: switch (TutorialTab.values[i]) {
      TutorialTab.input => _input(ctx, session),
      TutorialTab.learn => _learn(ctx, session),
      TutorialTab.practice => _practice(ctx, session),
      TutorialTab.favorites => _favorites(ctx, session),
      TutorialTab.missing => _missing(ctx, session),
    }),
  )..classList.add('play-area');
  return el('main', cls: 'screen tutorial', children: [area]);
}

/// Chips over pages side by side ([labels], the page [index] showing): a press
/// on a chip glides its white fill over and brings the page in, a swipe moves
/// the page with the finger and the fill with it, as in Virulja's food
/// categories. [choose] takes the page to show next; [pageOf] draws a page.
/// The tutorial (Practice, Learn) and Checkout practice and input (Play,
/// Learn) have them.
web.HTMLElement swipeTabs(
  ViewContext ctx, {
  required String name,
  required List<String> labels,
  required int index,
  required void Function(int index) choose,
  required web.HTMLElement Function(int index) pageOf,
}) {
  late final web.HTMLElement row;
  late final SwipeMark mark;
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
          attrs: {'aria-pressed': '${i == index}'},
          onPressed: (kb) {
            ctx.keepFocus(kb ? '$name-tab-$i' : null);
            show(i);
          }),
  ]);
  mark = SwipeMark(row);
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
          mark.follow(exists(index + step) ? row.children.item(index + step) as web.HTMLElement? : null, fraction));
  return area;
}

/// Input: the number, what it says, and the keypad. A number from 2 to 170 is
/// at once the one Practice, Learn and Favorites show. Three seconds after the
/// last key (or after Next checkout) the next digit starts a new number.
List<web.HTMLElement> _input(ViewContext ctx, TutorialSession session) {
  final digits = session.typedDigits;

  web.HTMLButtonElement digit(int n) => button('$n',
      cls: 'key pad-key',
      focusKey: 'input-digit-$n',
      onPressed: (kb) {
        session.typeDigit(n);
        ctx.keepFocus(kb ? 'input-digit-$n' : null);
        ctx.rerender();
      });

  final undo = button(tr('UNDO'),
      cls: 'key pad-key pad-undo',
      focusKey: 'input-undo',
      ariaLabel: tr('Delete the last digit'),
      disabled: digits.isEmpty,
      onPressed: (kb) {
        session.deleteDigit();
        ctx.keepFocus(kb ? 'input-undo' : null);
        ctx.rerender();
      });
  undo.insertBefore(undoIcon(), undo.firstChild);

  // What the number says, as Checkout input does: a number outside 2 to 170,
  // or one that cannot be checked out at all.
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
      el('p', cls: 'target number-display${digits.isEmpty ? ' empty' : ''}',
          text: digits.isEmpty ? '–' : digits,
          attrs: {'aria-label': digits.isEmpty ? tr('No number yet') : tr('Number {n}', {'n': digits})}),
      el('p', cls: 'hint', text: line, attrs: {'role': 'status'}),
    ]),
    el('div', cls: 'keypad', attrs: {'aria-label': tr('Number pad')}, children: [
      digit(1), digit(2), digit(3),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      undo, digit(0), el('span', cls: 'pad-spacer'),
    ]),
  ];
}

/// The darts in hand, 1, 2 or 3, for Learn and Missing (one choice for both).
web.HTMLElement _dartsChips(ViewContext ctx, TutorialSession session, String name) {
  web.HTMLButtonElement darts(int n) => button('$n',
      cls: 'chip${session.learnDarts == n ? ' selected' : ''}',
      focusKey: '$name-darts-$n',
      ariaLabel: trn(n, '{n} dart in hand', '{n} darts in hand'),
      attrs: {'aria-pressed': '${session.learnDarts == n}'},
      onPressed: (kb) {
        ctx.keepFocus(kb ? '$name-darts-$n' : null);
        session.learnDarts = n;
        ctx.rerender();
      });
  return el('div', cls: 'chips', children: [darts(1), darts(2), darts(3)]);
}

/// A number that cannot be checked out at all says so, with one of the
/// insults, as Checkout input does.
web.HTMLElement _impossible(int target) => el('div', cls: 'tutor-card', children: [
      el('p', cls: 'impossible-title', text: tr('This number is impossible to checkout.'), attrs: {'role': 'status'}),
      el('p', cls: 'insult', text: Phrases.randomInsult(math.Random(target))),
    ]);

/// Learn: the number (typed in Input, or the Practice question), the darts in
/// hand, what the Practice checkout was worth, then the optimal routes, each
/// beside what its first dart leaves when it misses into single.
List<web.HTMLElement> _learn(ViewContext ctx, TutorialSession session) {
  final target = session.shownTarget;
  final card = session.learnCard;
  final review = session.learnDarts == session.practiceDarts ? session.practiceReview : null;

  return [
    el('div', cls: 'learn-top', children: [
      el('p', cls: 'target number-display', text: '$target', attrs: {'aria-label': tr('Number {n}', {'n': target})}),
      el('p', cls: 'label', text: tr('Darts in hand')),
      _dartsChips(ctx, session, 'learn'),
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
web.HTMLElement _reviewBox(ViewContext ctx, TutorialSession session, PracticeReview review) {
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
    el('p', cls: 'label', text: tr('Your darts in Practice')),
    if (darts.isNotEmpty)
      el('figure', cls: 'board-figure', children: [
        buildDartboard(
          linesOnly: true,
          marks: spreadMarks(darts, session.marks, math.Random(routeSeed(review.route.notation))),
          label: tr('Your darts: {route}', {'route': review.route.notation}),
        ),
        tileRow(darts, slots: darts.length, small: true, states: List.filled(darts.length, state), label: review.route.notation),
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

/// The optimal routes Learn shows on boards: the table's route, the other hit
/// of a pair (48: S16 or S8), then up to two more (one with a better double
/// first, as the result screen picks them).
List<CheckoutRoute> _learnRouteList(TutorCard card, List<CheckoutRoute> all) {
  final shown = <CheckoutRoute>[card.route!];
  if (card.aims.length == 2 && card.hits.length == 2) {
    final other = card.routeOf(card.hits[1]);
    if (other != null && !shown.any(other.isEquivalentTo)) shown.add(other);
  }
  shown.addAll(BetterDoubles.extras(all, exclude: shown).take(2));
  return shown;
}

/// Learn's routes: a column "Route" and a column "Miss into single" - each
/// optimal route beside what its first dart leaves when it misses into single
/// (a single first has none). "Also optimal" only when some optimal routes are
/// not on the boards; then why not the tempting other target.
web.HTMLElement _learnRoutes(ViewContext ctx, TutorCard card) {
  final target = card.target;
  final all = ctx.game.tutorial.tutor.optimalRoutes(target, card.darts);
  final shown = _learnRouteList(card, all);
  final everyOne = all.every((r) => shown.any(r.isEquivalentTo));
  return el('div', cls: 'tutor-card', children: [
    el('div', cls: 'route-grid two', children: [
      el('p', cls: 'label grid-head', text: tr('Route')),
      el('p', cls: 'label grid-head', text: tr('Miss into single')),
      for (final route in shown) ...[
        routeFigure(ctx, target, route),
        _outcomeCell(ctx, card, ctx.game.tutorial.tutor.firstMiss(target, card.darts, route)),
      ],
    ]),
    if (all.length == 1)
      el('p', cls: 'hint only-one', text: tr('Only possibility'))
    else if (!everyOne)
      button(tr('Also optimal'),
          cls: 'text-link extra-title tutor-all',
          focusKey: 'tutor-all',
          ariaLabel: tr('Also optimal: show every optimal way to check out {n}', {'n': target}),
          onPressed: (_) => showAllOptimal(ctx, target, all)),
    if (card.whyNot case final other?) ...[
      el('p', cls: 'card-why', text: tr('Why not {dart}?', {'dart': other.notation})),
      for (final miss in card.whyNotMisses)
        el('p', cls: 'card-line', text: _outcome(card, tr('Miss into {dart}', {'dart': miss.dart.notation}), miss)),
    ],
  ]);
}

/// A board for what a missed dart leaves: the dart and the route after it
/// (any checkout there is, optimal or not), and the line under it. Where
/// there is no such miss (a single first), where its misses are.
web.HTMLElement _outcomeCell(ViewContext ctx, TutorCard card, DartOutcome? miss) {
  if (miss == null) return el('p', cls: 'grid-none', text: tr('A single: see Missing'));
  final route = card.routeOf(miss);
  if (route == null) return _deadEnd(card, miss);
  return routeFigure(ctx, card.target, route)..append(el('p', cls: 'hint', text: _outcome(card, miss.dart.notation, miss)));
}

/// Missing: every optimal route that starts with a single, in the middle,
/// and the neighbours of that single to its left and right - what a miss into
/// each leaves, with any checkout there is. The darts in hand as in Learn.
List<web.HTMLElement> _missing(ViewContext ctx, TutorialSession session) {
  final target = session.shownTarget;
  final card = session.learnCard;
  final tutor = session.tutor;
  web.HTMLElement body;
  if (ctx.game.hasNoCheckout(target)) {
    body = _impossible(target);
  } else if (card == null || card.route == null) {
    body = el('p', cls: 'hint', text: trn(session.learnDarts, 'No checkout with {n} dart.', 'No checkout with {n} darts.'));
  } else {
    final singles = [
      for (final route in tutor.optimalRoutes(target, card.darts))
        if (CheckoutTutor.sideNeighbours(route.darts.first) != null && route.length > 1) route,
    ];
    body = singles.isEmpty
        ? el('p', cls: 'hint', text: tr('No optimal route starts with a single, so there is no neighbour to miss into.'))
        : el('div', cls: 'route-grid three', children: [
            el('p', cls: 'label grid-head', text: tr('Left neighbour')),
            el('p', cls: 'label grid-head', text: tr('Route')),
            el('p', cls: 'label grid-head', text: tr('Right neighbour')),
            for (final route in singles)
              if (CheckoutTutor.sideNeighbours(route.darts.first) case (final left, final right)) ...[
                _outcomeCell(ctx, card, tutor.outcome(target, card.darts, left)),
                routeFigure(ctx, target, route),
                _outcomeCell(ctx, card, tutor.outcome(target, card.darts, right)),
              ],
          ]);
  }
  return [
    el('div', cls: 'learn-top missing-top', children: [
      el('p', cls: 'target number-display', text: '$target', attrs: {'aria-label': tr('Number {n}', {'n': target})}),
      el('p', cls: 'label', text: tr('Darts in hand')),
      _dartsChips(ctx, session, 'missing'),
      body,
    ]),
  ];
}

/// Favorites: the favorite routes of the number (typed in Input, or the
/// Practice question), as the Favorites popup shows
/// them: a page for 2 darts and one for 3 (and 1 when there is one), swiped
/// left and right or chosen at the top.
List<web.HTMLElement> _favorites(ViewContext ctx, TutorialSession session) {
  final target = session.shownTarget;
  final number = el('p', cls: 'target', text: '$target');
  if (ctx.game.hasNoCheckout(target)) {
    return [number, el('p', cls: 'hint', text: tr('This number is impossible to checkout.'))];
  }
  final counts = {
    ...ctx.game.favorites.dartCountsFor(target),
    for (final darts in [2, 3])
      // Only real routes of that many darts: with three in hand, a number
      // with a two-dart checkout still plays two (no empty 3 Darts page).
      if (session.tutor.optimalRoutes(target, darts).any((r) => r.length == darts)) darts,
  }.toList()
    ..sort();
  final (names, pages) = favoritePages(ctx, target, counts, swipe: false);
  return [number, names, pages];
}

/// Practice: Checkout calculator without the clock. A number is dealt as the
/// calculator deals it - now and then one with no checkout, for the "No
/// checkout" button - and played the same way: the boxes, what is left, the
/// board with S, D and T, Undo. The last dart is judged at once and the answer
/// shows as on the calculator's result screen, with Next checkout and Replay
/// checkout. No points and nothing saved.
List<web.HTMLElement> _practice(ViewContext ctx, TutorialSession session) {
  final challenge = session.practice;

  void again(void Function() change) {
    change();
    ctx.keepFocus(null);
    ctx.rerender();
  }

  // Always at the foot, while playing and after: another number, or this one
  // again from the first dart.
  final actions = el('div', cls: 'practice-actions', children: [
    button(tr('Next checkout'), cls: 'cta', focusKey: 'next', onPressed: (_) => again(session.newQuestion)),
    button(tr('Replay checkout'), cls: 'cta secondary', focusKey: 'replay', onPressed: (_) => again(session.replay)),
  ]);

  final judged = session.result;
  if (judged != null) {
    return [
      el('div', cls: 'practice-result', children: resultView(ctx, judged, session.marks, listExtras: false)),
      actions,
    ];
  }

  final finalBox = session.thrown.length == challenge.dartsLeft - 1;
  return [
    el('p', cls: 'meta', text: tr('Finish on a double or Bull.')),
    el('p', cls: 'target', text: '${challenge.target}', attrs: {
      'aria-label': trn(challenge.dartsLeft, 'Checkout {target}, {n} dart left', 'Checkout {target}, {n} darts left',
          {'target': challenge.target}),
    }),
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
    actions,
  ];
}

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
    boards.add(titled(tr('Route'), routeFigure(ctx, target, route)));
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
      tileRow([miss.dart], slots: 1, small: true, states: const [TileState.absent], label: miss.dart.notation),
      el('p', cls: 'hint', text: _outcome(card, miss.dart.notation, miss)),
    ]);

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
