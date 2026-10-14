import 'dart:math';

import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  group('Phrases', () {
    test('there are exactly 1000 insults and 1000 encouragements', () {
      expect(Phrases.insults, hasLength(1000));
      expect(Phrases.encouragements, hasLength(1000));
      expect(Phrases.count, 1000);
    });

    test('every line is unique and not blank', () {
      for (final list in [Phrases.insults, Phrases.encouragements]) {
        expect(list.toSet(), hasLength(list.length));
        expect(list.every((line) => line.trim().isNotEmpty), isTrue);
        expect(list.every((line) => line == line.trim()), isTrue);
        expect(list.every((line) => line.endsWith('!') || line.endsWith('.')), isTrue);
      }
    });

    test('the lists never change between calls (or runs)', () {
      expect(identical(Phrases.insults, Phrases.insults), isTrue);
      expect(Phrases.insults.first, isNotEmpty);
    });

    test('the examples from the brief are in', () {
      expect(Phrases.insults, containsAll([
        'You look like a pickle!', 'Stinky head!', 'You look like a monkey!',
        'You are a triangle!',
      ]));
      expect(Phrases.encouragements, containsAll([
        'Go tiger!', 'Normal.', 'No pigeon is out of your reach.',
      ]));
    });

    test('"a" and "an" are used properly', () {
      final a = RegExp(r'\ba (?=[aeiou])');
      final an = RegExp(r'\ban (?![aeiou])');
      for (final line in [...Phrases.insults, ...Phrases.encouragements]) {
        // "a unicycle" is right: it starts with a consonant sound.
        final check = line.replaceAll('a unicycle', 'the unicycle');
        expect(a.hasMatch(check), isFalse, reason: line);
        expect(an.hasMatch(check), isFalse, reason: line);
      }
    });

    test('the two lists are different things', () {
      expect(Phrases.insults.toSet().intersection(Phrases.encouragements.toSet()), isEmpty);
    });

    test('a random line comes from the list, and the lines vary', () {
      final random = Random(1);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final insult = Phrases.randomInsult(random);
        final nice = Phrases.randomEncouragement(random);
        expect(Phrases.insults, contains(insult));
        expect(Phrases.encouragements, contains(nice));
        seen.add(insult);
      }
      expect(seen.length, greaterThan(150));
    });

    test('it stays silly, not nasty: no slurs and nothing about bodies or backgrounds', () {
      const banned = [
        'fat', 'ugly', 'stupid', 'idiot', 'retard', 'gay', 'black', 'white', 'jew',
        'cripple', 'bald', 'skinny', 'poor', 'loser',
      ];
      for (final line in [...Phrases.insults, ...Phrases.encouragements]) {
        final words = line.toLowerCase().split(RegExp(r'[^a-z]+'));
        for (final word in banned) {
          expect(words, isNot(contains(word)), reason: line);
        }
      }
    });
  });
}
