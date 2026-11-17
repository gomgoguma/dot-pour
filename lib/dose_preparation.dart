/// Observes stable setups throughout preparation. A steady increase is a suggestion
/// because the scale cannot identify what was added.
class DosePreparation {
  static const maximumBeanAddition = 40.0;
  static const _stabilityTolerance = 0.5;
  static const _setupTime = Duration(milliseconds: 1500);
  static const _doseTime = Duration(milliseconds: 800);

  DateTime? _lastAt;
  double? _anchor;
  DateTime? _stableFrom;
  double? _setupWeight;
  double? _suggestedDose;
  bool _allowOffset = false;

  bool get hasSetupWeight => _setupWeight != null;
  double? get setupWeight => _setupWeight;
  bool get readyForDose =>
      _setupWeight != null &&
      _anchor != null &&
      (_anchor! - _setupWeight!).abs() <= _stabilityTolerance &&
      _lastAt!.difference(_stableFrom!) >= _setupTime;
  double? get suggestedDose => _suggestedDose;

  void reset() {
    _allowOffset = false;
    _resetDetection();
  }

  void beginDoseWeighing(double baseline, DateTime at) {
    reset();
    _allowOffset = true;
    _setupWeight = baseline;
    _anchor = baseline;
    _stableFrom = at;
    _lastAt = at;
  }

  void _resetDetection() {
    _lastAt = null;
    _setupWeight = null;
    _clearStability();
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
        ((!_allowOffset && grams <= maximumBeanAddition) ||
            grams < setupWeight - _stabilityTolerance ||
            grams > setupWeight + maximumBeanAddition)) {
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
    if (!_allowOffset && grams <= maximumBeanAddition) {
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
        steadyFor >= _doseTime &&
                delta > _stabilityTolerance &&
                delta <= maximumBeanAddition
            ? delta
            : null;
  }

  void _clearStability() {
    _anchor = null;
    _stableFrom = null;
    _suggestedDose = null;
  }
}
