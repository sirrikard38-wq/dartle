import 'dart:io';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

/// The "All possibilities" popup and the scrollbar, checked from the source:
/// these parts are drawn in the browser, so the rules they follow are pinned here.
void main() {
  final screen = File('lib/ui/result_screen.dart').readAsStringSync();
  final modal = File('lib/ui/modal.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  group('result screen', () {
    test('a number with one optimal route says "Only possibility", not "All possibilities"', () {
      final engine = CheckoutEngine();
      final optimal = OptimalRouteService(engine);
      for (final one in [40, 50, 16, 170, 100]) {
        expect(optimal.optimalRoutes(one), hasLength(1), reason: '$one');
      }
      expect(optimal.optimalRoutes(132).length, greaterThan(1));
      expect(screen, contains('if (count == 1) return el('));
      expect(screen, contains("text: 'Only possibility'"));
      expect(screen, contains("button('All possibilities'"));
    });

    test('the link is under the last combination, under "Also optimal" - not under the number', () {
      // The boards' own figures hold it: after the "Also optimal" boxes of the
      // optimal route's board, and after those of your board when yours is optimal.
      final bestExtras = screen.indexOf('if (bestExtras != null) bestExtras');
      final link = screen.indexOf('if (possibilities != null) possibilities');
      expect(bestExtras, greaterThan(0));
      expect(link, greaterThan(bestExtras));
      final yourExtras = screen.indexOf('if (yourExtras != null) yourExtras');
      expect(screen.indexOf('if (!showBest && possibilities != null) possibilities'),
          greaterThan(yourExtras));
      // Between the number at the top and the boards there is no link any more.
      final underNumber = screen.substring(
          screen.indexOf("el('p', cls: 'target small'"), screen.indexOf("el('div', cls: 'result-boards'"));
      expect(underNumber, isNot(contains("button('All possibilities'")));
      expect(underNumber, isNot(contains('why-row')));
      expect(underNumber, isNot(contains("'Only possibility'")));
    });

    test('the popup shows every route at once - no "Shoot more"', () {
      expect(screen, contains('for (final route in RouteOrder.byFinisher(result.optimalRoutes)) figureFor(route)'));
      expect(screen, isNot(contains('Shoot more')));
      expect(File('lib/ui/result_screen.dart').readAsStringSync(), isNot(contains('RoutePages')));
      expect(css, isNot(contains('.shoot-more')));
    });

    test('the sentence is on the right, the number under it in the middle above the boards', () {
      final sentence = screen.indexOf("text: 'Every optimal way to check out'");
      final number = screen.indexOf("cls: 'modal-number', text: '\${challenge.target}'");
      final boards = screen.indexOf("cls: 'possibilities'");
      expect(sentence, greaterThan(0));
      expect(number, greaterThan(sentence));
      expect(boards, greaterThan(number));
      expect(screen, isNot(contains('Every optimal way to check out \${challenge.target}')));
      final rule = RegExp(r'\.modal-number \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('text-align: center'));
    });

    test('the boards are centred, so a last row with fewer boards is in the middle', () {
      final rule = RegExp(r'\.possibilities \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('display: flex'));
      expect(rule, contains('flex-wrap: wrap'));
      expect(rule, contains('justify-content: center'));
    });
  });

  group('popup', () {
    test('Close is its own centred box and the popup opens at its top', () {
      expect(modal, contains("cls: 'modal-close'"));
      expect(modal, isNot(contains("'cta modal-close'")));
      expect(modal, contains('preventScroll'));
      final rule = RegExp(r'\.modal-close \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('margin: 18px auto'));
    });
  });

  group('scrollbar', () {
    final script = File('lib/ui/scrollbars.dart').readAsStringSync();

    test('no arrows at the ends', () {
      expect(css, contains('::-webkit-scrollbar-button { display: none'));
    });

    test('invisible at rest, grey only while scrolling, fading out smoothly', () {
      expect(css, contains('::-webkit-scrollbar-thumb { background-color: transparent'));
      expect(css, contains('.scrolling::-webkit-scrollbar-thumb { background-color: var(--scrollbar)'));
      expect(css, contains('transition: background-color 600ms'));
      expect(RegExp(r'--scrollbar: #[0-9a-f]{6}').hasMatch(css), isTrue);
    });

    test('it goes away 1.5 s after the last scroll, and is wired into the app', () {
      expect(scrollbarHideAfterMs, 1500);
      expect(script, contains('Duration scrollbarHideAfter = Duration(milliseconds: 1500)'));
      expect(script, contains("'scroll'"));
      expect(script, contains("classList.add('scrolling')"));
      expect(script, contains("classList.remove('scrolling')"));
      expect(File('web/main.dart').readAsStringSync(), contains('autoHideScrollbars()'));
    });
  });
}

/// The delay in the script, read back from its source.
final int scrollbarHideAfterMs = int.parse(RegExp(r'Duration\(milliseconds: (\d+)\)')
    .firstMatch(File('lib/ui/scrollbars.dart').readAsStringSync())!
    .group(1)!);
