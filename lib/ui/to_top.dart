import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart_icon.dart';
import 'dart_shot_timing.dart';
import 'dom.dart';
import 'to_top_math.dart';

/// The little dart at the end of a long page (the Leaderboard and Statistics).
///
/// It is the same dart as on the welcome screen, pointing up, in the left corner,
/// and only shows once the page is scrolled down to its end. Pressed, it is thrown
/// up the screen while the page scrolls to the top: it slides across to the middle
/// of the page and goes up through the middle of the numbers. At the top it does
/// what the welcome dart does: a small circle appears in front of its tip, the
/// dart flies half a centimetre into it, sticks and wiggles - and then fades away.
/// One button lives on the page for good; [enabled] says whether the screen being
/// shown is one that has it.
class ToTopDart {
  ToTopDart() {
    // The dart is turned to point up by a wrapper, so that its wiggle (the welcome
    // dart's own keyframes) runs inside the turned frame about the tip.
    final turned = el('span', cls: 'to-top-turn')..appendChild(dartIcon() as web.Node);
    element = button('', cls: 'to-top', ariaLabel: 'Back to the top', onPressed: (_) => _launch())
      ..appendChild(turned);
    // The circle the dart sticks in at the top; it is not part of the button, which
    // moves.
    spot = el('span', cls: 'to-top-spot', attrs: {'aria-hidden': 'true'}, children: [
      el('span', cls: 'target-dot'),
    ]);
    web.document.body!.appendChild(spot);
    web.document.body!.appendChild(element);
    web.EventStreamProviders.scrollEvent.forTarget(web.window).listen((_) => refresh());
    web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) => refresh());
    // Taking the scroll over yourself ends the flight.
    web.EventStreamProviders.wheelEvent.forTarget(web.window).listen((_) => _interrupt());
    web.EventStreamProviders.touchStartEvent.forTarget(web.window).listen((_) => _interrupt());
    web.EventStreamProviders.keyDownEvent.forTarget(web.window).listen((_) => _interrupt());
  }

  late final web.HTMLButtonElement element;
  late final web.HTMLElement spot;
  bool _enabled = false;
  bool _flying = false;
  int _flightId = 0; // each flight has its own, so that an old one can tell it is over
  DateTime _launchedAt = DateTime.now();
  Timer? _safety;

  /// Wheel movement right after the press is a trackpad still coasting from the
  /// scroll that brought you here, not you stopping the dart.
  static const Duration _graceBeforeInterrupt = Duration(milliseconds: 250);

  /// What comes after the flight: the shot into the circle, the wiggle, the fade.
  static const int _afterFlightMs = dartFlightMs + dartWiggleMs + dartLeaveMs;

  /// Switches the dart on for the screens that have it (and off for the others).
  set enabled(bool value) {
    _enabled = value;
    refresh();
  }

  /// Shows the dart when the page is scrolled to its end, hides it otherwise.
  void refresh() {
    if (_flying) return;
    final page = web.document.documentElement!;
    final atEnd = _enabled &&
        isAtEnd(
          scrollY: web.window.scrollY,
          viewportHeight: page.clientHeight.toDouble(),
          pageHeight: page.scrollHeight.toDouble(),
        );
    element.classList.toggle('show', atEnd);
  }

  /// The room the status bar takes at the top of the screen (the header pads for it).
  double _statusBarPx() {
    final header = web.document.querySelector('.app-header');
    if (header == null) return 0;
    final padding = web.window.getComputedStyle(header).paddingTop;
    return double.tryParse(padding.replaceAll('px', '')) ?? 0;
  }

  void _place(double dx, double dy) => element.style
      .setProperty('transform', 'translate(${dx.toStringAsFixed(1)}px, ${dy.toStringAsFixed(1)}px)');

  void _launch() {
    if (_flying) return;
    final startY = web.window.scrollY;
    if (startY <= 0) {
      refresh();
      return;
    }
    if (web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      web.window.scrollTo(0.toJS, 0);
      _end();
      return;
    }

    // Measured once: the dart rests in its corner; it goes up through the middle of
    // the page to the top, where the circle is.
    final page = web.document.documentElement!;
    final rest = element.getBoundingClientRect();
    final restX = rest.left + rest.width / 2;
    final restY = rest.top + rest.height / 2;
    final middleX = page.clientWidth / 2;
    final circleY = _statusBarPx() + stickBelowTopPx;
    final stopY = dartStopY(circleY);
    spot.style
      ..setProperty('left', '${middleX.toStringAsFixed(1)}px')
      ..setProperty('top', '${circleY.toStringAsFixed(1)}px');

    final id = ++_flightId;
    _flying = true;
    _launchedAt = DateTime.now();
    element.classList.add('flying');
    final duration = flightMs(startY);
    // A hidden tab pauses animation frames; this makes sure the page still lands.
    _safety = Timer(Duration(milliseconds: duration + _afterFlightMs + 800), () {
      if (id != _flightId) return;
      web.window.scrollTo(0.toJS, 0);
      _end();
    });

    var firstFrame = -1.0;
    void frame(double now) {
      if (id != _flightId) return; // ended meanwhile (interrupted, or the safety net)
      if (firstFrame < 0) firstFrame = now;
      final progress = progressAt(now - firstFrame, duration);
      web.window.scrollTo(0.toJS, pageY(startY, progress));
      _place(dartX(restX, middleX, progress) - restX, dartY(restY, stopY, progress) - restY);
      if (progress < 1) {
        web.window.requestAnimationFrame(frame.toJS);
      } else {
        unawaited(_stickAndLeave(id, middleX - restX, dartStuckY(circleY) - restY));
      }
    }

    web.window.requestAnimationFrame(frame.toJS);
  }

  /// The page is at the top and the dart is half a centimetre short of the circle:
  /// the circle appears and the dart flies into it (the welcome dart's shot), then
  /// it wiggles, stuck, and then it fades away.
  Future<void> _stickAndLeave(int id, double dx, double dy) async {
    spot.classList.add('on');
    element.classList.add('shooting');
    _place(dx, dy);
    await Future<void>.delayed(const Duration(milliseconds: dartFlightMs));
    if (id != _flightId) return;
    element.classList.add('stuck');
    await Future<void>.delayed(const Duration(milliseconds: dartWiggleMs));
    if (id != _flightId) return;
    element.classList.add('leaving');
    spot.classList.add('leaving');
    await Future<void>.delayed(const Duration(milliseconds: dartLeaveMs));
    if (id != _flightId) return;
    _end();
  }

  void _interrupt() {
    if (!_flying) return;
    if (DateTime.now().difference(_launchedAt) < _graceBeforeInterrupt) return;
    _end();
  }

  /// The flight is over (finished or interrupted): the dart and its circle are out
  /// of sight, or finish fading, and the dart goes back to where it rests.
  void _end() {
    _safety?.cancel();
    _flightId++;
    _flying = false;
    for (final name in ['flying', 'shooting', 'stuck', 'leaving', 'show']) {
      element.classList.remove(name);
    }
    for (final name in ['on', 'leaving']) {
      spot.classList.remove(name);
    }
    element.style.setProperty('opacity', '0');
    Timer(const Duration(milliseconds: 300), () {
      if (_flying) return; // thrown again already
      element.style.removeProperty('transform');
      element.style.removeProperty('opacity');
      refresh();
    });
  }
}
