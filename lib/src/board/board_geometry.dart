import 'dart:math' as math;

import '../domain/dart_throw.dart';

/// Standard dartboard number order, clockwise starting at the top.
const List<int> boardOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

/// A position on the board, in the SVG's 400 x 400 coordinate space.
class BoardPoint {
  const BoardPoint(this.x, this.y);
  final double x;
  final double y;
}

// ---- Dartboard proportions ---------------------------------------------------
// Based on a regulation board, measured from the centre in millimetres (board
// radius 170, bull 6.35, outer bull 15.9, treble and double rings 8 wide). The
// real ones are too small to see and press on a screen, so the bulls are drawn
// [_bullBigger] times their real size and the double and treble rings
// [_ringBigger] times their real width.
const double _bullBigger = 1.5;
const double _ringBigger = 2;
const double _mmBull = 6.35 * _bullBigger; // double bull radius
const double _mmOuterBull = 15.9 * _bullBigger; // single bull radius
const double _mmTrebleInner = 103 - 4 * _ringBigger; // treble ring: centred where
const double _mmTrebleOuter = 103 + 4 * _ringBigger; // the real one is (99-107)
const double _mmDoubleInner = 170 - 8 * _ringBigger; // double ring: keeps the real
const double _mmDoubleOuter = 170; // outer edge; board radius 170

/// Drawn radius of the playing surface, in SVG units.
const double boardRadius = 144;
const double _scale = boardRadius / _mmDoubleOuter;

const double boardViewSize = 400;
const double boardCentre = 200;
const double bullRadius = _mmBull * _scale;
const double outerBullRadius = _mmOuterBull * _scale;
const double numberRadius = 171;

/// The angle one number's wedge spans.
const double wedgeAngle = 2 * math.pi / 20;

/// The ring areas of a number's wedge, from the middle outwards.
enum BoardZone {
  innerSingle(_mmOuterBull * _scale, _mmTrebleInner * _scale, Multiplier.single),
  trebleRing(_mmTrebleInner * _scale, _mmTrebleOuter * _scale, Multiplier.treble),
  outerSingle(_mmTrebleOuter * _scale, _mmDoubleInner * _scale, Multiplier.single),
  doubleRing(_mmDoubleInner * _scale, _mmDoubleOuter * _scale, Multiplier.double);

  const BoardZone(this.inner, this.outer, this.multiplier);

  final double inner;
  final double outer;
  final Multiplier multiplier;

  double get middle => (inner + outer) / 2;
}

/// The point at [radius] and [angle] (clockwise from the top) from the centre.
BoardPoint polarPoint(double radius, double angle) => BoardPoint(
      boardCentre + radius * math.sin(angle),
      boardCentre - radius * math.cos(angle),
    );

double _radiusOf(BoardPoint p) {
  final dx = p.x - boardCentre;
  final dy = p.y - boardCentre;
  return math.sqrt(dx * dx + dy * dy);
}

/// Where the middle of [dart]'s area sits on the board. Used to draw a mark
/// for darts that were entered without tapping the board (keypad, keyboard),
/// for the optimal route, and for a lit best dart. A single sits in the outer
/// single area (the one farther from the bull).
BoardPoint segmentCenter(DartThrow dart) {
  if (dart.isBull) return const BoardPoint(boardCentre, boardCentre);
  if (dart.isOuterBull) {
    return polarPoint((bullRadius + outerBullRadius) / 2, math.pi);
  }
  final slot = boardOrder.indexOf(dart.number);
  final angle = slot * wedgeAngle;
  final radius = switch (dart.multiplier) {
    Multiplier.single => BoardZone.outerSingle.middle,
    Multiplier.treble => BoardZone.trebleRing.middle,
    Multiplier.double => BoardZone.doubleRing.middle,
  };
  return polarPoint(radius, angle);
}

/// Puts a press on the ring that was thrown: a press already inside one of the
/// ring's areas keeps its exact spot; any other press (the wedge is pressable
/// everywhere) slides along its radius to the nearest of the ring's areas, so
/// the mark always sits on the right ring.
BoardPoint snapToRing(Multiplier ring, BoardPoint pressed) {
  final radius = _radiusOf(pressed);
  final angle = math.atan2(pressed.x - boardCentre, -(pressed.y - boardCentre));

  double gap(BoardZone zone) => radius < zone.inner
      ? zone.inner - radius
      : (radius > zone.outer ? radius - zone.outer : 0);

  final areas = BoardZone.values.where((z) => z.multiplier == ring).toList()
    ..sort((a, b) => gap(a).compareTo(gap(b)));
  final nearest = areas.first;
  if (gap(nearest) == 0) return pressed;
  return polarPoint(nearest.middle, angle);
}

/// One mark position per dart: where the player really tapped, or the middle of
/// the segment when no position was recorded.
List<BoardPoint> markPoints(List<DartThrow> darts, List<BoardPoint?> recorded) => [
      for (var i = 0; i < darts.length; i++)
        (i < recorded.length ? recorded[i] : null) ?? segmentCenter(darts[i]),
    ];

// ---- Marks of the same dart: side by side ------------------------------------

/// Radius of the circle drawn for a dart.
const double markRadius = 8;

/// Two marks in the same area share about half of their area: 50%, give or
/// take 10% (so 45% to 55%).
const double markOverlapMin = 0.45;
const double markOverlapMax = 0.55;

/// The share (0 to 1) of one mark's area that another mark at [b] covers.
double markOverlap(BoardPoint a, BoardPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  final x = math.sqrt(dx * dx + dy * dy) / (2 * markRadius);
  if (x >= 1) return 0;
  return (2 * math.acos(x) - 2 * x * math.sqrt(1 - x * x)) / math.pi;
}

/// How far apart two mark centres are when they share [overlap] of their area.
double markDistanceForOverlap(double overlap) {
  var low = 0.0; // x = distance / (2 * radius); overlap falls as x grows
  var high = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (low + high) / 2;
    final share = (2 * math.acos(mid) - 2 * mid * math.sqrt(1 - mid * mid)) / math.pi;
    if (share > overlap) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return 2 * markRadius * (low + high) / 2;
}

/// Which area of the board [point] is in, for [dart]: 0 bull, 1 outer bull, or
/// 10 + the ring zone. Marks of the same dart in the same area are spread.
int _areaOf(DartThrow dart, BoardPoint point) {
  if (dart.isBull) return 0;
  if (dart.isOuterBull) return 1;
  final radius = _radiusOf(point);
  BoardZone? best;
  var bestGap = double.infinity;
  for (final zone in BoardZone.values.where((z) => z.multiplier == dart.multiplier)) {
    final gap = radius < zone.inner
        ? zone.inner - radius
        : (radius > zone.outer ? radius - zone.outer : 0.0);
    if (gap < bestGap) {
      bestGap = gap;
      best = zone;
    }
  }
  return 10 + best!.index;
}

/// Is the centre of a mark at [point] inside [area] of [dart]'s number?
bool _insideArea(DartThrow dart, int area, BoardPoint point) {
  final radius = _radiusOf(point);
  if (area == 0) return radius <= bullRadius;
  if (area == 1) return radius > bullRadius && radius <= outerBullRadius;
  final zone = BoardZone.values[area - 10];
  if (radius < zone.inner || radius > zone.outer) return false;
  // Within the number's wedge.
  final slot = boardOrder.indexOf(dart.number);
  var diff = math.atan2(point.x - boardCentre, -(point.y - boardCentre)) - slot * wedgeAngle;
  while (diff > math.pi) {
    diff -= 2 * math.pi;
  }
  while (diff < -math.pi) {
    diff += 2 * math.pi;
  }
  return diff.abs() <= wedgeAngle / 2;
}

/// Where a mark for [dart] goes, given where it would [wanted] go and the marks
/// of the same dart already on the board ([earlier]).
///
/// A repeat of the same dart in the same area is placed beside the earlier mark
/// instead of on top of it, at a random angle but always sharing between 45% and
/// 55% of the area, and kept inside that area. The second of three is placed so
/// all three overlap each other about equally.
BoardPoint spreadMark(
  DartThrow dart,
  BoardPoint wanted,
  List<BoardPoint> earlier,
  math.Random random,
) {
  final area = _areaOf(dart, wanted);
  final same = earlier.where((p) => _areaOf(dart, p) == area).toList();
  if (same.isEmpty) return wanted;

  bool fits(BoardPoint candidate) {
    if (!_insideArea(dart, area, candidate)) return false;
    for (final other in same) {
      if (markOverlap(candidate, other) > markOverlapMax + 1e-6) return false;
    }
    return true;
  }

  double pickDistance() =>
      markDistanceForOverlap(markOverlapMin + random.nextDouble() * (markOverlapMax - markOverlapMin));

  // Third mark: sit at the same distance from the two already there, so each
  // pair overlaps by about the same half.
  if (same.length == 2) {
    final a = same[0];
    final b = same[1];
    final between = math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    final d = math.max(pickDistance(), between / 2 + 1e-6);
    final mx = (a.x + b.x) / 2;
    final my = (a.y + b.y) / 2;
    final h = math.sqrt(math.max(0.0, d * d - between * between / 4));
    if (between > 0) {
      final ux = -(b.y - a.y) / between;
      final uy = (b.x - a.x) / between;
      final options = [
        BoardPoint(mx + ux * h, my + uy * h),
        BoardPoint(mx - ux * h, my - uy * h),
      ]..shuffle(random);
      for (final option in options) {
        if (_insideArea(dart, area, option)) return option;
      }
    }
  }

  // Otherwise: a random angle around the latest mark, until it fits.
  final base = same.last;
  for (var attempt = 0; attempt < 80; attempt++) {
    final d = pickDistance();
    final angle = random.nextDouble() * 2 * math.pi;
    final candidate = BoardPoint(base.x + d * math.sin(angle), base.y - d * math.cos(angle));
    if (fits(candidate)) return candidate;
  }

  // Thin ring or a tight corner: slide along the ring instead.
  final baseRadius = _radiusOf(base);
  final baseAngle = math.atan2(base.x - boardCentre, -(base.y - boardCentre));
  final d = markDistanceForOverlap((markOverlapMin + markOverlapMax) / 2);
  final step = d / math.max(baseRadius, 1);
  final sign = random.nextBool() ? 1 : -1;
  for (final s in [sign, -sign]) {
    final candidate = polarPoint(baseRadius, baseAngle + s * step);
    if (fits(candidate)) return candidate;
  }
  return wanted;
}

/// Positions for every dart's mark. Marks already placed ([recorded]) are kept
/// as they are; the others start at the middle of their area and are spread
/// beside earlier marks of the same dart.
List<BoardPoint> spreadMarks(
  List<DartThrow> darts,
  List<BoardPoint?> recorded,
  math.Random random,
) {
  final placed = <BoardPoint>[];
  for (var i = 0; i < darts.length; i++) {
    final given = i < recorded.length ? recorded[i] : null;
    if (given != null) {
      placed.add(given);
      continue;
    }
    final earlier = [
      for (var j = 0; j < i; j++)
        if (darts[j] == darts[i]) placed[j],
    ];
    placed.add(spreadMark(darts[i], segmentCenter(darts[i]), earlier, random));
  }
  return placed;
}
