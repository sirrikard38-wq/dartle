import 'dart:async';
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
        label: tr('Route {route}', {'route': route.notation}),
      ),
      tileRow(route.darts,
          slots: route.length,
          small: true,
          states: List.filled(route.length, TileState.correct),
          label: route.notation),
      favoriteButton(ctx, target, route),
    ]);

/// Every route of [routes] as a board with its boxes, in the order given. A
/// number can have over a hundred (61 with three darts), and drawing them all
/// at once would freeze the popup, so the first boards are drawn straight away
/// and the rest follow in small batches while the popup is open. Nothing is
/// left out.
web.HTMLElement routeGrid(ViewContext ctx, int target, List<CheckoutRoute> routes) {
  const firstBatch = 12;
  const nextBatch = 8;
  final grid = el('div', cls: 'possibilities');
  void fill(int from) {
    // The popup was closed (or replaced): stop.
    if (from > 0 && !grid.isConnected) return;
    final to = math.min(from + (from == 0 ? firstBatch : nextBatch), routes.length);
    for (var i = from; i < to; i++) {
      grid.appendChild(routeFigure(ctx, target, routes[i]));
    }
    if (to < routes.length) {
      Timer(const Duration(milliseconds: 16), () => fill(to));
    }
  }

  fill(0);
  return grid;
}

/// The favorite mark: a small dart, an outline until it is pressed, then
/// filled white.
web.Element favoriteDartIcon() => svg('svg', cls: 'fav-icon', attrs: {
      'viewBox': '0 0 14 32',
      // Stretched a little sideways: a fatter dart, easier to see and press.
      'preserveAspectRatio': 'none',
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
  // The same route can have a button in more than one place (your darts on the
  // result screen and the popup); they all show the same state.
  final id = '$target|${Favorites.keyOf(route)}';
  void show(web.Element b, bool on) {
    b.classList.toggle('on', on);
    b.setAttribute('aria-pressed', '$on');
    b.setAttribute('aria-label',
        on
            ? tr('Favorite {route} - press to remove it', {'route': route.notation})
            : tr('Make {route} a favorite', {'route': route.notation}));
  }

  void showEverywhere(bool on) {
    final all = web.document.querySelectorAll('.fav-btn[data-fav="$id"]');
    for (var i = 0; i < all.length; i++) {
      show(all.item(i) as web.Element, on);
    }
  }

  late final web.HTMLButtonElement b;
  b = button('', cls: 'fav-btn', attrs: {'data-fav': id}, onPressed: (_) async {
    final on = !b.classList.contains('on');
    showEverywhere(on); // at once; the save follows
    ctx.toast(on ? tr('Added to favorites!') : tr('Removed from favorites!'));
    showEverywhere(await game.toggleFavorite(target, route));
  });
  b.appendChild(favoriteDartIcon());
  show(b, game.favorites.isFavorite(target, route));
  return b;
}

/// The player's own checkout can be a favorite too when it ends on a double and
/// adds up to the number - optimal or not. Null otherwise.
web.HTMLElement? favoriteForYourRoute(ViewContext ctx, int target, CheckoutRoute route) =>
    route.isCheckoutFor(target) ? favoriteButton(ctx, target, route) : null;

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
      el('h2', text: tr('Favorites')),
      el('p', cls: 'hint',
          text: tr('Mark a route with the dart in the "Also optimal" popup. '
              'Numbers with a favorite are white: press one to see them. '
              'Crossed out in red: no checkout.')),
      el('div', cls: 'fav-grid', children: [
        for (var n = CheckoutEngine.maxCheckout; n >= CheckoutEngine.minCheckout; n--)
          if (ctx.game.hasNoCheckout(n))
            // Crossed out in red, like a box that is already used.
            button('$n',
                cls: 'fav-number none',
                disabled: true,
                ariaLabel: tr('{n}: no checkout', {'n': n}),
                onPressed: (_) {})
          else if (favorites.hasAny(n))
            button('$n',
                cls: 'fav-number has',
                focusKey: 'fav-$n',
                ariaLabel: tr('{n}: show its favorites', {'n': n}),
                onPressed: (_) => showFavoritesPopup(ctx, n))
          else
            button('$n',
                cls: 'fav-number',
                disabled: true,
                ariaLabel: tr('{n}: no favorites', {'n': n}),
                onPressed: (_) {}),
      ]),
    ]),
  ]);
}

/// The favorites of [target], one page per number of darts ("2 Darts",
/// "3 Darts"). With more than one page, swipe left and right (or press the
/// names at the top) to go between them.
void showFavoritesPopup(ViewContext ctx, int target) {
  final counts = ctx.game.favorites.dartCountsFor(target);
  if (counts.isEmpty) return;
  final (tabs, pages) = favoritePages(ctx, target, counts);
  showModal(title: tr('Favorites for {n}', {'n': target}), showTitle: false, body: [
    tabs,
    el('p', cls: 'modal-number', text: '$target'),
    pages,
  ]);
}

/// The names of the pages ([counts]: the numbers of darts) and the pages of
/// [target]'s favorites, side by side: swipe left and right, or press a name.
/// A page with no favorites says so. With [swipe] false the pages do not
/// slide under the finger: only a press on a name turns them (the tutorial).
(web.HTMLElement, web.HTMLElement) favoritePages(ViewContext ctx, int target, List<int> counts,
    {bool swipe = true}) {
  final favorites = ctx.game.favorites;
  String name(int darts) => trn(darts, '{n} Dart', '{n} Darts');

  final tabs = <web.HTMLElement>[];
  final pages = el('div', cls: 'fav-pages${!swipe ? ' fixed' : counts.length > 1 ? ' swipe' : ''}');
  void select(int index) {
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', i == index);
      tabs[i].setAttribute('aria-selected', '${i == index}');
      // Pages that do not slide: only the chosen one is there.
      if (!swipe) pages.children.item(i)?.classList.toggle('off', i != index);
    }
  }

  for (var i = 0; i < counts.length; i++) {
    final darts = counts[i];
    final routes = favorites.routesFor(target, darts: darts);
    final page = el('section', cls: 'fav-page', attrs: {'aria-label': name(darts)}, children: [
      if (routes.isEmpty)
        el('p', cls: 'hint', text: trn(darts, 'No favorites with {n} dart yet.', 'No favorites with {n} darts yet.'))
      else
        el('div', cls: 'possibilities', children: [
          for (final route in routes) routeFigure(ctx, target, route),
        ]),
    ]);
    pages.appendChild(page);
    tabs.add(button(name(darts),
        cls: 'fav-tab',
        attrs: {'role': 'tab'},
        onPressed: (_) {
          if (swipe) pages.scrollTo(web.ScrollToOptions(left: page.offsetLeft.toDouble(), behavior: 'smooth'));
          select(i);
        }));
  }
  // Swiping: the page that is mostly in view is the one named at the top.
  pages.onScroll.listen((_) {
    final width = pages.clientWidth;
    if (width > 0) select((pages.scrollLeft / width).round().clamp(0, counts.length - 1));
  });
  select(0);
  return (el('div', cls: 'fav-tabs', attrs: {'role': 'tablist'}, children: tabs), pages);
}

/// The popup with every optimal way to check out [target] ([routes]), each on
/// its board with its boxes and the favorite dart: the favorites first, then
/// in order of the double they finish on. "Also optimal" opens it, on the
/// result screen and on the tutorial boards.
void showAllOptimal(ViewContext ctx, int target, List<CheckoutRoute> routes) {
  showModal(title: tr('Every optimal way to check out {n}', {'n': target}), showTitle: false, body: [
    el('p', cls: 'modal-line top', text: tr('Every optimal way to check out')),
    // The number under it, in the middle of the popup, above all the boards.
    el('p', cls: 'modal-number', text: '$target'),
    // The favorites first. Then in order of the dart they finish on: D1, D2 ...
    // D20, then the Bull - but a Bull finish sits right next to the route with
    // the treble of its single (T7 D18 and S7 Bull).
    routeGrid(ctx, target, favoritesFirst(ctx.game.favorites, target, routes, RouteOrder.forPopup(routes))),
  ]);
}
