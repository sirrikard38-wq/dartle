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
  ///
  /// With three darts in hand, a number that two darts can check out keeps only
  /// its two-dart routes: 82 is Bull D16 (not 25 S17 D20), 61 is 25 D18. When
  /// the three-dart row has none, the two-dart row stands in: 110 is T20 Bull.
  static CheckoutTableRow? row(int target, int darts) {
    final row = checkoutTables[darts]?[target];
    if (darts != 3 || row == null) return row;
    return _twoDartRows.putIfAbsent(target, () => _twoDartsOnly(target, row));
  }

  static final Map<int, CheckoutTableRow> _twoDartRows = {};

  static CheckoutTableRow _twoDartsOnly(int target, CheckoutTableRow row) {
    final two = checkoutTables[2]?[target];
    if (two == null || routes(two, target).isEmpty) return row;
    bool short(String choice) => routes(CheckoutTableRow(row.aim, choice, row.rule, ''), target)
        .every((route) => route.length <= 2);
    final choices = row.route.split(' ili ').map((choice) => choice.trim()).toList();
    final kept = choices.where(short).toList();
    if (kept.length == choices.length) return row;
    if (kept.isEmpty) return two;
    // A target almost as good stays when its hit leaves a one-dart finish.
    bool finishes(DartThrow dart) {
      final left = target - dart.score;
      if (left == 0) return dart.isFinishingDart;
      final one = checkoutTables[1]?[left];
      return one != null && routes(one, left).isNotEmpty;
    }

    final alternatives = [
      for (final part in row.alternatives.split(','))
        if (part.trim().isNotEmpty && _darts(part.trim()).every(finishes)) part.trim(),
    ];
    return CheckoutTableRow(kept.first.split(RegExp(r'\s+')).first, kept.join(' ili '), row.rule, alternatives.join(', '));
  }

  /// The first target (two for a pair of neighbours: 48 is S16 and S8). The
  /// table's BULL is the bull area when a route starts on the outer bull: 65
  /// with three darts is 25 D20 or Bull S7 D4, so 25 and the Bull are both hits.
  static List<DartThrow> aims(CheckoutTableRow row) {
    final bullArea = row.aim.toUpperCase() == 'BULL' &&
        row.route.split(' ili ').any((choice) => choice.trim().startsWith('25'));
    return bullArea ? const [DartThrow.outerBull, DartThrow.bull] : _darts(row.aim);
  }

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
