import 'dart:io';

import 'package:test/test.dart';

/// The Back button in the header is the welcome screen's dart turned round, with
/// no background. Pinned from the source and the stylesheet (it is drawn and
/// animated in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final shot = File('lib/ui/dart_shot.dart').readAsStringSync();
  final welcome = File('lib/ui/welcome_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  /// The first rule whose selector is exactly [selector].
  String rule(String selector) =>
      RegExp('(^|\n)${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;

  group('the button', () {
    test('it is the dart, not an arrow', () {
      final header = app.substring(app.indexOf('web.HTMLElement _buildHeader()'));
      expect(header, contains('_buildBackDart()'));
      expect(app, isNot(contains("button('←'")));
      expect(app, isNot(contains("cls: 'icon-btn',\n            ariaLabel: 'Back to the menu'")));
    });

    test('it is made by the same function as the welcome screen\'s dart', () {
      expect(shot, contains('web.HTMLElement buildDartStage('));
      expect(welcome, contains("buildDartStage(label: 'Continue'"));
      final back = app.substring(app.indexOf('web.HTMLElement _buildBackDart()'));
      expect(back, contains('buildDartStage('));
      expect(back, contains("label: 'Back to the menu'"));
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
      expect(app, contains("cls: 'icon-btn',\n        ariaLabel: _sound.isMuted ? 'Turn sound on' : 'Turn sound off'"));
    });
  });

  group('turned round: everything goes from right to left', () {
    test('the dart is turned 180 degrees, and nudges left when hovered', () {
      expect(rule('.dart-go.back-dart'), contains('transform: rotate(180deg);'));
      expect(rule('.dart-go.back-dart:hover'), contains('transform: rotate(180deg) translateX(5px);'));
    });

    test('pressed, it flies half a centimetre to the left, the same distance as the welcome dart', () {
      expect(rule('.dart-stage.back-stage.shooting .dart-go'),
          contains('transform: rotate(180deg) translateX(0.5cm);'));
      expect(css, contains('.dart-stage.shooting .dart-go { transform: translateX(0.5cm); }'));
    });

    test('the circle is on the left of its tip, 0.5cm ahead of it', () {
      final spot = rule('.back-stage .target-spot');
      expect(spot, contains('left: calc(50% - 0.4722 * var(--back-w) - 0.5cm);'));
    });

    test('the wiggle is the welcome dart\'s own, and turns round with the button', () {
      // One rule for both: the icon inside the turned button wiggles about its tip.
      expect(RegExp(r'\.dart-stage\.stuck \.dart-icon \{').allMatches(css), hasLength(1));
      expect(css, isNot(contains('back-wiggle')));
    });

    test('the same animation: the same shot, the same waiting for it, then the menu', () {
      final back = app.substring(app.indexOf('web.HTMLElement _buildBackDart()'));
      expect(back, contains('await playDartShot(stage);'));
      expect(back.indexOf('await playDartShot(stage);'),
          lessThan(back.indexOf('_showPage(MenuPage.home);')));
      expect(back, contains('if (shooting) return;'));
    });

    test('there is room on the left of the tip for the circle', () {
      final stage = rule('.dart-stage.back-stage');
      final margin = int.parse(RegExp(r'margin: 0 0 0 (\d+)px;').firstMatch(stage)!.group(1)!);
      // Circle: 0.5cm (about 19px) + its 13px, from the tip.
      expect(margin, greaterThanOrEqualTo(20));
      expect(stage, contains('justify-self: start;'));
    });
  });
}
