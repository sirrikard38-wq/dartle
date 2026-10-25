import 'dart:math';

/// The Croatian version of the silly lines (see `Phrases`): goofy insults for a
/// number that cannot be checked out, and five praise lines for a right "No
/// checkout". Built from word banks and sentence frames like the English ones,
/// but Croatian words have a gender, so every noun comes with the endings of
/// the words that go with it, and every adjective in all three genders.
/// Mild swearing only, nothing aimed at a real person.
abstract final class PhrasesHr {
  static const List<String> encouragements = [
    'Ti si lav',
    'Ti si tigar',
    'Ti si majmun',
    'Ti si krastavac',
    'Ti si pizza',
  ];

  /// The lines every list has (the examples from the brief).
  static const List<String> always = [
    'Izgledaš kao krastavac!',
    'Smrdljiva glava!',
    'Izgledaš kao majmun!',
    'Ti si trokut!',
  ];

  /// How many lines the Croatian list has (the same as the English one).
  static const int count = 1000;

  static List<String>? _insults;

  /// [count] different lines, in the same order every time.
  static List<String> get insults => _insults ??= _build();

  // ------------------------------------------------------------------ words

  /// A noun in the nominative, and the three words that must agree with its
  /// gender: "pravi", "prokleti" and the past tense of "pogoditi".
  static const List<_Noun> _nouns = [
    // masculine
    _Noun('krastavac', _Gender.m), _Noun('krumpir', _Gender.m), _Noun('kupus', _Gender.m),
    _Noun('puž', _Gender.m), _Noun('jež', _Gender.m), _Noun('pingvin', _Gender.m),
    _Noun('šaran', _Gender.m), _Noun('golub', _Gender.m), _Noun('magarac', _Gender.m),
    _Noun('majmun', _Gender.m), _Noun('kozel', _Gender.m), _Noun('tost', _Gender.m),
    _Noun('kolač', _Gender.m), _Noun('grah', _Gender.m), _Noun('luk', _Gender.m),
    _Noun('ćevap', _Gender.m), _Noun('burek', _Gender.m), _Noun('kruh', _Gender.m),
    _Noun('čekić', _Gender.m), _Noun('kišobran', _Gender.m), _Noun('tanjur', _Gender.m),
    _Noun('lonac', _Gender.m), _Noun('čajnik', _Gender.m), _Noun('toster', _Gender.m),
    _Noun('jastuk', _Gender.m), _Noun('sapun', _Gender.m), _Noun('ručnik', _Gender.m),
    _Noun('prometni čunj', _Gender.m), _Noun('gumeni patak', _Gender.m),
    _Noun('vrtni patuljak', _Gender.m),
    // feminine
    _Noun('tikva', _Gender.f), _Noun('repa', _Gender.f), _Noun('mrkva', _Gender.f),
    _Noun('kruška', _Gender.f), _Noun('jabuka', _Gender.f), _Noun('banana', _Gender.f),
    _Noun('patka', _Gender.f), _Noun('guska', _Gender.f), _Noun('koza', _Gender.f),
    _Noun('žaba', _Gender.f), _Noun('riba', _Gender.f), _Noun('kvaka', _Gender.f),
    _Noun('krpa', _Gender.f), _Noun('metla', _Gender.f), _Noun('kanta', _Gender.f),
    _Noun('vreća', _Gender.f), _Noun('kutija', _Gender.f), _Noun('žlica', _Gender.f),
    _Noun('tava', _Gender.f), _Noun('šalica', _Gender.f), _Noun('kobasica', _Gender.f),
    _Noun('hrenovka', _Gender.f), _Noun('palačinka', _Gender.f), _Noun('juha', _Gender.f),
    _Noun('torta', _Gender.f), _Noun('pogača', _Gender.f), _Noun('lopta', _Gender.f),
    _Noun('mokra čarapa', _Gender.f), _Noun('kora od banane', _Gender.f),
    _Noun('vrtna žaba', _Gender.f),
    // neuter
    _Noun('jaje', _Gender.n), _Noun('pile', _Gender.n), _Noun('prase', _Gender.n),
    _Noun('janje', _Gender.n), _Noun('pecivo', _Gender.n), _Noun('ogledalo', _Gender.n),
    _Noun('kopito', _Gender.n), _Noun('zrcalo', _Gender.n), _Noun('tijesto', _Gender.n),
    _Noun('vino', _Gender.n),
  ];

  /// An adjective in the nominative: masculine, feminine and neuter.
  static const List<(String, String, String)> _adjectives = [
    ('smrdljiv', 'smrdljiva', 'smrdljivo'),
    ('ljigav', 'ljigava', 'ljigavo'),
    ('ljepljiv', 'ljepljiva', 'ljepljivo'),
    ('pospan', 'pospana', 'pospano'),
    ('lijen', 'lijena', 'lijeno'),
    ('mrzovoljan', 'mrzovoljna', 'mrzovoljno'),
    ('kvrgav', 'kvrgava', 'kvrgavo'),
    ('mastan', 'masna', 'masno'),
    ('prašnjav', 'prašnjava', 'prašnjavo'),
    ('plijesniv', 'plijesniva', 'plijesnivo'),
    ('vlažan', 'vlažna', 'vlažno'),
    ('škripav', 'škripava', 'škripavo'),
    ('klimav', 'klimava', 'klimavo'),
    ('šašav', 'šašava', 'šašavo'),
    ('blesav', 'blesava', 'blesavo'),
    ('nespretan', 'nespretna', 'nespretno'),
    ('razmažen', 'razmažena', 'razmaženo'),
    ('dlakav', 'dlakava', 'dlakavo'),
    ('čupav', 'čupava', 'čupavo'),
    ('prljav', 'prljava', 'prljavo'),
    ('znojan', 'znojna', 'znojno'),
    ('trom', 'troma', 'tromo'),
    ('tvrdoglav', 'tvrdoglava', 'tvrdoglavo'),
    ('napuhan', 'napuhana', 'napuhano'),
    ('neuredan', 'neuredna', 'neuredno'),
    ('zahrđao', 'zahrđala', 'zahrđalo'),
    ('hrapav', 'hrapava', 'hrapavo'),
    ('mlitav', 'mlitava', 'mlitavo'),
    ('kiseo', 'kisela', 'kiselo'),
    ('ljutit', 'ljutita', 'ljutito'),
    ('tužan', 'tužna', 'tužno'),
    ('zbunjen', 'zbunjena', 'zbunjeno'),
    ('umoran', 'umorna', 'umorno'),
    ('mekan', 'mekana', 'mekano'),
    ('smotan', 'smotana', 'smotano'),
    ('razbarušen', 'razbarušena', 'razbarušeno'),
    ('užasan', 'užasna', 'užasno'),
    ('čudan', 'čudna', 'čudno'),
    ('smiješan', 'smiješna', 'smiješno'),
    ('naboran', 'naborana', 'naborano'),
  ];

  static const List<String> _shapes = [
    'trokut', 'trapez', 'romb', 'šesterokut', 'paralelogram', 'peterokut',
    'pravokutnik', 'osmerokut', 'kvadrat', 'krug',
  ];

  // ----------------------------------------------------------------- frames

  static Iterable<String> _candidates() sync* {
    for (final noun in _nouns) {
      yield 'Izgledaš kao ${noun.word}!';
      yield 'Smrdiš kao ${noun.word}!';
      yield 'Čak bi i ${noun.word} to ${noun.pogodio}!';
      yield 'Tvoj mozak je zvao. Želi biti ${noun.word}.';
      yield 'Ti si ${noun.pravi} ${noun.word}!';
      yield '${noun.prokleti} ${noun.word}!';
      yield 'Do vraga, ti ${noun.word}!';
      for (final adjective in _adjectives) {
        final adj = noun.adjective(adjective);
        yield '${_cap(adj)} ${noun.word}!';
        yield 'Ti si $adj ${noun.word}!';
        yield 'Izgledaš kao $adj ${noun.word}!';
        yield 'Smrdiš kao $adj ${noun.word}!';
        yield 'Bacaš kao $adj ${noun.word}!';
      }
    }
    for (final adjective in _adjectives) {
      yield '${_cap(adjective.$2)} glava!';
      yield 'Ti si tako ${adjective.$1}!';
    }
    for (final shape in _shapes) {
      yield 'Ti si $shape!';
      yield 'Bacaš kao $shape!';
    }
  }

  static String _cap(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  /// Unique lines, shuffled the same way every time, cut to [count].
  static List<String> _build() {
    final rest = <String>{..._candidates()}..removeAll(always);
    final unique = rest.toList()..sort();
    unique.shuffle(Random(7));
    assert(unique.length >= count, 'only ${unique.length} lines');
    final lines = [...always, ...unique.take(count - always.length)]..shuffle(Random(8));
    return List.unmodifiable(lines);
  }
}

enum _Gender { m, f, n }

/// A noun and what must agree with it.
class _Noun {
  const _Noun(this.word, this.gender);

  final String word;
  final _Gender gender;

  /// "pravi" (a real one), "prokleti" (damned) and the past tense of "pogoditi"
  /// in the noun's gender.
  String get pravi => switch (gender) { _Gender.m => 'pravi', _Gender.f => 'prava', _Gender.n => 'pravo' };

  String get prokleti =>
      switch (gender) { _Gender.m => 'Prokleti', _Gender.f => 'Prokleta', _Gender.n => 'Prokleto' };

  String get pogodio =>
      switch (gender) { _Gender.m => 'pogodio', _Gender.f => 'pogodila', _Gender.n => 'pogodilo' };

  /// The adjective (masculine, feminine, neuter) in this noun's gender.
  String adjective((String, String, String) forms) =>
      switch (gender) { _Gender.m => forms.$1, _Gender.f => forms.$2, _Gender.n => forms.$3 };
}
