import 'dart:convert';

import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';
import 'sample_players.dart';

enum LeaderboardSort {
  points('Total points'),
  averageTime('Average time'),
  accuracy('Accuracy'),
  optimalPercent('Optimal %');

  const LeaderboardSort(this.label);
  final String label;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    this.id,
    required this.playerName,
    required this.totalPoints,
    required this.averageTimeMs,
    required this.accuracyPercent,
    required this.optimalPercent,
    required this.attempts,
    this.isSample = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) => LeaderboardEntry(
        id: json['id'] as String?,
        playerName: json['playerName'] as String,
        totalPoints: (json['totalPoints'] as num).toInt(),
        averageTimeMs: (json['averageTimeMs'] as num?)?.toInt(),
        accuracyPercent: (json['accuracyPercent'] as num).toDouble(),
        optimalPercent: (json['optimalPercent'] as num).toDouble(),
        attempts: (json['attempts'] as num).toInt(),
      );

  factory LeaderboardEntry.fromStats(String playerName, StatsSummary stats) =>
      LeaderboardEntry(
        playerName: playerName,
        totalPoints: stats.totalPoints,
        averageTimeMs: stats.averageSuccessTimeMs,
        accuracyPercent: stats.accuracyPercent,
        optimalPercent: stats.optimalPercent,
        attempts: stats.totalAttempts,
      );

  /// Who this row belongs to on the online board (null for local rows).
  final String? id;

  /// A made-up player that only fills an empty place (see [SamplePlayers]); it
  /// is never stored or sent anywhere, and the screen marks it "sample".
  final bool isSample;
  final String playerName;
  final int totalPoints;

  /// Null when the player has no successful checkouts yet.
  final int? averageTimeMs;
  final double accuracyPercent;
  final double optimalPercent;
  final int attempts;

  Map<String, Object?> toJson() => {
        if (id != null) 'id': id,
        'playerName': playerName,
        'totalPoints': totalPoints,
        'averageTimeMs': averageTimeMs,
        'accuracyPercent': accuracyPercent,
        'optimalPercent': optimalPercent,
        'attempts': attempts,
      };
}

/// Where leaderboard data lives: on this device ([LocalLeaderboardRepository])
/// or on the shared online board (`OnlineLeaderboardRepository`).
abstract interface class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchEntries();

  /// Inserts or replaces this player's entry.
  Future<void> submit(LeaderboardEntry entry);

  /// True when the last [fetchEntries] came from the shared online board.
  bool get isOnline;

  /// This player's id on the online board (null when there is none yet), to
  /// show which row is theirs.
  String? get playerId;
}

/// Browser-local leaderboard seeded with mock rivals so it is never empty.
class LocalLeaderboardRepository implements LeaderboardRepository {
  LocalLeaderboardRepository(this._storage);

  static const String storageKey = 'dartle.leaderboard.v1';

  final StorageService _storage;

  @override
  bool get isOnline => false;

  @override
  String? get playerId => null;

  static const List<LeaderboardEntry> _mockRivals = [
    LeaderboardEntry(playerName: 'Bully', totalPoints: 186, averageTimeMs: 5200, accuracyPercent: 91, optimalPercent: 84, attempts: 40, isSample: true),
    LeaderboardEntry(playerName: 'TripleTwenty', totalPoints: 121, averageTimeMs: 6900, accuracyPercent: 82, optimalPercent: 70, attempts: 31, isSample: true),
    LeaderboardEntry(playerName: 'DoubleTop', totalPoints: 64, averageTimeMs: 4100, accuracyPercent: 95, optimalPercent: 60, attempts: 22, isSample: true),
    LeaderboardEntry(playerName: 'OneEighty', totalPoints: 12, averageTimeMs: 9800, accuracyPercent: 64, optimalPercent: 45, attempts: 17, isSample: true),
  ];

  @override
  Future<List<LeaderboardEntry>> fetchEntries() async {
    final stored = await _loadStored();
    final names = stored.map((e) => e.playerName).toSet();
    return [
      ...stored,
      ..._mockRivals.where((r) => !names.contains(r.playerName)),
    ];
  }

  @override
  Future<void> submit(LeaderboardEntry entry) async {
    final stored = await _loadStored();
    final updated = [
      ...stored.where((e) => e.playerName != entry.playerName),
      entry,
    ];
    await _storage.write(
      storageKey,
      jsonEncode([for (final e in updated) e.toJson()]),
    );
  }

  Future<List<LeaderboardEntry>> _loadStored() async {
    final raw = await _storage.read(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<Object?>)
          LeaderboardEntry.fromJson((item as Map<Object?, Object?>).cast<String, Object?>())
      ];
    } on Object {
      return [];
    }
  }
}

/// Ranking rules. Points is the primary leaderboard; other sorts are views.
class LeaderboardService {
  LeaderboardService(this._repository);

  final LeaderboardRepository _repository;

  /// True when the last board came from the shared online leaderboard.
  bool get isOnline => _repository.isOnline;

  /// This player's id on the online board, if they have one.
  String? get playerId => _repository.playerId;

  /// The board always has this many rows: the real players, and made-up
  /// "sample" players filling the empty places.
  static const int boardSize = 180;

  /// Set to false for a board of real players only (it then has as many rows
  /// as there are players, at most [boardSize]).
  static const bool fillWithSamples = true;

  Future<List<LeaderboardEntry>> ranked(
      [LeaderboardSort sort = LeaderboardSort.points]) async {
    final entries = await _repository.fetchEntries();
    return rank(withSamples(entries), sort).take(boardSize).toList();
  }

  /// The real players of [entries] plus enough sample players to make [size]
  /// rows. Any sample rows a repository sent are replaced. The sample players
  /// that go first are the best-scoring ones, so real players take over the top
  /// of the board as they join, and with [size] real players there are none.
  static List<LeaderboardEntry> withSamples(List<LeaderboardEntry> entries,
      {int size = boardSize}) {
    final real = [for (final e in entries) if (!e.isSample) e];
    final missing = size - real.length;
    if (!fillWithSamples || missing <= 0) return real;
    return [...real, ...SamplePlayers.all.skip(real.length).take(missing)];
  }

  Future<void> submit(String playerName, StatsSummary stats) =>
      _repository.submit(LeaderboardEntry.fromStats(playerName, stats));

  /// Pure ranking so it can be tested without any repository.
  static List<LeaderboardEntry> rank(
      List<LeaderboardEntry> entries, LeaderboardSort sort) {
    int primary(LeaderboardEntry a, LeaderboardEntry b) => switch (sort) {
          LeaderboardSort.points => b.totalPoints.compareTo(a.totalPoints),
          LeaderboardSort.averageTime => _compareTime(a.averageTimeMs, b.averageTimeMs),          LeaderboardSort.accuracy => b.accuracyPercent.compareTo(a.accuracyPercent),
          LeaderboardSort.optimalPercent => b.optimalPercent.compareTo(a.optimalPercent),
        };
    return [...entries]..sort((a, b) {
        final p = primary(a, b);
        if (p != 0) return p;
        final byPoints = b.totalPoints.compareTo(a.totalPoints);
        return byPoints != 0 ? byPoints : a.playerName.compareTo(b.playerName);
      });
  }

  /// Faster is better; players with no time yet sort last.
  static int _compareTime(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
