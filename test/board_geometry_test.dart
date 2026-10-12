import 'dart:math' as math;

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

DartThrow d(String text) => DartThrow.parse(text);

double radiusOf(BoardPoint p) =>
    math.sqrt(math.pow(p.x - boardCentre, 2) + math.pow(p.y - boardCentre, 2));

void main() {
  group('overlap maths', () {
    test('identical marks overlap fully, far apart marks not at all', () {
      const a = BoardPoint(100, 100);
      expect(markOverlap(a, a), closeTo(1, 1e-9));
      expect(markOverlap(a, const BoardPoint(100 + 2 * markRadius, 100)), 0);
      expect(markOverlap(a, const BoardPoint(500, 500)), 0);
    });

    test('the distance for half the area is about 0.8 of a radius', () {
      final distance = markDistanceForOverlap(0.5);
      expect(distance / markRadius, closeTo(0.808, 0.01));
      expect(markOverlap(const BoardPoint(0, 0), BoardPoint(distance, 0)), closeTo(0.5, 0.005));
    });

    test('markDistanceForOverlap inverts markOverlap across the range', () {
      for (final f in [0.1, 0.3, 0.45, 0.5, 0.55, 0.8]) {
        final distance = markDistanceForOverlap(f);
        expect(markOverlap(const BoardPoint(0, 0), BoardPoint(distance, 0)), closeTo(f, 0.005));
      }
    });
  });

  group('segmentCenter and snapToRing', () {
    test('the middle of each ring is where its mark goes', () {
      expect(radiusOf(segmentCenter(d('T20'))), closeTo(BoardZone.trebleRing.middle, 1e-6));
      expect(radiusOf(segmentCenter(d('D20'))), closeTo(BoardZone.doubleRing.middle, 1e-6));
      // A single goes in the outer single area, the one farther from the bull.
      expect(radiusOf(segmentCenter(d('S20'))), closeTo(BoardZone.outerSingle.middle, 1e-6));
      expect(radiusOf(segmentCenter(d('Bull'))), 0);
    });

    test('a press is moved onto the ring that was thrown', () {
      final deepInside = polarPoint(40, 0);
      expect(radiusOf(snapToRing(Multiplier.treble, deepInside)),
          closeTo(BoardZone.trebleRing.middle, 1e-6));
      expect(radiusOf(snapToRing(Multiplier.double, deepInside)),
          closeTo(BoardZone.doubleRing.middle, 1e-6));
      // Already on the ring: kept exactly.
      final onRing = polarPoint(BoardZone.trebleRing.inner + 1, 0.05);
      expect(snapToRing(Multiplier.treble, onRing), same(onRing));
    });
  });

  group('the same dart twice goes side by side', () {
    test('a different dart is not moved', () {
      final wanted = segmentCenter(d('T18'));
      final placed = spreadMark(d('T18'), wanted, [segmentCenter(d('T20'))], math.Random(1));
      expect(placed, same(wanted));
    });

    test('a first dart is not moved', () {
      final wanted = segmentCenter(d('T18'));
      expect(spreadMark(d('T18'), wanted, const [], math.Random(1)), same(wanted));
    });

    test('T18 T18: the marks share 45-55% of their area and stay in the treble area', () {
      for (var seed = 0; seed < 300; seed++) {
        final random = math.Random(seed);
        final first = segmentCenter(d('T18'));
        final second = spreadMark(d('T18'), first, [first], random);
        final overlap = markOverlap(first, second);
        expect(overlap, inInclusiveRange(markOverlapMin - 0.005, markOverlapMax + 0.005),
            reason: 'seed $seed: overlap $overlap');
        final r = radiusOf(second);
        expect(r, inInclusiveRange(BoardZone.trebleRing.inner, BoardZone.trebleRing.outer),
            reason: 'seed $seed left the treble ring');
        // within the 18 wedge
        final slot = boardOrder.indexOf(18);
        var diff = math.atan2(second.x - boardCentre, -(second.y - boardCentre)) - slot * wedgeAngle;
        while (diff > math.pi) {
          diff -= 2 * math.pi;
        }
        while (diff < -math.pi) {
          diff += 2 * math.pi;
        }
        expect(diff.abs(), lessThanOrEqualTo(wedgeAngle / 2), reason: 'seed $seed left the wedge');
      }
    });

    test('the placement is random: different seeds give different spots', () {
      final first = segmentCenter(d('S20'));
      final spots = {
        for (var seed = 0; seed < 40; seed++)
          spreadMark(d('S20'), first, [first], math.Random(seed)).x.toStringAsFixed(2),
      };
      expect(spots.length, greaterThan(10));
    });

    test('works in every ring, on the bulls, and for every number', () {
      final darts = [
        for (var n = 1; n <= 20; n++) ...[d('S$n'), d('D$n'), d('T$n')],
        d('Bull'),
        d('25'),
      ];
      for (final dart in darts) {
        final first = segmentCenter(dart);
        final second = spreadMark(dart, first, [first], math.Random(dart.hashCode));
        final overlap = markOverlap(first, second);
        expect(overlap, inInclusiveRange(markOverlapMin - 0.005, markOverlapMax + 0.005),
            reason: '$dart overlap $overlap');
      }
    });

    test('a pressed spot that is far from the first mark is still moved beside it', () {
      final first = segmentCenter(d('S20'));
      // pressed elsewhere in the same single area
      final pressed = polarPoint(BoardZone.outerSingle.middle + 6, 0.06);
      final placed = spreadMark(d('S20'), pressed, [first], math.Random(5));
      expect(markOverlap(first, placed), inInclusiveRange(0.44, 0.56));
    });

    test('the same dart in a DIFFERENT area (inner vs outer single) is left alone', () {
      final outer = segmentCenter(d('S20'));
      final inner = polarPoint(BoardZone.innerSingle.middle, 0);
      expect(spreadMark(d('S20'), inner, [outer], math.Random(1)), same(inner));
    });

    test('a third mark sits beside both, each pair sharing about half', () {
      var best = 1.0;
      for (var seed = 0; seed < 100; seed++) {
        final random = math.Random(seed);
        final first = segmentCenter(d('S20'));
        final second = spreadMark(d('S20'), first, [first], random);
        final third = spreadMark(d('S20'), first, [first, second], random);
        final a = markOverlap(first, third);
        final b = markOverlap(second, third);
        expect(a, lessThanOrEqualTo(markOverlapMax + 0.01), reason: 'seed $seed');
        expect(b, lessThanOrEqualTo(markOverlapMax + 0.01), reason: 'seed $seed');
        expect(a + b, greaterThan(0.6), reason: 'seed $seed: third is not beside the others');
        best = math.min(best, math.min(a, b));
      }
      expect(best, greaterThan(0.2));
    });

    test('spreadMarks keeps recorded marks and spreads the rest', () {
      final route = [d('T20'), d('T20'), d('D5')];
      final spread = spreadMarks(route, const [], math.Random(3));
      expect(spread, hasLength(3));
      expect(markOverlap(spread[0], spread[1]),
          inInclusiveRange(markOverlapMin - 0.005, markOverlapMax + 0.005));
      // D5 is a different dart: left on the middle of its own area.
      expect(spread[2].x, closeTo(segmentCenter(d('D5')).x, 1e-9));

      const kept = BoardPoint(10, 10);
      final withRecorded = spreadMarks(route, [kept], math.Random(3));
      expect(withRecorded[0], same(kept));
    });

    test('the same seed always gives the same placement (stable redraws)', () {
      final route = [d('T20'), d('T20'), d('D5')];
      final a = spreadMarks(route, const [], math.Random(99));
      final b = spreadMarks(route, const [], math.Random(99));
      for (var i = 0; i < 3; i++) {
        expect(a[i].x, b[i].x);
        expect(a[i].y, b[i].y);
      }
    });
  });
}
