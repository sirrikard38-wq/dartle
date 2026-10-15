import 'dart:math';

import 'leaderboard_service.dart';

/// Made-up players that fill the empty places of the leaderboard, so it always
/// has [count] rows. They are marked "sample" on screen, are never stored or
/// sent anywhere, and give way to real players as they join.
///
/// The list is built the same way every time (fixed seed): 180 different
/// names, the best-scoring first. Their points stay low (60 down to 1), so real
/// players with a real score sit above them.
abstract final class SamplePlayers {
  static const int count = 180;

  /// The most points a sample player has.
  static const int topPoints = 60;

  static List<LeaderboardEntry>? _all;

  /// Every sample player, best points first.
  static List<LeaderboardEntry> get all => _all ??= List.unmodifiable(_build());

  static const List<String> _firsts = [
    'Triple', 'Double', 'Bulls', 'Dart', 'Steady', 'Lucky', 'Quick', 'Calm',
    'Sharp', 'Flying', 'Golden', 'Iron', 'Silver', 'Crafty', 'Mighty', 'Tiny',
    'Rapid', 'Cool', 'Brave', 'Wild', 'Smooth', 'Sneaky', 'Lazy', 'Jolly',
    'Clever', 'Happy', 'Grumpy', 'Dizzy', 'Bouncy', 'Fuzzy',
  ];

  static const List<String> _seconds = [
    'Arrow', 'Barrel', 'Flight', 'Oche', 'Bullseye', 'Checkout', 'Finisher',
    'Thrower', 'Tungsten', 'Shaft', 'Treble', 'Ton', 'Wire', 'Board', 'Tip',
    'Grip', 'Pigeon', 'Walrus', 'Otter', 'Falcon', 'Badger', 'Gnome', 'Biscuit',
    'Noodle', 'Pickle', 'Goose', 'Llama', 'Sloth', 'Penguin', 'Waffle',
  ];

  static List<LeaderboardEntry> _build() {
    final random = Random(180);
    final names = <String>[
      for (final first in _firsts)
        for (final second in _seconds) '$first$second',
    ]..sort();
    names.shuffle(random);
    return [
      for (var i = 0; i < count; i++)
        _entry(names[i], i, random),
    ];
  }

  /// Player number [i] (0 is the best): points fall from [topPoints] to 1, the
  /// other figures are made up but plausible.
  static LeaderboardEntry _entry(String name, int i, Random random) {
    final points = max(1, topPoints - (i * (topPoints - 1)) ~/ (count - 1));
    return LeaderboardEntry(
      playerName: name,
      totalPoints: points,
      averageTimeMs: 4000 + random.nextInt(10000),
      accuracyPercent: 35 + random.nextInt(61).toDouble(),
      optimalPercent: 10 + random.nextInt(81).toDouble(),
      attempts: 5 + points * 2 + random.nextInt(10),
      isSample: true,
    );
  }
}
