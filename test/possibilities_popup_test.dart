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
    test('a number with one optimal route says "Only possibility"', () {
      final engine = CheckoutEngine();
      final optimal = OptimalRouteService(engine);
      for (final one in [40, 50, 16, 170, 100]) {
        expect(optimal.optimalRoutes(one), hasLength(1), reason: '$one');
      }
      expect(optimal.optimalRoutes(132).length, greaterThan(1));
      expect(screen, contains('result.optimalRoutes.length == 1'));
      expect(screen, contains("text: 'Only possibility'"));
    });

    test('"Also optimal" is the button that opens the popup; there is no "All possibilities"', () {
      expect(screen, contains("button('Also optimal'"));
      expect(screen, contains('onPressed: (_) => openPossibilities()'));
      expect(screen, contains("focusKey: 'all'"));
      // The words "All possibilities" are gone: no link, no popup title.
      expect(screen, isNot(contains("button('All possibilities'")));
      expect(screen, isNot(contains("title: 'All possibilities'")));
      expect(screen, isNot(contains("'All possibilities'")));
      expect(screen, isNot(contains('why-row')));
      // The popup does not draw a title of its own.
      expect(screen, contains('showTitle: false'));
      // A number with two or more optimal routes always has "Also optimal" boxes,
      // so the popup can always be opened (extras is empty only for one route).
      final engine = CheckoutEngine();
      final optimal = OptimalRouteService(engine);
      for (final n in engine.checkoutableTargets) {
        final routes = optimal.optimalRoutes(n);
        if (routes.length < 2) continue;
        for (final shown in routes) {
          // Whichever route is on screen as the best or as yours, something is left.
          expect(BetterDoubles.extras(routes, exclude: [shown]), isNotEmpty, reason: '$n without $shown');
        }
      }
    });

    /// The value of [property] in the first rule that matches [selector].
    String value(String selector, String property) {
      final rule = RegExp('${RegExp.escape(selector)} \\{[^}]*\\}').firstMatch(css)!.group(0)!;
      return RegExp('$property: ([^;]+);').firstMatch(rule)!.group(1)!;
    }

    test('"Also optimal" is as big as the captions "Your darts" and "Optimal route"', () {
      const label = '.extra-routes .extra-title.text-link';
      const caption = '.board-figure figcaption';
      expect(value(label, 'font-size'), value(caption, 'font-size'));
      expect(value(label, 'letter-spacing'), value(caption, 'letter-spacing'));
      expect(value(label, 'text-transform'), value(caption, 'text-transform'));
      // Still a link you can see is one.
      expect(RegExp(r'\.text-link \{[^}]*\}').firstMatch(css)!.group(0)!, contains('text-decoration: underline'));
    });

    test('its boxes are the size of the boxes of "Your darts" and "Optimal route"', () {
      const main = '.board-figure .tile-row.small .tile';
      const also = '.result-more .tile-row.small .tile';
      for (final property in ['width', 'height', 'font-size']) {
        expect(value(also, property), value(main, property), reason: property);
      }
      expect(value(also, 'width'), '50px');
      expect(value(also, 'height'), '42px');
    });

    test('"Also optimal" is in the middle under the boards: under both after a miss', () {
      // Not inside either board's figure any more, but in its own centred block
      // after the row of boards and before the time and buttons.
      final boards = screen.indexOf("cls: 'result-boards'");
      final more = screen.indexOf("cls: 'result-more'");
      final footer = screen.indexOf('..._footer(ctx, result)');
      expect(boards, greaterThan(0));
      expect(more, greaterThan(boards));
      expect(footer, greaterThan(more));
      final figures = screen.substring(boards, more);
      expect(figures, isNot(contains('extraBoxes')));
      expect(figures, isNot(contains('onlyPossibility')));
      final block = RegExp(r'\.result-more \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(block, contains('align-items: center'));
      expect(block, contains('width: 100%'));
    });

    test('the popup shows every route at once - no "Shoot more"', () {
      expect(screen, contains('for (final route in RouteOrder.forPopup(result.optimalRoutes)) figureFor(route)'));
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
      // The visible line has the sentence only; the number is its own line.
      expect(screen, isNot(contains("text: 'Every optimal way to check out \${challenge.target}")));
      final rule = RegExp(r'\.modal-number \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(rule, contains('text-align: center'));
    });

    test('the sentence is in the grey the old title had, in its own font', () {
      final title = RegExp(r'\.modal-title \{[^}]*\}').firstMatch(css)!.group(0)!;
      final greyOfTitle = RegExp(r'color: (var\(--[a-z-]+\))').firstMatch(title)!.group(1)!;
      final top = RegExp(r'\.modal-line\.top \{[^}]*\}').firstMatch(css)!.group(0)!;
      expect(top, contains('color: $greyOfTitle'));
      expect(greyOfTitle, 'var(--muted)');
      // Its own font: the rule sets no size, case or spacing of its own (so it
      // keeps the popup line's font, not the small capitals of the title).
      for (final property in ['font-size', 'text-transform', 'letter-spacing', 'font-family']) {
        expect(top, isNot(contains(property)), reason: property);
      }
      // It is the topmost text now: nothing in front of it.
      final body = screen.substring(screen.indexOf('void openPossibilities()'));
      expect(body.indexOf("cls: 'modal-line top'"), lessThan(body.indexOf("cls: 'modal-number'")));
      expect(modal, contains('if (showTitle) el(\'h3\''));
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
