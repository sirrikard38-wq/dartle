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

/// How far the dart has climbed from where it rests, of the [travelPx] it makes.
double dartLift(double travelPx, double progress) => travelPx * easeOut(progress);

/// How far into the flight the dart starts to fade.
const double fadeStart = 0.55;

/// The dart's opacity [progress] of the way through the flight: fully there at
/// first, then it fades smoothly (smoothstep), and is gone exactly when the page
/// reaches the top.
double dartOpacity(double progress) {
  if (progress <= fadeStart) return 1;
  if (progress >= 1) return 0;
  final t = (progress - fadeStart) / (1 - fadeStart);
  return 1 - t * t * (3 - 2 * t);
}
