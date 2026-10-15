import 'dart:async';

import 'package:web/web.dart' as web;

import 'dart_shot_timing.dart';

/// The press animation of the welcome dart. [stage] holds the dart and, just in
/// front of its tip, a tiny circle (smaller than the Bull) in a `.target-spot`:
///
///  1. `shooting`: the circle appears and the dart flies half a centimetre, so
///     its tip lands in the middle of the circle;
///  2. `stuck`: the dart stays in the circle and wiggles a little, like a dart
///     stuck in a board. Nothing pops.
///
/// The future completes when the wiggle is over, and the caller goes on to the
/// next screen. With reduced motion it completes at once.
Future<void> playDartShot(web.HTMLElement stage) async {
  if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  stage.classList.add('shooting');
  await Future<void>.delayed(const Duration(milliseconds: dartFlightMs));
  stage.classList.add('stuck');
  await Future<void>.delayed(const Duration(milliseconds: dartWiggleMs));
}
