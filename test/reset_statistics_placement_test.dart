import 'dart:io';

import 'package:test/test.dart';

/// "Reset statistics / Does not affect the leaderboard" is the last thing on the
/// Statistics screen and sits against the right edge. Pinned from the source and
/// the stylesheet (the screen is drawn in the browser).
void main() {
  final stats = File('lib/ui/stats_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  /// The rule for [selector] (the first one whose selector is exactly it).
  String rule(String selector) =>
      RegExp('(^|\n)${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;

  test('the button and its note come after everything else on the screen', () {
    final reset = stats.indexOf("cls: 'reset-box'");
    expect(reset, isNonNegative);
    expect(stats.indexOf("'Reset statistics'"), greaterThan(reset));
    expect(stats.indexOf("'Does not affect the leaderboard'"), greaterThan(reset));
    // After the title, the big numbers, the weak list and the every-number table.
    for (final earlier in ["el('h2', text: 'Statistics')", "cls: 'big-stats'", "cls: 'weak-list'", "cls: 'data-table'"]) {
      expect(stats.indexOf(earlier), isNonNegative, reason: earlier);
      expect(stats.indexOf(earlier), lessThan(reset), reason: earlier);
    }
    // Nothing is built after the box but the closing brackets.
    final tail = stats.substring(stats.indexOf("'Does not affect the leaderboard'"));
    expect(tail, isNot(contains("el('")));
  });

  test('the title is a plain centred heading again, with no row for the button', () {
    expect(stats, isNot(contains('stats-head')));
    expect(css, isNot(contains('stats-head')));
    expect(stats, contains("el('h2', text: 'Statistics')"));
  });

  test('the box is against the right edge and its text is right-aligned', () {
    final box = rule('.reset-box');
    expect(box, contains('align-self: flex-end;'));
    expect(box, contains('align-items: flex-end;'));
    expect(box, contains('text-align: right;'));
    expect(rule('.reset-stats'), contains('text-align: right;'));
    expect(css, isNot(contains('justify-self: start')));
  });

  test('it still says it does not touch the leaderboard, and still asks first', () {
    expect(stats, contains("'Does not affect the leaderboard'"));
    expect(stats, contains('web.window.confirm('));
    expect(stats, contains('game.resetStatistics()'));
  });
}
