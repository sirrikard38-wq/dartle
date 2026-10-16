import 'dart:io';

import 'package:test/test.dart';

/// The Statistics screen: no "More numbers" heading, and "Needs practice" from
/// the largest number to the smallest. Pinned from the source and the stylesheet
/// (the screen is drawn in the browser).
void main() {
  final screen = File('lib/ui/stats_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  test('the words "More numbers" are gone from the screen', () {
    expect(screen, isNot(contains('More numbers')));
    // The figures and the table are still there.
    expect(screen, contains("cls: 'more-stats'"));
    expect(screen, contains("cls: 'data-table'"));
    expect(screen, contains("'Optimal routes'"));
  });

  test('the space the heading gave is kept above the figures', () {
    final rule = RegExp(r'\.more-stats \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(rule, contains('margin-top: 22px;'));
    final h3 = RegExp(r'\nh3 \{[^}]*\}').firstMatch(css)!.group(0)!;
    expect(h3, contains('margin: 22px 0 8px;'));
  });

  test('"Needs practice" takes its list from the largest number to the smallest', () {
    expect(screen, contains("el('h3', text: 'Needs practice')"));
    expect(screen, contains('game.statistics.needsPractice(game.history)'));
    // The screen does not sort or pick the list itself.
    expect(screen, isNot(contains('..sort(')));
    expect(screen, isNot(contains('.take(5)')));
  });
}
