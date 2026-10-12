/// Async key/value persistence. Async on purpose so a real backend can replace
/// the local implementation without touching callers.
abstract interface class StorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Volatile implementation for tests and as a fallback when browser storage
/// is unavailable (e.g. private mode).
class InMemoryStorageService implements StorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
