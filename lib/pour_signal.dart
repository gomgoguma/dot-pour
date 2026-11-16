import 'dart:math' as math;

class PourSample {
  final Duration at;
  final double grams;
  const PourSample(this.at, this.grams);
}

/// Rejects handling transients without a multi-second smoothing buffer.
/// Normal readings wait for one following sample (100ms on DOT). Suspect
/// readings never change the accepted mass or silently establish a new zero.
class PourSignal {
  static const recoveryTime = Duration(milliseconds: 300);
  PourSample _accepted = const PourSample(Duration.zero, 0);
  PourSample? _pending, _previous;
  final List<PourSample> _recovery = [];
  bool holding = false;

  void reset(Duration at) {
    _accepted = PourSample(at, 0);
    _pending = null;
    _previous = null;
    _recovery.clear();
    holding = false;
  }

  void hold() {
    holding = true;
    _pending = null;
    _recovery.clear();
  }

  PourSample? add(
    double grams,
    Duration at, {
    bool overloaded = false,
    bool cumulative = true,
  }) {
    if (!grams.isFinite || overloaded) {
      hold();
      return null;
    }
    final sample = PourSample(at, grams);
    final previous = _previous ?? _accepted;
    final dt = math.max(0.0, (at - previous.at).inMicroseconds / 1000000);
    if (!holding &&
        (grams < _accepted.grams - 2 ||
            grams < previous.grams - 2 ||
            grams - previous.grams > math.max(8, 40 * dt))) {
      hold();
    }
    _previous = sample;
    if (holding) {
      // Recovery is conservative: a stable load near the last known water
      // mass, not a new zero or an arbitrary stable pressure/overload value.
      if (grams < _accepted.grams - 2 || grams > _accepted.grams + 8) {
        _recovery.clear();
        return null;
      }
      if (_recovery.isNotEmpty &&
          (_recovery.any((p) => (p.grams - grams).abs() > 0.8) ||
              at - _recovery.last.at > const Duration(milliseconds: 300))) {
        _recovery.clear();
      }
      _recovery.add(sample);
      if (at - _recovery.first.at < recoveryTime) return null;
      holding = false;
      _recovery.clear();
      _pending = sample;
      _accepted = PourSample(
        at,
        cumulative ? math.max(_accepted.grams, grams) : math.max(0, grams),
      );
      return _accepted;
    }
    final ready = _pending;
    _pending = sample;
    if (ready == null) return null;
    _accepted = PourSample(
      ready.at,
      cumulative
          ? math.max(_accepted.grams, ready.grams)
          : math.max(0, ready.grams),
    );
    return _accepted;
  }
}
