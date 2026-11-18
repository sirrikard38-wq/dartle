import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

/// A swipe must be this long, in pixels, to change the page.
const double _swipeLength = 60;

/// After this many pixels it is clear whether the finger goes sideways or down.
const double _lockDistance = 10;

/// A swipe from this close to the left edge is the way back, not a page change.
const double backGestureEdge = 30;

/// How far the page follows the finger when there is no next page.
const double _resistance = 0.25;

const Duration _slideTime = Duration(milliseconds: 80);
const String _slide = 'transform 80ms ease-out';
const Duration _finishTime = Duration(milliseconds: 180);

bool get wantsLessMotion => web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/// When a swipe last ended on the next page: the page drawn then is already in
/// place, so it comes in with no slide of its own.
DateTime _landedAt = DateTime(2000);
bool get _justSwiped => DateTime.now().difference(_landedAt) < const Duration(milliseconds: 400);

/// Lets [sliding] follow the finger across [page], with the page one [step]
/// away ([peek]) coming along beside it as far as the finger has gone. Past the
/// swipe length the page glides the rest of the way and [move] is called with
/// +1 for the next page, -1 for the one before. Short of it, it slides back.
/// The same swipe as the food categories of Virulja.
void followSwipes(
  web.HTMLElement page,
  web.HTMLElement sliding,
  bool Function(int step) canMove,
  void Function(int step) move, {
  web.HTMLElement? Function(int step)? peek,
  void Function(int step, double fraction)? follow,
}) {
  double? startX;
  double startY = 0;
  var sideways = false;
  web.HTMLElement? beside;
  var besideStep = 0;
  // Pages of their own that scroll sideways (the 2 Darts and 3 Darts
  // favorites): a swipe on them turns their page while they have one to turn
  // to that way, and only past their last page does it move this page.
  web.Element? ownPages;
  // How far the chip fill has followed the finger (0 to 1), and which way.
  var followed = 0.0;
  var followedStep = 1;

  void showBeside(int step) {
    if (besideStep == step) return;
    beside?.remove();
    beside = null;
    besideStep = step;
    if (peek == null || !canMove(step)) return;
    final next = peek(step);
    if (next == null) return;
    // As tall as the page that is there, so what sits at its foot (a keypad)
    // is where it will be once the page is in place.
    next.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '${step * 100}%'
      ..width = '100%'
      ..height = '${sliding.offsetHeight}px';
    sliding.style.position = 'relative';
    sliding.append(next);
    beside = next;
  }

  void clearBeside() {
    beside?.remove();
    beside = null;
    besideStep = 0;
  }

  page.onTouchStart.listen((event) {
    final touch = event.changedTouches.item(0)!;
    startX = event.touches.length == 1 && touch.clientX >= backGestureEdge ? touch.clientX.toDouble() : null;
    startY = touch.clientY.toDouble();
    sideways = false;
    final target = event.target;
    ownPages = target != null && target.isA<web.Element>() ? (target as web.Element).closest('.fav-pages:not(.fixed)') : null;
  });
  page.onTouchMove.listen((event) {
    final from = startX;
    if (from == null) return;
    final touch = event.changedTouches.item(0)!;
    final across = touch.clientX - from;
    final down = touch.clientY - startY;
    if (!sideways) {
      if (max(across.abs(), down.abs()) < _lockDistance) return;
      if (across.abs() < down.abs() * 2) {
        startX = null;
        return;
      }
      if (ownPages case final pages?) {
        final more = across < 0
            ? pages.scrollLeft < pages.scrollWidth - pages.clientWidth - 1
            : pages.scrollLeft > 1;
        if (more) {
          startX = null;
          return;
        }
      }
      sideways = true;
      sliding.style.transition = 'none';
    }
    final step = across < 0 ? 1 : -1;
    final free = canMove(step);
    showBeside(step);
    sliding.style.transform = 'translateX(${free ? across : across * _resistance}px)';
    final width = max(sliding.offsetWidth, 1);
    followed = free ? min(1, across.abs() / width).toDouble() : 0;
    followedStep = step;
    follow?.call(step, followed);
  });

  // The fill goes on from where the finger left it - never back to the start
  // first - to the next chip ([to] 1) or back to its own ([to] 0).
  void finishFollow(double to, Duration length) {
    final from = followed;
    final step = followedStep;
    followed = 0;
    if (follow == null) return;
    animate(length, (progress) => follow(step, from + (to - from) * progress), () {});
  }

  void goBack() {
    sliding.style
      ..transition = _slide
      ..transform = '';
    finishFollow(0, _slideTime);
    Timer(_slideTime + const Duration(milliseconds: 40), clearBeside);
  }

  page.onTouchEnd.listen((event) {
    final from = startX;
    startX = null;
    if (from == null || !sideways) return;
    final across = event.changedTouches.item(0)!.clientX - from;
    final step = across < 0 ? 1 : -1;
    if (across.abs() < _swipeLength || !canMove(step)) {
      goBack();
      return;
    }
    if (beside == null || wantsLessMotion) {
      clearBeside();
      move(step);
      return;
    }
    // The rest of the way, then the next page is drawn where it already is.
    sliding.style
      ..transition = 'transform ${_finishTime.inMilliseconds}ms ease-out'
      ..transform = 'translateX(${-step * 100}%)';
    finishFollow(1, _finishTime);
    Timer(_finishTime, () {
      _landedAt = DateTime.now();
      move(step);
    });
  });
  page.onTouchCancel.listen((_) {
    startX = null;
    goBack();
  });
}

/// The fill behind the chosen chip of [row], going with a swipe to the next
/// chip as far as the swipe has gone, the words turning dark as it covers them
/// (the food categories of Virulja do the same).
class SwipeMark {
  SwipeMark(this.row);

  final web.HTMLElement row;
  web.HTMLElement? _mark;
  web.HTMLElement? _words;

  web.HTMLElement? get _chosen => row.querySelector('.chip.selected') as web.HTMLElement?;

  /// Moves the fill [fraction] of the way from the chosen chip to [to].
  void follow(web.HTMLElement? to, double fraction) {
    final from = _chosen;
    if (from == null || to == null || fraction <= 0) {
      clear();
      return;
    }
    var mark = _mark;
    if (mark == null) {
      // The same chips again inside the fill, in dark, laid exactly over the
      // row's own: only what the fill covers of them shows.
      final words = (row.cloneNode(true) as web.HTMLElement)
        ..className = 'chips marker-words'
        ..style.width = '${row.clientWidth}px';
      mark = (web.document.createElement('span') as web.HTMLElement)
        ..className = 'chip-marker'
        ..append(words);
      mark.style
        ..top = '${from.offsetTop}px'
        ..height = '${from.offsetHeight}px';
      row
        ..append(mark)
        ..classList.add('gliding');
      _mark = mark;
      _words = words;
    }
    final left = from.offsetLeft + (to.offsetLeft - from.offsetLeft) * fraction;
    mark.style
      ..left = '${left}px'
      ..width = '${from.offsetWidth + (to.offsetWidth - from.offsetWidth) * fraction}px';
    _words?.style
      ?..left = '${-left}px'
      ..top = '${-from.offsetTop}px';
  }

  /// Takes the fill away, the row as it was.
  void clear() {
    _mark?.remove();
    _mark = null;
    _words = null;
    row.classList.remove('gliding');
  }
}

/// Calls [frame] with the progress, from 0 to 1, on every frame for [length],
/// then [end].
void animate(Duration length, void Function(double progress) frame, void Function() end) {
  final started = web.window.performance.now();
  var finished = false;

  void finish() {
    if (finished) return;
    finished = true;
    frame(1);
    end();
  }

  void tick(double now) {
    if (finished) return;
    final time = (now - started) / length.inMilliseconds;
    if (time >= 1) {
      finish();
    } else {
      frame(1 - pow(1 - max(time, 0), 3).toDouble());
      web.window.requestAnimationFrame(tick.toJS);
    }
  }

  web.window.requestAnimationFrame(tick.toJS);
  Timer(length * 2, finish);
}

/// Brings the freshly drawn page in from the side it comes from (+1: from the
/// right), when it was chosen by a press rather than a swipe.
void slideIn(int step) {
  final fresh = web.document.querySelector('.slide-page') as web.HTMLElement?;
  if (fresh == null || wantsLessMotion || _justSwiped) return;
  fresh.style
    ..transition = 'none'
    ..transform = 'translateX(${step * 100}%)';
  fresh.getBoundingClientRect(); // so that the browser sees where it starts
  fresh.style
    ..transition = 'transform 160ms ease-out'
    ..transform = '';
  Timer(const Duration(milliseconds: 320), () => fresh.style.transition = 'none');
}
