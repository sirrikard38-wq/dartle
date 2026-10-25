import 'dart:io';

import 'package:test/test.dart';

/// The top of every screen: the sound icon and the language box sit right next to
/// the word DARTLE, on its right; the calculator's score is at the far right.
/// Pinned from the source and the stylesheet (they are drawn in the browser).
void main() {
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
