import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart_icon.dart';
import 'dom.dart';
import 'to_top_math.dart';

/// The little dart at the end of a long page (the Leaderboard and Favorites).
///
/// It is the same dart as on the welcome screen, pointing up, in the left corner,
/// and only shows once the page is scrolled down to its end. Pressed, it is thrown
/// straight up from its corner while the page scrolls to the top. It rises only part
/// of the way up the screen ([dartRisePx]) and fades away smoothly as the top of the
/// page comes into view, so it never goes to the top of the screen. One button lives
/// on the page for good; [enabled] says whether the screen being shown is one that
/// has it.
class ToTopDart {
  ToTopDart() {
    element = button('',
        cls: 'to-top', ariaLabel: 'Back to the top', onPressed: (_) => _launch())
      ..appendChild(dartIcon() as web.Node);
    web.document.body!.appendChild(element);
    web.EventStreamProviders.scrollEvent.forTarget(web.window).listen((_) => refresh());
    web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) => refresh());
    // Taking the scroll over yourself ends the flight.
    web.EventStreamProviders.wheelEvent.forTarget(web.window).listen((_) => _interrupt());
    web.EventStreamProviders.touchStartEvent.forTarget(web.window).listen((_) => _interrupt());
    web.EventStreamProviders.keyDownEvent.forTarget(web.window).listen((_) => _interrupt());
  }

  late final web.HTMLButtonElement element;
  bool _enabled = false;
  bool _flying = false;
  DateTime _launchedAt = DateTime.now();
  Timer? _safety;

  /// Wheel movement right after the press is a trackpad still coasting from the
  /// scroll that brought you here, not you stopping the dart.
  static const Duration _graceBeforeInterrupt = Duration(milliseconds: 250);

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
    _flying = true;
    _launchedAt = DateTime.now();
    element.classList.add('flying');
    final travel = dartRisePx(web.document.documentElement!.clientHeight.toDouble());
    final duration = flightMs(startY);
    // A hidden tab pauses animation frames; this makes sure the page still lands.
    _safety = Timer(Duration(milliseconds: duration + 600), () {
      if (!_flying) return;
      web.window.scrollTo(0.toJS, 0);
      _end();
    });

    var firstFrame = -1.0;
    void frame(double now) {
      if (!_flying) return; // ended meanwhile (interrupted, or the safety net)
      if (firstFrame < 0) firstFrame = now;
      final progress = progressAt(now - firstFrame, duration);
      web.window.scrollTo(0.toJS, pageY(startY, progress));
      element.style
        ..setProperty('transform', 'translateY(${(-dartLift(travel, progress)).toStringAsFixed(1)}px)')
        ..setProperty('opacity', dartOpacity(progress).toStringAsFixed(3));
      if (progress < 1) {
        web.window.requestAnimationFrame(frame.toJS);
      } else {
        _end();
      }
    }

    web.window.requestAnimationFrame(frame.toJS);
  }

  void _interrupt() {
    if (!_flying) return;
    if (DateTime.now().difference(_launchedAt) < _graceBeforeInterrupt) return;
    _end();
  }

  /// The flight is over (landed or interrupted): the dart is out of sight, or
  /// finishes fading, and goes back to where it rests.
  void _end() {
    _safety?.cancel();
    _flying = false;
    element.classList.remove('flying');
    element.classList.remove('show');
    element.style.setProperty('opacity', '0');
    Timer(const Duration(milliseconds: 300), () {
      if (_flying) return; // thrown again already
      element.style.removeProperty('transform');
      element.style.removeProperty('opacity');
      refresh();
    });
  }
}
