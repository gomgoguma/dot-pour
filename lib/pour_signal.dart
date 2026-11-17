import 'dart:math' as math;

class PourSample {
  final Duration at;
  final double grams;
  const PourSample(this.at, this.grams);
}

/// Rejects handling transients without a multi-second smoothing buffer.
/// Normal readings wait for one following sample (100ms on DOT). Suspect
/// readings never change the accepted mass. After a lift, a coherent returning
/// load can be moving (pouring); recovery does not require a stationary plateau.
class PourSignal {
  static const recoveryTime = Duration(milliseconds: 200);
  PourSample _accepted = const PourSample(Duration.zero, 0);
  PourSample _rawAccepted = const PourSample(Duration.zero, 0);
  PourSample? _pending, _previous;
  final List<PourSample> _recovery = [];
  double _offset = 0;
  bool holding = false;

  void reset(Duration at) {
    _accepted = PourSample(at, 0);
    _rawAccepted = _accepted;
    _offset = 0;
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
    final previous = _previous ?? _rawAccepted;
    final dt = math.max(0.0, (at - previous.at).inMicroseconds / 1000000);
    if (!holding &&
        (grams < _rawAccepted.grams - 12 ||
            grams - previous.grams > math.max(12, 60 * dt))) {
      hold();
    }
    _previous = sample;
    if (holding) {
      // Allow plausible water added during handling and a small load shift on
      // return. Do not accept a removed vessel, a new zero or a large overload.
      final absentSeconds = math.max(
        0.0,
        (at - _rawAccepted.at).inMicroseconds / 1000000,
      );
      final lower =
          _rawAccepted.grams -
          math.max(12.0, _rawAccepted.grams.abs() * .05).clamp(12.0, 25.0);
      final upper = _rawAccepted.grams + 12 + 40 * math.min(2, absentSeconds);
      if (grams < lower ||
          grams > upper ||
          (_rawAccepted.grams > 5 && grams <= 2)) {
        _recovery.clear();
        return null;
      }
      if (_recovery.isNotEmpty) {
        final last = _recovery.last;
        final gap = (at - last.at).inMicroseconds / 1000000;
        final change = grams - last.grams;
        if (gap > 2 || change < -2 || change > math.max(6, 60 * gap)) {
          _recovery.clear();
        }
      }
      _recovery.add(sample);
      if (_recovery.length < 3 || at - _recovery.first.at < recoveryTime) {
        return null;
      }
      // Keep the known poured amount if the returned load settles slightly
      // lower. Subsequent additions use this load as their reference. A zero
      // reset or a large missing mass is deliberately not rebased.
      // Publish the last reading backed by a following sample, just as in a
      // normal pour. Keep the newest pending so it is published exactly once.
      final ready = _recovery[_recovery.length - 2];
      if (cumulative && ready.grams + _offset < _accepted.grams) {
        _offset = _accepted.grams - ready.grams;
      }
      holding = false;
      _recovery.clear();
      _pending = sample;
      _rawAccepted = ready;
      _accepted = PourSample(
        ready.at,
        cumulative
            ? math.max(_accepted.grams, ready.grams + _offset)
            : math.max(0, ready.grams),
      );
      return _accepted;
    }
    final ready = _pending;
    _pending = sample;
    if (ready == null) return null;
    // A one-sample pressure spike can be dropped without entering a hold.
    // Small reversals during a normal pour must not wait for pouring to stop.
    if (ready.grams - grams > 2) return null;
    _rawAccepted = ready;
    _accepted = PourSample(
      ready.at,
      cumulative
          ? math.max(_accepted.grams, ready.grams + _offset)
          : math.max(0, ready.grams),
    );
    return _accepted;
  }
}
