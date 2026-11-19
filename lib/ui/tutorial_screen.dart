import 'dart:async';
import 'dart:js_interop';
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

/// Checkout tutorial: Learn (type a number, choose the darts in hand, see the
/// route and a miss on two boards) and Practice (a number and darts are given
/// and played out as in Checkout calculator; then the same boards). A swipe
/// to the side goes from one to the other.
web.HTMLElement buildTutorialScreen(ViewContext ctx) {
  final session = ctx.game.tutorial;
  // In the order of [TutorialTab]: Practice, Learn, Favorites.
  final area = swipeTabs(
    ctx,
    name: 'tutorial',
    labels: [
      for (final which in TutorialTab.values)
        switch (which) {
          TutorialTab.practice => tr('Practice'),
          TutorialTab.learn => tr('Learn'),
          TutorialTab.favorites => tr('Favorites'),
        },
    ],
    index: session.tab.index,
    choose: (i) => session.tab = TutorialTab.values[i],
    pageOf: (i) => el('div', cls: 'tutorial-page', children: switch (TutorialTab.values[i]) {
      TutorialTab.learn => _learn(ctx, session),
      TutorialTab.practice => _practice(ctx, session),
      TutorialTab.favorites => _favorites(ctx, session),
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

/// The card waits this long after the last digit, so it does not jump about
/// while a number is typed.
const Duration _cardDelay = Duration(seconds: 1);
Timer? _cardTimer;

/// Redraws the screen with [change], keeping the keypad where it is on the
/// screen: what is above it moves instead (the page scrolls by as much as the
/// keypad would have moved).
void _keepKeypadInPlace(ViewContext ctx, void Function() change) {
  double? keypadTop() => web.document.querySelector('.screen.tutorial .keypad')?.getBoundingClientRect().top;
  final before = keypadTop();
  change();
  ctx.rerender();
  final after = keypadTop();
  if (before != null && after != null && after != before) {
    web.window.scrollBy((0).toJS, after - before);
  }
}

/// Learn: the number typed, the darts in hand, the boards and the keypad. The
/// keypad stays put: the boards show a second after the last digit, and what
/// they add goes above the keypad.
List<web.HTMLElement> _learn(ViewContext ctx, TutorialSession session) {
  final digits = session.learnDigits;
  final card = session.learnCard;

  void typed() {
    _cardTimer?.cancel();
    _cardTimer = Timer(_cardDelay, () {
      if (session.shownDigits == session.learnDigits) return;
      _keepKeypadInPlace(ctx, session.showTypedNumber);
    });
  }

  web.HTMLButtonElement darts(int n) => button('$n',
      cls: 'chip${session.learnDarts == n ? ' selected' : ''}',
      focusKey: 'learn-darts-$n',
      ariaLabel: trn(n, '{n} dart in hand', '{n} darts in hand'),
      attrs: {'aria-pressed': '${session.learnDarts == n}'},
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'learn-darts-$n' : null);
        _keepKeypadInPlace(ctx, () => session.learnDarts = n);
      });

  web.HTMLButtonElement digit(int n) => button('$n',
      cls: 'key pad-key',
      focusKey: 'learn-digit-$n',
      onPressed: (kb) {
        session.typeDigit(n);
        ctx.keepFocus(kb ? 'learn-digit-$n' : null);
        ctx.rerender();
        typed();
      });

  final undo = button(tr('UNDO'),
      cls: 'key pad-key pad-undo',
      focusKey: 'learn-undo',
      ariaLabel: tr('Delete the last digit'),
      disabled: digits.isEmpty,
      onPressed: (kb) {
        session.deleteDigit();
        ctx.keepFocus(kb ? 'learn-undo' : null);
        ctx.rerender();
        typed();
      });
  undo.insertBefore(undoIcon(), undo.firstChild);

  // What the number shown says, as Checkout input does: a number outside 2 to
  // 170, or one that cannot be checked out at all (with one of the insults).
  final shown = int.tryParse(session.shownDigits);
  final web.HTMLElement below;
  if (shown == null) {
    below = el('p', cls: 'hint', text: tr('Type a number from 2 to 170.'));
  } else if (shown < CheckoutEngine.minCheckout || shown > CheckoutEngine.maxCheckout) {
    below = el('p', cls: 'hint', text: tr('A number from 2 to 170.'));
  } else if (ctx.game.hasNoCheckout(shown)) {
    below = el('div', cls: 'tutor-card', children: [
      el('p', cls: 'impossible-title', text: tr('This number is impossible to checkout.'), attrs: {'role': 'status'}),
      el('p', cls: 'insult', text: Phrases.randomInsult(math.Random(shown))),
    ]);
  } else {
    below = card == null ? el('span') : tutorBoards(ctx, card);
  }

  return [
    // Everything but the keypad: it scrolls on its own when it is long, so the
    // keypad never moves.
    el('div', cls: 'learn-top', children: [
      el('p', cls: 'target number-display${digits.isEmpty ? ' empty' : ''}',
          text: digits.isEmpty ? '–' : digits,
          attrs: {'aria-label': digits.isEmpty ? tr('No number yet') : tr('Number {n}', {'n': digits})}),
      el('p', cls: 'label', text: tr('Darts in hand')),
      el('div', cls: 'chips', children: [darts(1), darts(2), darts(3)]),
      below,
    ]),
    el('div', cls: 'keypad', attrs: {'aria-label': tr('Number pad')}, children: [
      digit(1), digit(2), digit(3),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      undo, digit(0), el('span', cls: 'pad-spacer'),
    ]),
  ];
}

/// Favorites: the favorite routes of the number in Learn (the Practice
/// question, unless another number was typed), as the Favorites popup shows
/// them: a page for 2 darts and one for 3 (and 1 when there is one), swiped
/// left and right or chosen at the top.
List<web.HTMLElement> _favorites(ViewContext ctx, TutorialSession session) {
  final target = session.shownTarget;
  if (target == null) {
    return [el('p', cls: 'hint', text: tr('Type a number in Learn to see its favorites.'))];
  }
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
/// board can be made a favorite. Under them the targets almost as good and,
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

  final boards = <web.HTMLElement>[];
  if (route != null) {
    boards.add(titled(tr('Route'), routeFigure(ctx, target, route)));
    if (aims.length == 2 && card.hits.length == 2) {
      final other = card.routeOf(card.hits[1]);
      if (other != null) boards.add(titled(tr('Or'), routeFigure(ctx, target, other)));
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
      if (ctx.game.tutorial.tutor.optimalRoutes(target, card.darts) case final all when all.length > 1)
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
