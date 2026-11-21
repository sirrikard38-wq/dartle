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
    expect(formatEuro(FelgaLedger.owedCents(riko)), '1,5€');
    expect(formatEuro(FelgaLedger.owedCents(miha)), '2,5€');
  });

  test('debt is what is owed less what was paid; the club has what was paid, with what was added or spent', () {
    final ledger = FelgaLedger()..add('Riko');
    final riko = ledger.members.single..points = 3;
    riko.paidCents += parseEuroCents('1')!;
    expect(formatEuro(FelgaLedger.debtCents(riko)), '0,5€');
    riko.paidCents += parseEuroCents('-2')!;
    expect(formatEuro(FelgaLedger.debtCents(riko)), '2,5€');
    riko.paidCents += parseEuroCents('10')!;
    expect(formatEuro(FelgaLedger.debtCents(riko)), '-7,5€', reason: 'paid more than owed');
    ledger.clubCents += parseEuroCents('-3,25')!; // spent
    expect(formatEuro(ledger.totalCents), '9€');
    expect(formatEuro(ledger.currentCents), '5,75€');
    ledger.clubCents += parseEuroCents('10')!; // added
    expect(formatEuro(ledger.currentCents), '15,75€');
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

  test('reset: everything back to 0; the days since the last reset become one line with their totals', () {
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
      ..step(miha, -1, tuesday); // below 0 that day: not counted
    riko.paidCents = 100;
    ledger.clubCents = -300;
    ledger.reset(tuesday);
    expect([for (final m in ledger.members) m.points], [0, 0, 0]);
    expect([for (final m in ledger.members) m.paidCents], [0, 0, 0]);
    expect(ledger.clubCents, 0);
    expect(ledger.members.map((m) => m.name), ['Riko', 'Miha', 'Sin'], reason: 'the names stay');
    expect(ledger.currentDays, isEmpty, reason: 'the days of before are gone');
    final mark = ledger.resets.single;
    expect(mark.date, '24.11.2026');
    expect(mark.totals, {'Riko': 3, 'Miha': 1, 'Sin': 0});
    // After the reset a day starts a new line, even the same day.
    ledger.step(riko, 1, tuesday);
    expect(ledger.currentDays.single.count, 1);
    expect(ledger.currentDays.single.name, 'Riko');
    // A second reset counts only since the first one; the latest is first.
    ledger.reset(DateTime(2026, 11, 30));
    expect(ledger.resets.map((r) => r.date), ['30.11.2026', '24.11.2026']);
    expect(ledger.resets.first.totals, {'Riko': 1, 'Miha': 0, 'Sin': 0});
    expect(ledger.currentDays, isEmpty);
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.resets.first.totals, {'Riko': 1, 'Miha': 0, 'Sin': 0});
    expect(back.resets.last.totals, {'Riko': 3, 'Miha': 1, 'Sin': 0});
    expect(sin.points, 0);
  });

  test('it is kept and read back', () {
    final ledger = FelgaLedger()
      ..add('Riko')
      ..clubCents = -1250;
    ledger.members.single
      ..points = 4
      ..paidCents = 300;
    final back = FelgaLedger.fromJson(ledger.toJson());
    expect(back.members.single.name, 'Riko');
    expect(back.members.single.points, 4);
    expect(back.members.single.paidCents, 300);
    expect(back.clubCents, -1250);
    expect(FelgaLedger.fromJson('nonsense').members, isEmpty);
    // Saved before "Club money": what was spent comes back below zero.
    expect(FelgaLedger.fromJson('{"spent": 400, "members": []}').clubCents, -400);
  });
}
