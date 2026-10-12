import 'package:web/web.dart' as web;

import '../dartle.dart';

/// Browser localStorage behind [StorageService]. Falls back to memory when
/// storage is blocked (private mode, disabled cookies) so the app still runs.
class LocalStorageService implements StorageService {
  final InMemoryStorageService _fallback = InMemoryStorageService();

  @override
  Future<String?> read(String key) async {
    try {
      return web.window.localStorage.getItem(key);
    } on Object {
      return _fallback.read(key);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      web.window.localStorage.setItem(key, value);
    } on Object {
      await _fallback.write(key, value);
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      web.window.localStorage.removeItem(key);
    } on Object {
      await _fallback.remove(key);
    }
  }
}
