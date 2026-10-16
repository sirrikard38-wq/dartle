import 'dart:io';

import 'package:test/test.dart';

/// The little dart at the end of the Leaderboard and Statistics. Pinned from the
/// source and the stylesheet (it is drawn and animated in the browser).
void main() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final dart = File('lib/ui/to_top.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  /// The first rule whose selector is exactly [selector].
  String rule(String selector) =>
      RegExp('(^|\n)${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;

  group('where it shows', () {
    test('it is one button for the whole app, switched on for the two screens', () {
      expect(app, contains('_toTop = ToTopDart();'));
      expect(app, contains('_toTop.enabled ='));
      final switchOn = app.substring(app.indexOf('_toTop.enabled ='));
      expect(switchOn, contains('MenuPage.stats'));
      expect(switchOn, contains('MenuPage.leaderboard'));
      expect(switchOn.substring(0, switchOn.indexOf(';')), contains('!fullScreen'));
      expect(switchOn.substring(0, switchOn.indexOf(';')), contains('GamePhase.menu'));
    });

    test('it is the welcome screen\'s own dart, drawn by the same function', () {
      expect(dart, contains('dartIcon()'));
      expect(dart, contains("ariaLabel: 'Back to the top'"));
    });

    test('it is fixed at the right, and pointing up', () {
      final to = rule('.to-top');
      expect(to, contains('position: fixed;'));
      expect(to, contains('right: max(10px'));
      expect(rule('.to-top .dart-icon'), contains('rotate(-90deg)'));
    });

    test('it is out of sight (and out of the tab order) until the end of the page', () {
      final to = rule('.to-top');
      expect(to, contains('opacity: 0;'));
      expect(to, contains('visibility: hidden;'));
      expect(to, contains('pointer-events: none;'));
      expect(rule('.to-top.show'), contains('visibility: visible;'));
      expect(rule('.to-top.show'), contains('opacity: 1;'));
    });
  });

  group('the flight', () {
    test('the page is scrolled by the script, frame by frame, to the top', () {
      expect(dart, contains('requestAnimationFrame'));
      expect(dart, contains('web.window.scrollTo(0.toJS, pageY(startY, progress))'));
      // No CSS smooth scrolling to fight the script ("overscroll-behavior" is another property).
      expect(RegExp(r'(?<![\w-])scroll-behavior').hasMatch(css), isFalse);
    });

    test('the dart climbs and fades with the same progress as the scroll', () {
      expect(dart, contains("'translateY(\${(-dartLift(travel, progress))"));
      expect(dart, contains('dartOpacity(progress)'));
      // Landing is when the progress reaches 1.
      expect(dart, contains('if (progress < 1)'));
    });

    test('while it flies it is shown whatever the page does, with no transition fighting the script', () {
      final flying = rule('.to-top.flying');
      expect(flying, contains('visibility: visible;'));
      expect(flying, contains('transition: none;'));
    });

    test('a tab that pauses animation frames still lands at the top', () {
      expect(dart, contains('_safety = Timer('));
    });

    test('reduced motion: straight to the top, no flight', () {
      expect(dart, contains('prefers-reduced-motion: reduce'));
      expect(css, contains('.to-top, .to-top .dart-icon { transition: none; }'));
    });

    test('taking over the scroll yourself ends the flight', () {
      for (final event in ['wheelEvent', 'touchStartEvent', 'keyDownEvent']) {
        expect(dart, contains('EventStreamProviders.$event'));
      }
    });
  });
}
