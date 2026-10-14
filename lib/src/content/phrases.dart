import 'dart:math';

/// The silly lines of the app: 1000 goofy school-kid insults (for a number that
/// cannot be checked out) and 1000 encouragements (for a right "No checkout").
///
/// They are built from word banks and sentence frames, then shuffled with a
/// fixed seed, so the lists are always the same, every line is unique, and no
/// line is repeated until you have seen a lot of them. Mild swearing only; no
/// slurs, and nothing aimed at a real person's body or background.
abstract final class Phrases {
  /// How many lines each list has.
  static const int count = 1000;

  static List<String>? _insults;
  static List<String>? _encouragements;

  static List<String> get insults =>
      _insults ??= _build(_insultCandidates(), seed: 7, always: _alwaysInsults);

  static List<String> get encouragements => _encouragements ??=
      _build(_encouragementCandidates(), seed: 11, always: _alwaysEncouragements);

  /// The examples from the brief are always in the lists.
  static const List<String> _alwaysInsults = [
    'You look like a pickle!',
    'Stinky head!',
    'You look like a monkey!',
    'You are a triangle!',
  ];

  static const List<String> _alwaysEncouragements = [
    'Go tiger!',
    'Normal.',
    'No pigeon is out of your reach.',
  ];

  /// A random insult.
  static String randomInsult(Random random) => insults[random.nextInt(count)];

  /// A random encouragement.
  static String randomEncouragement(Random random) =>
      encouragements[random.nextInt(count)];

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
      yield 'You look like a $noun!';
      yield '${_cap(noun)} head!';
      yield 'Even a $noun would have hit that!';
      yield 'Your brain called. It wants to be a $noun.';
      for (final adj in _adjectives) {
        yield '${_cap(adj)} $noun!';
        yield 'You $adj $noun!';
        yield 'You smell like a $adj $noun!';
        yield 'Your darts are a $adj $noun!';
      }
    }
    for (final adj in _adjectives) {
      yield '${_cap(adj)} head!';
      yield 'You are so $adj!';
    }
    for (final shape in _shapes) {
      yield 'You are a $shape!';
      yield 'You throw like a $shape!';
    }
    // A little mild swearing, as ordered.
    for (final noun in _nouns) {
      yield 'Oh crap, you $noun!';
      yield 'What the hell, $noun head!';
      yield 'Bloody $noun!';
      yield 'Damn, you absolute $noun!';
    }
  }

  // --------------------------------------------------------- encouragements

  static const List<String> _animals = [
    'tiger', 'panther', 'eagle', 'dolphin', 'falcon', 'cheetah', 'lion',
    'wolf', 'badger', 'otter', 'hawk', 'shark', 'bear', 'fox', 'lynx', 'stallion',
    'gorilla', 'rhino', 'owl', 'cobra', 'gazelle', 'bison', 'moose', 'puma',
    'kingfisher', 'pelican', 'hummingbird', 'octopus', 'kangaroo', 'koala',
    'penguin', 'llama', 'hedgehog', 'capybara', 'walrus', 'ferret', 'beaver',
    'raccoon', 'giraffe', 'zebra',
  ];

  static const List<String> _praise = [
    'mighty', 'magnificent', 'brilliant', 'legendary', 'glorious', 'splendid',
    'fabulous', 'majestic', 'heroic', 'dazzling', 'unstoppable', 'radiant',
    'fearless', 'supreme', 'dashing', 'marvellous', 'spectacular', 'peerless',
    'gleaming', 'epic', 'golden', 'electric', 'cosmic', 'turbo', 'galactic',
  ];

  static const List<String> _things = [
    'pigeon', 'balloon', 'kite', 'cloud', 'comet', 'biscuit', 'sandwich',
    'high shelf', 'treetop', 'lighthouse', 'moon', 'rainbow', 'bus', 'sunbeam',
    'apple', 'banana', 'doughnut', 'skyscraper', 'mountain', 'butterfly',
    'seagull', 'frisbee', 'firework', 'trampoline', 'satellite',
  ];

  static const List<String> _skills = [
    'think', 'throw', 'shine', 'glide', 'dance', 'aim', 'plan', 'play',
    'count', 'sparkle',
  ];

  static Iterable<String> _encouragementCandidates() sync* {
    yield 'Normal.';
    yield 'Perfectly normal.';
    yield 'Very normal. Very good.';
    yield 'Totally normal behaviour. Carry on.';
    for (final animal in _animals) {
      yield 'Go $animal!';
      yield 'Absolute $animal energy!';
      yield 'Hell yes, $animal!';
      for (final praise in _praise) {
        yield 'You are a $praise $animal!';
      }
      for (final skill in _skills) {
        yield 'You $skill like a $animal!';
      }
    }
    for (final thing in _things) {
      yield 'No $thing is out of your reach.';
      yield 'You could out-throw a $thing.';
      for (final praise in _praise) {
        yield 'Pure $praise $thing energy!';
      }
    }
    for (final praise in _praise) {
      yield 'Bloody $praise!';
      yield 'Damn, that was $praise!';
      yield 'Well that is just $praise.';
      yield 'Stay $praise, my friend.';
    }
  }
}
