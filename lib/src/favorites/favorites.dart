import 'dart:convert';

import '../domain/checkout_route.dart';
import '../storage/storage_service.dart';

/// The checkout routes the player marked as a favorite (the dart icon in the
/// "Also optimal" popup), per number. A route counts for its own number of
/// darts: 64 can have favorites with two darts (T16 D8) and with three (S8 S16
/// D20). Saved on this device only.
class Favorites {
  Favorites(this._storage);

  static const String storageKey = 'dartle.favorites.v1';

  final StorageService _storage;

  /// Number -> its favorite routes (normalized notation), oldest first.
  final Map<int, List<String>> _byNumber = {};

  /// Reads the saved favorites. Anything unreadable is ignored.
  Future<void> load() async {
    _byNumber.clear();
    final raw = await _storage.read(storageKey);
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
        if (valid.isNotEmpty) _byNumber[target] = valid;
      });
    } on FormatException {
      // A broken save: start again with no favorites.
    }
  }

  /// The same text for every order of the setup darts (S8 S16 D20 is S16 S8 D20).
  static String keyOf(CheckoutRoute route) => route.normalized.notation;

  bool isFavorite(int target, CheckoutRoute route) =>
      _byNumber[target]?.contains(keyOf(route)) ?? false;

  /// Marks [route] as a favorite for [target], or takes the mark away, and
  /// saves. Returns whether it is a favorite now.
  Future<bool> toggle(int target, CheckoutRoute route) async {
    final key = keyOf(route);
    final routes = _byNumber.putIfAbsent(target, () => []);
    final now = !routes.contains(key);
    if (now) {
      routes.add(key);
    } else {
      routes.remove(key);
      if (routes.isEmpty) _byNumber.remove(target);
    }
    await _storage.write(storageKey, jsonEncode({
      for (final entry in _byNumber.entries) '${entry.key}': entry.value,
    }));
    return now;
  }

  /// The favorites of [target], oldest first; only those with [darts] darts
  /// when it is given.
  List<CheckoutRoute> routesFor(int target, {int? darts}) => [
        for (final text in _byNumber[target] ?? const <String>[])
          if (_parse(text) case final route? when darts == null || route.length == darts) route,
      ];

  /// The numbers of darts [target] has favorites with, fewest first.
  List<int> dartCountsFor(int target) =>
      (routesFor(target).map((r) => r.length).toSet().toList()..sort());

  /// True when [target] has at least one favorite.
  bool hasAny(int target) => _byNumber[target]?.isNotEmpty ?? false;

  static CheckoutRoute? _parse(String text) {
    try {
      final route = CheckoutRoute.parse(text);
      return route.isEmpty || !route.endsOnDouble ? null : route;
    } on FormatException {
      return null;
    }
  }
}
