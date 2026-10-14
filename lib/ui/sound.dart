import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Plays the celebration for an optimal checkout, for [duration].
///
/// Looks for a user-supplied clip at `audio/optimal.mp3` (put your own,
/// properly licensed file at `web/audio/optimal.mp3`). If it is missing or
/// cannot play, falls back to a short original synthesized fanfare, so the
/// feature works out of the box without bundling any copyrighted music.
class SoundService {
  SoundService() {
    try {
      _muted = web.window.localStorage.getItem(_storageKey) == 'off';
    } on Object {
      _muted = false;
    }
    _unlockOnFirstTap();
  }

  /// iPhones and iPads only let a page make sound from an audio context that a
  /// tap has started. So the first tap anywhere creates and wakes one, and the
  /// fanfare later uses that same context.
  void _unlockOnFirstTap() {
    final unlock = ((web.Event event) {
      try {
        _shared ??= web.AudioContext();
        if (_shared!.state != 'running') _shared!.resume();
      } on Object {
        // No audio support: the game still works without sound.
      }
    }).toJS;
    for (final type in const ['touchend', 'pointerdown', 'click', 'keydown']) {
      web.document.addEventListener(type, unlock);
    }
  }

  static const String clipPath = 'audio/optimal.mp3';
  static const Duration duration = Duration(seconds: 4);
  static const String _storageKey = 'dartle.sound';
  static const Duration _fade = Duration(milliseconds: 500);

  bool _muted = false;
  DateTime? _busyUntil;

  /// The page's one audio context (see [_unlockOnFirstTap]), kept for good.
  web.AudioContext? _shared;

  /// The volume knob of the fanfare that is playing; disconnecting it silences
  /// the fanfare at once.
  web.GainNode? _master;
  web.HTMLAudioElement? _clip;
  Timer? _stopTimer;
  Timer? _fadeTimer;

  bool get isMuted => _muted;

  void toggleMuted() {
    _muted = !_muted;
    try {
      web.window.localStorage.setItem(_storageKey, _muted ? 'off' : 'on');
    } on Object {
      // Preference just won't persist.
    }
    if (_muted) stop();
  }

  Future<void> playOptimal() async {
    if (_muted) return;
    // Never start a second one while one is still playing.
    if (_busyUntil != null && DateTime.now().isBefore(_busyUntil!)) return;
    _busyUntil = DateTime.now().add(duration);
    stop();
    try {
      final clip = web.HTMLAudioElement()
        ..src = clipPath
        ..volume = 0.85;
      _clip = clip;
      await clip.play().toDart;
      _stopTimer = Timer(duration - _fade, () => _fadeOut(clip));
    } on Object {
      _clip = null;
      _fanfare();
    }
  }

  void stop() {
    _stopTimer?.cancel();
    _fadeTimer?.cancel();
    final clip = _clip;
    if (clip != null) {
      clip.pause();
      clip.currentTime = 0;
      _clip = null;
    }
    // Cut the synthesized fanfare short too (muting, or leaving the result).
    final master = _master;
    if (master != null) {
      _master = null;
      master.disconnect();
      _busyUntil = null;
    }
  }

  void _fadeOut(web.HTMLAudioElement clip) {
    const steps = 10;
    var step = 0;
    final start = clip.volume;
    _fadeTimer = Timer.periodic(_fade ~/ steps, (timer) {
      step++;
      clip.volume = (start * (1 - step / steps)).clamp(0.0, 1.0);
      if (step >= steps) {
        timer.cancel();
        clip.pause();
        clip.currentTime = 0;
        if (identical(_clip, clip)) _clip = null;
      }
    });
  }

  /// Original rising fanfare, played once: four quick notes up, then a held
  /// major chord that fades out at the 4 second mark.
  void _fanfare() {
    try {
      final ctx = _shared ??= web.AudioContext();
      if (ctx.state != 'running') ctx.resume();
      final master = ctx.createGain();
      master.connect(ctx.destination);
      _master = master;
      final now = ctx.currentTime;
      final total = duration.inMilliseconds / 1000;

      void note(double hz, double start, double length, {double volume = 0.16}) {
        final osc = ctx.createOscillator()
          ..type = 'triangle'
          ..frequency.value = hz;
        final gain = ctx.createGain();
        final t0 = now + start;
        gain.gain.setValueAtTime(0, t0);
        gain.gain.linearRampToValueAtTime(volume, t0 + 0.04);
        gain.gain.exponentialRampToValueAtTime(0.0001, t0 + length);
        osc.connect(gain);
        gain.connect(master);
        osc.start(t0);
        osc.stop(t0 + length + 0.05);
      }

      // C major arpeggio up, then triumphant chord.
      const arpeggio = [261.63, 329.63, 392.0, 523.25];
      for (var i = 0; i < arpeggio.length; i++) {
        note(arpeggio[i], i * 0.22, 0.5);
      }
      const chord = [261.63, 329.63, 392.0, 523.25, 659.25];
      for (final hz in chord) {
        note(hz, 1.0, total - 1.0, volume: 0.09);
      }
      // One phrase only: no repeated melody, so it is heard exactly once.
      Timer(duration + const Duration(milliseconds: 300), () {
        if (identical(_master, master)) {
          _master = null;
          master.disconnect();
        }
      });
    } on Object {
      // No audio support: silently skip, the game still works.
    }
  }
}
