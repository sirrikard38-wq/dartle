import 'dart:convert';

/// One person of Felgalizacija: points (+1 / -1) and the money they paid in.
class FelgaMember {
  FelgaMember(this.name, {this.points = 0, this.paidCents = 0});

  final String name;
  int points;

  /// Everything entered as paid, added up (it can go below zero).
  int paidCents;
}

/// One line of the history: [name]'s felgas on [date] (-1 and +1 of that
/// day added up) - or a reset on [date], with [totals]: every name's felgas
/// since the reset before it, added up.
class FelgaDay {
  FelgaDay(this.name, this.date, this.count, {this.totals});

  /// A reset on [date].
  FelgaDay.reset(this.date, Map<String, int> this.totals)
      : name = '',
        count = 0;

  final String name;

  /// The day, written dd.mm.yyyy.
  final String date;
  int count;

  /// For a reset: each name's felgas since the reset before, added up; null
  /// for a day.
  final Map<String, int>? totals;

  bool get isReset => totals != null;
}

/// [day] written as the history shows it: 21.11.2026.
String felgaDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';

/// Felgalizacija: names with points, what each owes (a point is 0,50 €),
/// what each has paid, and the club's money: everything paid, with what was
/// added to it or spent from it.
class FelgaLedger {
  FelgaLedger({List<FelgaMember>? members, this.clubCents = 0, List<FelgaDay>? history})
      : members = members ?? [],
        history = history ?? [];

  /// One point costs this many cents.
  static const int centsPerPoint = 50;

  final List<FelgaMember> members;

  /// "Club money": every amount entered for the club, added up - below zero
  /// spent, above zero added.
  int clubCents;

  /// The history: one line for each name and day - every -1 and +1 of that
  /// day added up in it - the latest -1 / +1 first.
  final List<FelgaDay> history;

  /// The days since the last reset as they are shown: only those with felgas
  /// (a day that came to 0 or below is not written), the latest first.
  List<FelgaDay> get currentDays {
    final lastReset = history.indexWhere((d) => d.isReset);
    final since = lastReset < 0 ? history.length : lastReset;
    return [for (final d in history.sublist(0, since)) if (!d.isReset && d.count > 0) d];
  }

  /// The resets, the latest first.
  List<FelgaDay> get resets => [for (final d in history) if (d.isReset) d];

  /// Reset: every name's felgas, what they paid and the club money go back
  /// to 0 (the names stay). The days since the last reset leave the history;
  /// in their place one line stays, the reset: its date and each name's
  /// felgas of those days added up (since the reset before, not more).
  void reset(DateTime day) {
    final totals = <String, int>{for (final m in members) m.name: 0};
    final lastReset = history.indexWhere((d) => d.isReset);
    final since = lastReset < 0 ? history.length : lastReset;
    for (final d in history.sublist(0, since)) {
      if (d.count > 0) totals[d.name] = (totals[d.name] ?? 0) + d.count;
    }
    history
      ..removeRange(0, since)
      ..insert(0, FelgaDay.reset(felgaDate(day), totals));
    for (final m in members) {
      m
        ..points = 0
        ..paidCents = 0;
    }
    clubCents = 0;
  }

  /// [member] got [by] felgas (+1 or -1) on [day]: their points change, and
  /// so does their one line of that day in the history, which goes to the
  /// top. The line keeps counting below 1 too (a -1 and then a +1 on a day
  /// make 0), it is just not shown then.
  void step(FelgaMember member, int by, DateTime day) {
    member.points += by;
    final date = felgaDate(day);
    // Only since the last reset: a day line from before it stays as it was.
    final lastReset = history.indexWhere((d) => d.isReset);
    final since = lastReset < 0 ? history.length : lastReset;
    final i = history.sublist(0, since).indexWhere((d) => d.name == member.name && d.date == date);
    final line = i < 0 ? FelgaDay(member.name, date, 0) : history.removeAt(i);
    line.count += by;
    history.insert(0, line);
  }

  /// Adds [name] (trimmed); nothing for an empty one.
  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    members.add(FelgaMember(trimmed));
  }

  /// What [member] owes for their points.
  static int owedCents(FelgaMember member) => member.points * centsPerPoint;

  /// Still to pay: what they owe less what they paid (below zero: paid more).
  static int debtCents(FelgaMember member) => owedCents(member) - member.paidCents;

  /// Everything paid in.
  int get totalCents => members.fold(0, (sum, m) => sum + m.paidCents);

  /// "Owed to the club": what everyone still owes, added up (the column Owed;
  /// one who paid more counts below zero).
  int get owedTotalCents => members.fold(0, (sum, m) => sum + debtCents(m));

  /// "Money in the club now": everything paid in, with whatever was entered
  /// as club money ([clubCents]: above zero added, below zero spent).
  int get currentCents => totalCents + clubCents;

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
        'club': clubCents,
        'members': [
          for (final m in members) {'name': m.name, 'points': m.points, 'paid': m.paidCents},
        ],
        'history': [
          for (final d in history)
            if (d.isReset) {'reset': d.date, 'totals': d.totals} else {'name': d.name, 'date': d.date, 'count': d.count},
        ],
      });

  /// From [toJson]; an empty ledger for anything it cannot read.
  static FelgaLedger fromJson(String? text) {
    if (text == null) return FelgaLedger();
    try {
      final data = jsonDecode(text) as Map<String, Object?>;
      return FelgaLedger(
        // Before "Club money" it was what was spent: that much below zero.
        clubCents: (data['club'] as num?)?.toInt() ?? -((data['spent'] as num?)?.toInt() ?? 0),
        members: [
          for (final m in (data['members'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
            FelgaMember(m['name'] as String,
                points: (m['points'] as num?)?.toInt() ?? 0, paidCents: (m['paid'] as num?)?.toInt() ?? 0),
        ],
        history: [
          for (final d in (data['history'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
            if (d['reset'] case final String date)
              FelgaDay.reset(date, {
                for (final MapEntry(:key, :value) in (d['totals'] as Map<String, Object?>? ?? const {}).entries)
                  key: (value as num?)?.toInt() ?? 0,
              })
            else
              FelgaDay(d['name'] as String, d['date'] as String, (d['count'] as num?)?.toInt() ?? 0),
        ],
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
