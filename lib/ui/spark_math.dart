import 'dart:math' as math;

/// The numbers behind the welcome dart's press animation (no browser needed, so
/// they can be tested).

/// How long the dart takes to fly its half centimetre: the same speed as the
/// nudge it already had when you hover it (150 ms).
const int dartFlightMs = 150;

/// How long the sparks take to fly out and fade.
const int sparkFlightMs = 450;

/// How many sparks fly out of the popped circle.
const int sparkCount = 10;

/// How far the sparks fly from the middle of the circle: half a centimetre.
const double sparkReachCm = 0.5;

/// One centimetre in CSS pixels.
const double pixelsPerCm = 96 / 2.54;

/// Where each spark ends up, relative to the middle of the circle, in CSS
/// pixels: spread all the way round, each a little different in distance (80%
/// to 120% of [sparkReachCm]).
List<({double dx, double dy})> sparkOffsets(math.Random random) => [
      for (var i = 0; i < sparkCount; i++) _offset(i, random),
    ];

({double dx, double dy}) _offset(int i, math.Random random) {
  final angle = 2 * math.pi * (i + random.nextDouble() * 0.6) / sparkCount;
  final reach = sparkReachCm * pixelsPerCm * (0.8 + random.nextDouble() * 0.4);
  return (dx: math.cos(angle) * reach, dy: math.sin(angle) * reach);
}

/// The `style` attribute that sends a spark to [offset] (read by the CSS).
String sparkStyle(({double dx, double dy}) offset) =>
    '--dx:${offset.dx.toStringAsFixed(1)}px;--dy:${offset.dy.toStringAsFixed(1)}px';
