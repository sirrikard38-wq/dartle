// The numbers behind the little dart that shoots you back to the top of a long
// page (no browser needed, so they can be tested).

/// How close to the bottom of the page counts as being at the end of it.
const double atEndSlackPx = 40;

/// Is the page scrolled down to its end? Never while it is still at the top: a
/// page that has not been scrolled has no end to be at.
bool isAtEnd({
  required double scrollY,
  required double viewportHeight,
  required double pageHeight,
}) =>
    scrollY > 0 && scrollY + viewportHeight >= pageHeight - atEndSlackPx;

/// How long the flight to the top takes, for a page scrolled [distancePx] down.
// TODO(human): tune the feel of the flight - how long a long page takes.
int flightMs(double distancePx) => (450 + 0.2 * distancePx).clamp(450, 1100).round();

/// How far into the flight we are (0 to 1) after [elapsedMs].
double progressAt(double elapsedMs, int durationMs) =>
    durationMs <= 0 ? 1 : (elapsedMs / durationMs).clamp(0.0, 1.0);

/// The page's scroll: starts and stops softly (cubic ease in-out).
double easeInOut(double t) {
  if (t < 0.5) return 4 * t * t * t;
  final u = -2 * t + 2;
  return 1 - u * u * u / 2;
}

/// The dart's climb: it leaves fast and slows as it goes up (cubic ease out).
double easeOut(double t) {
  final u = 1 - t;
  return 1 - u * u * u;
}

/// Where the page is, [progress] of the way through a flight that began
/// [startY] pixels down: [startY] at first, 0 (the top) at the end.
double pageY(double startY, double progress) => startY * (1 - easeInOut(progress));

/// How far into the flight the dart has slid across from its corner to the middle
/// of the page. From then on it goes straight up the middle, through the middle of
/// the numbers.
const double reachesMiddleAt = 0.4;

/// Where the dart is across the screen, [progress] of the way through the flight:
/// at [restX] (its corner) first, and in the middle, at [middleX], from
/// [reachesMiddleAt] on.
double dartX(double restX, double middleX, double progress) =>
    restX + (middleX - restX) * easeOut((progress / reachesMiddleAt).clamp(0.0, 1.0));

/// How high the dart is, [progress] of the way through the flight: it leaves
/// [restY] fast and slows as it comes to [stopY] (both are heights of its middle).
double dartY(double restY, double stopY, double progress) =>
    restY + (stopY - restY) * easeOut(progress);

/// The dart is this long (pixels) when it points up.
const double dartLengthPx = 56;

/// How far above the dart's middle its tip is: the tip is at 70 of the icon's 72
/// units, so 70/72 - 1/2 of its length.
const double tipAboveMiddlePx = dartLengthPx * (70 / 72 - 0.5);

/// Half a centimetre in CSS pixels (96 to the inch): how far the welcome dart
/// flies into its circle, and how far this one does.
const double halfCmPx = 0.5 * 96 / 2.54;

/// How far below the top of the screen (under the status bar) the circle is that
/// the dart sticks in at the top.
const double stickBelowTopPx = 14;

/// The height of the dart's middle when its flight ends: its tip half a centimetre
/// short of the circle, which is [circleY] down.
double dartStopY(double circleY) => circleY + halfCmPx + tipAboveMiddlePx;

/// The height of the dart's middle once it has stuck: its tip in the middle of the
/// circle.
double dartStuckY(double circleY) => circleY + tipAboveMiddlePx;
