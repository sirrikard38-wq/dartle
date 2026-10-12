import 'dart:convert';

import '../storage/storage_service.dart';
import 'attempt_record.dart';

/// Persists the full attempt history. Statistics are always *derived* from it,
/// so there is a single source of truth and no counters that can drift.
class HistoryRepository {
  HistoryRepository(this._storage);

  static const String storageKey = 'dartle.history.v1';

  final StorageService _storage;

  Future<List<AttemptRecord>> load() async {
    final raw = await _storage.read(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final item in list)
          AttemptRecord.fromJson((item as Map<Object?, Object?>).cast<String, Object?>())
      ];
    } on Object {
      // Corrupt data must never brick the app; start fresh.
      return [];
    }
  }

  Future<void> save(List<AttemptRecord> history) => _storage.write(
        storageKey,
        jsonEncode([for (final r in history) r.toJson()]),
      );

  Future<void> clear() => _storage.remove(storageKey);
}
