/// A stopwatch independent of scale readings and the pour-over session.
class ManualTimer {
  final Duration Function() _now;
  Duration _elapsed = Duration.zero;
  Duration? _startedAt;

  ManualTimer({Duration Function()? now}) : _now = now ?? _clock();

  static Duration Function() _clock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  bool get running => _startedAt != null;
  Duration get elapsed =>
      _elapsed + (running ? _now() - _startedAt! : Duration.zero);

  void start() {
    _startedAt ??= _now();
  }

  void pause() {
    _elapsed = elapsed;
    _startedAt = null;
  }

  void reset() {
    _elapsed = Duration.zero;
    _startedAt = null;
  }
}
