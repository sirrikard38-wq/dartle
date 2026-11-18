import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'keyboard.dart';
import 'view_context.dart';

/// Checkout tutorial: Learn (type a number, choose the darts in hand, read the
/// card) and Practice (a number and darts are given; press where you would aim
/// and the same card says if it was right and why).
web.HTMLElement buildTutorialScreen(ViewContext ctx) {
  final session = ctx.game.tutorial;

  web.HTMLButtonElement tab(TutorialTab which, String label) => button(label,
      cls: 'chip${session.tab == which ? ' selected' : ''}',
      focusKey: 'tutorial-${which.name}',
      attrs: {'aria-pressed': '${session.tab == which}'},
      onPressed: (kb) {
        session.tab = which;
        ctx.keepFocus(kb ? 'tutorial-${which.name}' : null);
        ctx.rerender();
      });

  return el('main', cls: 'screen tutorial', children: [
    el('div', cls: 'play-area', children: [
      el('div', cls: 'chips tutorial-tabs', children: [
        tab(TutorialTab.learn, tr('Learn')),
        tab(TutorialTab.practice, tr('Practice')),
      ]),
      ...switch (session.tab) {
        TutorialTab.learn => _learn(ctx, session),
        TutorialTab.practice => _practice(ctx, session),
      },
    ]),
  ]);
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

/// Learn: the number typed, the darts in hand, the card and the keypad. The
/// keypad stays put: the card shows a second after the last digit, and what
/// it adds goes above the keypad.
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

  return [
    el('p', cls: 'target number-display${digits.isEmpty ? ' empty' : ''}',
        text: digits.isEmpty ? '–' : digits,
        attrs: {'aria-label': digits.isEmpty ? tr('No number yet') : tr('Number {n}', {'n': digits})}),
    el('p', cls: 'label', text: tr('Darts in hand')),
    el('div', cls: 'chips', children: [darts(1), darts(2), darts(3)]),
    if (card != null)
      tutorCard(card)
    else
      el('p', cls: 'hint', text: tr('Type a number from 2 to 170.')),
    el('div', cls: 'keypad', attrs: {'aria-label': tr('Number pad')}, children: [
      digit(1), digit(2), digit(3),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      undo, digit(0), el('span', cls: 'pad-spacer'),
    ]),
  ];
}

/// Practice: the question, the board to answer on, then the verdict and card.
List<web.HTMLElement> _practice(ViewContext ctx, TutorialSession session) {
  final answer = session.answer;
  final right = session.answerRight;
  final card = session.practiceCard;
  return [
    el('p', cls: 'target', text: '${session.practiceTarget}'),
    el('p', cls: 'hint', text: trn(session.practiceDarts, '{n} dart in hand', '{n} darts in hand')),
    if (answer == null) ...[
      el('p', cls: 'hint', text: tr('Press where you would aim.')),
      el('div', cls: 'board-wrap tutorial-board', children: [
        buildDartboard(
          byArea: true,
          onDart: (dart, point, kb) {
            session.pressAnswer(dart);
            ctx.rerender();
          },
          label: tr('Dartboard. Press the area you want to throw.'),
        ),
      ]),
    ] else ...[
      el('p', cls: 'headline ${right! ? 'good' : 'bad'}',
          text: right
              ? '✓ ${tr('Right: {dart}', {'dart': answer.notation})}'
              : '✗ ${tr('Not quite: {dart}', {'dart': answer.notation})}',
          attrs: {'role': 'status'}),
      tutorCard(card),
      button(tr('Next question'),
          cls: 'cta',
          focusKey: 'next-question',
          onPressed: (_) {
            session.newQuestion();
            ctx.keepFocus(null);
            ctx.rerender();
          }),
    ],
  ];
}

/// The card: what to aim at, the route, what a hit and a miss leave, and why
/// not the most tempting other target. Two or three short lines each.
web.HTMLElement tutorCard(TutorCard card) {
  final aims = card.aims;
  final route = card.route;
  // A hit that just goes on along the route says nothing the route does not.
  bool sameAsRoute(DartOutcome hit) =>
      aims.length == 1 &&
      route != null &&
      (hit.checkedOut ? route.length == 1 : hit.route?.notation == CheckoutRoute(route.darts.skip(1)).notation);
  final lines = <web.HTMLElement>[
    el('p', cls: 'card-aim',
        text: aims.length == 2
            ? tr('Aim between {a} and {b}.', {'a': aims[0].notation, 'b': aims[1].notation})
            : tr('Aim at {dart}.', {'dart': aims.first.notation})),
    if (route != null)
      el('p', cls: 'card-line', text: tr('Route: {route}', {'route': _chain(route, card.target)}))
    else
      el('p', cls: 'card-line',
          text: trn(card.darts, 'No checkout with {n} dart: aim for a good number to leave.',
              'No checkout with {n} darts: aim for a good number to leave.')),
    if (card.alsoGood.isNotEmpty)
      el('p', cls: 'card-line',
          text: tr('Almost as good: {darts}.', {'darts': card.alsoGood.map((d) => d.notation).join(', ')})),
    for (final hit in card.hits)
      if (!sameAsRoute(hit))
        el('p', cls: 'card-line', text: _outcome(card, tr('Hit {dart}', {'dart': hit.dart.notation}), hit)),
    for (final miss in card.misses)
      el('p', cls: 'card-line', text: _outcome(card, tr('Miss into {dart}', {'dart': miss.dart.notation}), miss)),
    if (card.whyNot case final other?) ...[
      el('p', cls: 'card-why', text: tr('Why not {dart}?', {'dart': other.notation})),
      if (card.whyNotHit case final hit?)
        el('p', cls: 'card-line', text: _outcome(card, tr('Hit {dart}', {'dart': hit.dart.notation}), hit)),
      for (final miss in card.whyNotMisses)
        el('p', cls: 'card-line', text: _outcome(card, tr('Miss into {dart}', {'dart': miss.dart.notation}), miss)),
    ],
  ];
  return el('div', cls: 'tutor-card', children: lines);
}

/// One line for what a dart leaves, each dart with what is left after it:
/// "Hit T20 (67) --> T17 (16) --> D8".
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
