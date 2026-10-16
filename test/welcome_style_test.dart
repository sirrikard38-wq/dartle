import 'dart:io';

import 'package:dartle/ui/dart_shot_timing.dart';
import 'package:test/test.dart';

/// The welcome screen's look and the dart's press animation, pinned from the
/// source and the stylesheet (it is drawn in the browser).
void main() {
  final css = File('web/styles.css').readAsStringSync();
  final screen = File('lib/ui/welcome_screen.dart').readAsStringSync();
  final shot = File('lib/ui/dart_shot.dart').readAsStringSync();

  group('layout', () {
    test('the dart sits under the name box, and "Welcome" is centred over the box', () {
      final form = screen.substring(screen.indexOf("el('div', cls: 'form'"));
      final heading = form.indexOf("el('h2', text: 'Welcome')");
      final nameBox = form.indexOf("el('div', cls: 'name-row', children: [input])");
      final dart = form.indexOf('stage,');
      expect(heading, greaterThanOrEqualTo(0));
      expect(nameBox, greaterThan(heading));
      expect(dart, greaterThan(nameBox), reason: 'the dart comes after (under) the box');
      // Nothing pushes the heading off the box any more.
      final h2 = RegExp(r'\.welcome \.form h2 \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(h2, isNot(contains('padding-right')));
    });

    test('the press cannot make the welcome screen scroll sideways', () {
      final welcome = RegExp(r'\.screen\.welcome \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(welcome, contains('overflow-x: clip'));
    });
  });

  group('press animation: the dart sticks in the circle and wiggles', () {
    test('the dart flies half a centimetre at its old speed (150 ms)', () {
      expect(css, contains('.dart-stage.shooting .dart-go { transform: translateX(0.5cm); }'));
      expect(css, contains('transition: transform 150ms ease;'));
      expect(dartFlightMs, 150);
    });

    test('a tiny circle sits half a centimetre in front of the dart tip, smaller than the Bull', () {
      final spot = RegExp(r'\.target-spot \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(spot, contains('left: calc(50% + 34px + 0.5cm)'));
      final dot = RegExp(r'\.target-dot \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(dot, contains('width: 13px'));
      expect(dot, contains('border-radius: 50%'));
      expect(css, contains('.dart-stage.shooting .target-dot { opacity: 1;'));
    });

    test('nothing pops: no pop animation, no sparks', () {
      expect(css, isNot(contains('dot-pop')));
      expect(css, isNot(contains('.spark')));
      expect(css, isNot(contains('popped')));
      expect(shot, isNot(contains('popped')));
      expect(shot, isNot(contains('spark')));
    });

    test('the dart wiggles around its tip, in the middle of the circle, and settles', () {
      final rule = RegExp(r'\.dart-stage\.stuck \.dart-icon \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('transform-origin: 97% 50%'), reason: 'the tip (70 of 72)');
      expect(rule, contains('animation: dart-wiggle 550ms'));
      // The whole block, with the braces of each step inside it.
      final keyframes =
          RegExp(r'@keyframes dart-wiggle \{(?:[^{}]|\{[^{}]*\})*\}').firstMatch(css)!.group(0)!;
      final angles = RegExp(r'rotate\((-?[\d.]+)deg\)').allMatches(keyframes).map((m) => double.parse(m.group(1)!)).toList();
      expect(angles.first, 0);
      expect(angles.last, 0, reason: 'it settles back straight');
      expect(angles.any((a) => a < 0) && angles.any((a) => a > 0), isTrue, reason: 'it swings both ways');
      expect(angles.every((a) => a.abs() <= 3), isTrue, reason: 'only a little: at most 3 degrees');
      expect(angles.map((a) => a.abs()).reduce((a, b) => a > b ? a : b), 2.5, reason: 'the biggest swing');
      expect(dartWiggleMs, 550);
      // Each swing is smaller than the one before: it settles.
      final swings = angles.sublist(1, angles.length - 1).map((a) => a.abs()).toList();
      for (var i = 1; i < swings.length; i++) {
        expect(swings[i], lessThan(swings[i - 1]), reason: 'swing $i');
      }
    });

    test('the sequence: fly into the circle, then stick and wiggle, then the next screen', () {
      expect(shot.indexOf("add('shooting')"), lessThan(shot.indexOf("add('stuck')")));
      final submit = screen.substring(screen.indexOf('Future<void> submit()'));
      expect(submit.indexOf('await playDartShot(stage)'),
          lessThan(submit.indexOf('ctx.showPage(MenuPage.home)')));
      expect(submit, contains('if (shooting) return;'), reason: 'one shot per press');
      // An empty name stops before the dart flies.
      expect(submit.indexOf('Enter your name to continue'),
          lessThan(submit.indexOf('shooting = true')));
    });

    test('with reduced motion there is no animation and no wait', () {
      expect(shot, contains('prefers-reduced-motion: reduce'));
    });

    test('the old extra press movement is gone', () {
      expect(css, isNot(contains('.dart-go:active')));
    });
  });
}
