import 'dart:math' as math;
import 'recipe.dart';
import 'pour_signal.dart';
import 'scales/scale_models.dart';

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
  final _signal = PourSignal();
  final List<PourSample> _flowSamples = [];
  bool _scaleInput = false, _breakBeforeNextPoint = false;
  bool get holdingMeasurement => _scaleInput && _signal.holding;
  Duration? _startedAt, _endedAt, _lastUpdate;
  int _pourSamples = 0;
  double _sampleInterval = 0.25;
  final List<BrewPoint> _points = [];
  List<BrewPoint>? _pointsSnapshot;
  List<BrewPoint> get points => _pointsSnapshot ??= List.unmodifiable(_points);
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

  static String? validate(double dose, double ratio, {double? maxWater}) {
    if (!dose.isFinite || dose < 0.1 || dose > 100) {
      return '원두량은 0.1~100g으로 입력해 주세요.';
    }
    if (!ratio.isFinite || ratio < 1 || ratio > 30) {
      return '비율은 1:1~1:30으로 입력해 주세요.';
    }
    if (maxWater != null && dose * ratio > maxWater) {
      return '목표 물량이 선택한 저울의 최대 용량 ${maxWater.toStringAsFixed(0)}g을 넘습니다.';
    }
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
    _signal.reset(_now());
    phase = BrewPhase.ready;
    _points.add(const BrewPoint(0, 0, 0));
  }

  /// Physical scale readings can contain lift/swirl/overload transients.
  /// Demo data goes directly through [update] because it is already clean.
  void ingestScaleReading(ScaleReading reading) {
    if (!active) return;
    _scaleInput = true;
    final wasHolding = _signal.holding;
    final sample = _signal.add(
      reading.grams - _baseline,
      _now(),
      overloaded: reading.overloaded,
      cumulative: phase == BrewPhase.pouring,
    );
    if (_signal.holding) {
      if (!wasHolding && _lastUpdate != null) {
        // Preserve the last accepted endpoint even if chart decimation has
        // not recorded it yet. Never use the disturbed sample's timestamp.
        _record(force: true, at: _lastUpdate);
      }
      flow = 0;
      _flowSamples.clear();
      _breakBeforeNextPoint = true;
      return;
    }
    if (sample == null) return;
    if (wasHolding) _flowSamples.clear();
    _flowSamples.add(sample);
    // Derive flow from a short window of accepted weight, rather than the
    // device's separate flow field. Stable weight yields 0g/s
    // within 0.4s; this never smooths the displayed mass over several seconds.
    while (_flowSamples.length > 1 &&
        sample.at - _flowSamples.first.at > const Duration(milliseconds: 400)) {
      _flowSamples.removeAt(0);
    }
    final dt = (sample.at - _flowSamples.first.at).inMicroseconds / 1000000;
    final rate =
        dt <= 0
            ? 0.0
            : math.max(0.0, (sample.grams - _flowSamples.first.grams) / dt);
    update(_baseline + sample.grams, flowGramsPerSecond: rate);
  }

  void update(double rawGrams, {double? flowGramsPerSecond}) {
    if (!active || !rawGrams.isFinite) return;
    final now = _now();
    // This is cumulative poured water; lifting a vessel must not erase it.
    final currentWater = math.max(0.0, rawGrams - _baseline);
    water =
        phase == BrewPhase.pouring
            ? math.max(water, currentWater)
            : currentWater;
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
    if (holdingMeasurement) return;
    if (_lastUpdate != null &&
        (_now() - _lastUpdate!) > const Duration(seconds: 1)) {
      flow = 0;
    }
    _record();
  }

  void _record({bool force = false, Duration? at}) {
    if (holdingMeasurement && at == null) return;
    final time =
        at != null && _startedAt != null
            ? (at - _startedAt!).inMicroseconds / 1000000
            : seconds;
    if (time <= 0) return;
    if (_points.isNotEmpty && time < _points.last.seconds) return;
    if (_points.isNotEmpty &&
        time - _points.last.seconds < _sampleInterval &&
        !force) {
      return;
    }
    final point = BrewPoint(
      time,
      water,
      flow,
      breakBefore: _breakBeforeNextPoint,
    );
    _breakBeforeNextPoint = false;
    _pointsSnapshot = null;
    if (_points.isNotEmpty && time == _points.last.seconds) {
      _points[_points.length - 1] = BrewPoint(
        time,
        water,
        flow,
        breakBefore: point.breakBefore || _points.last.breakBefore,
      );
    } else {
      _points.add(point);
    }
    // Bound storage for unusually long sessions, preserving origin and newest
    // sample while progressively reducing only the older curve's resolution.
    if (_points.length > 2400) {
      final reduced = <BrewPoint>[];
      var gap = false;
      for (var i = 0; i < _points.length; i++) {
        final p = _points[i];
        gap |= p.breakBefore;
        if (i.isEven || i == _points.length - 1) {
          reduced.add(BrewPoint(p.seconds, p.grams, p.flow, breakBefore: gap));
          gap = false;
        }
      }
      _points
        ..clear()
        ..addAll(reduced);
      _sampleInterval *= 2;
    }
  }

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
    _signal.reset(_now());
    _flowSamples.clear();
    _scaleInput = false;
    _breakBeforeNextPoint = false;
    water = 0;
    flow = 0;
    _points.clear();
    _pointsSnapshot = null;
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
