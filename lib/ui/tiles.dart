import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

/// What a coloured box means, in words (for screen readers).
String _stateWord(TileState state) => switch (state) {
      TileState.correct => tr('correct'),
      TileState.present => tr('in the route but in a different position'),
      TileState.absent => tr('not in the route'),
    };

/// Glyphs so state never depends on colour alone.
const Map<TileState, String> _stateMarks = {
  TileState.correct: '✓',
  TileState.present: '•',
  TileState.absent: '×',
};

/// One small stylised dart pointing up: tip, barrel, shaft and flight. Always
/// the same size; boxes just hold more or fewer of them. Drawn in the current
/// text colour so it suits white, pink and grey boxes alike.
web.Element dartGlyph() => svg('svg', cls: 'dart-glyph', attrs: {
      'viewBox': '0 0 12 28',
      'aria-hidden': 'true',
      'focusable': 'false',
    }, children: [
      svg('path', attrs: {'d': 'M6 0 L8.3 5 L3.7 5 Z', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '3.4', 'y': '5', 'width': '5.2', 'height': '9', 'rx': '1.4', 'fill': 'currentColor'}),
      svg('rect', attrs: {'x': '5.2', 'y': '14', 'width': '1.6', 'height': '5', 'fill': 'currentColor'}),
      svg('path', attrs: {'d': 'M6 18 L11 28 L8 28 L6 23.5 L4 28 L1 28 Z', 'fill': 'currentColor'}),
    ]);

/// A Wordle row of [slots] tiles. Missing entries render as empty boxes.
///
/// * [states] colours the tiles and plays the flip reveal (result screen only:
///   the boxes stay plain while you play).
/// * [activeIndex] outlines the free box that will receive the next dart.
/// * [showDarts] puts small darts in each box: one in each box.
/// * [used] are the boxes that are already used (crossed out in burgundy, with
///   their darts dotted). They cannot be filled: [darts], [states] and
///   [activeIndex] count only the free boxes, left to right.
web.HTMLElement tileRow(
  List<DartThrow> darts, {
  required int slots,
  List<TileState>? states,
  int activeIndex = -1,
  bool small = false,
  String? label,
  bool showDarts = false,
  Set<int> used = const {},
}) {
  final free = [for (var i = 0; i < slots; i++) if (!used.contains(i)) i];
  return el('div', cls: 'tile-row${small ? ' small' : ''}', attrs: {
    'role': 'group',
    'aria-label': label ??
        trn(free.length, 'Your checkout, {n} dart left', 'Your checkout, {n} darts left'),
  }, children: [
    for (var i = 0; i < slots; i++)
      if (used.contains(i))
        _tile(null, index: i, active: false, showDarts: showDarts, usedBox: true)
      else
        _tile(
          free.indexOf(i) < darts.length ? darts[free.indexOf(i)] : null,
          index: i,
          state: states != null && free.indexOf(i) < states.length
              ? states[free.indexOf(i)]
              : null,
          active: free.indexOf(i) == activeIndex,
          showDarts: showDarts,
        ),
  ]);
}

web.HTMLElement _tile(DartThrow? dart,
    {required int index,
    TileState? state,
    required bool active,
    required bool showDarts,
    bool usedBox = false}) {
  // A coloured tile plays the animated end-of-attempt flip (`reveal`).
  final classes = [
    'tile',
    if (dart != null) 'filled m-${dart.multiplier.name}',
    if (active) 'active',
    if (usedBox) 'used',
    if (showDarts || usedBox) 'has-darts',
    if (state != null) 'reveal ${state.name}',
  ].join(' ');

  final description = usedBox
      ? tr('already used')
      : dart == null
          ? tr('empty')
          : state == null
              ? dart.spokenName
              : '${dart.spokenName}, ${_stateWord(state)}';

  return el('div', cls: classes, attrs: {
    'aria-label': tr('Dart {n}: {state}', {'n': index + 1, 'state': description}),
    'style': '--i:$index',
  }, children: [
    textNode(dart?.notation ?? ''),
    if (state != null) el('span', cls: 'mark', text: _stateMarks[state]!, attrs: {'aria-hidden': 'true'}),
    // Every box holds one dart.
    if (showDarts || usedBox)
      el('span', cls: 'tile-darts', attrs: {'aria-hidden': 'true'}, children: [
        dartGlyph() as web.Node,
      ]),
  ]);
}
