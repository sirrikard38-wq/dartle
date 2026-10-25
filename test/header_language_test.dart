import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:dartle/ui/view_context.dart';
import 'package:test/test.dart';

/// The top of every screen: the sound icon and the language box are the Back dart
/// mirrored - 2cm to the right of
/// the word DARTLE, as the dart is 2cm to its left; the calculator's score is at the far right.
/// Pinned from the source and the stylesheet (they are drawn in the browser).
void main() {
  mirrorAndBackTests();
  final app = File('lib/ui/app.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();
  final header = app.substring(
      app.indexOf('web.HTMLElement _buildHeader()'), app.indexOf('web.HTMLElement _buildBackDart()'));

  String rule(String selector) =>
      RegExp('(^|\n)${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;

  test('the sound icon and the language box are together, before the score', () {
    final tools = header.indexOf("cls: 'header-tools'");
    expect(tools, isNonNegative);
    expect(header.indexOf('if (showSound) soundButton'), greaterThan(tools));
    expect(header.indexOf('languageButton,'), greaterThan(header.indexOf('if (showSound) soundButton')));
    expect(header.indexOf("cls: 'score-box'"), greaterThan(header.indexOf('languageButton,')));
  });

  test('the language box shows the two letters of the language that is on and goes to the next', () {
    expect(header, contains('el(\'span\', cls: \'lang-code\', text: language.code)'));
    expect(header, contains('_game.setLanguage(language.next)'));
    // It is there in every mode (the sound icon is not).
    expect(header, isNot(contains('if (showSound) languageButton')));
  });

  test('the cell right of the title starts at the title, with the score pushed to the far right', () {
    final right = rule('.header-right');
    expect(right, contains('display: flex;'));
    expect(right, contains('justify-content: space-between;'));
  });

  test('on a phone the title and the buttons are a little tighter so everything fits', () {
    final phone = css.substring(css.indexOf('@media (max-width: 440px)'));
    expect(phone.substring(0, phone.indexOf('\n}')), contains('.lang-btn'));
    expect(phone.substring(0, phone.indexOf('\n}')), contains('.title'));
  });

  test('the page language is set for screen readers', () {
    expect(app, contains("setAttribute('lang', I18n.current.code.toLowerCase())"));
  });
}

void mirrorAndBackTests() {
  final app = File('lib/ui/app.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  group('the sound icon is the Back dart mirrored', () {
    test('the dart is 2cm left of DARTLE, the tools start 2cm right of it', () {
      expect(css, contains('margin: 0 min(2cm, calc(100% - var(--back-w))) 0 0;'));
      final tools = RegExp(r'\.header-tools \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(tools, contains('margin-left: min(2cm, max(0px, calc(100% - var(--tools-w) - var(--score-w))));'));
    });

    test('the sound icon is as wide as the dart (48px), thinner on a phone', () {
      expect(css, contains('--back-w: 48px'));
      expect(css, contains('.header-tools .icon-btn { min-width: 48px; }'));
    });

    test('what has to fit beside the tools is told to the stylesheet', () {
      expect(app, contains("cls: 'header-right\${showSound ? '' : ' no-sound'}\${showScore ? ' has-score' : ''}'"));
      expect(css, contains('.header-right.no-sound'));
      expect(css, contains('.header-right.has-score'));
    });
  });

  group('the Back dart goes one step back', () {
    test('from a game, a result or the number pad: the game modes', () {
      for (final phase in [
        GamePhase.playing,
        GamePhase.result,
        GamePhase.entering,
        GamePhase.impossible,
      ]) {
        expect(ViewContext.backTarget(phase), MenuPage.modes, reason: '$phase');
      }
    });

    test('from the modes, Favorites and the Leaderboard (all menu pages): the menu', () {
      expect(ViewContext.backTarget(GamePhase.menu), MenuPage.home);
    });

    test('the dart uses it', () {
      expect(app, contains('_showPage(ViewContext.backTarget(_game.phase));'));
      expect(app, isNot(contains('_showPage(MenuPage.home);')));
    });
  });
}
