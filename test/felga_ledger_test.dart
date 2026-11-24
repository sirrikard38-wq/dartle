import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  test('points cost 0,50 € each; the list goes from the most points down', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..add('Miha')
      ..add('Sin')
      ..add('   ');
    expect(ledger.members, hasLength(3), reason: 'no empty name');
    final [riko, miha, sin] = ledger.members;
    riko.points = 3;
    miha.points = 5;
    sin.points = 6 - 1;
    expect(ledger.byPoints.map((m) => m.name), ['Miha', 'Sin', 'Riko']);
    expect(formatEuro(FelgaLedger().owedCents(riko)), '1,5€');
    expect(formatEuro(FelgaLedger().owedCents(miha)), '2,5€');
  });

  test('debt is what is owed less what was paid; the club has what was paid', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single..points = 3;
    riko.paidCents += parseEuroCents('1')!;
    expect(formatEuro(FelgaLedger().debtCents(riko)), '0,5€');
    riko.paidCents += parseEuroCents('-2')!;
    expect(formatEuro(FelgaLedger().debtCents(riko)), '2,5€');
    riko.paidCents += parseEuroCents('10')!;
    expect(formatEuro(FelgaLedger().debtCents(riko)), '-7,5€', reason: 'paid more than owed');
    expect(formatEuro(ledger.totalCents), '9€');
    expect(formatEuro(ledger.currentCents), '9€');
    // Total money in the club: what everyone still owes (Riko paid 7,5 more).
    ledger
      ..add('Miha')
      ..members.last.points = 4; // owes 2
    expect(formatEuro(ledger.owedTotalCents), '-5,5€');
  });

  test('money is written with a dot for thousands and a comma for decimals, as it is typed', () {
    expect(formatEuro(123456), '1.234,56€');
    expect(formatEuro(-50), '-0,5€');
    expect(formatTypedEuro('1234'), '1.234');
    expect(formatTypedEuro('1234,567'), '1.234,56');
    expect(formatTypedEuro('-1000000'), '-1.000.000');
    expect(formatTypedEuro('12,'), '12,');
    expect(parseEuroCents('1.234,5'), 123450);
    expect(parseEuroCents(''), isNull);
    expect(parseEuroCents('-'), isNull);
  });

  test('what each paid is listed by debt, the most first', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..add('Miha')
      ..add('Sin');
    final [riko, miha, sin] = ledger.members;
    riko.points = 3; // owes 1,5
    miha
      ..points = 5
      ..paidCents = 400; // owes -1,5 (paid more)
    sin.points = 2; // owes 1
    expect(ledger.byDebt.map((m) => m.name), ['Riko', 'Sin', 'Miha']);
    sin.points = 3; // owes 1,5, like Riko: Riko was added first
    expect(ledger.byDebt.map((m) => m.name), ['Riko', 'Sin', 'Miha']);
  });

  test('the history: each name and day with its felgas, the latest -1 / +1 at the top', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..add('Miha');
    final [riko, miha] = ledger.members;
    final monday = DateTime(2026, 11, 23, 20), tuesday = DateTime(2026, 11, 24, 21);
    ledger
      ..step(riko, 1, monday)
      ..step(riko, 1, monday)
      ..step(miha, 1, monday)
      ..step(riko, 1, monday); // Riko again: his line goes back to the top
    String lines() => ledger.currentDays.map((d) => '${d.name} ${d.date} ${d.count}').join(', ');
    expect(lines(), 'Riko 23.11.2026 3, Miha 23.11.2026 1');
    expect(riko.points, 3);
    ledger.step(miha, 1, tuesday);
    expect(lines(), 'Miha 24.11.2026 1, Riko 23.11.2026 3, Miha 23.11.2026 1');
    ledger.step(miha, -1, tuesday); // a mistake taken back: nothing that day
    expect(lines(), 'Riko 23.11.2026 3, Miha 23.11.2026 1');
    expect(miha.points, 1);
    // A day below zero is not written; it still counts: -1, +1 is 0, then +1.
    final wednesday = DateTime(2026, 11, 25);
    ledger.step(riko, -1, wednesday);
    expect(lines(), 'Riko 23.11.2026 3, Miha 23.11.2026 1');
    ledger.step(riko, 1, wednesday);
    expect(lines(), 'Riko 23.11.2026 3, Miha 23.11.2026 1');
    ledger.step(riko, 1, wednesday);
    expect(lines(), 'Riko 25.11.2026 1, Riko 23.11.2026 3, Miha 23.11.2026 1');
    // One line for each name and day.
    expect(ledger.history.where((d) => d.name == 'Riko' && d.date == '25.11.2026'), hasLength(1));
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.currentDays.map((d) => '${d.name} ${d.date} ${d.count}').join(', '), lines());
  });

  test('reset: everything back to 0; what there was is kept "From the first day to the reset"', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..add('Miha')
      ..add('Sin');
    final [riko, miha, sin] = ledger.members;
    final monday = DateTime(2026, 11, 23), tuesday = DateTime(2026, 11, 24);
    ledger
      ..step(riko, 1, monday)
      ..step(riko, 1, monday)
      ..step(miha, 1, monday)
      ..step(riko, 1, tuesday)
      ..step(miha, -1, tuesday);
    riko.paidCents = 100;
    ledger.leftCents = 300;
    expect(ledger.sameDaysAs(tuesday), isNull);
    ledger.reset(tuesday);
    expect([for (final m in ledger.members) m.points], [0, 0, 0]);
    expect([for (final m in ledger.members) m.paidCents], [0, 0, 0]);
    expect(ledger.leftCents, 0);
    expect(ledger.members.map((m) => m.name), ['Riko', 'Miha', 'Sin'], reason: 'the names stay');
    expect(ledger.history, isEmpty, reason: 'the days are gone');
    String totals(FelgaPeriod p) => p.totals.map((t) => '${t.name} ${t.felgas} ${t.owedCents} ${t.paidCents}').join(', ');
    final kept = ledger.periods.single;
    expect('${kept.from} - ${kept.to}', '23.11.2026 - 24.11.2026');
    expect(totals(kept), 'Riko 3 50 100, Miha 0 0 0, Sin 0 0 0', reason: 'felgas, still owed, paid');
    // After the reset a day starts a new line, even the same day.
    ledger.step(riko, 1, tuesday);
    expect(ledger.currentDays.single.count, 1);
    // The next reset: from its first day; the latest first.
    ledger.reset(DateTime(2026, 11, 30));
    expect(ledger.periods.map((p) => '${p.from} - ${p.to}'), ['24.11.2026 - 30.11.2026', '23.11.2026 - 24.11.2026']);
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.periods.map(totals), ledger.periods.map(totals));
    expect(back.periods.map((p) => p.id), ledger.periods.map((p) => p.id));
    expect(sin.points, 0);
    // Taken away for good.
    ledger.deletePeriod(ledger.periods.first);
    expect(ledger.periods.single, same(kept));
  });

  test('a reset with the same days as one kept: added to it, or thrown away', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single;
    final monday = DateTime(2026, 11, 23);
    ledger
      ..step(riko, 1, monday)
      ..reset(monday)
      ..step(riko, 1, monday);
    expect(ledger.sameDaysAs(monday), same(ledger.periods.single));
    ledger.reset(monday, keep: FelgaResetKeep.merge);
    expect(ledger.periods.single.totals.single.felgas, 2);
    expect(ledger.periods.single.totals.single.owedCents, 100);
    ledger
      ..step(riko, 1, monday)
      ..reset(monday, keep: FelgaResetKeep.discard);
    expect(ledger.periods.single.totals.single.felgas, 2);
    expect(riko.points, 0);
  });

  test('felgas never go below 0', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single;
    expect(ledger.step(riko, -1, DateTime(2026, 11, 23)), isFalse);
    expect(riko.points, 0);
    expect(ledger.history, isEmpty);
    expect(ledger.step(riko, 1, DateTime(2026, 11, 23)), isTrue);
    expect(riko.points, 1);
  });

  test('kept before "From ... to ...": a reset "Up to" a day comes back from that day to it', () {
    final ledger = FelgaLedger.fromJson('{"members": [{"name": "Riko", "points": 1}], "history": ['
        '{"name": "Riko", "date": "25.11.2026", "count": 1}, '
        '{"reset": "24.11.2026", "totals": {"Riko": 3}}, '
        '{"name": "Riko", "date": "20.11.2026", "count": 2}]}');
    expect(ledger.currentDays.map((d) => d.date), ['25.11.2026']);
    final kept = ledger.periods.single;
    expect('${kept.from} - ${kept.to}', '24.11.2026 - 24.11.2026');
    expect(kept.totals.single.felgas, 3);
  });

  test('it is kept and read back', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..leftCents = 1250;
    ledger.members.single
      ..points = 4
      ..paidCents = 300;
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.members.single.name, 'Riko');
    expect(back.members.single.points, 4);
    expect(back.members.single.paidCents, 300);
    expect(back.leftCents, 1250);
    expect(FelgaLedger.fromJson('nonsense').members, isEmpty);
    // "Club money" kept before is left out.
    expect(FelgaLedger.fromJson('{"club": -400, "spent": 400, "members": []}').leftCents, 0);
  });

  test('a name taken out: gone from the lists, its days stay; its money stays in the club, its debt goes', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..add('Miha');
    final [riko, miha] = ledger.members;
    final day = DateTime(2026, 11, 24);
    ledger
      ..step(riko, 1, day)
      ..step(riko, 1, day)
      ..step(miha, 1, day)
      ..step(miha, 1, day)
      ..step(miha, 1, day);
    riko.paidCents = 100;
    miha.paidCents = 50; // owes 1€ more
    expect(formatEuro(ledger.currentCents), '1,5€');
    expect(formatEuro(ledger.owedTotalCents), '1€');
    ledger.remove(miha);
    expect(ledger.members.map((m) => m.name), ['Riko']);
    expect(formatEuro(ledger.currentCents), '1,5€', reason: 'the money in the club is the same');
    expect(formatEuro(ledger.owedTotalCents), '0€', reason: 'what Miha owed is owed no more');
    expect(ledger.history.map((d) => '${d.name} ${d.count}'), ['Miha 3', 'Riko 2'], reason: 'the history stays');
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.currentCents, ledger.currentCents);
  });

  test('a cost per felga: for every felga, or only for the felgas from now on', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single;
    final day = DateTime(2026, 11, 24);
    for (var i = 0; i < 6; i++) {
      ledger.step(riko, 1, day);
    }
    expect(formatEuro(ledger.owedCents(riko)), '3€', reason: '0,50€ a felga at first');
    ledger.setPrice(25, applyToAll: true);
    expect(formatEuro(ledger.owedCents(riko)), '1,5€', reason: '6 felgas at 0,25€');
    ledger.step(riko, 1, day);
    expect(formatEuro(ledger.owedCents(riko)), '1,75€');
    ledger.setPrice(100, applyToAll: false);
    expect(formatEuro(ledger.owedCents(riko)), '1,75€', reason: 'the felgas before keep their cost');
    ledger.step(riko, 1, day);
    expect(formatEuro(ledger.owedCents(riko)), '2,75€', reason: 'a new one costs 1€');
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.priceCents, 100);
    expect(back.owedCents(back.members.single), ledger.owedCents(riko));
  });

  test('a name changes, in the history too', () {
    final ledger = FelgaLedger()..add('Miha');
    final miha = ledger.members.single;
    ledger
      ..step(miha, 1, DateTime(2026, 11, 24))
      ..rename(miha, ' Mihovil ');
    expect(miha.name, 'Mihovil');
    expect(ledger.history.single.name, 'Mihovil');
  });

  test('a day is taken out of the history; the felgas stay', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single;
    ledger
      ..step(riko, 1, DateTime(2026, 11, 23))
      ..step(riko, 1, DateTime(2026, 11, 24))
      ..deleteDay('23.11.2026');
    expect(ledger.history.map((d) => d.date), ['24.11.2026']);
    expect(riko.points, 2);
  });
}
