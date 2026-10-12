import 'dart:convert';

import '../stats/statistics_service.dart';
import '../storage/storage_service.dart';

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
    required this.playerName,
    required this.totalPoints,
    required this.averageTimeMs,
    required this.accuracyPercent,
    required this.optimalPercent,
    required this.attempts,
  });

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) => LeaderboardEntry(
        playerName: json['playerName'] as String,
        totalPoints: json['totalPoints'] as int,
        averageTimeMs: json['averageTimeMs'] as int?,
        accuracyPercent: (json['accuracyPercent'] as num).toDouble(),
        optimalPercent: (json['optimalPercent'] as num).toDouble(),
        attempts: json['attempts'] as int,
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

  final String playerName;
  final int totalPoints;

  /// Null when the player has no successful checkouts yet.
  final int? averageTimeMs;
  final double accuracyPercent;
  final double optimalPercent;
  final int attempts;

  Map<String, Object?> toJson() => {
        'playerName': playerName,
        'totalPoints': totalPoints,
        'averageTimeMs': averageTimeMs,
        'accuracyPercent': accuracyPercent,
        'optimalPercent': optimalPercent,
        'attempts': attempts,
      };
}

/// Where leaderboard data lives. Implement this against a real backend later.
abstract interface class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchEntries();

  /// Inserts or replaces the entry for `entry.playerName`.
  Future<void> submit(LeaderboardEntry entry);
}

/// Browser-local leaderboard seeded with mock rivals so it is never empty.
class LocalLeaderboardRepository implements LeaderboardRepository {
  LocalLeaderboardRepository(this._storage);

  static const String storageKey = 'dartle.leaderboard.v1';

  final StorageService _storage;

  static const List<LeaderboardEntry> _mockRivals = [
    LeaderboardEntry(playerName: 'Bully', totalPoints: 186, averageTimeMs: 5200, accuracyPercent: 91, optimalPercent: 84, attempts: 40),
    LeaderboardEntry(playerName: 'TripleTwenty', totalPoints: 121, averageTimeMs: 6900, accuracyPercent: 82, optimalPercent: 70, attempts: 31),
    LeaderboardEntry(playerName: 'DoubleTop', totalPoints: 64, averageTimeMs: 4100, accuracyPercent: 95, optimalPercent: 60, attempts: 22),
    LeaderboardEntry(playerName: 'OneEighty', totalPoints: 12, averageTimeMs: 9800, accuracyPercent: 64, optimalPercent: 45, attempts: 17),
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

  Future<List<LeaderboardEntry>> ranked(
      [LeaderboardSort sort = LeaderboardSort.points]) async {
    final entries = await _repository.fetchEntries();
    return rank(entries, sort);
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
