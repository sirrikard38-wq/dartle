import 'dart:io';

import 'package:dartle/ui/dart_shot_timing.dart';
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

    test('it is fixed at the left, and pointing up', () {
      final to = rule('.to-top');
      expect(to, contains('position: fixed;'));
      expect(to, contains('left: max(10px'));
      expect(to, isNot(contains('right:')));
      // Turned by a wrapper, so that the wiggle runs in the turned frame.
      expect(rule('.to-top-turn'), contains('transform: rotate(-90deg);'));
      expect(rule('.to-top .dart-icon'), isNot(contains('transform')));
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

  group('the flight: up through the middle of the numbers', () {
    test('the page is scrolled by the script, frame by frame, to the top', () {
      expect(dart, contains('requestAnimationFrame'));
      expect(dart, contains('web.window.scrollTo(0.toJS, pageY(startY, progress))'));
      // No CSS smooth scrolling to fight the script ("overscroll-behavior" is another property).
      expect(RegExp(r'(?<![\w-])scroll-behavior').hasMatch(css), isFalse);
    });

    test('the dart slides across to the middle of the page and goes up along it', () {
      expect(dart, contains('final middleX = page.clientWidth / 2;'));
      expect(dart, contains('dartX(restX, middleX, progress)'));
      expect(dart, contains('dartY(restY, stopY, progress)'));
      // It is placed with a translate, from where it rests in the corner.
      expect(dart, contains("'translate(\${dx.toStringAsFixed(1)}px"));
    });

    test('it does not fade on the way: it is there to stick', () {
      expect(dart, isNot(contains('dartOpacity')));
      expect(dart, isNot(contains("setProperty('opacity', dart")));
      expect(rule('.to-top.flying'), contains('opacity: 1;'));
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
      expect(css, contains('.to-top, .to-top-turn, .to-top-spot { transition: none; }'));
    });

    test('taking over the scroll yourself ends the flight', () {
      for (final event in ['wheelEvent', 'touchStartEvent', 'keyDownEvent']) {
        expect(dart, contains('EventStreamProviders.$event'));
      }
    });
  });

  group('at the top it sticks and wiggles, like the welcome dart, and then fades away', () {
    test('the circle is the welcome circle, put at the middle of the page near the top', () {
      expect(dart, contains("el('span', cls: 'target-dot')"));
      expect(dart, contains("cls: 'to-top-spot'"));
      expect(dart, contains('final circleY = _statusBarPx() + stickBelowTopPx;'));
      expect(dart, contains("setProperty('left', '\${middleX.toStringAsFixed(1)}px')"));
      expect(dart, contains("setProperty('top', '\${circleY.toStringAsFixed(1)}px')"));
      expect(rule('.to-top-spot'), contains('position: fixed;'));
      expect(rule('.to-top-spot.on .target-dot'), contains('opacity: 1;'));
    });

    test('in order: the circle and the shot, the wiggle, the fade - each as long as the CSS says', () {
      final seq = dart.substring(dart.indexOf('Future<void> _stickAndLeave'));
      final order = [
        "spot.classList.add('on');",
        "element.classList.add('shooting');",
        'Duration(milliseconds: dartFlightMs)',
        "element.classList.add('stuck');",
        'Duration(milliseconds: dartWiggleMs)',
        "element.classList.add('leaving');",
        'Duration(milliseconds: dartLeaveMs)',
        '_end();',
      ];
      var at = -1;
      for (final step in order) {
        final next = seq.indexOf(step);
        expect(next, greaterThan(at), reason: step);
        at = next;
      }
      expect(rule('.to-top.flying.shooting'), contains('transition: transform ${dartFlightMs}ms'));
      expect(rule('.to-top.flying.leaving'), contains('opacity: 0;'));
      expect(rule('.to-top.flying.leaving'), contains('opacity ${dartLeaveMs}ms'));
    });

    test('the wiggle is the welcome dart\'s own, about the tip', () {
      final stuck = rule('.to-top.stuck .dart-icon');
      expect(stuck, contains('transform-origin: 97% 50%;'));
      expect(stuck, contains('animation: dart-wiggle ${dartWiggleMs}ms'));
      // One set of keyframes, shared with the welcome dart.
      expect(RegExp(r'@keyframes dart-wiggle').allMatches(css), hasLength(1));
    });

    test('the dart flies the last half centimetre into the circle: the same as the welcome dart', () {
      expect(dart, contains('final stopY = dartStopY(circleY);'));
      expect(dart, contains('dartStuckY(circleY) - restY'));
      expect(css, contains('.dart-stage.shooting .dart-go { transform: translateX(0.5cm); }'));
    });

    test('it all ends cleanly: classes and circle reset, back in its corner', () {
      final end = dart.substring(dart.indexOf('void _end()'));
      for (final name in ['flying', 'shooting', 'stuck', 'leaving', 'show', 'on']) {
        expect(end, contains("'$name'"), reason: name);
      }
      expect(end, contains("element.style.removeProperty('transform');"));
    });
  });
}
