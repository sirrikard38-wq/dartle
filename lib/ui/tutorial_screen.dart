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
import 'swipes.dart';
import 'tiles.dart';
import 'view_context.dart';

/// Checkout tutorial: Learn (type a number, choose the darts in hand, see the
/// route and a miss on two boards) and Practice (a number and darts are given
/// and played out as in Checkout calculator; then the same boards). A swipe
/// to the side goes from one to the other.
web.HTMLElement buildTutorialScreen(ViewContext ctx) {
  final session = ctx.game.tutorial;
  final tabs = TutorialTab.values;
  final index = session.tab.index;

  late final web.HTMLElement row;
  late final SwipeMark mark;

  // A press glides the fill over to the chip pressed, then the page comes in.
  void show(TutorialTab which) {
    if (which == session.tab) return;
    final step = which.index > index ? 1 : -1;
    final to = row.children.item(which.index) as web.HTMLElement?;
    animate(const Duration(milliseconds: 160), (progress) => mark.follow(to, progress), () {
      session.tab = which;
      ctx.rerender();
      slideIn(step);
    });
  }

  web.HTMLButtonElement tab(TutorialTab which, String label) => button(label,
      cls: 'chip${session.tab == which ? ' selected' : ''}',
      focusKey: 'tutorial-${which.name}',
      attrs: {'aria-pressed': '${session.tab == which}'},
      onPressed: (kb) {
        ctx.keepFocus(kb ? 'tutorial-${which.name}' : null);
        show(which);
      });

  web.HTMLElement pageOf(TutorialTab which) => el('div', cls: 'tutorial-page', children: switch (which) {
        TutorialTab.learn => _learn(ctx, session),
        TutorialTab.practice => _practice(ctx, session),
      });

  row = el('div', cls: 'chips tutorial-tabs', children: [
    tab(TutorialTab.learn, tr('Learn')),
    tab(TutorialTab.practice, tr('Practice')),
  ]);
  mark = SwipeMark(row);
  final sliding = el('div', cls: 'slide-page', children: [pageOf(session.tab)]);
  final area = el('div', cls: 'play-area swipe-area', children: [
    row,
    el('div', cls: 'slide-clip', children: [sliding]),
  ]);
  followSwipes(area, sliding, (step) => index + step >= 0 && index + step < tabs.length, (step) {
    session.tab = tabs[index + step];
    ctx.rerender();
  },
      peek: (step) => pageOf(tabs[index + step]),
      follow: (step, fraction) => mark.follow(
          index + step >= 0 && index + step < tabs.length ? row.children.item(index + step) as web.HTMLElement? : null,
          fraction));

  return el('main', cls: 'screen tutorial', children: [area]);
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

/// Practice: the number is played out as in Checkout calculator - the boxes,
/// what is left, the board with S, D and T, and Undo. Once every dart is
/// thrown (or it is checked out, or bust) the verdict and the boards show.
List<web.HTMLElement> _practice(ViewContext ctx, TutorialSession session) {
  final darts = session.practiceDarts;
  final layout = BoxLayout.defaultFor(darts);
  final done = session.practiceDone;

  final boxes = tileRow(session.thrown,
      slots: Visit.darts, used: layout.used, activeIndex: session.thrown.length, showDarts: true);

  if (!done) {
    final finalBox = session.thrown.length == darts - 1;
    return [
      el('p', cls: 'meta', text: tr('Finish on a double or Bull in the given number of darts.')),
      el('p', cls: 'target', text: '${session.practiceTarget}'),
      boxes,
      remainingLine(session.practiceTarget, session.thrown),
      buildInputPanel(
        multiplier: finalBox ? Multiplier.double : (ctx.pickedMultiplier ?? Multiplier.single),
        finalBox: finalBox,
        canUndo: session.thrown.isNotEmpty,
        marks: markPoints(session.thrown, session.marks),
        ringButtons: true,
        onPickMultiplier: (m, kb, focusKey) {
          ctx.pickedMultiplier = m;
          ctx.keepFocus(kb ? focusKey : null);
          ctx.rerender();
        },
        onDart: (dart, point, kb) {
          session.throwPractice(dart, point);
          ctx.rerender();
        },
        onUndo: (kb) {
          ctx.keepFocus(kb ? 'undo' : null);
          session.undoPractice();
          ctx.rerender();
        },
      ),
    ];
  }

  final right = session.practiceRight!;
  final left = session.practiceLeft;
  final headline = right
      ? tr('Optimal!')
      : session.practiceCheckedOut
          ? tr('Checkout!')
          : left < 0 || left == 1 || left == 0
              ? tr('Bust')
              : tr('Out of darts');
  return [
    el('p', cls: 'headline ${session.practiceCheckedOut ? 'good' : 'bad'}',
        text: '${session.practiceCheckedOut ? '✓' : '✗'} $headline', attrs: {'role': 'status'}),
    el('p', cls: 'target small', text: '${session.practiceTarget}'),
    boxes,
    tutorBoards(ctx, session.practiceCard),
    button(tr('Next question'),
        cls: 'cta',
        focusKey: 'next-question',
        onPressed: (_) {
          session.newQuestion();
          ctx.keepFocus(null);
          ctx.rerender();
        }),
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
    el('p', cls: 'card-aim', text: aim),
    if (route == null) ...[
      el('p', cls: 'card-line', text: trn(card.darts, 'No checkout with {n} dart.', 'No checkout with {n} darts.')),
      el('p', cls: 'card-line', text: tr('Aim for a good number to leave.')),
    ],
    if (boards.isNotEmpty) el('div', cls: 'result-boards tutor-boards', children: boards),
    if (card.alsoGood.isNotEmpty)
      el('p', cls: 'card-line',
          text: tr('Almost as good: {darts}.', {'darts': card.alsoGood.map((d) => d.notation).join(', ')})),
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
