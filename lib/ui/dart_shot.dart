import 'dart:async';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'dom.dart';
import 'spark_math.dart';

/// The press animation of the welcome dart. [stage] holds the dart and, just in
/// front of its tip, a tiny circle (smaller than the Bull) in a `.target-spot`:
///
///  1. `shooting`: the circle appears and the dart flies half a centimetre, so
///     its tip lands in the middle of the circle;
///  2. `popped`: the circle pops and little sparks fly half a centimetre out and
///     fade.
///
/// The future completes when the sparks are gone, and the caller goes on to the
/// next screen. With reduced motion it completes at once.
Future<void> playDartShot(web.HTMLElement stage, {math.Random? random}) async {
  if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  stage.classList.add('shooting');
  await Future<void>.delayed(const Duration(milliseconds: dartFlightMs));
  stage.classList.add('popped');
  final spot = stage.querySelector('.target-spot');
  if (spot != null) {
    for (final offset in sparkOffsets(random ?? math.Random())) {
      spot.appendChild(el('span', cls: 'spark', attrs: {'style': sparkStyle(offset)}));
    }
  }
  await Future<void>.delayed(const Duration(milliseconds: sparkFlightMs));
}
