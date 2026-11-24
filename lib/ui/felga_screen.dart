import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dart_icon.dart';
import 'dart_shot_timing.dart';
import 'dom.dart';
import 'keyboard.dart';
import 'modal.dart';
import 'swipes.dart';
import 'view_context.dart';

/// Where Felgalizacija is kept (this device only).
const String _key = 'dartle.felga.v1';

FelgaLedger? _ledger;

/// Whose book [_ledger] is.
String? _ledgerId;

/// The name box is open (after +, until X).
bool _adding = false;


/// A -1 or +1 pressed: for [_flashTime] that button, the name and the felgas
/// of that name flash white with black letters (soft, blurred edges), with
/// fireworks, and fade back. Each press has its own: one pressed while
/// another still shows does not cut it short.
class _Flash {
  _Flash(this.member, this.by);

  final FelgaMember member;
  final int by;
  final DateTime at = DateTime.now();

  Duration get age => DateTime.now().difference(at);
}

final List<_Flash> _flashes = [];
const Duration _flashTime = Duration(milliseconds: 1500);

/// The presses still showing, the oldest first.
List<_Flash> _live() => _flashes..removeWhere((f) => f.age >= _flashTime);

/// The latest press still showing that [where] picks; null for none.
_Flash? _latest(bool Function(_Flash f) where) => _live().where(where).lastOrNull;

/// The book of the Felgalizacija open.
FelgaLedger get _book {
  final open = _open;
  if (_ledgerId != open.id) {
    _ledger = null;
    _ledgerId = open.id;
  }
  return _ledger ??= FelgaLedger.fromJson(() {
    try {
      return web.window.localStorage.getItem(open.storageKey);
    } on Object {
      return null;
    }
  }());
}

void _save(FelgaLedger ledger) {
  try {
    web.window.localStorage.setItem(_open.storageKey, ledger.toJson());
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
  // None left to show: the menu.
  if (felgaList().isEmpty) Timer.run(() => ctx.showPage(MenuPage.home));
  final ledger = _book;

  web.HTMLElement part() => el('div', cls: 'felga-part');
  final moneyPart = el('div', cls: 'felga-money-rows'), owesPart = part(), namesPart = part();
  final newNamePart = part(), togglePart = part(), paidPart = part(), resetPart = part(), historyPart = part();
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
  void openNameBox({required bool focus, bool slide = false}) {
    final input = el('input', cls: 'felga-input', attrs: {
      'type': 'text',
      'maxlength': '40',
      'autocomplete': 'off',
      'enterkeyhint': 'done',
      'aria-label': tr('Name'),
    }) as web.HTMLInputElement;
    void fit() => fitToText(input, minCh: 10, room: () => web.window.innerWidth - 130.0);
    fit();
    // The new name comes in over the +; the page moves up by its row at once,
    // so the +, the box and everything under them stay where they are on the
    // screen (no late jump of the page to keep the box in sight).
    void confirm() {
      if (input.value.trim().isNotEmpty) {
        final before = input.getBoundingClientRect().top;
        ledger.add(input.value);
        input.value = '';
        fit();
        changed();
        final moved = input.getBoundingClientRect().top - before;
        if (moved.abs() >= 0.5) web.window.scrollBy(web.ScrollToOptions(top: moved, behavior: 'instant'));
      }
      input.focus(web.FocusOptions(preventScroll: true));
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
    final row = el('div', cls: 'felga-new', children: [el('span'), input, tick]);
    fill(newNamePart, [row]);
    if (slide) _slideOpen(row);
    if (focus) input.focus();
  }

  // A flash goes on where it was if a part is filled again meanwhile.
  T flash<T extends web.HTMLElement>(T element, _Flash? press) {
    if (press != null) {
      element.classList.add('flash');
      element.style.animationDelay = '-${press.age.inMilliseconds}ms';
    }
    return element;
  }

  // Felgas never go below 0: a -1 on 0 does nothing.
  web.HTMLElement step(FelgaMember member, int by) => flash(
      button(by > 0 ? '+1' : '-1',
          cls: 'felga-step',
          ariaLabel: by > 0
              ? tr('{name}: one point more', {'name': member.name})
              : tr('{name}: one point less', {'name': member.name}),
          onPressed: (_) {
            if (!ledger.step(member, by, DateTime.now())) return;
            _flashes.add(_Flash(member, by));
            changed();
          }),
      _latest((f) => f.member == member && f.by == by));

  // A money box: four digits wide (wider for a longer number), the grey €
  // after it, written with a dot for thousands and a comma for decimals while
  // it is typed. It opens no phone keyboard but the page's own number keys
  // (a phone keyboard cannot be given a minus or a comma): they rise from the
  // foot of the screen with − and , in their bottom left corner. The cursor
  // always goes to the end. The number is confirmed ([onConfirm]) with the
  // tick of those keys, or when the box is left.
  web.HTMLElement moneyBox(String label, void Function(int cents) onConfirm) {
    final input = el('input', cls: 'money-input', attrs: {
      'type': 'text',
      'inputmode': 'none',
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
    // Typed on a real keyboard (a computer): a minus anywhere turns the sign,
    // a dot at the end is the decimal comma.
    input.onInput.listen((_) {
      var text = input.value;
      final minuses = '-'.allMatches(text).length;
      final digits = text.replaceAll('-', '');
      if (minuses > '-'.allMatches(last).length) {
        text = last.startsWith('-') ? digits : '-$digits';
      } else {
        text = minuses > 0 && last.startsWith('-') ? '-$digits' : digits;
      }
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

    input.onFocus.listen((_) {
      toEnd();
      _pad.open(input, (change) {
        input.value = last = formatTypedEuro(change(input.value));
        fit();
        toEnd();
      });
    });
    input.onClick.listen((_) => toEnd());
    input.onBlur.listen((_) {
      _pad.close(input);
      confirm();
    });
    input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        input.blur();
      }
    });
    return el('label', cls: 'money', children: [input, el('span', cls: 'euro', text: '€')]);
  }

  // While the + is open: a line under a name, over it, to type a new name;
  // taken when the keyboard goes down (the box is left) or with Enter.
  web.HTMLElement memberLine(FelgaMember member) {
    final input = el('input', cls: 'felga-member-input', attrs: {
      'type': 'text',
      'maxlength': '40',
      'autocomplete': 'off',
      'enterkeyhint': 'done',
      'aria-label': tr('New name of {name}', {'name': member.name}),
    }) as web.HTMLInputElement
      ..value = member.name;
    void take() {
      final typed = input.value.trim();
      if (typed.isEmpty || typed == member.name) {
        input.value = member.name;
        return;
      }
      ledger.rename(member, typed);
      changed();
    }

    input.onKeyDown.listen((event) {
      if (event.key != 'Enter') return;
      event.preventDefault();
      take();
      input.blur();
    });
    input.onBlur.listen((_) => take());
    return input;
  }

  // The + under the names: pressed, it turns into an X (over a second), the
  // box for a new name glides open under it and an x comes right of each
  // name's +1 (to take them out); the X takes them away.
  web.HTMLElement toggleButton() => _turningPlus(
        cls: 'felga-toggle',
        focusKey: 'felga-toggle',
        open: _adding,
        openLabel: tr('Stop adding names'),
        closedLabel: tr('Add a name'),
        onToggle: (open) {
          _adding = open;
          namesPart.classList.toggle('removing', open);
          if (open) {
            openNameBox(focus: true, slide: true);
          } else {
            final row = newNamePart.firstElementChild;
            if (row != null) _slideShut(row as web.HTMLElement);
          }
        },
      );

  // Where each row of the two sorted lists is, before a change...
  Map<String, double> rowTops() {
    final tops = <String, double>{};
    for (final part in [owesPart, paidPart]) {
      final cells = part.querySelectorAll('[data-row]');
      for (var i = 0; i < cells.length; i++) {
        final cell = cells.item(i) as web.HTMLElement;
        tops.putIfAbsent(cell.getAttribute('data-row')!, () => cell.getBoundingClientRect().top);
      }
    }
    return tops;
  }

  // ...and after it each row glides from where it was to its new place: two
  // names that change places move towards each other at the same time.
  void slideRows(Map<String, double> before) {
    if (before.isEmpty || wantsLessMotion) return;
    final moved = <web.HTMLElement>[];
    for (final part in [owesPart, paidPart]) {
      final cells = part.querySelectorAll('[data-row]');
      for (var i = 0; i < cells.length; i++) {
        final cell = cells.item(i) as web.HTMLElement;
        final was = before[cell.getAttribute('data-row')];
        if (was == null) continue;
        final dy = was - cell.getBoundingClientRect().top;
        if (dy.abs() < 1) continue;
        cell.style
          ..transition = 'none'
          ..transform = 'translateY(${dy}px)';
        moved.add(cell);
      }
    }
    if (moved.isEmpty) return;
    moved.first.getBoundingClientRect(); // so that the start is drawn
    for (final cell in moved) {
      cell.style
        ..transition = 'transform 450ms cubic-bezier(0.4, 0, 0.2, 1)'
        ..transform = '';
    }
  }

  refresh = () {
    final before = rowTops();
    final anyone = ledger.members.isNotEmpty;
    // The two sums one under the other, at the top on the right ([_topPart]).
    fill(moneyPart, [
      el('span', cls: 'felga-money-words', text: tr('Money in the club')),
      el('strong', text: formatEuro(ledger.currentCents)),
      el('span', cls: 'felga-money-words', text: tr('Owed to the club')),
      el('strong', text: formatEuro(ledger.owedTotalCents)),
    ]);
    // Right under the money: the felgas and the fines, most first, each
    // place numbered on the left (1. at the top). The numbers stay where they
    // are; the rest of a row moves when the order changes.
    fill(owesPart, [
      if (anyone) ...[
        el('div', cls: 'felga-grid owes', children: [
          el('span'),
          el('span'),
          el('span', cls: 'felga-head felgas', text: 'Felga'),
          el('span', cls: 'felga-head', text: tr('Fine')),
          for (final (place, member) in ledger.byPoints.indexed) ...[
            el('span', cls: 'felga-cell place', text: '${place + 1}.'),
            el('span', cls: 'felga-cell name', text: member.name, attrs: {'data-row': 'o:${member.name}'}),
            flash(
                el('span', cls: 'felga-cell num felgas', attrs: {'data-row': 'o:${member.name}'}, children: [
                  el('span', children: [
                    textNode('${member.points}'),
                    // Every press still showing has its own fireworks.
                    for (final press in _live())
                      if (press.member == member) _sparks(inward: press.by < 0, age: press.age),
                  ]),
                ]),
                _latest((f) => f.member == member)),
            // The fine, and right of it, while the flash lasts, +1 or -1 (what
            // was pressed) fading in and out with it - outside the list, so
            // the list stays in the middle.
            el('span', cls: 'felga-cell num fine', attrs: {'data-row': 'o:${member.name}'}, children: [
              textNode(formatEuro(ledger.owedCents(member))),
              if (_latest((f) => f.member == member) case final press?)
                flash(el('span', cls: 'felga-delta', text: press.by > 0 ? '+1' : '-1'), press),
            ]),
          ],
        ]),
        _arrow(),
      ],
    ]);
    // The names, with -1 and +1 one under the other (as wide as the longest
    // name), and right of +1 an x to take the name out - seen only while the
    // + is open (an X); its room is always kept (an empty column on the left
    // too), so nothing moves. Under them the box for a new one, and the +.
    fill(namesPart, [
      if (anyone)
        el('div', cls: 'felga-names', children: [
          for (final member in ledger.members) ...[
            el('span'),
            step(member, -1),
            el('span', cls: 'felga-name-cell', children: [
              flash(el('span', cls: 'felga-name', text: member.name), _latest((f) => f.member == member)),
              memberLine(member),
            ]),
            step(member, 1),
            button('', cls: 'felga-remove', ariaLabel: tr('Throw {name} out', {'name': member.name}), onPressed: (_) {
              _ask(tr('Do you want to throw {name} out of the Felgalizacija?', {'name': member.name}), () {
                ledger.remove(member);
                _flashes.removeWhere((f) => f.member == member);
                changed();
              });
            })
              ..append(svg('svg', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
                svg('path', attrs: {'d': 'M6 6 L18 18 M18 6 L6 18'}),
              ])),
          ],
        ]),
    ]);
    fill(togglePart, [toggleButton()]);
    // What each paid, whoever owes the most first: a number in the box is
    // added to Paid (or taken off, below zero), and the box is empty again.
    fill(paidPart, [
      if (anyone) ...[
        _arrow(),
        el('h3', cls: 'felga-title', text: tr('Payments')),
        el('div', cls: 'felga-grid paid', children: [
          el('span'),
          el('span'),
          el('span', cls: 'felga-head', text: tr('Owed')),
          el('span', cls: 'felga-head', text: tr('Paid')),
          for (final member in ledger.byDebt) ...[
            el('span', cls: 'felga-cell name', text: member.name, attrs: {'data-row': 'p:${member.name}'}),
            moneyBox(tr('{name} paid', {'name': member.name}), (cents) {
              member.paidCents += cents;
              changed();
            })
              ..setAttribute('data-row', 'p:${member.name}'),
            el('span',
                cls: 'felga-cell num',
                text: formatEuro(ledger.debtCents(member)),
                attrs: {'data-row': 'p:${member.name}'}),
            el('span',
                cls: 'felga-cell num',
                text: formatEuro(member.paidCents),
                attrs: {'data-row': 'p:${member.name}'}),
          ],
        ]),
      ],
    ]);
    // Reset, asked twice: the numbers above back to 0; the felgas by date
    // stay, added up in a line "From ... to ..." (or added to the line of the
    // same days, or deleted for good).
    fill(resetPart, [
      button(tr('Reset'), cls: 'felga-reset-all', focusKey: 'felga-reset', onPressed: (_) {
        _ask(tr('Are you sure you want to reset all the data?'), () {
          _ask(
              tr('Are you really 100% million billion percent sure? Only the Felgalizacija\'s numbers of now are '
                  'reset: the felgas in the history are not deleted.'), () {
            void reset(FelgaResetKeep keep) {
              ledger.reset(DateTime.now(), keep: keep);
              _flashes.clear(); // no flash goes on over the zeros
              changed();
            }

            final same = ledger.sameDaysAs(DateTime.now());
            if (same == null) {
              reset(FelgaResetKeep.record);
              return;
            }
            _choose(tr('There is already a record from {from} to {to}. Add these to it, or delete them forever?',
                {'from': same.from, 'to': same.to}), [
              (tr('Add them up'), () => reset(FelgaResetKeep.merge)),
              (tr('Delete forever'), () => reset(FelgaResetKeep.discard)),
            ]);
          });
        });
      }),
    ]);
    // Felgas by date: today's in the middle, under the day; under them, a
    // little apart, each day before as a line "Felgas 23.11.2026" on the right
    // (the latest first) that opens its names; then "History" and a line
    // "From ... to ..." for each reset, the latest first.
    final days = ledger.currentDays, resets = ledger.periods;
    final today = felgaDate(DateTime.now());
    final byDate = _byDate(days);
    final todays = byDate[today];
    final earlier = [for (final e in byDate.entries) if (e.key != today) e];
    // A line gone: saved; the part drawn again only if its list is empty now.
    void gone() {
      _save(ledger);
      final left = _byDate(ledger.currentDays).keys.where((d) => d != today);
      if (ledger.periods.isEmpty || left.isEmpty) refresh();
    }

    fill(historyPart, [
      if (days.isNotEmpty || resets.isNotEmpty) ...[
        _arrow(),
        el('h3', cls: 'felga-title', text: tr('Felgas by date')),
        el('div', cls: 'felga-history', children: [
          if (todays != null) ...[
            el('p', cls: 'felga-day-date', text: today),
            _dayGrid(todays, ledger.priceCents),
          ],
          if (earlier.isNotEmpty)
            el('div', cls: 'felga-days', children: [
              for (final MapEntry(key: date, value: names) in earlier)
                _dayLine(date, names, ledger.priceCents, onDelete: () {
                  ledger.deleteDay(date);
                  gone();
                }),
            ]),
          if (resets.isNotEmpty)
            el('div', cls: 'felga-resets', children: [
              el('p', cls: 'felga-history-label', text: tr('History')),
              for (final reset in resets)
                _resetLine(reset, onDelete: () {
                  ledger.deletePeriod(reset);
                  gone();
                }),
            ]),
        ]),
      ],
    ]);
    slideRows(before);
  };

  refresh();
  namesPart.classList.toggle('removing', _adding);
  if (_adding) openNameBox(focus: false);
  return el('main', cls: 'screen felga', children: [
    _topPart(moneyPart, _open, price: () => ledger.priceCents, onPrice: (cents, all) {
      ledger.setPrice(cents, applyToAll: all);
      changed();
    }),
    owesPart,
    namesPart,
    togglePart,
    newNamePart,
    paidPart,
    resetPart,
    historyPart,
    // At the very foot, on the right: the whole Felgalizacija deleted, asked
    // three times; then the menu, with 10 s to undo it.
    button(tr('Delete Felgalizacija'), cls: 'felga-delete', focusKey: 'felga-delete', onPressed: (_) {
      _ask(tr('Are you sure you want to delete this Felgalizacija?'), () {
        _ask(tr('Are you really sure? Everything in it will be gone.'), () {
          _ask(
              tr('Are you really, like, a hundred thousand million percent sure you want to delete the whole '
                  'Felgalizacija of the entire club forever, with no way back, all the history you had together?'),
              () => _deleteOpen(ctx));
        });
      });
    }),
  ]);
}

/// The days of [days] (the latest first), each with its names, the most
/// felgas first.
Map<String, List<FelgaDay>> _byDate(List<FelgaDay> days) {
  final byDate = <String, List<FelgaDay>>{};
  for (final day in days) {
    (byDate[day.date] ??= []).add(day);
  }
  for (final names in byDate.values) {
    names.sort((a, b) => b.count.compareTo(a.count));
  }
  return byDate;
}

/// Deletes the Felgalizacija open - its book and its place in the list - and
/// goes to the menu, where "Felgalizacija deleted" shows for 10 s with Undo,
/// which brings it all back. Not undone, it is gone for good.
void _deleteOpen(ViewContext ctx) {
  final list = felgaList();
  final entry = _open;
  final index = list.indexWhere((e) => e.id == entry.id);
  final others = {for (final e in list) if (e.id != entry.id) e.id};
  String? book;
  try {
    book = web.window.localStorage.getItem(entry.storageKey);
    web.window.localStorage.removeItem(entry.storageKey);
    web.window.sessionStorage.removeItem(_openKey);
  } on Object {
    // Kept for this visit only.
  }
  _saveList([for (final e in list) if (e.id != entry.id) e]);
  _ledger = null;
  _ledgerId = null;
  _flashes.clear();
  _openResets.clear();
  _adding = false;
  ctx.showPage(MenuPage.home);
  _undoBar(tr('Felgalizacija deleted'), () {
    // The one made in its place when it was the last is not kept.
    final now = [for (final e in felgaList()) if (others.contains(e.id)) e];
    now.insert(math.max(0, math.min(index, now.length)), entry);
    _saveList(now);
    try {
      if (book != null) web.window.localStorage.setItem(entry.storageKey, book);
    } on Object {
      // Kept for this visit only.
    }
    _ledger = null;
    _ledgerId = null;
    ctx.rerender();
  });
}

/// At the foot of the screen for [lasts]: [message] and Undo ([undo] runs).
void _undoBar(String message, void Function() undo, {Duration lasts = const Duration(seconds: 10)}) {
  final bar = el('div', cls: 'undo-bar', attrs: {'role': 'status', 'aria-live': 'polite'});
  late final Timer timer;
  void gone() {
    bar.classList.remove('show');
    Timer(const Duration(milliseconds: 450), () => bar.remove());
  }

  bar
    ..append(el('span', text: message))
    ..append(button(tr('Undo'), cls: 'undo-btn', onPressed: (_) {
      timer.cancel();
      gone();
      undo();
    }));
  web.document.body!.append(bar);
  Timer(const Duration(milliseconds: 16), () => bar.classList.add('show'));
  timer = Timer(lasts, gone);
}

/// The number keys of the money boxes, the page's own (a phone keyboard cannot
/// be given a minus or a comma): they rise from the foot of the screen while a
/// money box is typed in.
///
///     1  2  3  ⌫
///     4  5  6
///     7  8  9  ✓
///     −  ,  0
///
/// − turns the number below zero and back, , is the decimal comma, ⌫ takes the
/// last one away and ✓ confirms. Pressed, they leave the typing in the box.
class _MoneyPad {
  web.HTMLElement? _element;
  web.HTMLInputElement? _input;
  void Function(String Function(String text) change)? _apply;
  Timer? _hide;
  Timer? _watch;

  web.HTMLElement get _pad => _element ??= _build();

  web.HTMLElement _build() {
    web.HTMLElement key(String label, String aria, void Function() press, {String cls = ''}) {
      final b = button(label, cls: 'key pad-key money-pad-key $cls', ariaLabel: aria, onPressed: (_) => press());
      return b;
    }

    void change(String Function(String text) how) => _apply?.call(how);
    web.HTMLElement digit(int n) => key('$n', '$n', () => change((t) => '$t$n'));
    final pad = el('div', cls: 'money-pad', attrs: {'role': 'group', 'aria-label': tr('Number pad')}, children: [
      digit(1), digit(2), digit(3),
      key('', tr('Delete the last digit'), () => change((t) => t.isEmpty ? t : t.substring(0, t.length - 1)),
          cls: 'tall')
        ..append(undoIcon()),
      digit(4), digit(5), digit(6),
      digit(7), digit(8), digit(9),
      key('✓', tr('Done'), () => _input?.blur(), cls: 'tall done'),
      key('−', tr('Turn the sign'), () => change((t) => t.startsWith('-') ? t.substring(1) : '-$t')),
      key(',', tr('Decimal comma'), () => change((t) => t.contains(',') ? t : '$t,')),
      digit(0),
    ]);
    // A press anywhere on the keys leaves the typing in the box.
    pad.onMouseDown.listen((event) => event.preventDefault());
    return pad;
  }

  /// Shows the keys for [input]; [apply] changes what is in it.
  void open(web.HTMLInputElement input, void Function(String Function(String text) change) apply) {
    _hide?.cancel();
    _input = input;
    _apply = apply;
    final pad = _pad;
    if (!pad.isConnected) web.document.body!.append(pad);
    // Next frame, so that it slides up.
    Timer.run(() {
      pad.classList.add('open');
      web.document.body!.classList.add('money-pad-open');
      // The box stays in sight above the keys.
      Timer(const Duration(milliseconds: 200), () {
        if (_input == input) {
          input.scrollIntoView(web.ScrollIntoViewOptions(block: 'center', behavior: 'smooth'));
        }
      });
    });
    // Gone with its box (another page): the keys go too.
    _watch?.cancel();
    _watch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!(_input?.isConnected ?? false)) _close();
    });
  }

  /// [input] was left: the keys go down, unless another box takes them at once.
  void close(web.HTMLInputElement input) {
    if (_input != input) return;
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 60), _close);
  }

  void _close() {
    _watch?.cancel();
    _input = null;
    _apply = null;
    _element?.classList.remove('open');
    web.document.body?.classList.remove('money-pad-open');
  }
}

final _MoneyPad _pad = _MoneyPad();

/// One Felgalizacija on this device: its own book, the name its maker gave it
/// (none for the first one there was) and its password, which others join it
/// with.
class FelgaEntry {
  FelgaEntry(this.id, this.name, this.password);

  final String id;
  final String name;
  final String password;

  /// Where its book is kept: the first one where it always was.
  String get storageKey => id == _firstId ? _key : 'dartle.felga.$id';
}

const String _firstId = 'main';

/// Where the list of Felgalizacije is kept (this device only).
const String _listKey = 'dartle.felgas.v1';

/// Which one is open (for this visit, so a reload opens it again).
const String _openKey = 'dartle.felga-open';

/// The signs a password is made of: letters, digits and a few others, none
/// that can be taken for another (no 0 and O, 1, l and I).
const String _passwordSigns = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!#%&*+=?@';

/// A new password: 10 signs drawn at random.
String _newPassword() {
  final random = math.Random.secure();
  return [for (var i = 0; i < 10; i++) _passwordSigns[random.nextInt(_passwordSigns.length)]].join();
}

/// The Felgalizacije on this device, in the order they were made - none until
/// one is made (or joined). The book kept before there was a list becomes the
/// first one (no name); one kept before passwords gets one now.
List<FelgaEntry> felgaList() {
  var list = <FelgaEntry>[];
  var changed = false;
  var listed = false;
  try {
    final saved = web.window.localStorage.getItem(_listKey);
    listed = saved != null;
    if (saved != null) {
      list = [
        for (final e in (jsonDecode(saved) as List<Object?>).cast<Map<String, Object?>>())
          FelgaEntry(e['id'] as String, e['name'] as String? ?? '', e['password'] as String? ?? ''),
      ];
    }
  } on Object {
    list = [];
  }
  if (!listed && _hasOldBook()) {
    list = [FelgaEntry(_firstId, '', _newPassword())];
    changed = true;
  }
  list = [
    for (final e in list)
      if (e.password.isEmpty) FelgaEntry(e.id, e.name, _newPassword()) else e,
  ];
  if (changed || list.any((e) => !_savedPasswords.contains(e.password))) _saveList(list);
  return list;
}

/// A book kept before there was a list of Felgalizacije.
bool _hasOldBook() {
  try {
    return web.window.localStorage.getItem(_key) != null;
  } on Object {
    return false;
  }
}

/// The passwords as last saved (so the list is saved only when one is new).
Set<String> _savedPasswords = {};

void _saveList(List<FelgaEntry> list) {
  _savedPasswords = {for (final e in list) e.password};
  try {
    web.window.localStorage.setItem(
        _listKey, jsonEncode([for (final e in list) {'id': e.id, 'name': e.name, 'password': e.password}]));
  } on Object {
    // Kept for this visit only.
  }
}

FelgaEntry get _open {
  String? id;
  try {
    id = web.window.sessionStorage.getItem(_openKey);
  } on Object {
    id = null;
  }
  final list = felgaList();
  // None at all (the last one deleted, the page opened again): an empty one
  // that is in no list - the screen goes to the menu at once.
  return list.where((e) => e.id == id).firstOrNull ?? list.firstOrNull ?? FelgaEntry(_firstId, '', '');
}

/// Opens [entry]'s page.
void openFelga(ViewContext ctx, FelgaEntry entry) {
  try {
    web.window.sessionStorage.setItem(_openKey, entry.id);
  } on Object {
    // The first one opens after a reload.
  }
  _ledger = null;
  _ledgerId = null;
  _flashes.clear();
  _openResets.clear();
  _adding = false;
  ctx.showPage(MenuPage.felga);
}

/// The menu's + is open (an X): the boxes under it are there.
bool _menuAdding = false;

/// A + that turns into an X (over a second) when pressed, and back.
web.HTMLButtonElement _turningPlus({
  required String cls,
  required String focusKey,
  required bool open,
  required String openLabel,
  required String closedLabel,
  required void Function(bool open) onToggle,
}) {
  late final web.HTMLButtonElement plus;
  plus = button('',
      cls: '$cls turning-plus${open ? ' open' : ''}',
      focusKey: focusKey,
      ariaLabel: open ? openLabel : closedLabel,
      attrs: {'aria-expanded': '$open'},
      onPressed: (_) {
        final now = !plus.classList.contains('open');
        plus.classList.toggle('open', now);
        plus
          ..setAttribute('aria-expanded', '$now')
          ..setAttribute('aria-label', now ? openLabel : closedLabel);
        onToggle(now);
      })
    ..append(svg('svg', cls: 'felga-plus', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
      svg('path', attrs: {'d': 'M12 3 V21 M3 12 H21'}),
    ]));
  return plus;
}

/// The menu's buttons for Felgalizacija: one for each (the word, and under it
/// the name its maker gave it, the two in the middle one under the other) -
/// with none yet, "Add new Felgalizacija" instead - then a +. Pressed, the + turns into an X and under it come the word with a
/// line under it, the cursor on it and the keyboard up - the name of a new
/// one is just typed, Enter makes it - and "Do you have a password to join?"
/// with a box for it. The X takes them away.
List<web.HTMLElement> buildFelgaButtons(ViewContext ctx) {
  final list = felgaList();
  web.HTMLElement lines(String name, [web.HTMLElement? under]) => el('span', cls: 'felga-btn-lines', children: [
        el('span', cls: 'felga-btn-word', text: 'Felgalizacija'),
        if (under != null) under else if (name.isNotEmpty) el('span', cls: 'felga-btn-name', text: name),
      ]);

  final panel = el('div', cls: 'felga-join');

  void fillPanel({required bool focus, bool slide = false}) {
    late final _NameLine name;
    name = _nameLine(
      label: tr('Name of the Felgalizacija'),
      // The whole name always seen, the dart right of it in the button too.
      room: () => ((name.input.closest('.felga-naming') as web.HTMLElement?)?.clientWidth ?? 0) - 120.0,
      onConfirm: (typed) {
        final entry = FelgaEntry('${DateTime.now().millisecondsSinceEpoch}', typed, _newPassword());
        // Its maker is its first member.
        try {
          web.window.localStorage.setItem(entry.storageKey, (FelgaLedger()..add(ctx.game.playerName)).toJson());
        } on Object {
          // Kept for this visit only.
        }
        _saveList([...felgaList(), entry]);
        _menuAdding = false;
        ctx.rerender();
        // For 4 s it can be undone: as if it had never been made.
        _undoBar(tr('New Felgalizacija created'), lasts: const Duration(seconds: 4), () {
          _saveList([for (final e in felgaList()) if (e.id != entry.id) e]);
          try {
            web.window.localStorage.removeItem(entry.storageKey);
          } on Object {
            // Nothing was kept.
          }
          ctx.rerender();
        });
      },
    );

    final password = el('input', cls: 'felga-name-input felga-pass-input', attrs: {
      'type': 'text',
      'maxlength': '10',
      'autocomplete': 'off',
      'autocapitalize': 'off',
      'autocorrect': 'off',
      'spellcheck': 'false',
      'enterkeyhint': 'go',
      'aria-label': tr('Password'),
    }) as web.HTMLInputElement;
    password.onKeyDown.listen((event) {
      if (event.key != 'Enter') return;
      event.preventDefault();
      final typed = password.value.trim();
      if (typed.isEmpty) return;
      final mine = felgaList().where((e) => e.password == typed).firstOrNull;
      if (mine != null) {
        _menuAdding = false;
        openFelga(ctx, mine);
        return;
      }
      ctx.toast(tr('No Felgalizacija has this password.'));
    });

    final inner = el('div', cls: 'felga-join-inner', children: [
      el('div', cls: 'menu-btn felga-btn felga-naming', children: [lines('', name.line)]),
      el('p', cls: 'felga-or', text: tr('Or')),
      el('p', cls: 'felga-join-question', text: tr('Do you have a password to join?')),
      password,
    ]);
    panel
      ..textContent = ''
      ..append(inner);
    name.fit();
    if (slide) _slideOpen(inner);
    // At once, still in the press: so the phone's keyboard comes up.
    if (focus) name.input.focus();
  }

  final plus = _turningPlus(
    cls: 'menu-plus',
    focusKey: 'felga-add',
    open: _menuAdding,
    openLabel: tr('Close'),
    closedLabel: tr('Add a Felgalizacija'),
    onToggle: (open) {
      _menuAdding = open;
      if (open) {
        fillPanel(focus: false, slide: true);
      } else {
        final inner = panel.firstElementChild;
        if (inner != null) _slideShut(inner as web.HTMLElement);
      }
    },
  );
  if (_menuAdding) fillPanel(focus: false);

  // Goes down and up (quickly) before its Felgalizacija opens.
  web.HTMLButtonElement felgaButton(FelgaEntry entry) {
    late final web.HTMLButtonElement pressed;
    pressed = button('',
        cls: 'menu-btn felga-btn',
        focusKey: 'felga-${entry.id}',
        ariaLabel: entry.name.isEmpty ? 'Felgalizacija' : 'Felgalizacija ${entry.name}',
        onPressed: (_) => pressThen(pressed, () {
              _menuAdding = false;
              openFelga(ctx, entry);
            }))
      ..append(lines(entry.name));
    return pressed;
  }

  return [
    for (final entry in list) felgaButton(entry),
    // None yet: no Felgalizacija button, only these words over the +.
    if (list.isEmpty) button(tr('Add new Felgalizacija'), cls: 'felga-add-words', onPressed: (_) => plus.click()),
    plus,
    panel,
  ];
}

/// At the top: on the left "password" in small grey letters with a +; on the
/// right Money in the club and Owed to the club ([money]: the words end under
/// each other, the amounts too, the € under the €). Either of the first two
/// pressed, the + turns into an X and the password glides open under them
/// (white, as small); pressed - or held for a second - it is copied ("Copied" shows for
/// 1.5 s). The X takes it away at once. Under it "change name" with a +:
/// pressed, a line for the new name glides open under the top, with the dart
/// right of it; the dart (or Enter) gives the Felgalizacija that name.
web.HTMLElement _topPart(web.HTMLElement money, FelgaEntry entry,
    {required int Function() price, required void Function(int cents, bool applyToAll) onPrice}) {
  final password = entry.password;
  final box = el('div', cls: 'felga-pass-box');
  void copyNow() {
    _copy(password);
    final note = el('span', cls: 'felga-copied', text: tr('Copied'), attrs: {'role': 'status'});
    box.append(note);
    Timer(const Duration(milliseconds: 1500), () => note.remove());
  }

  void show(bool open) {
    box.textContent = '';
    if (!open) return;
    Timer? hold;
    var held = false;
    final shown = button(password, cls: 'felga-password', ariaLabel: tr('Copy the password'), onPressed: (_) {
      if (held) {
        held = false; // copied already, by holding it
        return;
      }
      copyNow();
    });
    const web.EventStreamProvider<web.Event>('pointerdown').forElement(shown).listen((_) {
      held = false;
      hold?.cancel();
      hold = Timer(const Duration(seconds: 1), () {
        held = true;
        copyNow();
      });
    });
    for (final end in const ['pointerup', 'pointerleave', 'pointercancel']) {
      web.EventStreamProvider<web.Event>(end).forElement(shown).listen((_) => hold?.cancel());
    }
    web.EventStreamProviders.contextMenuEvent.forElement(shown).listen((event) => event.preventDefault());
    final row = el('div', cls: 'felga-pass-row', children: [shown]);
    box.append(row);
    _slideOpen(row);
  }

  final plus = _turningPlus(
    cls: 'felga-pass-plus',
    focusKey: 'felga-pass',
    open: false,
    openLabel: tr('Hide the password'),
    closedLabel: tr('Show the password'),
    onToggle: show,
  );
  final word = button(tr('password'), cls: 'felga-pass-word', onPressed: (_) => plus.click());

  final renameBox = el('div', cls: 'felga-rename-box');
  late final web.HTMLButtonElement renamePlus;
  renamePlus = _turningPlus(
    cls: 'felga-pass-plus',
    focusKey: 'felga-rename',
    open: false,
    openLabel: tr('Close'),
    closedLabel: tr('Change the name'),
    onToggle: (open) {
      if (!open) {
        final row = renameBox.firstElementChild;
        if (row != null) _slideShut(row as web.HTMLElement);
        return;
      }
      final now = felgaList().where((e) => e.id == entry.id).firstOrNull ?? entry;
      final name = _nameLine(
        label: tr('New name of the Felgalizacija'),
        value: now.name,
        room: () => web.window.innerWidth - 140.0,
        onConfirm: (typed) {
          _saveList([for (final e in felgaList()) e.id == entry.id ? FelgaEntry(e.id, typed, e.password) : e]);
          renamePlus.click(); // closes the line
        },
      );
      final row = el('div', cls: 'felga-rename', children: [name.line]);
      renameBox
        ..textContent = ''
        ..append(row);
      name.fit();
      _slideOpen(row);
      name.input.focus();
    },
  );
  final renameWord = button(tr('change name'), cls: 'felga-pass-word', onPressed: (_) => renamePlus.click());

  // Cost: what a felga costs. A new one, confirmed with the dart, is asked
  // about: for the felgas already counted too, or only from now on?
  final costBox = el('div', cls: 'felga-rename-box');
  final costNow = el('span', cls: 'felga-cost-now', text: formatEuro(price()));
  late final web.HTMLButtonElement costPlus;
  costPlus = _turningPlus(
    cls: 'felga-pass-plus',
    focusKey: 'felga-cost',
    open: false,
    openLabel: tr('Close'),
    closedLabel: tr('Change the cost of a felga'),
    onToggle: (open) {
      if (!open) {
        final row = costBox.firstElementChild;
        if (row != null) _slideShut(row as web.HTMLElement);
        return;
      }
      final line = _nameLine(
        label: tr('Cost of a felga'),
        value: formatTypedEuro(formatEuro(price()).replaceAll('€', '')),
        decimal: true,
        suffix: '€',
        room: () => 160.0,
        onConfirm: (typed) {
          final cents = parseEuroCents(typed);
          if (cents == null || cents <= 0) return;
          void apply(bool all) {
            onPrice(cents, all);
            costNow.textContent = formatEuro(cents);
            costPlus.click(); // closes the line
          }

          _choose(tr('Apply to all felgas already entered?'), [
            (tr('Yes'), () => apply(true)),
            (tr('No'), () => apply(false)),
          ], secondLast: true);
        },
      );
      final row = el('div', cls: 'felga-rename', children: [line.line]);
      costBox
        ..textContent = ''
        ..append(row);
      line.fit();
      _slideOpen(row);
    },
  );
  final costWord = button(tr('felga cost'), cls: 'felga-pass-word', onPressed: (_) => costPlus.click());

  // Settings: pressed, its + turns and these three glide open under it.
  final settingsBox = el('div', cls: 'felga-settings-box');
  final settingsPlus = _turningPlus(
    cls: 'felga-pass-plus',
    focusKey: 'felga-settings',
    open: false,
    openLabel: tr('Close the settings'),
    closedLabel: tr('Open the settings'),
    onToggle: (open) {
      if (open) {
        final inner = el('div', cls: 'felga-settings', children: [
          el('div', cls: 'felga-pass-line', children: [renameWord, renamePlus]),
          el('div', cls: 'felga-pass-line', children: [costWord, costNow, costPlus]),
          el('div', cls: 'felga-pass-line', children: [word, plus]),
          box,
        ]);
        settingsBox
          ..textContent = ''
          ..append(inner);
        _slideOpen(inner);
        return;
      }
      // Shut: everything opened in it is shut too.
      for (final p in [plus, renamePlus, costPlus]) {
        if (p.classList.contains('open')) p.click();
      }
      final inner = settingsBox.firstElementChild;
      if (inner != null) _slideShut(inner as web.HTMLElement);
    },
  );
  final settingsWord = button(tr('settings'), cls: 'felga-pass-word', onPressed: (_) => settingsPlus.click());
  return el('div', cls: 'felga-top-area', children: [
    el('div', cls: 'felga-top', children: [
      el('div', cls: 'felga-pass', children: [
        el('div', cls: 'felga-pass-line', children: [settingsWord, settingsPlus]),
        settingsBox,
        // Unseen and flat: the lines of the settings, so the column is as wide
        // shut as open and "settings +" does not move when they open.
        el('div', cls: 'felga-pass-sizer', attrs: {'aria-hidden': 'true'}, children: [
          for (final words in [tr('change name'), '${tr('felga cost')} ${formatEuro(price())}', tr('password')])
            el('div', cls: 'felga-pass-line', children: [
              el('span', cls: 'felga-pass-word', text: words),
              el('span', cls: 'felga-pass-plus'),
            ]),
        ]),
      ]),
      el('div', cls: 'felga-money', children: [money]),
    ]),
    renameBox,
    costBox,
  ]);
}

/// A name on a line ([_nameLine]): the line, its box, and [fit] to size it.
typedef _NameLine = ({web.HTMLElement line, web.HTMLInputElement input, void Function() fit});

/// A name typed on a line that grows with it, and right of it, once the box
/// is pressed, a small dart pointing at it. The dart pressed (or Enter), it
/// flies into the name and quivers there, like the dart of the welcome screen;
/// then [onConfirm] gets the name. [room]: the width the name may take.
_NameLine _nameLine({
  required String label,
  required void Function(String name) onConfirm,
  double Function()? room,
  String value = '',
  bool decimal = false,
  String? suffix,
}) {
  final input = el('input', cls: 'felga-name-input', attrs: {
    'type': 'text',
    'maxlength': decimal ? '8' : '30',
    'autocomplete': 'off',
    'enterkeyhint': 'done',
    if (decimal) 'inputmode': 'decimal',
    'aria-label': label,
  }) as web.HTMLInputElement
    ..value = value;
  // A cost: written as euros are while it is typed (a dot becomes the comma).
  if (decimal) {
    input.onInput.listen((_) {
      final text = input.value.replaceAll('.', ',');
      input.value = formatTypedEuro(text.startsWith('-') ? text.substring(1) : text);
    });
  }
  void fit() => fitToText(input, minCh: 8, room: room);
  final line = el('span', cls: 'felga-name-line${value.isEmpty ? '' : ' ready'}');
  var shooting = false;
  void shoot() {
    final typed = input.value.trim();
    if (typed.isEmpty || shooting) {
      input.focus();
      return;
    }
    shooting = true;
    if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      onConfirm(typed);
      return;
    }
    line.classList.add('shot');
    Timer(const Duration(milliseconds: dartFlightMs), () {
      line.classList.add('stuck');
      Timer(const Duration(milliseconds: dartWiggleMs), () => onConfirm(typed));
    });
  }

  final dart = button('', cls: 'felga-name-dart', ariaLabel: tr('Confirm the name'), onPressed: (_) => shoot())
    ..appendChild(dartIcon() as web.Node);
  // Pressed, the dart leaves the typing in the box (the keyboard stays up).
  dart.onMouseDown.listen((event) => event.preventDefault());
  input.onFocus.listen((_) => line.classList.add('ready'));
  input.onInput.listen((_) => fit());
  input.onKeyDown.listen((event) {
    if (event.key != 'Enter') return;
    event.preventDefault();
    shoot();
  });
  line.append(input);
  if (suffix != null) line.append(el('span', cls: 'felga-name-suffix', text: suffix));
  line.append(dart);
  return (line: line, input: input, fit: fit);
}

/// Puts [text] on the clipboard.
void _copy(String text) {
  try {
    web.window.navigator.clipboard.writeText(text);
    return;
  } on Object {
    // An older way, below.
  }
  final area = el('textarea', attrs: {'readonly': ''}) as web.HTMLTextAreaElement;
  area
    ..value = text
    ..style.position = 'fixed'
    ..style.opacity = '0';
  web.document.body!.append(area);
  area.select();
  web.document.execCommand('copy');
  area.remove();
}

/// The resets whose numbers are open in the history (by id).
final Set<String> _openResets = {};

/// A question in a popup with Yes and No; [yes] runs on Yes.
void _ask(String question, void Function() yes) =>
    _choose(question, [(tr('Yes'), yes), (tr('No'), () {})], secondLast: true);

/// A question in a popup with its [answers] side by side, each running its
/// own; the popup closes on any. [secondLast]: the last one is the quiet one.
void _choose(String question, List<(String, void Function())> answers, {bool secondLast = false}) {
  showModal(title: tr('Reset'), showTitle: false, body: [
    modalLine(question),
    el('div', cls: 'felga-ask', children: [
      for (final (i, (label, run)) in answers.indexed)
        button(label, cls: secondLast && i == answers.length - 1 ? 'cta secondary' : 'cta', onPressed: (_) {
          closeModal();
          run();
        }),
    ]),
  ]);
}

/// A line in the history, on the right: a button ([label]) and an X right of
/// it. The button opens (and closes) [numbers] under it - in its place, and
/// nothing else on the page is drawn again, so nothing above it moves. The X
/// asks [question], and the line goes in fireworks; the lines under it glide
/// up into its place ([onDelete] takes it out of the book).
web.HTMLElement _recordLine({
  required String id,
  required String label,
  required web.HTMLElement Function() numbers,
  required String question,
  required void Function() onDelete,
}) {
  final line = el('div', cls: 'felga-reset-line', attrs: {'data-reset': id});
  web.HTMLElement? shown = _openResets.contains(id) ? numbers() : null;
  late final web.HTMLButtonElement open;
  open = button(label, cls: 'felga-reset-link', attrs: {'aria-expanded': '${shown != null}'}, onPressed: (_) {
    final was = shown;
    if (was == null) {
      _openResets.add(id);
      final grown = numbers();
      shown = grown;
      line.append(grown);
      _slideOpen(grown);
    } else {
      _openResets.remove(id);
      shown = null;
      _slideShut(was);
    }
    open.setAttribute('aria-expanded', '${shown != null}');
  });
  final cross = button('', cls: 'felga-reset-x', ariaLabel: tr('Delete this record'), onPressed: (_) {
    _ask(question, () {
      _openResets.remove(id);
      _goInFireworks(line, onDelete);
    });
  })
    ..append(svg('svg', attrs: {'viewBox': '0 0 24 24', 'aria-hidden': 'true'}, children: [
      svg('path', attrs: {'d': 'M6 6 L18 18 M18 6 L6 18'}),
    ]));
  line
    ..append(el('div', cls: 'felga-reset-row', children: [open, cross]))
    ..append(shown ?? el('span', attrs: {'hidden': ''}));
  return line;
}

/// A reset: "From 01.11.2026 to 21.11.2026"; opened, every name with their
/// felgas, what they owed and what they paid, the most felgas first.
web.HTMLElement _resetLine(FelgaPeriod reset, {required void Function() onDelete}) {
  final totals = [...reset.totals]..sort((a, b) => b.felgas.compareTo(a.felgas));
  return _recordLine(
    id: reset.id,
    label: tr('From {from} to {to}', {'from': reset.from, 'to': reset.to}),
    numbers: () => el('div', cls: 'felga-reset-totals', children: [
      el('span'),
      el('span', cls: 'felga-head felgas', text: 'Felga'),
      el('span', cls: 'felga-head', text: tr('Owed')),
      el('span', cls: 'felga-head', text: tr('Paid')),
      for (final t in totals) ...[
        el('span', cls: 'felga-cell name', text: t.name),
        el('span', cls: 'felga-cell num felgas', text: '${t.felgas}'),
        el('span', cls: 'felga-cell num', text: formatEuro(t.owedCents)),
        el('span', cls: 'felga-cell num', text: formatEuro(t.paidCents)),
      ],
    ]),
    question: tr('Do you want to delete this record from planet Earth forever, really 100%?'),
    onDelete: onDelete,
  );
}

/// A day before today: "Felgas 23.11.2026"; opened, its names.
web.HTMLElement _dayLine(String date, List<FelgaDay> names, int price, {required void Function() onDelete}) =>
    _recordLine(
      id: 'day:$date',
      label: tr('Felgas {date}', {'date': date}),
      numbers: () => _dayGrid(names, price),
      question: tr('Are you sure you want to delete the felgas of {date}?', {'date': date}),
      onDelete: onDelete,
    );

/// A day's names, the most felgas first: name, felgas, what they cost.
web.HTMLElement _dayGrid(List<FelgaDay> names, int price) => el('div', cls: 'felga-grid history', children: [
      for (final day in names) ...[
        el('span', cls: 'felga-cell name', text: day.name),
        el('span', cls: 'felga-cell num felgas', text: '${day.count}'),
        el('span', cls: 'felga-cell num', text: formatEuro(day.count * price)),
      ],
    ]);

/// [box] (just put in) grows from nothing to its height.
void _slideOpen(web.HTMLElement box) {
  if (wantsLessMotion) return;
  final at = web.window.getComputedStyle(box);
  final room = (top: at.marginTop, bottom: at.marginBottom, padTop: at.paddingTop, padBottom: at.paddingBottom);
  final height = box.getBoundingClientRect().height;
  _softEdge(box, true);
  box.style
    ..overflow = 'hidden'
    ..height = '0px'
    ..marginTop = '0px'
    ..marginBottom = '0px'
    ..paddingTop = '0px'
    ..paddingBottom = '0px'
    ..opacity = '0';
  box.getBoundingClientRect(); // so that the start is drawn
  box.style
    ..transition = _slideTransition(420)
    ..height = '${height}px'
    ..marginTop = room.top
    ..marginBottom = room.bottom
    ..paddingTop = room.padTop
    ..paddingBottom = room.padBottom
    ..opacity = '1';
  Timer(const Duration(milliseconds: 440), () {
    box.style
      ..transition = ''
      ..height = ''
      ..marginTop = ''
      ..marginBottom = ''
      ..paddingTop = ''
      ..paddingBottom = ''
      ..overflow = '';
    _softEdge(box, false);
  });
}

/// Height, margins, padding and opacity, gliding over [ms].
String _slideTransition(int ms) => [
      for (final p in const ['height', 'margin-top', 'margin-bottom', 'padding-top', 'padding-bottom'])
        '$p ${ms}ms cubic-bezier(0.4, 0, 0.2, 1)',
      'opacity ${ms}ms ease',
    ].join(', ');

/// While [box] glides open or shut its lower edge is soft (it fades out over
/// its last 18px), so nothing seems to come out from behind a sharp edge.
void _softEdge(web.HTMLElement box, bool on) {
  const fade = 'linear-gradient(to bottom, #000 0, #000 calc(100% - 18px), transparent 100%)';
  for (final name in const ['mask-image', '-webkit-mask-image']) {
    if (on) {
      box.style.setProperty(name, fade);
    } else {
      box.style.removeProperty(name);
    }
  }
}

/// [box] shrinks to nothing and goes.
void _slideShut(web.HTMLElement box) {
  if (wantsLessMotion) {
    box.remove();
    return;
  }
  _softEdge(box, true);
  box.style
    ..overflow = 'hidden'
    ..height = '${box.getBoundingClientRect().height}px';
  box.getBoundingClientRect();
  box.style
    ..transition = _slideTransition(360)
    ..height = '0px'
    ..marginTop = '0px'
    ..marginBottom = '0px'
    ..paddingTop = '0px'
    ..paddingBottom = '0px'
    ..opacity = '0';
  Timer(const Duration(milliseconds: 380), () => box.remove());
}

/// A deleted reset: fireworks round [line] as it fades out; then it goes
/// ([gone] runs) and the lines under it glide up into its place over a
/// second.
void _goInFireworks(web.HTMLElement line, void Function() gone) {
  final calm = wantsLessMotion;
  line.classList.add('going');
  if (!calm) {
    // Over the line, but not in it: the sparks fly on after it is gone.
    final at = line.getBoundingClientRect();
    final sky = el('div', cls: 'felga-line-sky', attrs: {
      'aria-hidden': 'true',
      'style': 'left: ${at.left}px; top: ${at.top}px; width: ${at.width}px; height: ${at.height}px',
    }, children: [
      for (final x in const [12, 50, 88]) el('span', cls: 'felga-line-burst', attrs: {'style': 'left: $x%'}, children: [_sparks()]),
    ]);
    web.document.body!.append(sky);
    Timer(const Duration(milliseconds: 1600), () => sky.remove());
  }
  Timer(Duration(milliseconds: calm ? 0 : 700), () {
    final below = <web.HTMLElement>[];
    var sibling = line.nextElementSibling;
    while (sibling != null) {
      below.add(sibling as web.HTMLElement);
      sibling = sibling.nextElementSibling;
    }
    final tops = [for (final b in below) b.getBoundingClientRect().top];
    line.remove();
    gone();
    if (calm) return;
    for (var i = 0; i < below.length; i++) {
      final dy = tops[i] - below[i].getBoundingClientRect().top;
      below[i].style
        ..transition = 'none'
        ..transform = 'translateY(${dy}px)';
    }
    if (below.isEmpty) return;
    below.first.getBoundingClientRect();
    for (final b in below) {
      b.style
        ..transition = 'transform 1s cubic-bezier(0.4, 0, 0.2, 1)'
        ..transform = '';
    }
  });
}

/// Fireworks: 36 sparks flying out of the flash, not in a perfect circle - a
/// third of them go out to 0.8 cm from the middle, a third to 0.9 cm, a third
/// to 1 cm (1 cm is 37.8 CSS pixels), their directions a little uneven too.
/// For a -1 ([inward]) they run backwards: they appear out there, smoothly,
/// and fly into the box.
web.HTMLElement _sparks({bool inward = false, Duration age = Duration.zero}) => el('span',
        cls: 'felga-burst${inward ? ' inward' : ''}',
        attrs: {'aria-hidden': 'true', 'style': 'animation-delay: -${age.inMilliseconds}ms'},
        children: [
      for (var i = 0; i < 36; i++)
        el('i', attrs: {
          'style': '--a: ${i * 10 + const [0, 4, -3][i % 3]}deg; '
              '--d: ${const [30.2, 37.8, 34.0][i % 3]}px',
        }),
    ]);

/// A very long grey arrow across the screen (5 mm from each edge): the
/// feathers on the left, the point on the right. It parts the sections.
web.HTMLElement _arrow() => el('div', cls: 'felga-arrow', attrs: {'aria-hidden': 'true'}, children: [
      svg('svg', cls: 'arrow-feathers', attrs: {'viewBox': '0 0 30 20'}, children: [
        svg('path', attrs: {'d': 'M1 1 L29 10 L1 19 L12 10 Z M12 10 H30'}),
      ]),
      el('span', cls: 'arrow-shaft'),
    ]);
