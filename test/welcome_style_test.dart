import 'dart:io';
import 'dart:math';

import 'package:dartle/ui/spark_math.dart';
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

  group('press animation', () {
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

    test('the circle pops, then sparks fly half a centimetre out', () {
      expect(css, contains('.dart-stage.popped .target-dot { animation: dot-pop'));
      expect(css, contains('@keyframes spark-fly'));
      expect(css, contains('translate(var(--dx), var(--dy))'));
      expect(sparkReachCm, 0.5);
      expect(shot, contains("stage.classList.add('shooting')"));
      expect(shot, contains("stage.classList.add('popped')"));
      expect(shot.indexOf("add('shooting')"), lessThan(shot.indexOf("add('popped')")));
    });

    test('the next screen comes after the animation, not before', () {
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

  group('sparks', () {
    test('ten of them, spread all the way round', () {
      final offsets = sparkOffsets(Random(1));
      expect(offsets, hasLength(10));
      // Every quarter of the circle has some.
      expect(offsets.where((o) => o.dx > 0 && o.dy > 0), isNotEmpty);
      expect(offsets.where((o) => o.dx < 0 && o.dy > 0), isNotEmpty);
      expect(offsets.where((o) => o.dx < 0 && o.dy < 0), isNotEmpty);
      expect(offsets.where((o) => o.dx > 0 && o.dy < 0), isNotEmpty);
    });

    test('each flies about half a centimetre: 80% to 120% of 18.9 px', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final o in sparkOffsets(Random(seed))) {
          final distance = sqrt(o.dx * o.dx + o.dy * o.dy);
          expect(distance, inInclusiveRange(0.5 * pixelsPerCm * 0.8, 0.5 * pixelsPerCm * 1.2),
              reason: 'seed $seed');
        }
      }
    });

    test('the style carries the end point for the CSS', () {
      expect(sparkStyle((dx: 12.34, dy: -5.67)), '--dx:12.3px;--dy:-5.7px');
    });
  });
}
