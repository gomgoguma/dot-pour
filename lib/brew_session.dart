import 'dart:math' as math;
import 'recipe.dart';

enum BrewPhase { setup, ready, pouring, finished, interrupted }

class BrewSession {
  final Duration Function() _now;
  BrewSession({Duration Function()? now}) : _now = now ?? _monotonicClock();
  static Duration Function() _monotonicClock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  double dose = 20, ratio = 16, water = 0, flow = 0;
  double _baseline = 0;
  double _lastRawWater = 0;
  Duration? _startedAt, _endedAt, _lastUpdate;
  int _pourSamples = 0;
  double _sampleInterval = 0.25;
  final List<BrewPoint> _points = [];
  List<BrewPoint> get points => List.unmodifiable(_points);
  BrewPhase phase = BrewPhase.setup;

  double get target => dose * ratio;
  double get percent => water / target * 100;
  double get remaining => math.max(0, target - water);
  double get extra => math.max(0, water - target);
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : (_endedAt ?? _now()) - _startedAt!;
  double get seconds => elapsed.inMicroseconds / 1000000;
  bool get active => phase == BrewPhase.ready || phase == BrewPhase.pouring;
  bool get reached => water >= target;
  bool get canSave =>
      phase == BrewPhase.finished &&
      water >= 0.5 &&
      _points.length >= 2 &&
      seconds > 0;

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
    reset();
    this.dose = dose;
    this.ratio = ratio;
    _baseline = rawGrams;
    phase = BrewPhase.ready;
    _points.add(const BrewPoint(0, 0, 0));
  }

  void update(double rawGrams, {double? flowGramsPerSecond}) {
    if (!active || !rawGrams.isFinite) return;
    final now = _now();
    water = math.max(0, rawGrams - _baseline);
    if (flowGramsPerSecond != null && flowGramsPerSecond.isFinite) {
      flow = math.max(0, flowGramsPerSecond);
    } else if (_lastUpdate != null) {
      final dt = (now - _lastUpdate!).inMicroseconds / 1000000;
      if (dt > 0) {
        final instant = math.max(0.0, (water - _lastRawWater) / dt);
        flow = flow * 0.65 + instant * 0.35;
        if (flow < 0.05) flow = 0;
      }
    }
    _lastRawWater = water;
    _lastUpdate = now;
    if (phase == BrewPhase.ready) {
      _pourSamples = water >= 0.5 ? _pourSamples + 1 : 0;
      if (_pourSamples >= 2) {
        phase = BrewPhase.pouring;
        _startedAt = now;
      }
    }
    if (phase == BrewPhase.pouring) _record();
  }

  void tick() {
    if (phase != BrewPhase.pouring) return;
    if (_lastUpdate != null &&
        (_now() - _lastUpdate!) > const Duration(seconds: 1)) {
      flow = 0;
    }
    _record();
  }

  void _record({bool force = false}) {
    final time = seconds;
    if (time <= 0) return;
    if (_points.isNotEmpty &&
        time - _points.last.seconds < _sampleInterval &&
        !force) {
      return;
    }
    final point = BrewPoint(time, water, flow);
    if (_points.isNotEmpty && time == _points.last.seconds) {
      _points[_points.length - 1] = point;
    } else {
      _points.add(point);
    }
    // Bound storage for unusually long sessions, preserving origin and newest
    // sample while progressively reducing only the older curve's resolution.
    if (_points.length > 2400) {
      final reduced = [
        for (var i = 0; i < _points.length - 1; i += 2) _points[i],
        _points.last,
      ];
      _points
        ..clear()
        ..addAll(reduced);
      _sampleInterval *= 2;
    }
  }

  bool vesselRemoved(double rawGrams) => active && rawGrams < _baseline - 2;
  void finish() {
    _endedAt = _now();
    _record(force: true);
    flow = 0;
    phase = BrewPhase.finished;
  }

  void interrupt() {
    if (!active) return;
    _endedAt = _now();
    _record(force: true);
    flow = 0;
    phase = BrewPhase.interrupted;
  }

  void reset() {
    _startedAt = null;
    _endedAt = null;
    _lastUpdate = null;
    _pourSamples = 0;
    _lastRawWater = 0;
    _sampleInterval = 0.25;
    water = 0;
    flow = 0;
    _points.clear();
    phase = BrewPhase.setup;
  }

  BrewRecipe toRecipe(String name, {bool isDemo = false}) {
    if (!canSave) throw StateError('저장할 추출 기록이 없습니다.');
    final now = DateTime.now();
    return BrewRecipe(
      id: 'brew-${now.microsecondsSinceEpoch}',
      name: name.trim(),
      dose: dose,
      ratio: ratio,
      unit: PourUnit.grams,
      steps: BrewRecipe.inferPours(_points),
      trace: points,
      duration: seconds,
      createdAt: now,
      isDemo: isDemo,
    );
  }
}
