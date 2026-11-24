import 'dart:convert';
import 'dart:math' as math;

/// One person of Felgalizacija: points (+1 / -1) and the money they paid in.
class FelgaMember {
  FelgaMember(this.name, {this.points = 0, this.paidCents = 0, this.adjustCents = 0, this.uid});

  String name;
  int points;

  /// The account (the device's online sign-in) this name belongs to; null
  /// while nobody has said "that is me" (not "synced").
  String? uid;

  /// What their felgas cost beyond the cost of a felga now (below zero: less),
  /// from felgas counted at an earlier cost that was not applied to them.
  int adjustCents;

  /// Everything entered as paid, added up (it can go below zero).
  int paidCents;
}

/// One line of the history: [name]'s felgas on [date] (-1 and +1 of that
/// day added up).
class FelgaDay {
  FelgaDay(this.name, this.date, this.count);

  String name;

  /// The day, written dd.mm.yyyy.
  final String date;
  int count;
}

/// One name in a reset: their felgas, what they still owed and what they had
/// paid when it was reset.
class FelgaTotal {
  FelgaTotal(this.name, {this.felgas = 0, this.owedCents = 0, this.paidCents = 0});

  final String name;
  int felgas;
  int owedCents;
  int paidCents;
}

/// A reset: from the first day with felgas to the day it was reset, every
/// name with their felgas, what they owed and what they paid.
class FelgaPeriod {
  FelgaPeriod({required this.id, required this.from, required this.to, required this.totals});

  /// Tells it apart from the others (two can have the same days).
  final String id;

  /// The days, written dd.mm.yyyy.
  final String from;
  final String to;
  final List<FelgaTotal> totals;

  bool sameDays(FelgaPeriod other) => from == other.from && to == other.to;

  /// Adds [other]'s numbers to these, name by name (a name only in [other]
  /// comes in at the end).
  void addAll(FelgaPeriod other) {
    for (final t in other.totals) {
      final mine = totals.where((m) => m.name == t.name).firstOrNull;
      if (mine == null) {
        totals.add(FelgaTotal(t.name, felgas: t.felgas, owedCents: t.owedCents, paidCents: t.paidCents));
      } else {
        mine
          ..felgas += t.felgas
          ..owedCents += t.owedCents
          ..paidCents += t.paidCents;
      }
    }
  }
}

/// What a reset does with the numbers it takes away: keeps them as a new
/// line ([record]), adds them to the line of the same days ([merge]), or
/// throws them away for good ([discard]).
enum FelgaResetKeep { record, merge, discard }

/// [day] written as the history shows it: 21.11.2026.
String felgaDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';

/// 21.11.2026 back as a day; null when it is not one.
DateTime? _readDate(String date) {
  final parts = [for (final p in date.split('.')) int.tryParse(p)];
  if (parts.length != 3 || parts.contains(null)) return null;
  return DateTime(parts[2]!, parts[1]!, parts[0]!);
}

/// Felgalizacija: names with points, what each owes (a point is 0,50 €),
/// what each has paid, and the club's money: everything paid, with what was
/// added to it or spent from it.
class FelgaLedger {
  FelgaLedger({
    List<FelgaMember>? members,
    this.leftCents = 0,
    this.priceCents = defaultPriceCents,
    List<FelgaDay>? history,
    List<FelgaPeriod>? periods,
  })  : members = members ?? [],
        history = history ?? [],
        periods = periods ?? [];

  /// What a felga costs until another cost is set.
  static const int defaultPriceCents = 50;

  /// What a felga costs now ("cost").
  int priceCents;

  /// A new cost of a felga: for every felga already counted too ([applyToAll])
  /// or only for the felgas from now on - those before keep their cost.
  void setPrice(int cents, {required bool applyToAll}) {
    if (cents <= 0) return;
    for (final m in members) {
      m.adjustCents = applyToAll ? 0 : m.adjustCents + m.points * (priceCents - cents);
    }
    priceCents = cents;
  }

  /// [member] is called [name] (trimmed) from now on, in the history too.
  void rename(FelgaMember member, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == member.name) return;
    for (final d in history) {
      if (d.name == member.name) d.name = trimmed;
    }
    member.name = trimmed;
  }

  final List<FelgaMember> members;

  /// What the names taken out of the Felgalizacija had paid: it stays in the
  /// club's money.
  int leftCents;

  /// The history since the last reset: one line for each name and day -
  /// every -1 and +1 of that day added up in it - the latest -1 / +1 first.
  final List<FelgaDay> history;

  /// The resets, the latest first.
  final List<FelgaPeriod> periods;

  /// The days as they are shown: only those with felgas (a day that came to 0
  /// is not written), the latest first.
  List<FelgaDay> get currentDays => [for (final d in history) if (d.count > 0) d];

  /// What a reset on [day] would keep: from the first day with felgas (or
  /// [day], with none) to [day], each name with their felgas, what they still
  /// owe and what they paid.
  FelgaPeriod periodUpTo(DateTime day) {
    DateTime? first;
    for (final d in currentDays) {
      final date = _readDate(d.date);
      if (date != null && (first == null || date.isBefore(first))) first = date;
    }
    return FelgaPeriod(
      id: '${DateTime.now().microsecondsSinceEpoch}-${periods.length}',
      from: felgaDate(first ?? day),
      to: felgaDate(day),
      totals: [
        for (final m in members) FelgaTotal(m.name, felgas: m.points, owedCents: debtCents(m), paidCents: m.paidCents),
      ],
    );
  }

  /// The reset already kept with the same days as one on [day] would have;
  /// null for none.
  FelgaPeriod? sameDaysAs(DateTime day) {
    final next = periodUpTo(day);
    return periods.where(next.sameDays).firstOrNull;
  }

  /// Reset: every name's felgas, what they paid and the club money go back
  /// to 0 (the names stay) and the days leave the history. What there was is
  /// kept as a line "From ... to ..." ([keep]: or added to the line of the
  /// same days, or thrown away).
  void reset(DateTime day, {FelgaResetKeep keep = FelgaResetKeep.record}) {
    final period = periodUpTo(day);
    switch (keep) {
      case FelgaResetKeep.record:
        periods.insert(0, period);
      case FelgaResetKeep.merge:
        final same = periods.where(period.sameDays).firstOrNull;
        if (same == null) {
          periods.insert(0, period);
        } else {
          same.addAll(period);
        }
      case FelgaResetKeep.discard:
        break;
    }
    history.clear();
    for (final m in members) {
      m
        ..points = 0
        ..paidCents = 0
        ..adjustCents = 0;
    }
    leftCents = 0;
  }

  /// Takes [member] out: gone from the lists, still in the history; what
  /// they paid stays in the club's money, and what they still owed is owed to
  /// the club no more.
  void remove(FelgaMember member) {
    if (!members.remove(member)) return;
    leftCents += member.paidCents;
  }

  /// Takes the felgas of [date] (dd.mm.yyyy) out of the history; nobody's
  /// felgas change.
  void deleteDay(String date) => history.removeWhere((d) => d.date == date);

  /// Takes [period] out of the history for good.
  void deletePeriod(FelgaPeriod period) => periods.remove(period);

  /// [member] got [by] felgas (+1 or -1) on [day]: their points change, and
  /// so does their one line of that day in the history, which goes to the
  /// top. Felgas never go below 0: a -1 then does nothing (false). The line
  /// keeps counting below 1 (a -1 and then a +1 on a day make 0), it is just
  /// not shown then.
  bool step(FelgaMember member, int by, DateTime day) {
    if (member.points + by < 0) return false;
    member.points += by;
    // No felgas left: nothing from an earlier cost either.
    if (member.points == 0) member.adjustCents = 0;
    final date = felgaDate(day);
    final i = history.indexWhere((d) => d.name == member.name && d.date == date);
    final line = i < 0 ? FelgaDay(member.name, date, 0) : history.removeAt(i);
    line.count += by;
    history.insert(0, line);
    return true;
  }

  /// Adds [name] (trimmed), the name of [uid] when given; nothing for an
  /// empty one.
  void add(String name, {String? uid}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    members.add(FelgaMember(trimmed, uid: uid));
  }

  /// The member that is [uid]'s name; null for none.
  FelgaMember? memberOf(String uid) => members.where((m) => m.uid == uid).firstOrNull;

  /// The names nobody has said "that is me" of yet.
  List<FelgaMember> get unsynced => [for (final m in members) if (m.uid == null) m];

  /// The maker of a Felgalizacija kept before it went online: the name
  /// [name] becomes [uid]'s, if nobody has one yet and no name is [uid]'s.
  bool claimByName(String name, String uid) {
    if (memberOf(uid) != null) return false;
    final mine = members.where((m) => m.uid == null && m.name == name.trim()).firstOrNull;
    if (mine == null) return false;
    mine.uid = uid;
    return true;
  }

  /// Everything [other] has, taken over: a name in both stays the same
  /// [FelgaMember] here (so what is open on the screen for it still works).
  void takeFrom(FelgaLedger other) {
    final kept = {for (final m in members) m.name: m};
    members
      ..clear()
      ..addAll([
        for (final o in other.members)
          if (kept[o.name] case final m?)
            (m
              ..points = o.points
              ..paidCents = o.paidCents
              ..adjustCents = o.adjustCents
              ..uid = o.uid)
          else
            o,
      ]);
    history
      ..clear()
      ..addAll(other.history);
    periods
      ..clear()
      ..addAll(other.periods);
    leftCents = other.leftCents;
    priceCents = other.priceCents;
  }

  /// Two phones changed the same Felgalizacija: [theirs] is what is online
  /// now, [mine] what this one made of [base] (what both had last). The
  /// answer is [theirs] with everything [mine] changed since [base] put on
  /// top: each name's felgas and payments go up and down by as much as they
  /// did here (so a +1 here and a +1 there make +2), names added here come
  /// in, names taken out here go, and so do the days and resets deleted here;
  /// a new cost or a new reset here is kept. [mine]'s objects are used in it.
  static FelgaLedger merged(FelgaLedger base, FelgaLedger mine, FelgaLedger theirs) {
    final out = FelgaLedger.fromJson(theirs.toJson());
    FelgaMember? named(FelgaLedger book, String name) => book.members.where((m) => m.name == name).firstOrNull;

    for (final b in base.members) {
      if (named(mine, b.name) == null) {
        // Taken out here: what they paid is already in [leftCents]'s change.
        final there = named(out, b.name);
        if (there != null) out.members.remove(there);
      }
    }
    for (final m in mine.members) {
      final b = named(base, m.name);
      final there = named(out, m.name);
      if (there == null) {
        if (b == null) out.members.add(m); // added here; one taken out there stays out
        continue;
      }
      there
        ..points = math.max(0, there.points + m.points - (b?.points ?? 0))
        ..paidCents += m.paidCents - (b?.paidCents ?? 0)
        ..adjustCents += m.adjustCents - (b?.adjustCents ?? 0);
      if (m.uid != null && m.uid != b?.uid) there.uid = m.uid;
    }

    int count(FelgaLedger book, String name, String date) =>
        book.history.where((d) => d.name == name && d.date == date).fold(0, (sum, d) => sum + d.count);
    void change(String name, String date, {required bool toTop}) {
      final by = count(mine, name, date) - count(base, name, date);
      if (by == 0) return;
      final i = out.history.indexWhere((d) => d.name == name && d.date == date);
      if (!toTop && i >= 0) {
        out.history[i].count += by;
        return;
      }
      final line = i < 0 ? FelgaDay(name, date, 0) : out.history.removeAt(i);
      line.count += by;
      out.history.insert(0, line);
    }

    // The lines changed here go to the top, the latest of them first.
    final seen = <String>{};
    for (final d in mine.history.reversed) {
      if (seen.add('${d.name}\n${d.date}')) change(d.name, d.date, toTop: true);
    }
    for (final d in base.history) {
      if (seen.add('${d.name}\n${d.date}')) change(d.name, d.date, toTop: false);
    }

    if (mine.priceCents != base.priceCents) out.priceCents = mine.priceCents;
    out.leftCents += mine.leftCents - base.leftCents;

    final baseIds = {for (final p in base.periods) p.id: jsonEncode(_periodJson(p))};
    final mineIds = {for (final p in mine.periods) p.id};
    out.periods.removeWhere((p) => baseIds.containsKey(p.id) && !mineIds.contains(p.id));
    for (final p in mine.periods.reversed) {
      final i = out.periods.indexWhere((o) => o.id == p.id);
      if (!baseIds.containsKey(p.id)) {
        if (i < 0) out.periods.insert(0, p);
      } else if (baseIds[p.id] != jsonEncode(_periodJson(p)) && i >= 0) {
        out.periods[i] = p;
      }
    }
    return out;
  }

  /// What [member] owes for their points.
  int owedCents(FelgaMember member) => member.points * priceCents + member.adjustCents;

  /// Still to pay: what they owe less what they paid (below zero: paid more).
  int debtCents(FelgaMember member) => owedCents(member) - member.paidCents;

  /// Everything paid in.
  int get totalCents => members.fold(0, (sum, m) => sum + m.paidCents);

  /// "Owed to the club": what everyone still owes, added up (the column Owed;
  /// one who paid more counts below zero).
  int get owedTotalCents => members.fold(0, (sum, m) => sum + debtCents(m));

  /// "Money in the club now": everything paid in, with whatever was entered
  /// by names since taken out ([leftCents]).
  int get currentCents => totalCents + leftCents;

  /// The members by points, most first (equal points keep the order they were
  /// added in).
  List<FelgaMember> get byPoints => _sortedBy((m) => m.points);

  /// The members by what they still owe, most first (below zero last; equal
  /// debts keep the order they were added in).
  List<FelgaMember> get byDebt => _sortedBy(debtCents);

  List<FelgaMember> _sortedBy(int Function(FelgaMember member) value) {
    final indexed = [for (var i = 0; i < members.length; i++) (i, members[i])];
    indexed.sort((a, b) {
      final most = value(b.$2).compareTo(value(a.$2));
      return most != 0 ? most : a.$1.compareTo(b.$1);
    });
    return [for (final (_, m) in indexed) m];
  }

  String toJson() => jsonEncode({
        'left': leftCents,
        'price': priceCents,
        'members': [
          for (final m in members)
            {
              'name': m.name,
              'points': m.points,
              'paid': m.paidCents,
              'adjust': m.adjustCents,
              if (m.uid != null) 'uid': m.uid,
            },
        ],
        'history': [
          for (final d in history) {'name': d.name, 'date': d.date, 'count': d.count},
        ],
        'periods': [for (final p in periods) _periodJson(p)],
      });

  static Map<String, Object?> _periodJson(FelgaPeriod p) => {
        'id': p.id,
        'from': p.from,
        'to': p.to,
        'totals': [
          for (final t in p.totals) {'name': t.name, 'felgas': t.felgas, 'owed': t.owedCents, 'paid': t.paidCents},
        ],
      };

  /// From [toJson]; an empty ledger for anything it cannot read. Kept before
  /// "From ... to ...", each reset was a line "Up to" a day among the days
  /// (with the felgas only): it comes back as a reset from that day to it,
  /// and the days after it in the list (from before it) are left out.
  static FelgaLedger fromJson(String? text) {
    if (text == null) return FelgaLedger();
    try {
      final data = jsonDecode(text) as Map<String, Object?>;
      final days = <FelgaDay>[];
      final periods = <FelgaPeriod>[];
      var beforeReset = true;
      final lines = (data['history'] as List<Object?>? ?? const []).cast<Map<String, Object?>>();
      for (var i = 0; i < lines.length; i++) {
        final d = lines[i];
        if (d['reset'] case final String date) {
          beforeReset = false;
          periods.add(FelgaPeriod(id: 'old-$i', from: date, to: date, totals: [
            for (final MapEntry(:key, :value) in (d['totals'] as Map<String, Object?>? ?? const {}).entries)
              FelgaTotal(key, felgas: (value as num?)?.toInt() ?? 0),
          ]));
        } else if (beforeReset) {
          days.add(FelgaDay(d['name'] as String, d['date'] as String, (d['count'] as num?)?.toInt() ?? 0));
        }
      }
      for (final p in (data['periods'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
        periods.add(FelgaPeriod(
          id: p['id'] as String,
          from: p['from'] as String,
          to: p['to'] as String,
          totals: [
            for (final t in (p['totals'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
              FelgaTotal(t['name'] as String,
                  felgas: (t['felgas'] as num?)?.toInt() ?? 0,
                  owedCents: (t['owed'] as num?)?.toInt() ?? 0,
                  paidCents: (t['paid'] as num?)?.toInt() ?? 0),
          ],
        ));
      }
      return FelgaLedger(
        // "Club money" (kept as 'club' or 'spent') is no more: left out.
        leftCents: (data['left'] as num?)?.toInt() ?? 0,
        priceCents: (data['price'] as num?)?.toInt() ?? defaultPriceCents,
        members: [
          for (final m in (data['members'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
            FelgaMember(m['name'] as String,
                points: (m['points'] as num?)?.toInt() ?? 0,
                paidCents: (m['paid'] as num?)?.toInt() ?? 0,
                adjustCents: (m['adjust'] as num?)?.toInt() ?? 0,
                uid: m['uid'] as String?),
        ],
        history: days,
        periods: periods,
      );
    } on Object {
      return FelgaLedger();
    }
  }
}

/// Euros as written in Croatia: a dot for thousands, a comma for decimals, no
/// decimals when there are none and no trailing zero: 1,5€, 2€, 1.234,56€,
/// -0,5€.
String formatEuro(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = _groupThousands('${abs ~/ 100}');
  final rest = abs % 100;
  var decimals = '';
  if (rest != 0) {
    decimals = ',${rest.toString().padLeft(2, '0')}';
    if (decimals.endsWith('0')) decimals = decimals.substring(0, decimals.length - 1);
  }
  return '${negative ? '-' : ''}$whole$decimals€';
}

String _groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// What is typed into a money box, written as it should look while typing: a
/// minus only at the start, digits grouped by dots, one comma and at most two
/// decimals after it ("1234,5" -> "1.234,5"; "-50" stays "-50").
String formatTypedEuro(String typed) {
  final negative = typed.trimLeft().startsWith('-');
  final comma = typed.indexOf(',');
  final wholeRaw = (comma < 0 ? typed : typed.substring(0, comma)).replaceAll(RegExp(r'[^0-9]'), '');
  final whole = wholeRaw.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  var out = '${negative ? '-' : ''}${_groupThousands(whole)}';
  if (comma >= 0) {
    final decimals = typed.substring(comma + 1).replaceAll(RegExp(r'[^0-9]'), '');
    out += ',${decimals.length > 2 ? decimals.substring(0, 2) : decimals}';
  }
  return out;
}

/// The cents in a money box ("1.234,5" -> 123450, "-2" -> -200); null when
/// there is no number in it.
int? parseEuroCents(String typed) {
  final formatted = formatTypedEuro(typed);
  final negative = formatted.startsWith('-');
  final body = negative ? formatted.substring(1) : formatted;
  final parts = body.split(',');
  final whole = parts.first.replaceAll('.', '');
  final decimals = parts.length > 1 ? parts[1] : '';
  if (whole.isEmpty && decimals.isEmpty) return null;
  final cents = int.parse(whole.isEmpty ? '0' : whole) * 100 + int.parse(decimals.padRight(2, '0'));
  return negative ? -cents : cents;
}
