/// A monotonic time source. Injected so tests can control time.
typedef MonotonicClock = Duration Function();

/// Default clock backed by a [Stopwatch] (monotonic, unaffected by system
/// clock changes and independent of UI frame rate).
MonotonicClock stopwatchClock() {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
}

/// Measures one checkout attempt.
///
/// Starting is idempotent: calling [start] on a running timer is a no-op, so a
/// UI re-render can never reset it. Use [restart] to deliberately begin anew.
class AttemptTimer {
  AttemptTimer([MonotonicClock? clock]) : _clock = clock ?? stopwatchClock();

  final MonotonicClock _clock;
  Duration? _startedAt;
  Duration? _stoppedAt;

  bool get isRunning => _startedAt != null && _stoppedAt == null;
  bool get isStopped => _stoppedAt != null;

  /// Elapsed time; frozen once stopped, zero before starting.
  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_stoppedAt ?? _clock()) - start;
  }

  void start() {
    if (_startedAt != null) return;
    _startedAt = _clock();
  }

  /// Freezes and returns the elapsed time. Safe to call repeatedly.
  Duration stop() {
    if (_startedAt != null) _stoppedAt ??= _clock();
    return elapsed;
  }

  void restart() {
    _startedAt = _clock();
    _stoppedAt = null;
  }

  void reset() {
    _startedAt = null;
    _stoppedAt = null;
  }
}
