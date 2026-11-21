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
