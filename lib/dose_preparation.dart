/// Observes stable setups throughout preparation. A steady increase is a suggestion
/// because the scale cannot identify what was added.
class DosePreparation {
  static const minimumSetupWeight = 60.0;
  static const zeroTolerance = 0.5;
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
  bool _stablePositiveWeight = false;

  bool get hasSetupWeight => _setupWeight != null;
  bool get tared => _tared;
  bool get hasStablePositiveWeight => _stablePositiveWeight;
  double? get suggestedDose => _suggestedDose;

  void reset() {
    _tared = false;
    _resetDetection();
  }

  void _resetDetection() {
    _lastAt = null;
    _setupWeight = null;
    _clearStability();
  }

  void markTared() {
    reset();
    _tared = true;
  }

  void observe(double grams, DateTime at, {required Duration maxGap}) {
    if (!grams.isFinite) {
      _resetDetection();
      return;
    }

    final previousAt = _lastAt;
    if (previousAt != null &&
        (at.isBefore(previousAt) || at.difference(previousAt) >= maxGap)) {
      _resetDetection();
    }
    _lastAt = at;

    final setupWeight = _setupWeight;
    if (setupWeight != null &&
        (grams < minimumSetupWeight ||
            grams < setupWeight - _stabilityTolerance ||
            grams > setupWeight + _maximumDose + _stabilityTolerance)) {
      _setupWeight = null;
      _clearStability();
    }

    final anchor = _anchor;
    if (anchor == null || (grams - anchor).abs() > _stabilityTolerance) {
      _anchor = grams;
      _stableFrom = at;
      _suggestedDose = null;
      _stablePositiveWeight = false;
      return;
    }

    final steadyFor = at.difference(_stableFrom!);
    _stablePositiveWeight = grams > zeroTolerance && steadyFor >= _setupTime;
    if (grams < minimumSetupWeight) {
      _suggestedDose = null;
      return;
    }
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
    _stablePositiveWeight = false;
  }
}
