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

    test('the dart rises only part of the screen, so it never goes to the top of it', () {
      expect(riseFraction, inExclusiveRange(0.2, 0.6));
      for (final height in [400.0, 568.0, 812.0, 1080.0]) {
        final rise = dartRisePx(height);
        expect(rise, closeTo(height * riseFraction, 1e-9));
        // It starts in the bottom corner (its middle is about 48px above the bottom,
        // see .to-top) and stops well below the top of the screen: its tip, 26px
        // above its middle, stays in the lower part of the screen.
        final stoppingMiddle = height - 48 - rise;
        expect(stoppingMiddle - 26.5, greaterThan(height * 0.25), reason: '$height px high');
      }
    });

    test('the dart leaves fast: it has climbed more than half before the flight is half over', () {
      expect(dartLift(700, 0), 0);
      expect(dartLift(700, 1), 700);
      expect(dartLift(700, 0.5), greaterThan(350));
    });
  });

  group('the dart fades', () {
    test('fully there at first, gone exactly when the page reaches the top', () {
      expect(dartOpacity(0), 1);
      expect(dartOpacity(fadeStart), 1);
      expect(dartOpacity(1), 0);
    });

    test('and smoothly in between: never brighter, never a jump', () {
      var last = 1.0;
      for (var i = 0; i <= 200; i++) {
        final v = dartOpacity(i / 200);
        expect(v, lessThanOrEqualTo(last), reason: 'at ${i / 200}');
        expect(last - v, lessThan(0.05), reason: 'a jump at ${i / 200}');
        last = v;
      }
    });
  });
}
