import 'dart:io';

import 'package:dartle/ui/dart_shot_timing.dart';
import 'package:test/test.dart';

/// The Back button in the header is the welcome screen's dart turned round, with
/// no background. Pressed, it slides half a centimetre to the left and fades out
/// smoothly (no circle, no wiggle). The welcome screen's own animation is not
/// touched. Pinned from the source and the stylesheet (it is drawn and animated
/// in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final shot = File('lib/ui/dart_shot.dart').readAsStringSync();
  final welcome = File('lib/ui/welcome_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  /// The first rule whose selector is exactly [selector].
  String rule(String selector) =>
      RegExp('(^|\n)${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;

  final back = app.substring(app.indexOf('web.HTMLElement _buildBackDart()'));

  group('the button', () {
    test('it is the dart, not an arrow', () {
      final header = app.substring(app.indexOf('web.HTMLElement _buildHeader()'));
      expect(header, contains('_buildBackDart()'));
      expect(app, isNot(contains("button('←'")));
    });

    test('it is made by the same function as the welcome screen\'s dart', () {
      expect(shot, contains('web.HTMLElement buildDartStage('));
      expect(welcome, contains("buildDartStage(label: tr('Continue')"));
      expect(back, contains('buildDartStage('));
      expect(back, contains("label: tr('Back to the menu')"));
      expect(back, contains("stageClass: 'back-stage'"));
      expect(back, contains("buttonClass: 'back-dart'"));
    });

    test('it has no background to be too big: none at rest, hovered or pressed', () {
      expect(rule('.dart-go'), contains('background: none;'));
      expect(rule('.dart-go'), contains('border: 0;'));
      for (final selector in ['.dart-go.back-dart', '.dart-go.back-dart:hover']) {
        expect(rule(selector), isNot(contains('background')), reason: selector);
      }
      expect(css, isNot(contains('.dart-go:active')));
      expect(css, isNot(contains('.back-dart:active')));
    });

    test('the sound button is not touched: it keeps its own style', () {
      expect(app, contains("cls: 'icon-btn',\n        ariaLabel: _sound.isMuted ? tr('Turn sound on') : tr('Turn sound off')"));
    });
  });

  group('pressed: it slides left and fades out smoothly', () {
    test('the dart is turned 180 degrees, and nudges left when hovered', () {
      expect(rule('.dart-go.back-dart'), contains('transform: rotate(180deg);'));
      expect(rule('.dart-go.back-dart:hover'), contains('transform: rotate(180deg) translateX(5px);'));
    });

    test('it still moves, the same half centimetre as the welcome dart, and disappears', () {
      final fading = rule('.dart-stage.back-stage.fading .dart-go');
      expect(fading, contains('transform: rotate(180deg) translateX(0.5cm);'));
      expect(fading, contains('opacity: 0;'));
      // The welcome dart's flight is 0.5cm too.
      expect(css, contains('.dart-stage.shooting .dart-go { transform: translateX(0.5cm); }'));
    });

    test('it is smooth: an eased transition on the slide and on the fade, as long as the script waits', () {
      final fading = rule('.dart-stage.back-stage.fading .dart-go');
      expect(fading, contains('transform ${dartFadeMs}ms cubic-bezier('));
      expect(fading, contains('opacity ${dartFadeMs}ms cubic-bezier('));
      // Not a flick and not a wait: between a fifth and just over half a second.
      expect(dartFadeMs, inInclusiveRange(200, 600));
    });

    test('the script waits for the fade, then goes to the menu; a second press does nothing', () {
      expect(back, contains('await playDartFade(stage);'));
      expect(back.indexOf('await playDartFade(stage);'),
          lessThan(back.indexOf('_showPage(MenuPage.home);')));
      expect(back, contains('if (leaving) return;'));
      expect(shot, contains("stage.classList.add('fading');"));
      expect(shot, contains('Duration(milliseconds: dartFadeMs)'));
      // Reduced motion: no animation, straight on.
      expect(shot.substring(shot.indexOf('Future<void> playDartFade')),
          contains('prefers-reduced-motion: reduce'));
    });
  });

  group('no little circle and no wiggle on the Back dart', () {
    test('the Back dart is built without the circle', () {
      expect(back, contains('circle: false,'));
      expect(shot, contains('bool circle = true,'));
      expect(shot, contains('if (circle)'));
    });

    test('it does not play the welcome shot, and has no rule for the circle or the wiggle', () {
      expect(back, isNot(contains('playDartShot')));
      expect(css, isNot(contains('.back-stage .target-spot')));
      expect(css, isNot(contains('.back-stage.shooting')));
      expect(css, isNot(contains('.back-stage.stuck')));
      expect(css, isNot(contains('back-wiggle')));
    });
  });

  group('the welcome screen keeps its animation, as it was', () {
    test('the circle, the flight and the wiggle are all still there', () {
      expect(welcome, contains('await playDartShot(stage);'));
      expect(shot, contains("stage.classList.add('shooting');"));
      expect(shot, contains("stage.classList.add('stuck');"));
      expect(css, contains('.dart-stage.shooting .target-dot { opacity: 1;'));
      expect(css, contains('.dart-stage.shooting .dart-go { transform: translateX(0.5cm); }'));
      expect(RegExp(r'\.dart-stage\.stuck \.dart-icon \{[^}]*animation: dart-wiggle 550ms').hasMatch(css),
          isTrue);
      // The welcome dart is built with its circle (the default).
      expect(welcome, isNot(contains('circle: false')));
    });
  });

  group('where it sits: 2cm to the left of the word DARTLE', () {
    test('at the right end of the header\'s left cell, which ends where the title begins', () {
      final stage = rule('.dart-stage.back-stage');
      expect(stage, contains('justify-self: end;'));
      expect(stage, isNot(contains('justify-self: start')));
      expect(rule('.app-header'), contains('grid-template-columns: 1fr auto 1fr;'));
    });

    test('with 2cm of margin on its right, which never pushes it off the screen on a narrow phone', () {
      final stage = rule('.dart-stage.back-stage');
      expect(stage, contains('margin: 0 min(2cm, calc(100% - var(--back-w))) 0 0;'));
      expect(stage, contains('--back-w: 48px;'));
    });
  });
}
