import 'dart:math' as math;

/// Short-window flow and a one-shot first-pour detector for basic scale mode.
/// A fresh, stable zero is required before two rising water measurements.
class ScaleFlow {
  final _samples = <({double grams, DateTime at})>[];
  DateTime? _zeroSince;
  bool _armed = false;
  int _rises = 0;
  double _flow = 0;

  double flowAt(DateTime now) =>
      _samples.isEmpty || now.difference(_samples.last.at).inMilliseconds > 600
          ? 0
          : _flow;

  void reset() {
    _samples.clear();
    _zeroSince = null;
    _armed = false;
    _rises = 0;
    _flow = 0;
  }

  bool observe(double grams, DateTime at) {
    if (!grams.isFinite) {
      reset();
      return false;
    }
    if (_samples.isNotEmpty) {
      final previous = _samples.last;
      final dt = at.difference(previous.at).inMicroseconds / 1e6;
      if (dt <= 0) return false;
      if (dt > 1 || (grams - previous.grams).abs() > math.max(2, 40 * dt)) {
        reset();
      }
    }
    final previousGrams = _samples.isEmpty ? grams : _samples.last.grams;
    _samples.add((grams: grams, at: at));
    while (_samples.length > 2 &&
        at.difference(_samples[1].at).inMilliseconds >= 400) {
      _samples.removeAt(0);
    }
    final dt = at.difference(_samples.first.at).inMicroseconds / 1e6;
    _flow = dt >= .15 ? ((grams - _samples.first.grams) / dt).clamp(0, 40) : 0;
    if (grams.abs() <= .3) {
      _zeroSince ??= at;
      if (at.difference(_zeroSince!).inMilliseconds >= 300) _armed = true;
      _rises = 0;
      return false;
    }
    _zeroSince = null;
    if (grams < -.3 || grams < previousGrams - .3) {
      _armed = false;
      _rises = 0;
    }
    if (!_armed) return false;
    if (grams >= .5 && grams - previousGrams >= .1 - 1e-9) {
      _rises++;
    } else {
      _rises = 0;
    }
    if (_rises < 2) return false;
    _armed = false;
    _rises = 0;
    return true;
  }
}
