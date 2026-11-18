import 'dart:async';
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
}) {
  double? startX;
  double startY = 0;
  var sideways = false;
  web.HTMLElement? beside;
  var besideStep = 0;

  void showBeside(int step) {
    if (besideStep == step) return;
    beside?.remove();
    beside = null;
    besideStep = step;
    if (peek == null || !canMove(step)) return;
    final next = peek(step);
    if (next == null) return;
    next.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '${step * 100}%'
      ..width = '100%';
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
      sideways = true;
      sliding.style.transition = 'none';
    }
    final step = across < 0 ? 1 : -1;
    final free = canMove(step);
    showBeside(step);
    sliding.style.transform = 'translateX(${free ? across : across * _resistance}px)';
  });

  void goBack() {
    sliding.style
      ..transition = _slide
      ..transform = '';
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
