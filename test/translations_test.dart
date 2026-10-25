import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:dartle/src/content/phrases_hr.dart';
import 'package:dartle/src/i18n/croatian.dart';
import 'package:test/test.dart';

import 'support/used_texts.dart';

/// The pieces in braces of a text: `{name}` in "Hi, {name}".
Set<String> pieces(String text) =>
    {for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) m.group(1)!};

void main() {
  tearDown(() => I18n.current = Language.en);

  group('the Croatian catalog', () {
    final used = usedTexts();

    test('has every text the app asks for', () {
      final missing = [for (final key in used) if (!croatian.containsKey(key)) key]..sort();
      expect(missing, isEmpty, reason: 'not translated yet:\n${missing.join('\n')}');
    });

    test('has nothing left over that the app no longer asks for', () {
      final stale = [for (final key in croatian.keys) if (!used.contains(key)) key]..sort();
      expect(stale, isEmpty, reason: 'not used any more:\n${stale.join('\n')}');
    });

    test('keeps every {piece} of the English text, and adds none', () {
      for (final entry in croatian.entries) {
        for (final form in entry.value.split('|')) {
          expect(pieces(form).difference(pieces(entry.key)), isEmpty,
              reason: 'extra piece in: $form');
        }
        // Every form of a count text has the pieces of the English ones.
        if (entry.key.contains('|')) {
          for (final form in entry.value.split('|')) {
            expect(pieces(form), pieces(entry.key.split('|').first),
                reason: 'a form is missing a piece: $form');
          }
        } else {
          expect(pieces(entry.value), pieces(entry.key), reason: entry.key);
        }
      }
    });

    test('count texts have the three Croatian forms', () {
      for (final entry in croatian.entries.where((e) => e.key.contains('|'))) {
        expect(entry.value.split('|'), hasLength(3), reason: entry.key);
        expect(entry.key.split('|'), hasLength(2), reason: entry.key);
      }
    });

    test('never leaves a text empty or the same as the English (apart from darts words)', () {
      const same = {
        'Single', 'Double', 'Triple', 'Bull, 50', 'Bust', 'Checkout!',
      };
      for (final entry in croatian.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        if (!same.contains(entry.key)) {
          expect(entry.value, isNot(entry.key), reason: 'not translated: ${entry.key}');
        }
      }
    });
  });

  group('tr', () {
    test('is the English text itself in English', () {
      expect(tr('Start'), 'Start');
      expect(tr('Hi, {name}', {'name': 'Ana'}), 'Hi, Ana');
    });

    test('is the Croatian text in Croatian, with the pieces filled in', () {
      I18n.current = Language.hr;
      expect(tr('Start'), 'Kreni');
      expect(tr('Hi, {name}', {'name': 'Ana'}), 'Bok, Ana');
      expect(tr('Number {n}', {'n': 74}), 'Broj 74');
    });

    test('a text with no translation is shown in English, never blank', () {
      I18n.current = Language.hr;
      expect(tr('A brand new text {x}', {'x': 1}), 'A brand new text 1');
    });

    test('a piece that was not given stays as it is', () {
      expect(tr('Hi, {name}'), 'Hi, {name}');
    });
  });

  group('trn - texts that depend on a count', () {
    test('English: one, or the other form', () {
      expect(trn(1, '{n} Dart', '{n} Darts'), '1 Dart');
      expect(trn(2, '{n} Dart', '{n} Darts'), '2 Darts');
      expect(trn(0, '{n} Dart', '{n} Darts'), '0 Darts');
    });

    test('Croatian: 1 and 21, 2 to 4 and 22, and the rest (11 to 14 are the rest)', () {
      I18n.current = Language.hr;
      String darts(int n) => trn(n, '{n} Dart', '{n} Darts');
      expect(darts(1), '1 strelica');
      expect(darts(2), '2 strelice');
      expect(darts(3), '3 strelice');
      expect(darts(4), '4 strelice');
      expect(darts(5), '5 strelica');
      expect(darts(11), '11 strelica');
      expect(darts(12), '12 strelica');
      expect(darts(14), '14 strelica');
      expect(darts(21), '21 strelica');
      expect(darts(22), '22 strelice');
      expect(darts(25), '25 strelica');
      expect(darts(0), '0 strelica');
    });

    test('the other pieces are filled in too', () {
      I18n.current = Language.hr;
      expect(trn(2, 'Checkout {target}, {n} dart left', 'Checkout {target}, {n} darts left', {'target': 74}),
          'Checkout 74, ostale 2 strelice');
      expect(trn(1, 'Checkout {target}, {n} dart left', 'Checkout {target}, {n} darts left', {'target': 40}),
          'Checkout 40, ostala 1 strelica');
    });
  });

  group('the language', () {
    test('there are two for now, EN and HR, and the box goes round them', () {
      expect(Language.values.map((l) => l.code), ['EN', 'HR']);
      expect(Language.en.next, Language.hr);
      expect(Language.hr.next, Language.en);
      expect(Language.fromCode('HR'), Language.hr);
      expect(Language.fromCode('XX'), isNull);
      expect(Language.fromCode(null), isNull);
    });

    test('every language but English has a catalog', () {
      for (final language in Language.values.where((l) => l != Language.en)) {
        expect(I18n.catalogs[language], isNotNull, reason: language.name);
      }
    });

    test('the choice is saved and read back; English when nothing was saved', () async {
      final storage = InMemoryStorageService();
      await I18n.load(storage);
      expect(I18n.current, Language.en);
      await I18n.choose(storage, Language.hr);
      expect(I18n.current, Language.hr);
      I18n.current = Language.en;
      await I18n.load(storage);
      expect(I18n.current, Language.hr);
    });

    test('a broken saved value falls back to English', () async {
      final storage = InMemoryStorageService();
      await storage.write(I18n.storageKey, 'klingon');
      await I18n.load(storage);
      expect(I18n.current, Language.en);
    });

    test('the game switches the language, keeps it, and tells the screen', () async {
      final storage = InMemoryStorageService();
      final game = createGameController(storage);
      await game.init();
      var told = 0;
      game.addListener(() => told++);
      await game.setLanguage(Language.hr);
      expect(I18n.current, Language.hr);
      expect(told, 1);
      I18n.current = Language.en;
      final again = createGameController(storage);
      await again.init();
      expect(I18n.current, Language.hr, reason: 'it is read back when the app starts');
    });
  });

  group('the texts the app builds from the game', () {
    test('the mode names, the leaderboard buttons and the scoring lines all change', () {
      I18n.current = Language.hr;
      expect(tr(GameMode.calculator.label), 'Checkout kalkulator');
      expect(tr(GameMode.choice.label), 'Checkout vježba');
      expect(tr(GameMode.input.label), 'Checkout unos');
      expect(tr(LeaderboardSort.points.label), 'Ukupno bodova');
      final score = const ScoringService().score(
        correct: true,
        timeLeft: const Duration(seconds: 10),
        streakBefore: 0,
      );
      expect(score.explain().first, contains('Preostalo vrijeme: 10.00s'));
      expect(score.explain()[1], 'To je 1. checkout zaredom, pa vrijedi 1 bod.');
    });

    test('the spoken names of the darts change', () {
      I18n.current = Language.hr;
      expect(DartThrow.parse('T20').spokenName, 'Triple 20');
      expect(DartThrow.parse('Bull').spokenName, 'Bull, 50');
      expect(DartThrow.parse('25').spokenName, 'Vanjski bull, 25');
    });
  });

  group('the silly lines in Croatian', () {
    test('1000 different insults, in the same order every time', () {
      final lines = PhrasesHr.insults;
      expect(lines, hasLength(1000));
      expect(lines.toSet(), hasLength(1000));
      expect(identical(PhrasesHr.insults, PhrasesHr.insults), isTrue);
      for (final always in PhrasesHr.always) {
        expect(lines, contains(always));
      }
    });

    test('every insult is a sentence of its own with an ending', () {
      for (final line in PhrasesHr.insults) {
        expect(line.trim(), line);
        expect(line.endsWith('!') || line.endsWith('.'), isTrue, reason: line);
        expect(line.length, greaterThan(8), reason: line);
      }
    });

    test('the words agree with the noun: feminine, neuter and masculine endings', () {
      final lines = PhrasesHr.insults.toSet();
      // Whatever is in the list, a feminine noun never gets a masculine adjective.
      expect(lines.any((l) => l.contains('smrdljiv repa')), isFalse);
      expect(lines.any((l) => l.contains('smrdljiva krastavac')), isFalse);
      expect(lines.any((l) => l.contains('smrdljivo krumpir')), isFalse);
    });

    test('Phrases gives the Croatian lines when Croatian is on', () {
      final random = Random(1);
      I18n.current = Language.hr;
      expect(PhrasesHr.insults, contains(Phrases.randomInsult(random)));
      expect(PhrasesHr.encouragements, contains(Phrases.randomEncouragement(random)));
      I18n.current = Language.en;
      expect(Phrases.insults, contains(Phrases.randomInsult(random)));
      expect(Phrases.encouragements, contains(Phrases.randomEncouragement(random)));
    });
  });
}
