import 'dart:async';

import 'package:web/web.dart' as web;

import 'dart_icon.dart';
import 'dart_shot_timing.dart';
import 'dom.dart';

/// A dart that is a button, with the tiny circle its tip will fly into (see
/// [playDartShot]). It is the Enter button of the welcome screen, and, turned
/// round (`back-stage` / `back-dart`), the Back button of the header.
/// [stageClass] and [buttonClass] are added to the classes of the stage and of
/// the button.
web.HTMLElement buildDartStage({
  required String label,
  required void Function() onPressed,
  String stageClass = '',
  String buttonClass = '',
  String? focusKey,
}) {
  return el('div', cls: 'dart-stage $stageClass'.trim(), children: [
    el('span', cls: 'target-spot', attrs: {'aria-hidden': 'true'}, children: [
      el('span', cls: 'target-dot'),
    ]),
    button('',
        cls: 'dart-go $buttonClass'.trim(),
        ariaLabel: label,
        focusKey: focusKey,
        onPressed: (_) => onPressed())
      ..appendChild(dartIcon() as web.Node),
  ]);
}

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
