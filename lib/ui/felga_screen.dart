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

/// The last -1 or +1 pressed: for [_flashTime] that button, the name and the
/// felgas of that name flash white with black letters (soft, blurred edges),
/// and fade back.
FelgaMember? _flashMember;
int _flashBy = 0;
DateTime _flashAt = DateTime(2000);
const Duration _flashTime = Duration(milliseconds: 1500);

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
/// each paid (a box adds to it), still to pay and paid; the club money (added
/// above zero, spent below); and the history of the felgas.
///
/// A change does not draw the whole page again: each part is filled anew in
/// its place, and the box for a new name stays as it is - so the phone's
/// keyboard stays up and the page does not jump.
web.HTMLElement buildFelgaScreen(ViewContext ctx) {
  final ledger = _book;

  web.HTMLElement part() => el('div', cls: 'felga-part');
  final moneyPart = part(), owesPart = part(), namesPart = part(), newNamePart = part();
  final togglePart = part(), paidPart = part(), clubPart = part(), historyPart = part();
  void fill(web.HTMLElement into, List<web.HTMLElement> children) {
    into.textContent = '';
    for (final child in children) {
      into.append(child);
    }
  }

  late final void Function() refresh;
  void changed() {
    _save(ledger);
    refresh();
  }

  // The box for a new name: 10 letters wide, wider as a longer name is typed,
  // in the middle of the screen, its tick to the right of it; Enter or the
  // tick adds the name and the box is empty and ready for the next one.
  void openNameBox({required bool focus}) {
    final input = el('input', cls: 'felga-input', attrs: {
      'type': 'text',
      'maxlength': '40',
      'autocomplete': 'off',
      'enterkeyhint': 'done',
      'aria-label': tr('Name'),
    }) as web.HTMLInputElement;
    void fit() => input.style.width = '${math.max(10, input.value.length + 1)}ch';
    fit();
    void confirm() {
      if (input.value.trim().isNotEmpty) {
        ledger.add(input.value);
        input.value = '';
        fit();
        changed();
      }
      input.focus();
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
    // Pressed, the tick leaves the typing in the box (the keyboard stays up).
    tick.onMouseDown.listen((event) => event.preventDefault());
    fill(newNamePart, [el('div', cls: 'felga-new', children: [el('span'), input, tick])]);
    if (focus) input.focus();
  }

  // The flash of the last -1 / +1 goes on where it was if a part is filled
  // again meanwhile.
  T flash<T extends web.HTMLElement>(T element, bool on) {
    final flashed = DateTime.now().difference(_flashAt);
    if (on && flashed < _flashTime) {
      element.classList.add('flash');
      element.style.animationDelay = '-${flashed.inMilliseconds}ms';
    }
    return element;
  }

  web.HTMLElement step(FelgaMember member, int by) => flash(
      button(by > 0 ? '+1' : '-1',
          cls: 'felga-step',
          ariaLabel: by > 0
              ? tr('{name}: one point more', {'name': member.name})
              : tr('{name}: one point less', {'name': member.name}),
          onPressed: (_) {
            ledger.step(member, by, DateTime.now());
            _flashMember = member;
            _flashBy = by;
            _flashAt = DateTime.now();
            changed();
          }),
      member == _flashMember && by == _flashBy);

  // A money box: four digits wide (wider for a longer number), the grey €
  // after it, written with a dot for thousands and a comma for decimals while
  // it is typed. It opens the phone-number keys, which have a minus (the
  // number keys with a decimal point have none on Android): a minus typed
  // anywhere turns the number below zero and back, a dot typed at the end is
  // the decimal comma. The cursor always goes to the end. The number is
  // confirmed ([onConfirm]) when the box is left or Enter is pressed.
  web.HTMLElement moneyBox(String label, void Function(int cents) onConfirm) {
    final input = el('input', cls: 'money-input', attrs: {
      'type': 'text',
      'inputmode': 'tel',
      'enterkeyhint': 'done',
      'autocomplete': 'off',
      'aria-label': label,
    }) as web.HTMLInputElement;
    void fit() => input.style.width = '${math.max(4, input.value.length)}ch';
    void toEnd() => Timer.run(() {
          final end = input.value.length;
          input.setSelectionRange(end, end);
        });
    fit();
    var last = '';
    input.onInput.listen((_) {
      var text = input.value;
      final minuses = '-'.allMatches(text).length;
      final digits = text.replaceAll('-', '');
      if (minuses > '-'.allMatches(last).length) {
        // A minus was typed: the sign turns.
        text = last.startsWith('-') ? digits : '-$digits';
      } else {
        // The minus kept where it was, or taken away.
        text = minuses > 0 && last.startsWith('-') ? '-$digits' : digits;
      }
      // A dot at the end was typed (the dots of the thousands never are).
      if (text.endsWith('.')) text = '${text.substring(0, text.length - 1)},';
      input.value = last = formatTypedEuro(text);
      fit();
    });
    var confirming = false;
    void confirm() {
      if (confirming) return;
      final cents = parseEuroCents(input.value);
      input.value = last = '';
      fit();
      if (cents == null || cents == 0) return;
      confirming = true;
      onConfirm(cents);
    }

    input.onFocus.listen((_) => toEnd());
    input.onClick.listen((_) => toEnd());
    input.onBlur.listen((_) => confirm());
    input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        input.blur();
      }
    });
    return el('label', cls: 'money', children: [input, el('span', cls: 'euro', text: '€')]);
  }

  web.HTMLElement toggleButton() {
    final turn = _justToggled;
    _justToggled = false;
    return button('',
        cls: 'felga-toggle${_adding ? ' open' : ''}${turn ? ' turning' : ''}',
        focusKey: 'felga-toggle',
        ariaLabel: _adding ? tr('Stop adding names') : tr('Add a name'),
        onPressed: (_) {
          _adding = !_adding;
          _justToggled = true;
          fill(togglePart, [toggleButton()]);
          if (_adding) {
            openNameBox(focus: true);
          } else {
            fill(newNamePart, []);
          }
        })
      ..append(svg('svg', cls: 'felga-plus', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
        svg('path', attrs: {'d': 'M12 3 V21 M3 12 H21'}),
      ]));
  }

  refresh = () {
    final anyone = ledger.members.isNotEmpty;
    fill(moneyPart, [
      el('div', cls: 'felga-money', children: [
        el('p', children: [textNode('${tr('Total money in the club')} '), el('strong', text: formatEuro(ledger.totalCents))]),
        el('p', children: [textNode('${tr('Money in the club now')} '), el('strong', text: formatEuro(ledger.currentCents))]),
      ]),
    ]);
    // Right under the money: the felgas and the fines, most first.
    fill(owesPart, [
      if (anyone) ...[
        el('div', cls: 'felga-grid owes', children: [
          el('span'),
          el('span', cls: 'felga-head felgas', text: 'Felga'),
          el('span', cls: 'felga-head', text: 'Kazna'),
          for (final member in ledger.byPoints) ...[
            el('span', cls: 'felga-cell name', text: member.name),
            flash(el('span', cls: 'felga-cell num felgas', children: [el('span', text: '${member.points}')]),
                member == _flashMember),
            el('span', cls: 'felga-cell num', text: formatEuro(FelgaLedger.owedCents(member))),
          ],
        ]),
        _arrow(),
      ],
    ]);
    // The names, with -1 and +1 one under the other (as wide as the longest
    // name); under them the box for a new one, and the + (X while it is open).
    fill(namesPart, [
      if (anyone)
        el('div', cls: 'felga-names', children: [
          for (final member in ledger.members) ...[
            step(member, -1),
            flash(el('span', cls: 'felga-name', text: member.name), member == _flashMember),
            step(member, 1),
          ],
        ]),
    ]);
    fill(togglePart, [toggleButton()]);
    // What each paid, whoever owes the most first: a number in the box is
    // added to Paid (or taken off, below zero), and the box is empty again.
    fill(paidPart, [
      if (anyone) ...[
        _arrow(),
        el('div', cls: 'felga-grid paid', children: [
          el('span'),
          el('span'),
          el('span', cls: 'felga-head', text: tr('Owed')),
          el('span', cls: 'felga-head', text: tr('Paid')),
          for (final member in ledger.byDebt) ...[
            el('span', cls: 'felga-cell name', text: member.name),
            moneyBox(tr('{name} paid', {'name': member.name}), (cents) {
              member.paidCents += cents;
              changed();
            }),
            el('span', cls: 'felga-cell num', text: formatEuro(FelgaLedger.debtCents(member))),
            el('span', cls: 'felga-cell num', text: formatEuro(member.paidCents)),
          ],
        ]),
      ],
    ]);
    // Club money: an amount above zero is added to the club, below zero spent
    // from it; each is added up, and the box is empty again.
    fill(clubPart, [
      el('div', cls: 'felga-spent', children: [
        el('span', text: tr('Club money')),
        moneyBox(tr('Club money'), (cents) {
          ledger.clubCents += cents;
          changed();
        }),
        el('span', cls: 'felga-club-sum', text: formatEuro(ledger.clubCents)),
      ]),
    ]);
    // The history: each -1 / +1 under the name and the day, with that day's
    // felgas of the name; the latest at the top.
    fill(historyPart, [
      if (ledger.history.isNotEmpty) ...[
        _arrow(),
        el('div', cls: 'felga-grid history', children: [
          for (final day in ledger.history) ...[
            el('span', cls: 'felga-cell name', text: day.name),
            el('span', cls: 'felga-cell date', text: day.date),
            el('span', cls: 'felga-cell num felgas', text: '${day.count}'),
          ],
        ]),
      ],
    ]);
  };

  refresh();
  if (_adding) openNameBox(focus: false);
  return el('main', cls: 'screen felga', children: [
    moneyPart,
    owesPart,
    namesPart,
    newNamePart,
    togglePart,
    paidPart,
    clubPart,
    historyPart,
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
