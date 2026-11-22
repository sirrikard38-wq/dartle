import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
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

  // The + under the names: pressed, it turns into an X (over a second) and
  // the box for a new name comes under it; the X takes the box away.
  web.HTMLElement toggleButton() => _turningPlus(
        cls: 'felga-toggle',
        focusKey: 'felga-toggle',
        open: _adding,
        openLabel: tr('Stop adding names'),
        closedLabel: tr('Add a name'),
        onToggle: (open) {
          _adding = open;
          if (open) {
            openNameBox(focus: true);
          } else {
            fill(newNamePart, []);
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
    // The two sums one under the other: the words end under each other, the
    // amounts too (the € under the €), a little apart; the two in the middle.
    fill(moneyPart, [
      el('div', cls: 'felga-money', children: [
        el('span', cls: 'felga-money-words', text: tr('Owed to the club')),
        el('strong', text: formatEuro(ledger.owedTotalCents)),
        el('span', cls: 'felga-money-words', text: tr('Money in the club now')),
        el('strong', text: formatEuro(ledger.currentCents)),
      ]),
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
              textNode(formatEuro(FelgaLedger.owedCents(member))),
              if (_latest((f) => f.member == member) case final press?)
                flash(el('span', cls: 'felga-delta', text: press.by > 0 ? '+1' : '-1'), press),
            ]),
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
            flash(el('span', cls: 'felga-name', text: member.name), _latest((f) => f.member == member)),
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
            el('span', cls: 'felga-cell name', text: member.name, attrs: {'data-row': 'p:${member.name}'}),
            moneyBox(tr('{name} paid', {'name': member.name}), (cents) {
              member.paidCents += cents;
              changed();
            })
              ..setAttribute('data-row', 'p:${member.name}'),
            el('span',
                cls: 'felga-cell num',
                text: formatEuro(FelgaLedger.debtCents(member)),
                attrs: {'data-row': 'p:${member.name}'}),
            el('span',
                cls: 'felga-cell num',
                text: formatEuro(member.paidCents),
                attrs: {'data-row': 'p:${member.name}'}),
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
      // Reset, asked twice: everything back to 0; what there was stays as a
      // line "From ... to ...". One with the same days already there: add
      // them up, or delete these for good?
      button(tr('Reset'), cls: 'felga-reset-all', focusKey: 'felga-reset', onPressed: (_) {
        _ask(tr('Are you sure you want to reset all the data?'), () {
          _ask(
              tr('Are you really 100% million billion percent sure you want to reset the data? '
                  'The history will stay.'), () {
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
    // The history: each -1 / +1 since the last reset under the name and the
    // day, with that day's felgas of the name, the latest at the top; at the
    // very foot, on the right, a button for each reset ("From 01.11.2026 to
    // 21.11.2026"), the latest first.
    final days = ledger.currentDays, resets = ledger.periods;
    fill(historyPart, [
      if (days.isNotEmpty || resets.isNotEmpty) ...[
        _arrow(),
        el('h3', cls: 'felga-title', text: tr('Felgas by date')),
        el('div', cls: 'felga-history', children: [
          if (days.isNotEmpty)
            el('div', cls: 'felga-grid history', children: [
              for (final day in days) ...[
                el('span', cls: 'felga-cell name', text: day.name),
                el('span', cls: 'felga-cell date', text: day.date),
                el('span', cls: 'felga-cell num felgas', text: '${day.count}'),
              ],
            ]),
          if (resets.isNotEmpty)
            el('div', cls: 'felga-resets', children: [
              for (final reset in resets)
                _resetLine(reset, onDelete: () {
                  ledger.deletePeriod(reset);
                  _save(ledger);
                  // The last line gone: the history goes too.
                  if (ledger.periods.isEmpty && ledger.currentDays.isEmpty) refresh();
                }),
            ]),
        ]),
      ],
    ]);
    slideRows(before);
  };

  refresh();
  if (_adding) openNameBox(focus: false);
  return el('main', cls: 'screen felga', children: [
    _lockPart(_open.password),
    moneyPart,
    owesPart,
    namesPart,
    togglePart,
    newNamePart,
    paidPart,
    clubPart,
    historyPart,
  ]);
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

/// The Felgalizacije on this device, in the order they were made; the first
/// one (no name) is always there. One kept before passwords gets one now.
List<FelgaEntry> felgaList() {
  var list = <FelgaEntry>[];
  var changed = false;
  try {
    final saved = web.window.localStorage.getItem(_listKey);
    if (saved != null) {
      list = [
        for (final e in (jsonDecode(saved) as List<Object?>).cast<Map<String, Object?>>())
          FelgaEntry(e['id'] as String, e['name'] as String? ?? '', e['password'] as String? ?? ''),
      ];
    }
  } on Object {
    list = [];
  }
  if (list.isEmpty) {
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
  return list.where((e) => e.id == id).firstOrNull ?? list.first;
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
/// the name its maker gave it, the two in the middle one under the other),
/// then a +. Pressed, the + turns into an X and under it come the word with a
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

  void fillPanel({required bool focus}) {
    final name = el('input', cls: 'felga-name-input', attrs: {
      'type': 'text',
      'maxlength': '30',
      'autocomplete': 'off',
      'enterkeyhint': 'done',
      'aria-label': tr('Name of the Felgalizacija'),
    }) as web.HTMLInputElement;
    void fit() => name.style.width = '${math.max(8, name.value.length + 2)}ch';
    fit();
    name.onInput.listen((_) => fit());
    name.onKeyDown.listen((event) {
      if (event.key != 'Enter') return;
      event.preventDefault();
      final typed = name.value.trim();
      if (typed.isEmpty) return;
      _saveList([...felgaList(), FelgaEntry('${DateTime.now().millisecondsSinceEpoch}', typed, _newPassword())]);
      _menuAdding = false;
      ctx.rerender();
    });

    final password = el('input', cls: 'felga-pass-input', attrs: {
      'type': 'text',
      'maxlength': '10',
      'autocomplete': 'off',
      'autocapitalize': 'off',
      'autocorrect': 'off',
      'spellcheck': 'false',
      'enterkeyhint': 'go',
      'placeholder': tr('password'),
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

    panel
      ..textContent = ''
      ..append(el('div', cls: 'felga-naming', children: [lines('', name)]))
      ..append(el('p', cls: 'felga-join-question', text: tr('Do you have a password to join?')))
      ..append(password);
    // At once, still in the press: so the phone's keyboard comes up.
    if (focus) name.focus();
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
        fillPanel(focus: true);
      } else {
        panel.textContent = '';
      }
    },
  );
  if (_menuAdding) fillPanel(focus: false);

  return [
    for (final entry in list)
      button('',
          cls: 'menu-btn felga-btn',
          focusKey: 'felga-${entry.id}',
          ariaLabel: entry.name.isEmpty ? 'Felgalizacija' : 'Felgalizacija ${entry.name}',
          onPressed: (_) {
            _menuAdding = false;
            openFelga(ctx, entry);
          })
        ..append(lines(entry.name)),
    plus,
    panel,
  ];
}

/// At the top of a Felgalizacija: an arrow and a lock. Pressed, the arrow
/// flies into the lock and the password shows under it; pressed, the password
/// is copied ("Copied" shows for 1.5 s and fades away). It is hidden again once
/// it is scrolled out of sight, or the page is left.
web.HTMLElement _lockPart(String password) {
  final part = el('div', cls: 'felga-lock-part');
  StreamSubscription<web.Event>? watch;
  void hide() {
    watch?.cancel();
    watch = null;
    part.classList
      ..remove('open')
      ..remove('hit');
  }

  late final web.HTMLButtonElement shown;
  final lock = button('', cls: 'felga-lock', ariaLabel: tr('Show the password'), onPressed: (_) {
    if (part.classList.contains('hit')) return;
    part.classList.add('hit');
    Timer(Duration(milliseconds: wantsLessMotion ? 0 : 750), () {
      if (!part.classList.contains('hit')) return;
      part.classList.add('open');
      watch = web.EventStreamProviders.scrollEvent.forTarget(web.window).listen((_) {
        if (!part.isConnected) {
          hide();
          return;
        }
        final at = shown.getBoundingClientRect();
        if (at.bottom < 0 || at.top > web.window.innerHeight) hide();
      });
    });
  })
    ..append(svg('svg', attrs: {'viewBox': '0 0 64 26', 'aria-hidden': 'true'}, children: [
      svg('g', cls: 'lock-arrow', children: [
        svg('path', attrs: {'d': 'M2 15 H27 M22 10.5 L27.5 15 L22 19.5 M2 11 L6 15 L2 19 M6 11 L10 15 L6 19'}),
      ]),
      svg('g', cls: 'lock-body', children: [
        svg('path', attrs: {'d': 'M45 12 V8.5 a6 6 0 0 1 12 0 V12'}),
        svg('rect', attrs: {'x': '41', 'y': '12', 'width': '20', 'height': '12', 'rx': '2.5'}),
        svg('path', attrs: {'d': 'M51 16.5 V19.5'}),
      ]),
    ]));

  shown = button(password, cls: 'felga-password', ariaLabel: tr('Copy the password'), onPressed: (_) {
    _copy(password);
    final note = el('span', cls: 'felga-copied', text: tr('Copied'), attrs: {'role': 'status'});
    part.append(note);
    Timer(const Duration(milliseconds: 1500), () => note.remove());
  });
  return part
    ..append(lock)
    ..append(shown);
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

/// A reset in the history: a button "From 01.11.2026 to 21.11.2026" and an X
/// right of it. The button opens (and closes) every name with their felgas,
/// what they owed and what they paid, the most felgas first - it opens and
/// closes in its place and nothing else on the page is drawn again, so
/// nothing above it moves. The X asks, and the line goes in fireworks; the
/// lines under it glide up into its place ([onDelete] takes it out of the
/// book).
web.HTMLElement _resetLine(FelgaPeriod reset, {required void Function() onDelete}) {
  final totals = [...reset.totals]..sort((a, b) => b.felgas.compareTo(a.felgas));
  web.HTMLElement numbers() => el('div', cls: 'felga-reset-totals', children: [
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
      ]);

  final line = el('div', cls: 'felga-reset-line', attrs: {'data-reset': reset.id});
  web.HTMLElement? shown = _openResets.contains(reset.id) ? numbers() : null;
  late final web.HTMLButtonElement open;
  open = button(tr('From {from} to {to}', {'from': reset.from, 'to': reset.to}),
      cls: 'felga-reset-link',
      attrs: {'aria-expanded': '${shown != null}'},
      onPressed: (_) {
        final was = shown;
        if (was == null) {
          _openResets.add(reset.id);
          final grown = numbers();
          shown = grown;
          line.append(grown);
          _slideOpen(grown);
        } else {
          _openResets.remove(reset.id);
          shown = null;
          _slideShut(was);
        }
        open.setAttribute('aria-expanded', '${shown != null}');
      });
  final cross = button('', cls: 'felga-reset-x', ariaLabel: tr('Delete this record'), onPressed: (_) {
    _ask(tr('Do you want to delete this record from planet Earth forever, really 100%?'), () {
      _openResets.remove(reset.id);
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

/// [box] (just put in) grows from nothing to its height.
void _slideOpen(web.HTMLElement box) {
  if (wantsLessMotion) return;
  final height = box.scrollHeight;
  box.style
    ..overflow = 'hidden'
    ..height = '0px'
    ..opacity = '0';
  box.getBoundingClientRect(); // so that the start is drawn
  box.style
    ..transition = 'height 260ms ease, opacity 260ms ease'
    ..height = '${height}px'
    ..opacity = '1';
  Timer(const Duration(milliseconds: 280), () {
    box.style
      ..transition = ''
      ..height = ''
      ..overflow = '';
  });
}

/// [box] shrinks to nothing and goes.
void _slideShut(web.HTMLElement box) {
  if (wantsLessMotion) {
    box.remove();
    return;
  }
  box.style
    ..overflow = 'hidden'
    ..height = '${box.getBoundingClientRect().height}px';
  box.getBoundingClientRect();
  box.style
    ..transition = 'height 220ms ease, opacity 220ms ease'
    ..height = '0px'
    ..opacity = '0';
  Timer(const Duration(milliseconds: 240), () => box.remove());
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
        svg('path', attrs: {'d': 'M1 3 L10 10 L1 17 M9 3 L18 10 L9 17 M17 3 L26 10 L17 17 M10 10 H30'}),
      ]),
      el('span', cls: 'arrow-shaft'),
      svg('svg', cls: 'arrow-point', attrs: {'viewBox': '0 0 18 20'}, children: [
        svg('path', attrs: {'d': 'M0 10 H4 M0 3 L18 10 L0 17 L5 10 Z'}),
      ]),
    ]);
