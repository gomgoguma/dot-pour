import 'dart:math' as math;

enum BrewPhase { setup, ready, pouring, finished, interrupted }

class BrewSession {
  double dose = 20;
  double ratio = 16;
  double water = 0;
  double _baseline = 0;
  int _pourSamples = 0;
  BrewPhase phase = BrewPhase.setup;
  final Stopwatch _clock = Stopwatch();

  double get target => dose * ratio;
  double get percent => water / target * 100;
  double get remaining => math.max(0, target - water);
  double get extra => math.max(0, water - target);
  Duration get elapsed => _clock.elapsed;
  bool get active => phase == BrewPhase.ready || phase == BrewPhase.pouring;
  bool get reached => water >= target;

  static String? validate(double dose, double ratio) {
    if (!dose.isFinite || dose < 0.1 || dose > 100) {
      return '원두량은 0.1~100g으로 입력해 주세요.';
    }
    if (!ratio.isFinite || ratio < 1 || ratio > 30) {
      return '비율은 1:1~1:30으로 입력해 주세요.';
    }
    if (dose * ratio > 1200) return '목표 물량이 도트의 최대 용량 1,200g을 넘습니다.';
    return null;
  }

  void start({
    required double rawGrams,
    required double dose,
    required double ratio,
  }) {
    final error = validate(dose, ratio);
    if (error != null || !rawGrams.isFinite) {
      throw ArgumentError(error ?? '유효한 저울 값이 필요합니다.');
    }
    this.dose = dose;
    this.ratio = ratio;
    _baseline = rawGrams;
    water = 0;
    _pourSamples = 0;
    _clock
      ..stop()
      ..reset();
    phase = BrewPhase.ready;
  }

  void update(double rawGrams) {
    if (!active || !rawGrams.isFinite) return;
    water = math.max(0, rawGrams - _baseline);
    if (phase == BrewPhase.ready) {
      _pourSamples = water >= 0.5 ? _pourSamples + 1 : 0;
      if (_pourSamples >= 2) {
        phase = BrewPhase.pouring;
        _clock.start();
      }
    }
  }

  bool vesselRemoved(double rawGrams) => active && rawGrams < _baseline - 2;

  void finish() {
    _clock.stop();
    phase = BrewPhase.finished;
  }

  void interrupt() {
    if (!active) return;
    _clock.stop();
    phase = BrewPhase.interrupted;
  }

  void reset() {
    _clock
      ..stop()
      ..reset();
    water = 0;
    phase = BrewPhase.setup;
  }
}
