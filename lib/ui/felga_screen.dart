import 'dart:async';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'view_context.dart';

/// Where Felgalizacija is kept (this device only).
const String _key = 'dartle.felga.v1';

FelgaLedger? _ledger;

/// The name box is open (after +, until X).
bool _adding = false;

/// + or X was just pressed: the icon turns once, not on every redraw.
bool _justToggled = false;

FelgaLedger get _book {
  return _ledger ??= FelgaLedger.fromJson(() {
    try {
      return web.window.localStorage.getItem(_key);
    } on Object {
      return null;
    }
  }());
}

void _save(FelgaLedger ledger) {
  try {
    web.window.localStorage.setItem(_key, ledger.toJson());
  } on Object {
    // Kept for this visit only.
  }
}

/// Felgalizacija: the club's money at the top; the names by felgas with their
/// fines (a felga is 0,50 €); under a long arrow the names, each with -1 and
/// +1, and under them a + that opens a box for a new name (confirmed with the
/// tick; the + turns into an X, which closes it); under another arrow what
/// each paid (a box adds to it), still to pay and paid; and at the foot the
/// club money (added above zero, spent below).
web.HTMLElement buildFelgaScreen(ViewContext ctx) {
  final ledger = _book;
  void changed() {
    _save(ledger);
    ctx.rerender();
  }

  final total = el('strong', text: formatEuro(ledger.totalCents));
  final current = el('strong', text: formatEuro(ledger.currentCents));

  // + in the top corner; open, it is an X (turned a quarter round).
  final turn = _justToggled;
  _justToggled = false;
  final toggle = button('',
      cls: 'felga-toggle${_adding ? ' open' : ''}${turn ? ' turning' : ''}',
      focusKey: 'felga-toggle',
      ariaLabel: _adding ? tr('Stop adding names') : tr('Add a name'),
      onPressed: (kb) {
        _adding = !_adding;
        _justToggled = true;
        ctx.keepFocus(_adding ? 'felga-name' : (kb ? 'felga-toggle' : null));
        ctx.rerender();
      })
    ..append(svg('svg', cls: 'felga-plus', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
      svg('path', attrs: {'d': 'M12 3 V21 M3 12 H21'}),
    ]));

  // The box for a new name: 10 letters wide, wider as a longer name is typed,
  // in the middle of the screen, its tick to the right of it; Enter or the
  // tick adds the name and a new empty box is ready under it.
  web.HTMLElement? newName;
  if (_adding) {
    final input = el('input', cls: 'felga-input', attrs: {
      'type': 'text',
      'maxlength': '40',
      'autocomplete': 'off',
      'enterkeyhint': 'done',
      'aria-label': tr('Name'),
      'data-focus': 'felga-name',
    }) as web.HTMLInputElement;
    void fit() => input.style.width = '${math.max(10, input.value.length + 1)}ch';
    fit();
    void confirm() {
      ctx.keepFocus('felga-name');
      if (input.value.trim().isEmpty) {
        input.focus();
        return;
      }
      ledger.add(input.value);
      changed();
    }

    input.onInput.listen((_) => fit());
    input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        confirm();
      }
    });
    final tick = button('', cls: 'felga-tick', ariaLabel: tr('Confirm the name'), onPressed: (_) => confirm())
      ..append(svg('svg', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
        svg('path', attrs: {'d': 'M4 12.5 L9.5 18 L20 6'}),
      ]));
    newName = el('div', cls: 'felga-new', children: [el('span'), input, tick]);
  }

  web.HTMLElement step(FelgaMember member, int by) => button(by > 0 ? '+1' : '-1',
      cls: 'felga-step',
      ariaLabel: by > 0
          ? tr('{name}: one point more', {'name': member.name})
          : tr('{name}: one point less', {'name': member.name}),
      onPressed: (_) {
        member.points += by;
        changed();
      });

  // A money box: four digits wide (wider for a longer number), the grey €
  // after it, written with a dot for thousands and a comma for decimals while
  // it is typed. The cursor always goes to the end; the − before it turns the
  // number below zero and back (a phone's number keys have no minus).
  web.HTMLInputElement moneyBox(String label, String value) {
    final input = el('input', cls: 'money-input', attrs: {
      'type': 'text',
      'inputmode': 'decimal',
      'autocomplete': 'off',
      'aria-label': label,
    }) as web.HTMLInputElement;
    input.value = value;
    void fit() => input.style.width = '${math.max(4, input.value.length)}ch';
    void toEnd() => Timer.run(() {
          final end = input.value.length;
          input.setSelectionRange(end, end);
        });
    fit();
    input.onInput.listen((_) {
      input.value = formatTypedEuro(input.value);
      fit();
    });
    input.onFocus.listen((_) => toEnd());
    input.onClick.listen((_) => toEnd());
    input.onKeyDown.listen((event) {
      if (event.key == 'Enter') input.blur();
    });
    return input;
  }

  web.HTMLElement money(web.HTMLInputElement input) {
    final sign = button('−', cls: 'money-sign', ariaLabel: tr('Change the sign'), onPressed: (_) {
      input.value = formatTypedEuro(input.value.startsWith('-') ? input.value.substring(1) : '-${input.value}');
      input.dispatchEvent(web.Event('input'));
      input.focus();
    });
    // Pressed, it leaves the box being typed in (nothing is confirmed yet).
    sign.onMouseDown.listen((event) => event.preventDefault());
    return el('label', cls: 'money', children: [sign, input, el('span', cls: 'euro', text: '€')]);
  }

  // What each paid, whoever owes the most first: a number in the box is added
  // to Paid (or taken off, below zero) when it is confirmed, and the box is
  // empty again.
  final paidRows = <web.HTMLElement>[];
  for (final member in ledger.byDebt) {
    final box = moneyBox(tr('{name} paid', {'name': member.name}), '');
    box.onChange.listen((_) {
      final cents = parseEuroCents(box.value);
      if (cents == null) return;
      member.paidCents += cents;
      changed();
    });
    paidRows.addAll([
      el('span', cls: 'felga-cell name', text: member.name),
      money(box),
      el('span', cls: 'felga-cell num', text: formatEuro(FelgaLedger.debtCents(member))),
      el('span', cls: 'felga-cell num', text: formatEuro(member.paidCents)),
    ]);
  }

  // Club money: an amount above zero is added to the club, below zero spent
  // from it; each is added up when it is confirmed, and the box is empty again.
  final club = moneyBox(tr('Club money'), '');
  club.onChange.listen((_) {
    final cents = parseEuroCents(club.value);
    if (cents == null) return;
    ledger.clubCents += cents;
    changed();
  });

  return el('main', cls: 'screen felga', children: [
    el('div', cls: 'felga-money', children: [
      el('p', children: [textNode('${tr('Total money in the club')} '), total]),
      el('p', children: [textNode('${tr('Money in the club now')} '), current]),
    ]),
    // Right under the money: the felgas and the fines, most first.
    if (ledger.members.isNotEmpty) ...[
      el('div', cls: 'felga-grid owes', children: [
        el('span'),
        el('span', cls: 'felga-head', text: 'Felga'),
        el('span', cls: 'felga-head', text: 'Kazna'),
        for (final member in ledger.byPoints) ...[
          el('span', cls: 'felga-cell name', text: member.name),
          el('span', cls: 'felga-cell num', text: '${member.points}'),
          el('span', cls: 'felga-cell num', text: formatEuro(FelgaLedger.owedCents(member))),
        ],
      ]),
      _arrow(),
    ],
    // The names, with -1 and +1 one under the other (as wide as the longest
    // name); under them the box for a new one, and the + (X while it is open).
    if (ledger.members.isNotEmpty)
      el('div', cls: 'felga-names', children: [
        for (final member in ledger.members) ...[
          step(member, -1),
          el('span', cls: 'felga-name', text: member.name),
          step(member, 1),
        ],
      ]),
    if (newName != null) newName,
    toggle,
    if (ledger.members.isNotEmpty) ...[
      _arrow(),
      el('div', cls: 'felga-grid paid', children: [
        el('span'),
        el('span'),
        el('span', cls: 'felga-head', text: tr('Owed')),
        el('span', cls: 'felga-head', text: tr('Paid')),
        ...paidRows,
      ]),
    ],
    el('div', cls: 'felga-spent', children: [
      el('span', text: tr('Club money')),
      money(club),
      el('span', cls: 'felga-club-sum', text: formatEuro(ledger.clubCents)),
    ]),
  ]);
}

/// A very long grey arrow across the screen (5 mm from each edge): the
/// feathers on the left, the point on the right. It parts the sections.
web.HTMLElement _arrow() => el('div', cls: 'felga-arrow', attrs: {'aria-hidden': 'true'}, children: [
      svg('svg', cls: 'arrow-feathers', attrs: {'viewBox': '0 0 30 20'}, children: [
        svg('path', attrs: {'d': 'M1 3 L10 10 L1 17 M9 3 L18 10 L9 17 M17 3 L26 10 L17 17 M10 10 H30'}),
      ]),
      el('span', cls: 'arrow-shaft'),
      svg('svg', cls: 'arrow-point', attrs: {'viewBox': '0 0 18 20'}, children: [
        svg('path', attrs: {'d': 'M0 10 H4 M0 3 L18 10 L0 17 L5 10 Z'}),
      ]),
    ]);
