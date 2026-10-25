import 'dart:math';

import '../i18n/i18n.dart';
import 'phrases_hr.dart';

/// The silly lines of the app: 1000 goofy school-kid insults (for a number that
/// cannot be checked out) and five short praise lines (for a right "No
/// checkout").
///
/// The insults are built from word banks and sentence frames, then shuffled
/// with a fixed seed, so the list is always the same, every line is unique, and
/// no line is repeated until you have seen a lot of them. Mild swearing only; no
/// slurs, and nothing aimed at a real person's body or background.
abstract final class Phrases {
  /// How many insults there are.
  static const int count = 1000;

  static List<String>? _insults;

  static List<String> get insults =>
      _insults ??= _build(_insultCandidates(), seed: 7, always: _alwaysInsults);

  /// What a right "No checkout" says, one of these at random.
  static const List<String> encouragements = [
    'You a lion',
    'You a tiger',
    'You a monkey',
    'You a cucumber',
    'You a pizza',
  ];

  /// The examples from the brief are always in the list.
  static const List<String> _alwaysInsults = [
    'You look like a pickle!',
    'Stinky head!',
    'You look like a monkey!',
    'You are a triangle!',
  ];

  /// A random insult.
  static String randomInsult(Random random) {
    final lines = I18n.current == Language.hr ? PhrasesHr.insults : insults;
    return lines[random.nextInt(lines.length)];
  }

  /// A random praise line for a right "No checkout".
  static String randomEncouragement(Random random) {
    final lines = I18n.current == Language.hr ? PhrasesHr.encouragements : encouragements;
    return lines[random.nextInt(lines.length)];
  }

  /// Unique lines, shuffled the same way every time, cut to [count]. The
  /// [always] lines are in every time.
  static List<String> _build(
    Iterable<String> candidates, {
    required int seed,
    required List<String> always,
  }) {
    final rest = <String>{...candidates}..removeAll(always);
    final unique = rest.toList()..sort();
    unique.shuffle(Random(seed));
    assert(unique.length >= count, 'only ${unique.length} lines');
    final lines = [...always, ...unique.take(count - always.length)]
      ..shuffle(Random(seed + 1));
    return List.unmodifiable(lines);
  }

  /// "a" or "an" for the word that follows ("an otter", but "a unicycle").
  static String _a(String word) =>
      'aeiou'.contains(word[0]) && !word.startsWith('uni') ? 'an' : 'a';

  static String _cap(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  // ---------------------------------------------------------------- insults

  static const List<String> _nouns = [
    'pickle', 'potato', 'turnip', 'soggy biscuit', 'traffic cone', 'wet sock',
    'banana peel', 'garden gnome', 'rubber duck', 'cardboard box', 'meatball',
    'lumpy pillow', 'cabbage', 'sloth', 'goose', 'toaster', 'jelly', 'sandwich',
    'squeaky shoe', 'sponge', 'crooked spoon', 'penguin', 'burnt toast', 'fish',
    'walrus', 'llama', 'pigeon', 'noodle', 'teapot', 'waffle', 'raisin',
    'cheese', 'cereal bowl', 'sticky bun', 'spinning top', 'chicken', 'coconut',
    'wonky chair', 'rusty bucket', 'hedgehog', 'cloud', 'marshmallow',
    'broccoli', 'doorknob', 'kazoo', 'bagpipe', 'unicycle', 'accordion',
    'sausage', 'parsnip', 'radish', 'walnut', 'ostrich', 'flamingo', 'hamster',
    'goat', 'donkey', 'monkey', 'toad', 'newt', 'slug', 'snail', 'worm', 'moth',
    'cactus', 'mop', 'sock puppet', 'spatula', 'ladle', 'colander', 'teabag',
    'jellybean', 'gumdrop', 'pretzel', 'muffin', 'dumpling', 'pancake',
    'cucumber', 'beetroot', 'trombone', 'bicycle bell', 'lawn flamingo',
    'scarecrow', 'snowman', 'pillow fort', 'paper plane', 'bath duck',
    'sofa cushion', 'umbrella', 'wheelbarrow', 'garden hose', 'doormat',
  ];

  static const List<String> _shapes = [
    'triangle', 'trapezoid', 'rhombus', 'hexagon', 'parallelogram', 'pentagon',
    'rectangle', 'octagon', 'oval', 'square',
  ];

  static const List<String> _adjectives = [
    'stinky', 'smelly', 'wobbly', 'soggy', 'grumpy', 'lumpy', 'squishy',
    'fuzzy', 'slimy', 'crusty', 'sweaty', 'dusty', 'mouldy', 'wonky', 'clumsy',
    'floppy', 'squeaky', 'bonkers', 'goofy', 'silly', 'loopy', 'dizzy',
    'droopy', 'wiggly', 'scruffy', 'crooked', 'lazy', 'sleepy', 'sneaky',
    'grubby', 'mushy', 'greasy', 'bumpy', 'spotty', 'sticky', 'rusty', 'cranky',
    'jittery', 'frizzy', 'baggy', 'creaky', 'flimsy', 'gloopy', 'soppy',
  ];

  static Iterable<String> _insultCandidates() sync* {
    for (final noun in _nouns) {
      yield 'You look like ${_a(noun)} $noun!';
      yield '${_cap(noun)} head!';
      yield 'Even ${_a(noun)} $noun would have hit that!';
      yield 'Your brain called. It wants to be ${_a(noun)} $noun.';
      for (final adj in _adjectives) {
        yield '${_cap(adj)} $noun!';
        yield 'You $adj $noun!';
        yield 'You smell like ${_a(adj)} $adj $noun!';
        yield 'Your darts are ${_a(adj)} $adj $noun!';
      }
    }
    for (final adj in _adjectives) {
      yield '${_cap(adj)} head!';
      yield 'You are so $adj!';
    }
    for (final shape in _shapes) {
      yield 'You are ${_a(shape)} $shape!';
      yield 'You throw like ${_a(shape)} $shape!';
    }
    // A little mild swearing, as ordered.
    for (final noun in _nouns) {
      yield 'Oh crap, you $noun!';
      yield 'What the hell, $noun head!';
      yield 'Bloody $noun!';
      yield 'Damn, you absolute $noun!';
    }
  }
}
