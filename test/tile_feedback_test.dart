import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

List<TileState> eval(String guess, String answer) => TileFeedback.evaluate(
    CheckoutRoute.parse(guess).darts, CheckoutRoute.parse(answer));

void main() {
  const c = TileState.correct, p = TileState.present, a = TileState.absent;

  test('exact match is all correct', () {
    expect(eval('T20 D6', 'T20 D6'), [c, c]);
  });

  test('swapping the finisher into setup is present, not correct', () {
    expect(eval('D6 T20', 'T20 D6'), [p, p]);
  });

  test('setup darts are order-independent (a combination)', () {
    expect(eval('T19 T20 D8', 'T20 T19 D8'), [c, c, c]);
    expect(eval('T19 T20 D8', 'T20 T19 D8'), eval('T20 T19 D8', 'T20 T19 D8'));
    expect(eval('T19 S1 D8', 'T20 T19 D8'), [c, a, c]);
  });

  test('unrelated darts are absent', () {
    expect(eval('S1 D1', 'T20 D6'), [a, a]);
    expect(eval('T20 D5', 'T20 D6'), [c, a]);
  });

  test('repeated darts are counted like Wordle', () {
    // Answer has one T20; the second guessed T20 must not be present.
    expect(eval('T20 T20 D5', 'T20 T19 D6'), [c, a, a]);
    expect(eval('S20 T20 D5', 'T20 T20 D6'), [a, c, a]);
    expect(eval('T20 T20 Bull', 'T20 T20 Bull'), [c, c, c]);
  });

  test('best() uses the closest acceptable route', () {
    final guess = CheckoutRoute.parse('T16 D12').darts;
    final routes = [CheckoutRoute.parse('T20 D6'), CheckoutRoute.parse('T16 D12')];
    expect(TileFeedback.best(guess, routes), [c, c]);
  });

  test('shorter or empty guesses are safe', () {
    expect(TileFeedback.evaluate(const [], CheckoutRoute.parse('D20')), isEmpty);
    expect(eval('T20', 'T20 D6'), [c]);
  });
}
