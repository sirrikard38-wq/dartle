import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  group('RoutePages (All possibilities: the first six, then "Shoot more")', () {
    List<int> numbers(int count) => [for (var i = 1; i <= count; i++) i];

    test('six routes show at once', () {
      expect(RoutePages.firstShown, 6);
    });

    test('six or fewer routes: all shown, nothing behind "Shoot more"', () {
      for (final count in [0, 1, 5, 6]) {
        final pages = RoutePages.split(numbers(count));
        expect(pages.first, numbers(count), reason: '$count routes');
        expect(pages.rest, isEmpty, reason: '$count routes');
      }
    });

    test('more than six: the first six, the rest behind "Shoot more", in order', () {
      final pages = RoutePages.split(numbers(14));
      expect(pages.first, [1, 2, 3, 4, 5, 6]);
      expect(pages.rest, [7, 8, 9, 10, 11, 12, 13, 14]);
      expect(RoutePages.split(numbers(7)).rest, [7]);
    });

    test('132 has more than six optimal routes, 40 has one', () {
      final engine = CheckoutEngine();
      final optimal = OptimalRouteService(engine);
      expect(RoutePages.split(optimal.optimalRoutes(132)).rest, isNotEmpty);
      expect(RoutePages.split(optimal.optimalRoutes(40)).rest, isEmpty);
    });

    test('the popup code uses it, and Close is not styled by the older .cta rule', () {
      final screen = File('lib/ui/result_screen.dart').readAsStringSync();
      expect(screen, contains('RoutePages.split'));
      expect(screen, contains('Shoot more'));
      final modal = File('lib/ui/modal.dart').readAsStringSync();
      expect(modal, contains("cls: 'modal-close'"));
      expect(modal, contains('preventScroll'));
    });
  });
}
