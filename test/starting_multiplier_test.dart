import 'package:dartle/dartle.dart';
import 'package:dartle/ui/view_context.dart';
import 'package:test/test.dart';

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);

  group('which ring is toggled when a checkout starts', () {
    test('Triple when the best route has a triple in it', () {
      for (final target in [72, 85, 119, 130, 170]) {
        final challenge = catalog.forTarget(target)!;
        expect(challenge.optimalRoute.trebleCount, greaterThan(0), reason: '$target');
        expect(ViewContext.startingMultiplier(challenge), Multiplier.treble, reason: '$target');
      }
    });

    test('Triple for a number with no checkout', () {
      for (final challenge in catalog.impossible) {
        expect(challenge.hasCheckout, isFalse);
        expect(ViewContext.startingMultiplier(challenge), Multiplier.treble,
            reason: '${challenge.target}');
      }
      expect(catalog.impossible.map((c) => c.target), [159, 162, 163, 165, 166, 168, 169]);
    });

    test('Single (nothing picked) when the best route has no triple', () {
      for (final target in [35, 42, 40, 50]) {
        final challenge = catalog.forTarget(target)!;
        expect(challenge.optimalRoute.trebleCount, 0, reason: '$target');
        expect(ViewContext.startingMultiplier(challenge), isNull, reason: '$target');
      }
    });

    test('nothing on screen: nothing picked', () {
      expect(ViewContext.startingMultiplier(null), isNull);
    });
  });
}
