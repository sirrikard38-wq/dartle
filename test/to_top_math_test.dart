import 'package:dartle/ui/to_top_math.dart';
import 'package:test/test.dart';

/// The little dart that shoots you back to the top: when it shows, how long the
/// flight takes, and how the page and the dart move and fade.
void main() {
  group('when the dart shows', () {
    bool at(double y, {double viewport = 800, double page = 6000}) =>
        isAtEnd(scrollY: y, viewportHeight: viewport, pageHeight: page);

    test('at the end of the page', () {
      expect(at(5200), isTrue); // 5200 + 800 = 6000
    });

    test('a little before the very end still counts', () {
      expect(at(5200 - atEndSlackPx), isTrue);
      expect(at(5200 - atEndSlackPx - 1), isFalse);
    });

    test('not while the page is higher up', () {
      expect(at(100), isFalse);
      expect(at(3000), isFalse);
    });

    test('never at the top, even when the whole page fits on the screen', () {
      expect(at(0, viewport: 800, page: 700), isFalse);
      expect(at(0), isFalse);
    });
  });

  group('the flight', () {
    test('a longer way takes longer, but never goes quicker than a blink or slower than 1.5 s', () {
      var last = 0;
      for (final distance in [1.0, 100.0, 600.0, 2000.0, 6000.0, 20000.0]) {
        final ms = flightMs(distance);
        expect(ms, inInclusiveRange(300, 1500), reason: '$distance px');
        expect(ms, greaterThanOrEqualTo(last), reason: '$distance px');
        last = ms;
      }
    });

    test('progress runs from 0 to 1 and stays there', () {
      expect(progressAt(0, 800), 0);
      expect(progressAt(400, 800), 0.5);
      expect(progressAt(800, 800), 1);
      expect(progressAt(5000, 800), 1);
      expect(progressAt(-30, 800), 0);
      expect(progressAt(10, 0), 1);
    });

    test('both easings start at 0, end at 1 and only ever go forward', () {
      for (final ease in [easeInOut, easeOut]) {
        expect(ease(0), 0);
        expect(ease(1), 1);
        var last = -1.0;
        for (var i = 0; i <= 100; i++) {
          final v = ease(i / 100);
          expect(v, greaterThanOrEqualTo(last), reason: 'at ${i / 100}');
          last = v;
        }
      }
    });

    test('the page starts where it is and ends exactly at the top', () {
      expect(pageY(5200, 0), 5200);
      expect(pageY(5200, 1), 0);
      expect(pageY(5200, 0.5), closeTo(2600, 1e-9)); // halfway through, halfway up
    });

  });

  group('the dart goes up through the middle of the page', () {
    test('it starts in its corner and is in the middle from reachesMiddleAt on', () {
      expect(dartX(50, 400, 0), 50);
      expect(dartX(50, 400, reachesMiddleAt), closeTo(400, 1e-9));
      expect(dartX(50, 400, 0.7), closeTo(400, 1e-9));
      expect(dartX(50, 400, 1), closeTo(400, 1e-9));
    });

    test('it slides across and never back, and then keeps to the middle line', () {
      var last = 50.0;
      for (var i = 0; i <= 100; i++) {
        final x = dartX(50, 400, i / 100);
        expect(x, greaterThanOrEqualTo(last), reason: 'at ${i / 100}');
        if (i / 100 >= reachesMiddleAt) expect(x, closeTo(400, 1e-9), reason: 'at ${i / 100}');
        last = x;
      }
    });

    test('it works from either side of the middle', () {
      expect(dartX(700, 400, 0), 700);
      expect(dartX(700, 400, 1), closeTo(400, 1e-9));
    });

    test('it climbs from where it rests to where it stops, fast first and slowing at the end', () {
      expect(dartY(700, 90, 0), 700);
      expect(dartY(700, 90, 1), closeTo(90, 1e-9));
      // More than half the way up before the flight is half over.
      expect(700 - dartY(700, 90, 0.5), greaterThan((700 - 90) / 2));
      var last = 700.0;
      for (var i = 0; i <= 100; i++) {
        final y = dartY(700, 90, i / 100);
        expect(y, lessThanOrEqualTo(last), reason: 'at ${i / 100}');
        last = y;
      }
    });
  });

  group('the circle it sticks in at the top', () {
    test('its tip is 70 of the 72 units along: 26.4px above the middle of the 56px dart', () {
      expect(dartLengthPx, 56);
      expect(tipAboveMiddlePx, closeTo(26.44, 0.01));
    });

    test('half a centimetre is 18.9px, the distance the welcome dart flies', () {
      expect(halfCmPx, closeTo(18.9, 0.05));
    });

    test('the flight ends half a centimetre short of the circle, and the last half centimetre is the shot', () {
      const circle = 14.0;
      expect(dartStopY(circle) - dartStuckY(circle), closeTo(halfCmPx, 1e-9));
      // The dart is below the circle (heights count down the screen) and points up.
      expect(dartStopY(circle), greaterThan(dartStuckY(circle)));
      // Stuck: its tip, above its middle, is exactly in the middle of the circle.
      expect(dartStuckY(circle) - tipAboveMiddlePx, closeTo(circle, 1e-9));
    });

    test('the circle is near the top of the screen', () {
      expect(stickBelowTopPx, inInclusiveRange(8, 30));
    });
  });
}
