/// Observes a single setup before tare. A steady increase is only a suggestion
/// because the scale cannot identify what was added.
class DosePreparation {
  static const minimumSetupWeight = 60.0;
  static const _minimumDose = 10.0;
  static const _maximumDose = 40.0;
  static const _stabilityTolerance = 0.5;
  static const _setupTime = Duration(milliseconds: 1500);
  static const _doseTime = Duration(milliseconds: 800);

  DateTime? _lastAt;
  double? _anchor;
  DateTime? _stableFrom;
  double? _setupWeight;
  double? _suggestedDose;
  bool _tared = false;

  bool get hasSetupWeight => _setupWeight != null;
  bool get tared => _tared;
  double? get suggestedDose => _suggestedDose;

  void reset() {
    _lastAt = null;
    _setupWeight = null;
    _tared = false;
    _clearStability();
  }

  void markTared() {
    reset();
    _tared = true;
  }

  void observe(double grams, DateTime at, {required Duration maxGap}) {
    if (_tared) return;
    if (!grams.isFinite || grams < minimumSetupWeight) {
      reset();
      return;
    }

    final previousAt = _lastAt;
    if (previousAt != null &&
        (at.isBefore(previousAt) || at.difference(previousAt) >= maxGap)) {
      reset();
    }
    _lastAt = at;

    final setupWeight = _setupWeight;
    if (setupWeight != null &&
        (grams < setupWeight - _stabilityTolerance ||
            grams > setupWeight + _maximumDose + _stabilityTolerance)) {
      _setupWeight = null;
      _clearStability();
    }

    final anchor = _anchor;
    if (anchor == null || (grams - anchor).abs() > _stabilityTolerance) {
      _anchor = grams;
      _stableFrom = at;
      _suggestedDose = null;
      return;
    }

    final steadyFor = at.difference(_stableFrom!);
    final baseline = _setupWeight;
    if (baseline == null) {
      if (steadyFor >= _setupTime) _setupWeight = grams;
      return;
    }

    final delta = ((grams - baseline) * 10).round() / 10;
    _suggestedDose =
        steadyFor >= _doseTime && delta >= _minimumDose && delta <= _maximumDose
            ? delta
            : null;
  }

  void _clearStability() {
    _anchor = null;
    _stableFrom = null;
    _suggestedDose = null;
  }
}
