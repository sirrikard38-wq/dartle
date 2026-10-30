import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

// The measurements, marks and placement rules live in
// lib/src/board/board_geometry.dart (pure Dart, unit-tested). This file only
// draws them.
const double _viewSize = boardViewSize;
const double _centre = boardCentre;
const double _bullRadius = bullRadius;
const double _outerBullRadius = outerBullRadius;
const double _numberRadius = numberRadius;
const double _wedge = wedgeAngle;

// With a ring toggled, each number is pressed anywhere in its wedge (this far
// out) and the toggled ring decides single/double/treble. The middle press area
// covers the whole outer bull.
const double _hitInner = _outerBullRadius;
const double _hitOuter = 188;

BoardPoint _polar(double radius, double angle) => polarPoint(radius, angle);

String _p(BoardPoint p) => '${p.x.toStringAsFixed(2)} ${p.y.toStringAsFixed(2)}';

String _sectorPath(double r0, double r1, double a0, double a1) =>
    'M ${_p(_polar(r0, a0))} L ${_p(_polar(r1, a0))} '
    'A $r1 $r1 0 0 1 ${_p(_polar(r1, a1))} '
    'L ${_p(_polar(r0, a1))} A $r0 $r0 0 0 0 ${_p(_polar(r0, a0))} Z';

/// An SVG dartboard: bull, outer bull, inner single, treble, outer single and
/// double areas, with the numbers around the outside.
///
/// * With a [mode], that ring's areas are grey and every other area is dark.
///   Press anywhere in a number's wedge to throw that ring at that number;
///   [onDart] gets the dart and where the mark goes.
/// * With [byArea] there are no ring buttons: every area is shown and the area
///   you press is the dart you throw (a press on the treble ring is a treble).
/// * With neither, the board is display-only and every area is shown.
/// * [linesOnly] draws no filled areas at all - just the white lines that
///   divide them - so only the [marks] stand out (used to compare boards).
/// * [marks] are drawn as translucent circles - where darts landed.
/// * With [lit], those darts' areas are lit up in light grey and every other
///   area fades back, so only the best choices stand out. The lighting is only
///   a hint: a press is still worth exactly the area pressed (T20 lit: a press
///   on S20 or D20 is S20 or D20). With [bright] darts (the more optimal
///   ones) the other lit areas turn a darker grey, and the [brightest] are
///   lit white.
web.Element buildDartboard({
  Multiplier? mode,
  List<BoardPoint> marks = const [],
  void Function(DartThrow dart, BoardPoint point, bool viaKeyboard)? onDart,
  bool animateLastMark = false,
  bool linesOnly = false,
  bool byArea = false,
  Set<DartThrow>? lit,
  Set<DartThrow> bright = const {},
  Set<DartThrow> brightest = const {},
  String? label,
}) {
  final interactive = (mode != null || byArea) && onDart != null;
  bool isOn(Multiplier m) => byArea || mode == null || mode == m;

  // With Single toggled, the single ring between the treble and double rings
  // lights up, and so does the outer bull (the green 25) - but not the inner
  // single area next to the bull.
  final singleRingOnly = mode == Multiplier.single && !byArea;
  bool zoneOn(BoardZone zone) =>
      isOn(zone.multiplier) && !(singleRingOnly && zone == BoardZone.innerSingle);
  final outerBullOn = isOn(Multiplier.single);

  String highlight(DartThrow dart) {
    if (lit == null) return '';
    if (!lit.contains(dart)) return ' dim';
    if (brightest.contains(dart)) return ' lit brightest';
    return bright.contains(dart) ? ' lit bright' : ' lit';
  }

  /// Which area of a ring zone lights up for a lit dart. A lit single lights
  /// only the single ring between the treble and double rings (the outer
  /// single), never the inner single area next to the bull.
  String highlightZone(BoardZone zone, DartThrow dart) =>
      zone == BoardZone.innerSingle && lit != null ? ' dim' : highlight(dart);

  /// Is [p] inside the area that is lit for [dart]? A mark for a lit dart is
  /// only left where it is highlighted.
  bool inLitArea(DartThrow dart, BoardPoint p) {
    final dx = p.x - _centre;
    final dy = p.y - _centre;
    final radius = math.sqrt(dx * dx + dy * dy);
    if (dart.isBull) return radius <= _bullRadius;
    if (dart.isOuterBull) return radius > _bullRadius && radius <= _outerBullRadius;
    final zone = switch (dart.multiplier) {
      Multiplier.single => BoardZone.outerSingle,
      Multiplier.treble => BoardZone.trebleRing,
      Multiplier.double => BoardZone.doubleRing,
    };
    return radius >= zone.inner && radius <= zone.outer;
  }

  // With brighter darts the plain lit areas step back to a darker grey.
  final root = svg('svg',
      cls: 'dartboard${linesOnly ? ' lines' : ''}${bright.isNotEmpty ? ' tiers' : ''}', attrs: {
    'viewBox': '0 0 $_viewSize $_viewSize',
    'role': 'group',
    'aria-label': label ??
        (byArea
            ? tr('Dartboard. Press the area you want to throw.')
            : mode == null
                ? tr('Dartboard')
                : tr('Dartboard. Press a number to throw {ring}.', {'ring': tr(mode.label).toLowerCase()})),
  });

  BoardPoint pressPoint(web.MouseEvent event) {
    final rect = root.getBoundingClientRect();
    return BoardPoint(
      (event.clientX - rect.left) * _viewSize / rect.width,
      (event.clientY - rect.top) * _viewSize / rect.height,
    );
  }

  /// Makes [target] a button that throws [dart].
  void makeTappable(web.Element target, DartThrow dart, {String? focusKey}) {
    target.setAttribute('role', 'button');
    // One tab stop per number; the other areas are for touch and mouse.
    target.setAttribute('tabindex', focusKey == null ? '-1' : '0');
    target.setAttribute('aria-label', dart.spokenName);
    if (focusKey != null) target.setAttribute('data-focus', focusKey);

    void press(BoardPoint? pointer) {
      // By keyboard (no pointer) the mark goes in the middle of the dart's
      // area. Otherwise it goes where you pressed, moved onto the ring that was
      // thrown.
      final BoardPoint at;
      if (pointer == null) {
        at = segmentCenter(dart);
      } else if (lit != null && lit.contains(dart)) {
        // A lit dart: the mark stays on the highlighted part of its number
        // (a press on the inner single of a lit single goes to the lit ring).
        at = inLitArea(dart, pointer) ? pointer : segmentCenter(dart);
      } else if (dart.number == DartThrow.bullNumber) {
        at = pointer; // inside the bull area already
      } else {
        at = snapToRing(dart.multiplier, pointer);
      }
      onDart!(dart, at, pointer == null);
    }

    target.onClick.listen((event) {
      // detail == 0: keyboard activation, so there is no pointer position.
      press(event.detail == 0 ? null : pressPoint(event));
    });
    web.EventStreamProviders.keyDownEvent.forElement(target).listen((event) {
      if (event.key == 'Enter' || event.key == ' ') {
        event.preventDefault();
        event.stopPropagation();
        press(null);
      }
    });
  }

  // Numbers around the outside, straight on the page (no disc behind them).
  for (var slot = 0; slot < boardOrder.length; slot++) {
    final at = _polar(_numberRadius, slot * _wedge);
    root.appendChild(svg('text', cls: 'num', text: '${boardOrder[slot]}', attrs: {
      'x': at.x.toStringAsFixed(2),
      'y': at.y.toStringAsFixed(2),
      'text-anchor': 'middle',
      'dominant-baseline': 'central',
    }));
  }

  // The four ring areas of every number (drawing only).
  for (var slot = 0; slot < boardOrder.length; slot++) {
    final number = boardOrder[slot];
    final a0 = slot * _wedge - _wedge / 2;
    final a1 = slot * _wedge + _wedge / 2;
    for (final zone in BoardZone.values) {
      root.appendChild(svg('path',
          cls: 'zone ${slot.isEven ? 'tone-a' : 'tone-b'} '
              '${zoneOn(zone) ? 'on' : 'off'}'
              '${highlightZone(zone, DartThrow(zone.multiplier, number))}',
          attrs: {'d': _sectorPath(zone.inner, zone.outer, a0, a1)}));
    }
  }

  // Outer bull (25) counts as a single; the bull (50) as a double.
  root.appendChild(svg('circle',
      cls: 'zone bull-outer ${outerBullOn ? 'on' : 'off'}'
          '${highlight(DartThrow.outerBull)}',
      attrs: {'cx': '$_centre', 'cy': '$_centre', 'r': '$_outerBullRadius'}));
  root.appendChild(svg('circle',
      cls: 'zone bull-inner ${isOn(Multiplier.double) ? 'on' : 'off'}'
          '${highlight(DartThrow.bull)}',
      attrs: {'cx': '$_centre', 'cy': '$_centre', 'r': '$_bullRadius'}));

  // The edge of the playing surface.
  root.appendChild(svg('circle', cls: 'frame', attrs: {
    'cx': '$_centre', 'cy': '$_centre', 'r': '$boardRadius',
  }));

  // Invisible press areas.
  if (interactive) {
    web.Element sector(double r0, double r1, double a0, double a1) =>
        svg('path', cls: 'hit', attrs: {'d': _sectorPath(r0, r1, a0, a1)});

    for (var slot = 0; slot < boardOrder.length; slot++) {
      final number = boardOrder[slot];
      final a0 = slot * _wedge - _wedge / 2;
      final a1 = slot * _wedge + _wedge / 2;
      if (!byArea) {
        // Ring toggled: the whole wedge, thrown as the toggled ring.
        final hit = sector(_hitInner, _hitOuter, a0, a1);
        makeTappable(hit, DartThrow(mode!, number), focusKey: 'seg-$number');
        root.appendChild(hit);
      } else {
        // The exact area pressed is the dart thrown, lit or not.
        for (final zone in BoardZone.values) {
          final hit = sector(zone.inner, zone.outer, a0, a1);
          makeTappable(hit, DartThrow(zone.multiplier, number),
              focusKey: zone == BoardZone.outerSingle ? 'seg-$number' : null);
          root.appendChild(hit);
        }
      }
    }

    web.Element circle(double r) => svg('circle',
        cls: 'hit', attrs: {'cx': '$_centre', 'cy': '$_centre', 'r': '$r'});

    if (byArea) {
      final outer = circle(_outerBullRadius);
      makeTappable(outer, DartThrow.outerBull, focusKey: 'seg-25');
      root.appendChild(outer);
      final inner = circle(_bullRadius);
      makeTappable(inner, DartThrow.bull, focusKey: 'seg-bull');
      root.appendChild(inner);
    } else if (mode != Multiplier.treble) {
      // 25 with Single, Bull with Double. (Nothing with Treble - there is no
      // treble bull.)
      final bullDart = mode == Multiplier.double ? DartThrow.bull : DartThrow.outerBull;
      final centre = circle(_hitInner);
      makeTappable(centre, bullDart, focusKey: bullDart.isBull ? 'seg-bull' : 'seg-25');
      root.appendChild(centre);
    }
  }

  // Where the darts landed: translucent circles on top of everything.
  for (var i = 0; i < marks.length; i++) {
    final isNewest = animateLastMark && i == marks.length - 1;
    root.appendChild(svg('circle', cls: 'mark${isNewest ? ' newest' : ''}', attrs: {
      'cx': marks[i].x.toStringAsFixed(2),
      'cy': marks[i].y.toStringAsFixed(2),
      'r': '$markRadius',
    }));
  }

  return root;
}
