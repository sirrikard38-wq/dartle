import 'checkout_route.dart';
import 'checkout_tables.dart';
import 'dart_throw.dart';

/// One row of the checkout tables (`data/checkout-tables`): what to aim at on
/// a number with some darts in hand. The text is kept as the tables write it;
/// [CheckoutTable] reads it.
final class CheckoutTableRow {
  const CheckoutTableRow(this.aim, this.route, this.rule, this.alternatives);

  /// The first target: `T20`, `BULL`, or two neighbours `S16/S8`.
  final String aim;

  /// The whole route if every dart hits: `T20 T17 D8`; `S16/S8 D16/D20` (two
  /// routes, one per neighbour); `25 D18 ili BULL S3 D4` (either); a setup only
  /// when no checkout is left, `T19 S10 (ostaje 32)`. Empty in the one-dart
  /// table, where the aim is the route when it finishes.
  final String route;

  /// The kind of choice, in the tables' words: `Double odmah`, `Priprema` ...
  final String rule;

  /// Up to two targets almost as good: `T14, T18`, `S3/S19`. Often empty.
  final String alternatives;
}

/// The tables: for every number from 2 to 170 and 1, 2 or 3 darts in hand,
/// the target to aim at, the route and the targets almost as good. They come
/// from a model of the board with the spread of a real throw, so they look at
/// what a miss into the next area leaves, not only at a hit.
abstract final class CheckoutTable {
  /// The row for [target] with [darts] darts in hand, or null.
  static CheckoutTableRow? row(int target, int darts) => checkoutTables[darts]?[target];

  /// The first target (two for a pair of neighbours: 48 is S16 and S8).
  static List<DartThrow> aims(CheckoutTableRow row) => _darts(row.aim);

  /// The targets almost as good as [aims].
  static List<DartThrow> alternatives(CheckoutTableRow row) => [
        for (final part in row.alternatives.split(','))
          if (part.trim().isNotEmpty) ..._darts(part.trim()),
      ];

  /// The routes of [row] that check [target] out (a setup that leaves a number
  /// for the next visit is not one).
  static List<CheckoutRoute> routes(CheckoutTableRow row, int target) {
    final text = row.route.isEmpty ? row.aim : row.route;
    final routes = <CheckoutRoute>[];
    for (final choice in text.replaceAll(RegExp(r'\(.*?\)'), '').split(' ili ')) {
      final tokens = choice.trim().split(RegExp(r'\s+'));
      final ways = tokens.map((t) => t.split('/').length).reduce((a, b) => a > b ? a : b);
      for (var i = 0; i < ways; i++) {
        final darts = [
          for (final token in tokens)
            _dart(token.contains('/') ? token.split('/')[i] : token),
        ];
        final route = CheckoutRoute(darts);
        if (route.isCheckoutFor(target)) routes.add(route);
      }
    }
    return routes;
  }

  static List<DartThrow> _darts(String text) => [for (final part in text.split('/')) _dart(part)];

  static DartThrow _dart(String text) =>
      text.toUpperCase() == 'BULL' ? DartThrow.bull : DartThrow.parse(text);
}
