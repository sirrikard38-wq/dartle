import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'swipes.dart';

/// A coordinate of the finger: a fraction of a pixel on many phones (the
/// typed getter takes it for a whole number and fails).
double _coord(web.PointerEvent event, String name) =>
    ((event as JSObject).getProperty<JSNumber?>(name.toJS))?.toDartDouble ?? 0;

const _pointerDown = web.EventStreamProvider<web.PointerEvent>('pointerdown');
const _pointerMove = web.EventStreamProvider<web.PointerEvent>('pointermove');
const _pointerUp = web.EventStreamProvider<web.PointerEvent>('pointerup');
const _pointerCancel = web.EventStreamProvider<web.PointerEvent>('pointercancel');

/// A long press on a chip of [row]: every chip jiggles, as a phone's home
/// screen icons do while they are moved, and any of them can be dragged left
/// or right to a new place (the others make room as it passes them). A press
/// anywhere outside the row ends it; [onDone] then gets the new order - the
/// chips' first places (their `data-i`), left to right - if it changed.
class TabReorder {
  TabReorder(this.row, {required this.onDone}) {
    _pointerDown.forElement(row).listen(_down);
    _pointerMove.forElement(row).listen(_move);
    _pointerUp.forElement(row).listen(_up);
    _pointerCancel.forElement(row).listen(_up);
    // No menu or text selection from the long press.
    web.EventStreamProviders.contextMenuEvent.forElement(row).listen((event) => event.preventDefault());
  }

  final web.HTMLElement row;
  final void Function(List<int> order) onDone;

  /// How long a press must be to start.
  static const Duration longPress = Duration(milliseconds: 450);

  bool _editing = false;
  bool _swallowClick = false;
  Timer? _press;
  web.HTMLElement? _drag;
  int _pointer = 0;
  double _downX = 0, _downY = 0, _startX = 0;
  StreamSubscription<web.PointerEvent>? _outside;

  /// True when a press on a chip must not open its page: while the chips are
  /// being moved, and for the click that ends the long press.
  bool takeClick() {
    if (_editing || _swallowClick) {
      _swallowClick = false;
      return true;
    }
    return false;
  }

  web.HTMLElement? _chipOf(web.EventTarget? target) {
    if (target == null || !target.isA<web.Element>()) return null;
    final chip = (target as web.Element).closest('.chip');
    return chip != null && chip.parentElement == row ? chip as web.HTMLElement : null;
  }

  void _down(web.PointerEvent event) {
    final chip = _chipOf(event.target);
    if (chip == null) return;
    _downX = _coord(event, 'clientX');
    _downY = _coord(event, 'clientY');
    _pointer = event.pointerId;
    if (_editing) {
      _begin(chip);
      return;
    }
    _press?.cancel();
    _press = Timer(longPress, () {
      _press = null;
      _swallowClick = true;
      _start();
      _begin(chip);
    });
  }

  void _start() {
    _editing = true;
    swipesPaused = true;
    row.classList.add('jiggle');
    // A press outside the row ends the moving.
    _outside = _pointerDown.forTarget(web.document).listen((event) {
      final target = event.target;
      if (target != null && target.isA<web.Node>() && row.contains(target as web.Node?)) return;
      _finish();
    });
  }

  void _begin(web.HTMLElement chip) {
    _drag = chip;
    _startX = _downX;
    chip.classList.add('dragging');
    try {
      chip.setPointerCapture(_pointer);
    } on Object {
      // The moves still reach the row while the finger stays over it.
    }
  }

  double get _gap => double.tryParse(web.window.getComputedStyle(row).columnGap.replaceAll('px', '')) ?? 0;

  void _move(web.PointerEvent event) {
    final x = _coord(event, 'clientX');
    if (_press != null) {
      // Moving before the press is long enough: a swipe or a scroll, not this.
      if ((x - _downX).abs() > 10 || (_coord(event, 'clientY') - _downY).abs() > 10) {
        _press!.cancel();
        _press = null;
      }
      return;
    }
    final chip = _drag;
    if (chip == null) return;
    event.preventDefault();
    var dx = x - _startX;
    // Past half of a neighbour the two change places, like magnets: the
    // neighbour glides over to the place that was the chip's, and the chip
    // stays under the finger. (`translate`, not `transform`: the jiggle has
    // the transform.)
    final next = chip.nextElementSibling;
    if (dx > 0 && next != null && next.classList.contains('chip') && dx > (next as web.HTMLElement).offsetWidth / 2) {
      final was = next.getBoundingClientRect().left;
      row.insertBefore(next, chip);
      _startX += next.offsetWidth + _gap;
      dx = x - _startX;
      _glide(next, was - next.getBoundingClientRect().left);
    }
    final prev = chip.previousElementSibling;
    if (dx < 0 && prev != null && prev.classList.contains('chip') && -dx > (prev as web.HTMLElement).offsetWidth / 2) {
      final was = prev.getBoundingClientRect().left;
      row.insertBefore(chip, prev);
      _startX -= prev.offsetWidth + _gap;
      dx = x - _startX;
      _glide(prev, was - prev.getBoundingClientRect().left);
    }
    chip.style
      ..transition = 'none'
      ..setProperty('translate', '${dx}px 0');
  }

  /// [chip] just moved in the row by [from] pixels: it glides there instead
  /// of jumping.
  void _glide(web.HTMLElement chip, double from) {
    chip.style
      ..transition = 'none'
      ..setProperty('translate', '${from}px 0');
    chip.getBoundingClientRect(); // so that the start is drawn
    chip.style
      ..transition = 'translate 200ms ease-out'
      ..setProperty('translate', '0px 0');
  }

  void _up(web.PointerEvent event) {
    _press?.cancel();
    _press = null;
    final chip = _drag;
    if (chip == null) return;
    _drag = null;
    chip.classList.remove('dragging');
    // Let go: it settles into its place, never over another.
    chip.style
      ..transition = 'translate 200ms ease-out'
      ..setProperty('translate', '0px 0');
  }

  void _finish() {
    if (!_editing) return;
    _editing = false;
    swipesPaused = false;
    _outside?.cancel();
    _outside = null;
    row.classList.remove('jiggle');
    final chips = row.querySelectorAll(':scope > .chip');
    final order = [
      for (var i = 0; i < chips.length; i++) int.parse((chips.item(i) as web.Element).getAttribute('data-i') ?? '$i'),
    ];
    final moved = [for (var i = 0; i < order.length; i++) order[i] != i].contains(true);
    if (moved) onDone(order);
  }
}
