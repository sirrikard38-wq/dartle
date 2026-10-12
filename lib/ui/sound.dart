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
  }

  static const String clipPath = 'audio/optimal.mp3';
  static const Duration duration = Duration(seconds: 4);
  static const String _storageKey = 'dartle.sound';
  static const Duration _fade = Duration(milliseconds: 500);

  bool _muted = false;
  DateTime? _busyUntil;
  web.AudioContext? _context;
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
    final context = _context;
    if (context != null) {
      _context = null;
      context.close();
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
      final ctx = web.AudioContext();
      _context = ctx;
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
        gain.connect(ctx.destination);
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
        if (identical(_context, ctx)) _context = null;
        ctx.close();
      });
    } on Object {
      // No audio support: silently skip, the game still works.
    }
  }
}
