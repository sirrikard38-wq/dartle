/// How the "All possibilities" popup pages a long list of optimal routes: the
/// first few are shown, the rest wait behind a little dart and "Shoot more".
abstract final class RoutePages {
  /// How many routes are shown before "Shoot more".
  static const int firstShown = 6;

  /// Splits [routes] into the ones shown at once and the rest. A number with
  /// [firstShown] routes or fewer has nothing behind "Shoot more".
  static ({List<T> first, List<T> rest}) split<T>(List<T> routes, {int firstCount = firstShown}) {
    if (routes.length <= firstCount) return (first: List.of(routes), rest: const []);
    return (first: routes.sublist(0, firstCount), rest: routes.sublist(firstCount));
  }
}
