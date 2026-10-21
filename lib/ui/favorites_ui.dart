import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dartboard.dart';
import 'dom.dart';
import 'modal.dart';
import 'tiles.dart';
import 'view_context.dart';

/// A stable number from a route's text, so "random" placement is the same on
/// every redraw of the same route.
int routeSeed(String text) =>
    text.codeUnits.fold<int>(17, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);

/// One route on its own small board with its boxes under it, as the popups show
/// it, with the favorite dart in its top corner.
web.HTMLElement routeFigure(ViewContext ctx, int target, CheckoutRoute route) =>
    el('figure', cls: 'board-figure', children: [
      buildDartboard(
        linesOnly: true,
        marks: spreadMarks(route.darts, const [], math.Random(routeSeed(route.notation))),
        label: 'Route ${route.notation}',
      ),
      tileRow(route.darts,
          slots: route.length,
          small: true,
          states: List.filled(route.length, TileState.correct),
          label: route.notation),
      favoriteButton(ctx, target, route),
    ]);

/// The favorite mark: a small dart, an outline until it is pressed, then
/// filled white.
web.Element favoriteDartIcon() => svg('svg', cls: 'fav-icon', attrs: {
      'viewBox': '0 0 14 32',
      'aria-hidden': 'true',
      'focusable': 'false',
    }, children: [
      svg('path', cls: 'fav-shape', attrs: {
        // Tip, barrel, shaft and flight in one outline.
        'd': 'M7 1 L9.4 6.5 L9.4 16 Q9.4 17 8.2 17 L7.9 17 L7.9 21 L12.5 30.5 L9.4 30.5 '
            'L7 26 L4.6 30.5 L1.5 30.5 L6.1 21 L6.1 17 L5.8 17 Q4.6 17 4.6 16 L4.6 6.5 Z',
      }),
    ]);

/// The button with [favoriteDartIcon] for [route] on [target]. Pressing it marks
/// the route as a favorite (or takes the mark away) and saves it; the dart
/// fills in white straight away.
web.HTMLButtonElement favoriteButton(ViewContext ctx, int target, CheckoutRoute route) {
  final game = ctx.game;
  late final web.HTMLButtonElement b;
  void show(bool on) {
    b.classList.toggle('on', on);
    b.setAttribute('aria-pressed', '$on');
    b.setAttribute('aria-label',
        on ? 'Favorite ${route.notation} - press to remove it' : 'Make ${route.notation} a favorite');
  }

  b = button('', cls: 'fav-btn', onPressed: (_) async {
    show(!b.classList.contains('on')); // at once; the save follows
    show(await game.toggleFavorite(target, route));
  });
  b.appendChild(favoriteDartIcon());
  show(game.favorites.isFavorite(target, route));
  return b;
}

/// The routes a popup lists for [target]: its favorites among [routes] first
/// (in the order they were marked), then the others in [rest] order.
List<CheckoutRoute> favoritesFirst(
  Favorites favorites,
  int target,
  List<CheckoutRoute> routes,
  List<CheckoutRoute> rest,
) {
  final marked = [
    for (final f in favorites.routesFor(target))
      if (routes.any(f.isEquivalentTo)) routes.firstWhere(f.isEquivalentTo),
  ];
  return [
    ...marked,
    for (final r in rest)
      if (!marked.any(r.isEquivalentTo)) r,
  ];
}

/// Favorites: every number from 170 down to 2. Numbers with a favorite are
/// white and open their favorites; the others are grey and do nothing.
web.HTMLElement buildFavoritesScreen(ViewContext ctx) {
  final favorites = ctx.game.favorites;
  return el('main', cls: 'screen favorites', children: [
    el('div', cls: 'play-area', children: [
      el('h2', text: 'Favorites'),
      el('p', cls: 'hint',
          text: 'Mark a route with the dart in the "Also optimal" popup. '
              'Numbers with a favorite are white: press one to see them.'),
      el('div', cls: 'fav-grid', children: [
        for (var n = CheckoutEngine.maxCheckout; n >= CheckoutEngine.minCheckout; n--)
          favorites.hasAny(n)
              ? button('$n',
                  cls: 'fav-number has',
                  focusKey: 'fav-$n',
                  ariaLabel: '$n: show its favorites',
                  onPressed: (_) => showFavoritesPopup(ctx, n))
              : button('$n',
                  cls: 'fav-number',
                  disabled: true,
                  ariaLabel: '$n: no favorites',
                  onPressed: (_) {}),
      ]),
    ]),
  ]);
}

/// The favorites of [target], one page per number of darts ("2 Darts",
/// "3 Darts"). With more than one page, swipe left and right (or press the
/// names at the top) to go between them.
void showFavoritesPopup(ViewContext ctx, int target) {
  final favorites = ctx.game.favorites;
  final counts = favorites.dartCountsFor(target);
  if (counts.isEmpty) return;
  String name(int darts) => '$darts ${darts == 1 ? 'Dart' : 'Darts'}';

  final tabs = <web.HTMLElement>[];
  final pages = el('div', cls: 'fav-pages${counts.length > 1 ? ' swipe' : ''}');
  void select(int index) {
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', i == index);
      tabs[i].setAttribute('aria-selected', '${i == index}');
    }
  }

  for (var i = 0; i < counts.length; i++) {
    final darts = counts[i];
    final page = el('section', cls: 'fav-page', attrs: {'aria-label': name(darts)}, children: [
      el('div', cls: 'possibilities', children: [
        for (final route in favorites.routesFor(target, darts: darts))
          routeFigure(ctx, target, route),
      ]),
    ]);
    pages.appendChild(page);
    tabs.add(button(name(darts),
        cls: 'fav-tab',
        attrs: {'role': 'tab'},
        onPressed: (_) {
          pages.scrollTo(web.ScrollToOptions(left: page.offsetLeft.toDouble(), behavior: 'smooth'));
          select(i);
        }));
  }
  // Swiping: the page that is mostly in view is the one named at the top.
  pages.onScroll.listen((_) {
    final width = pages.clientWidth;
    if (width > 0) select((pages.scrollLeft / width).round().clamp(0, counts.length - 1));
  });
  select(0);

  showModal(title: 'Favorites for $target', showTitle: false, body: [
    el('div', cls: 'fav-tabs', attrs: {'role': 'tablist'}, children: tabs),
    el('p', cls: 'modal-number', text: '$target'),
    pages,
  ]);
}
