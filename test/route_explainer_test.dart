import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

CheckoutRoute r(String text) => CheckoutRoute.parse(text);

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);
  final catalog = CheckoutCatalog(engine, optimal);
  final advisor = ChoiceAdvisor(engine, optimal);

  List<String> explain(int target,
      {String? player, bool correct = true, bool isOptimal = false, String? mistake}) {
    return RouteExplainer.explain(
      challenge: catalog.forTarget(target)!,
      optimalRoutes: optimal.optimalRoutes(target),
      playerRoute: player == null ? null : r(player),
      playerCorrect: correct,
      playerOptimal: isOptimal,
      mistake: mistake,
    );
  }

  String text(List<String> lines) => lines.join('\n');

  group('RouteExplainer', () {
    test('a number with no checkout', () {
      final lines = RouteExplainer.explain(
        challenge: catalog.impossible.first,
        optimalRoutes: const [],
      );
      expect(text(lines), contains('cannot be checked out'));
      expect(text(lines), contains('No checkout'));
    });

    test('67 with the first box used explains the bull-safe rule with the right numbers', () {
      final out = text(explain(67));
      expect(out, contains('Bull-safe'));
      expect(out, contains('single 17 leaves exactly 50'));
      expect(out, contains('triple 17 (51) and then D8'));
      expect(out, contains('S17 and then the Bull'));
      expect(out, contains('T17 D8'));
    });

    test('up to 60 it is a single that leaves a better double, not the Bull', () {
      final out = text(explain(57));
      expect(out, contains('a single that leaves a better double'));
      expect(out, isNot(contains('Bull-safe')));
      expect(out, contains('S17 D20'));
    });

    test('a three-dart number with a bull-safe first dart', () {
      final out = text(explain(119));
      expect(out, contains('Bull-safe'));
      expect(out, contains('should leave 51 to 70'));
      expect(out, contains('T20 T9 D16 or T20 S9 Bull'));
    });

    test('a three-dart number whose first dart would leave 51 to 54 has no bull-safe route there', () {
      final out = text(explain(108));
      expect(out, isNot(contains('T19 S1 Bull')));
    });

    test('35: neighbouring singles win', () {
      final out = text(explain(35));
      expect(out, contains('two neighbouring singles'));
    });

    test('85: no single can do it, so triples', () {
      final out = text(explain(85));
      expect(out, contains('No single can do the job'));
      expect(out, contains('T15 to T20'));
    });

    test('one dart', () {
      expect(text(explain(40)), contains('One dart finishes it: D20.'));
    });

    test('a better double is mentioned when one is available', () {
      expect(text(explain(35)), contains('better double'));
    });

    test('an optimal player route is confirmed', () {
      final out = text(explain(57, player: 'S17 D20', isOptimal: true));
      expect(out, contains('Your route S17 D20 is one of the optimal routes.'));
    });

    test('a route that is not optimal says why: fewer singles', () {
      final out = text(explain(47, player: 'T5 D16')); // S5 would leave 42: no treble route here
      expect(out, contains('checks out, but it is not optimal'));
      expect(out, contains('0 singles where the best routes have 1'));
      expect(out, contains('T5 is not a sensible aim'));
    });

    test('a route that is not optimal says why: not bull-safe', () {
      final out = text(explain(67, player: 'T19 D5'));
      expect(out, contains('bull-safe'));
    });

    test('a route that is not optimal says why: too many darts', () {
      final out = text(explain(57, player: 'S20 S17 D10'));
      expect(out, contains('uses 3 darts, and the fewest is 2'));
    });

    test('a wrong answer repeats what went wrong', () {
      final out = text(explain(72,
          player: 'T20 D5', correct: false, mistake: '60 + 10 = 70. Incorrect.'));
      expect(out, contains('do not check out'));
      expect(out, contains('60 + 10 = 70'));
    });

    test('every checkoutable number has an explanation that names its optimal routes', () {
      for (final target in engine.checkoutableTargets) {
        final c = catalog.forTarget(target)!;
        final routes = optimal.optimalRoutes(target);
        final out = text(RouteExplainer.explain(challenge: c, optimalRoutes: routes));
        expect(out, contains(routes.first.notation), reason: '$target');
      }
    });
  });

  group('Only possible checkout', () {
    test('numbers with exactly one legal route', () {
      for (final t in [170, 167, 156, 153]) {
        expect(advisor.hasOnlyOneCheckout(t), isTrue, reason: '$t');
      }
      for (final t in [160, 100, 40, 164]) {
        expect(advisor.hasOnlyOneCheckout(t), isFalse, reason: '$t');
      }
    });
  });
}
