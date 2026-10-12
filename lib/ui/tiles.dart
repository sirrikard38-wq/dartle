import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';

const Map<TileState, String> _stateWords = {
  TileState.correct: 'correct',
  TileState.present: 'in the route but in a different position',
  TileState.absent: 'not in the route',
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
/// * [states] colours the tiles and plays the flip reveal.
/// * [activeIndex] outlines the box that will receive the next dart.
/// * [showDarts] puts small darts in each box: one in the first box, two in
///   the second, three in the third (the box's dart number).
/// * [blurred] blurs out that many boxes from the left: darts already thrown.
///   They cannot be used, so [darts] (and [states] and [activeIndex]) start at
///   the first box after them.
web.HTMLElement tileRow(
  List<DartThrow> darts, {
  required int slots,
  List<TileState>? states,
  int activeIndex = -1,
  bool small = false,
  String? label,
  bool live = false,
  bool showDarts = false,
  int blurred = 0,
}) {
  final free = slots - blurred;
  return el('div', cls: 'tile-row${small ? ' small' : ''}', attrs: {
    'role': 'group',
    'aria-label': label ??
        'Your checkout, $free ${free == 1 ? 'dart' : 'darts'} left',
  }, children: [
    for (var i = 0; i < slots; i++)
      if (i < blurred)
        _tile(null, index: i, active: false, live: live, showDarts: showDarts, blurred: true)
      else
        _tile(
          i - blurred < darts.length ? darts[i - blurred] : null,
          index: i,
          state: states != null && i - blurred < states.length ? states[i - blurred] : null,
          active: i - blurred == activeIndex,
          live: live,
          showDarts: showDarts,
        ),
  ]);
}

web.HTMLElement _tile(DartThrow? dart,
    {required int index,
    TileState? state,
    required bool active,
    required bool live,
    required bool showDarts,
    bool blurred = false}) {
  // `live` colours a dart the moment it is entered (no flip, no replay on each
  // re-render); `reveal` is the animated end-of-attempt flip.
  final classes = [
    'tile',
    if (dart != null) 'filled m-${dart.multiplier.name}',
    if (active) 'active',
    if (blurred) 'blurred',
    if (showDarts) 'has-darts',
    if (state != null) '${live ? 'live' : 'reveal'} ${state.name}',
  ].join(' ');

  final description = blurred
      ? 'already thrown'
      : dart == null
          ? 'empty'
          : state == null
              ? dart.spokenName
              : '${dart.spokenName}, ${_stateWords[state]}';

  return el('div', cls: classes, attrs: {
    'aria-label': 'Dart ${index + 1}: $description',
    'style': '--i:$index',
  }, children: [
    textNode(dart?.notation ?? ''),
    if (state != null) el('span', cls: 'mark', text: _stateMarks[state]!, attrs: {'aria-hidden': 'true'}),
    // Box 1 holds one dart, box 2 two, box 3 three - all the same size.
    if (showDarts)
      el('span', cls: 'tile-darts', attrs: {'aria-hidden': 'true'}, children: [
        for (var k = 0; k <= index; k++) dartGlyph() as web.Node,
      ]),
  ]);
}
