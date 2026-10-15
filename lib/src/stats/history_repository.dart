import 'dart:convert';

import '../storage/storage_service.dart';
import 'attempt_record.dart';

/// Persists the full attempt history. Statistics are always *derived* from it,
/// so there is a single source of truth and no counters that can drift.
///
/// Two of these exist side by side, each under its own key: the one the
/// Statistics screen shows (which "Reset statistics" clears) and the record the
/// leaderboard is worked out from (which a reset never touches).
class HistoryRepository {
  HistoryRepository(this._storage, {String key = storageKey}) : _key = key;

  static const String storageKey = 'dartle.history.v1';

  final StorageService _storage;
  final String _key;

  Future<List<AttemptRecord>> load() async => await loadIfSaved() ?? [];

  /// The saved attempts, or null when nothing is saved under this key (or it
  /// cannot be read). Corrupt data must never brick the app.
  Future<List<AttemptRecord>?> loadIfSaved() async {
    final raw = await _storage.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final item in list)
          AttemptRecord.fromJson((item as Map<Object?, Object?>).cast<String, Object?>())
      ];
    } on Object {
      return null;
    }
  }

  Future<void> save(List<AttemptRecord> history) => _storage.write(
        _key,
        jsonEncode([for (final r in history) r.toJson()]),
      );

  Future<void> clear() => _storage.remove(_key);
}
