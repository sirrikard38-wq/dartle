import 'dart:convert';

import '../domain/checkout_route.dart';
import '../storage/storage_service.dart';

/// The checkout routes the player marked as a favorite (the dart icon in the
/// "Also optimal" popup), per number. A route counts for its own number of
/// darts: 64 can have favorites with two darts (T16 D8) and with three (S8 S16
/// D20). Saved on this device only.
///
/// A number with only one optimal route (for that number of darts) has it as
/// a favorite from the start - 170 is T20 T20 Bull, 40 is D20 - until the
/// player takes the mark away.
class Favorites {
  Favorites(this._storage, {Map<int, List<CheckoutRoute>> defaults = const {}})
      : _defaults = {
          for (final entry in defaults.entries)
            entry.key: [for (final route in entry.value) keyOf(route)],
        };

  static const String storageKey = 'dartle.favorites.v1';

  /// The routes that are favorites from the start but were unmarked.
  static const String removedKey = 'dartle.favorites.removed.v1';

  final StorageService _storage;

  /// Number -> the routes that are favorites from the start (its only optimal
  /// route, one per number of darts).
  final Map<int, List<String>> _defaults;

  /// Number -> the routes the player marked (normalized notation), oldest
  /// first.
  final Map<int, List<String>> _byNumber = {};

  /// Number -> the routes of [_defaults] the player unmarked.
  final Map<int, List<String>> _removed = {};

  /// Reads the saved favorites. Anything unreadable is ignored.
  Future<void> load() async {
    await _read(storageKey, _byNumber);
    await _read(removedKey, _removed);
  }

  Future<void> _read(String key, Map<int, List<String>> into) async {
    into.clear();
    final raw = await _storage.read(key);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((number, routes) {
        final target = int.tryParse(number);
        if (target == null || routes is! List) return;
        final valid = [
          for (final text in routes)
            if (text is String && _parse(text) != null) text,
        ];
        if (valid.isNotEmpty) into[target] = valid;
      });
    } on FormatException {
      // A broken save: start again without it.
    }
  }

  Future<void> _write(String key, Map<int, List<String>> from) =>
      _storage.write(key, jsonEncode({
        for (final entry in from.entries) '${entry.key}': entry.value,
      }));

  /// The same text for every order of the setup darts (S8 S16 D20 is S16 S8 D20).
  static String keyOf(CheckoutRoute route) => route.normalized.notation;

  bool _isDefault(int target, String key) => _defaults[target]?.contains(key) ?? false;
  bool _isRemoved(int target, String key) => _removed[target]?.contains(key) ?? false;

  bool isFavorite(int target, CheckoutRoute route) {
    final key = keyOf(route);
    if (_byNumber[target]?.contains(key) ?? false) return true;
    return _isDefault(target, key) && !_isRemoved(target, key);
  }

  /// Marks [route] as a favorite for [target], or takes the mark away, and
  /// saves. Returns whether it is a favorite now.
  Future<bool> toggle(int target, CheckoutRoute route) async {
    final key = keyOf(route);
    final now = !isFavorite(target, route);
    if (_isDefault(target, key)) {
      // A favorite from the start: unmarking it is remembered.
      _change(_removed, target, key, add: !now);
      _change(_byNumber, target, key, add: false);
      await _write(removedKey, _removed);
      await _write(storageKey, _byNumber);
    } else {
      _change(_byNumber, target, key, add: now);
      await _write(storageKey, _byNumber);
    }
    return now;
  }

  static void _change(Map<int, List<String>> map, int target, String key, {required bool add}) {
    final routes = map.putIfAbsent(target, () => []);
    routes.remove(key);
    if (add) routes.add(key);
    if (routes.isEmpty) map.remove(target);
  }

  /// The favorites of [target] - the one it has from the start first, then
  /// the marked ones, oldest first; only those with [darts] darts when it is
  /// given.
  List<CheckoutRoute> routesFor(int target, {int? darts}) => [
        for (final text in [
          for (final key in _defaults[target] ?? const <String>[])
            if (!_isRemoved(target, key)) key,
          for (final key in _byNumber[target] ?? const <String>[])
            if (!_isDefault(target, key)) key,
        ])
          if (_parse(text) case final route? when darts == null || route.length == darts) route,
      ];

  /// The numbers of darts [target] has favorites with, fewest first.
  List<int> dartCountsFor(int target) =>
      (routesFor(target).map((r) => r.length).toSet().toList()..sort());

  /// True when [target] has at least one favorite.
  bool hasAny(int target) => routesFor(target).isNotEmpty;

  static CheckoutRoute? _parse(String text) {
    try {
      final route = CheckoutRoute.parse(text);
      return route.isEmpty || !route.endsOnDouble ? null : route;
    } on FormatException {
      return null;
    }
  }
}
