import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

CheckoutRoute r(String text) => CheckoutRoute.parse(text);

void main() {
  final engine = CheckoutEngine();
  final optimal = OptimalRouteService(engine);

  group('routes from dartscheckoutassistant.com', () {
    test('every number with a checkout has a first-choice route', () {
      for (final n in engine.checkoutableTargets) {
        expect(siteThrowRoutes[n], isNotEmpty, reason: '$n');
      }
      expect(siteThrowRoutes.keys.toSet(), engine.checkoutableTargets.toSet());
    });

    test('every route is a legal checkout of its number', () {
      for (final map in [siteThrowRoutes, siteOtherRoutes]) {
        map.forEach((n, routes) {
          for (final text in routes) {
            final route = r(text);
            expect(route.total, n, reason: '$n $text');
            expect(engine.isLegalRoute(n, route), isTrue, reason: '$n $text');
          }
        });
      }
    });

    test('spot checks against the pages', () {
      expect(siteThrowRoutes[130], ['T20 T20 D5']);
      expect(siteOtherRoutes[130], ['S20 T20 Bull', 'T19 T19 D8']);
      expect(siteThrowRoutes[65], ['25 D20', 'T15 D10']);
      expect(siteThrowRoutes[170], ['T20 T20 Bull']);
      expect(siteThrowRoutes[40], ['D20']);
    });

    test('no route is listed twice for a number', () {
      siteThrowRoutes.forEach((n, routes) {
        final all = [...routes, ...?siteOtherRoutes[n]].map((t) => r(t));
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            expect(all.elementAt(i).isEquivalentTo(all.elementAt(j)), isFalse,
                reason: '$n ${all.elementAt(i)}');
          }
        }
      });
    });
  });

  group('the site\'s first choices are accepted next to the chart', () {
    test('82: T14 D20 as well as the chart\'s Bull D16', () {
      expect(optimal.isOptimal(82, r('T14 D20')), isTrue);
      expect(optimal.isOptimal(82, r('Bull D16')), isTrue);
    });

    test('three-dart numbers: T19 S6 D20 on 103', () {
      expect(optimal.isOptimal(103, r('T19 S6 D20')), isTrue);
      expect(optimal.isOptimal(116, r('T19 S19 D20')), isTrue);
    });

    test('130: the backup S20 T20 Bull is bull-safe, T19 T19 D8 is only an option', () {
      expect(optimal.isOptimal(130, r('S20 T20 Bull')), isTrue);
      expect(optimal.isOptimal(130, r('T19 T19 D8')), isFalse);
    });

    test('your rules win where they disagree with the site', () {
      // The site starts 50 with S10 D20, but one dart (the Bull) is fewer.
      expect(optimal.isOptimal(50, r('S10 D20')), isFalse);
      // The site's 135 starts Bull T15 D20; a route with a single (25) is better.
      expect(optimal.isOptimal(135, r('Bull T15 D20')), isFalse);
      // First box used on 62: only the bull-safe route, not the site's T10 D16.
      expect(optimal.isOptimal(62, r('T10 D16')), isFalse);
      expect(optimal.isOptimal(62, r('T12 D13')), isTrue);
    });

    test('a site route never makes a longer route optimal', () {
      for (final n in engine.checkoutableTargets) {
        for (final route in optimal.optimalRoutes(n)) {
          expect(route.length, engine.minimumDarts(n), reason: '$n $route');
        }
      }
    });
  });
}
