import 'dart:math' as math;

import 'recipe.dart';
import 'scale_flow.dart';

enum EspressoPhase { setup, armed, brewing, finished, interrupted }

class EspressoSession {
  static const startThreshold = 0.2;
  static const _minimumPour = Duration(seconds: 5);
  static const _stopDelay = Duration(seconds: 4);
  static const _graphInterval = Duration(milliseconds: 200);

  final _points = <BrewPoint>[];
  final _flow = ScaleFlow();
  EspressoPhase phase = EspressoPhase.setup;
  double? dose;
  double yieldGrams = 0;
  bool holding = false;
  double _baseline = 0;
  double _lastIncreaseWeight = 0;
  DateTime? _startedAt, _endedAt, _lastIncrease, _candidateAt;
  bool _canAutoFinish = false;
  Duration _pouringTime = Duration.zero;
  DateTime? _lastReading, _lastPoint;

  bool get active =>
      phase == EspressoPhase.armed || phase == EspressoPhase.brewing;
  List<BrewPoint> get points => List.unmodifiable(_points);
  double? get ratio => dose == null ? null : yieldGrams / dose!;
  static bool validDose(double dose) =>
      dose.isFinite && dose >= .1 && dose <= 100;

  double secondsAt(DateTime at) =>
      _startedAt == null
          ? 0
          : math.max(
            0,
            (_endedAt ?? at).difference(_startedAt!).inMicroseconds / 1e6,
          );
  double flowAt(DateTime at) =>
      phase == EspressoPhase.brewing && !holding ? _flow.flowAt(at) : 0;

  void start({
    required double baseline,
    required DateTime at,
    required bool automatic,
  }) {
    if (phase != EspressoPhase.setup || dose == null) return;
    _baseline = baseline;
    _lastReading = at;
    _flow.observe(0, at);
    if (automatic) {
      phase = EspressoPhase.armed;
    } else {
      _begin(at);
    }
  }

  void _begin(DateTime at) {
    phase = EspressoPhase.brewing;
    _startedAt = at;
    _sample(at, force: true);
  }

  void observe(double? rawWeight, DateTime at) {
    if (!active || (_lastReading?.isAfter(at) ?? false)) return;
    if (_lastReading == at) return;
    _lastReading = at;
    final net =
        rawWeight == null || !rawWeight.isFinite ? null : rawWeight - _baseline;
    if (phase == EspressoPhase.armed) {
      if (net == null || net < startThreshold - 1e-6) {
        _candidateAt = null;
        return;
      }
      final first = _candidateAt;
      if (first == null || at.difference(first) > const Duration(seconds: 1)) {
        _candidateAt = at;
        return;
      }
      _begin(first);
    }

    if (net == null || net < -.4 || net < yieldGrams - 1) {
      if (!holding) {
        _flow.reset();
        _lastIncrease = null;
        _pouringTime = Duration.zero;
      }
      holding = true;
      _sample(at);
      return;
    }

    if (holding) {
      holding = false;
      // Restart flow at the current weight. Returning the cup is not a pour.
      _flow.reset();
    }
    yieldGrams = math.max(yieldGrams, net);
    _flow.observe(net, at);
    if (yieldGrams - _lastIncreaseWeight >= startThreshold - 1e-6) {
      final previous = _lastIncrease ?? _candidateAt;
      if (previous != null) {
        final interval = at.difference(previous);
        if (interval >= _stopDelay && !_canAutoFinish) {
          _pouringTime = Duration.zero;
        } else {
          _pouringTime += interval;
        }
      }
      _candidateAt = null;
      _lastIncrease = at;
      _lastIncreaseWeight = yieldGrams;
      if (_pouringTime >= _minimumPour) _canAutoFinish = true;
    }
    _sample(at);
    final last = _lastIncrease;
    if (last != null && _canAutoFinish && at.difference(last) >= _stopDelay) {
      finish(at);
    }
  }

  void _sample(DateTime at, {bool force = false}) {
    if (!force &&
        _lastPoint != null &&
        at.difference(_lastPoint!) < _graphInterval) {
      return;
    }
    final seconds = secondsAt(at);
    final point = BrewPoint(seconds, yieldGrams, flowAt(at));
    if (_points.isNotEmpty && _points.last.seconds == seconds) {
      _points[_points.length - 1] = point;
    } else {
      _points.add(point);
    }
    _lastPoint = at;
  }

  void finish(DateTime at, {bool interrupted = false}) {
    if (!active) return;
    if (phase == EspressoPhase.armed && !interrupted) {
      reset();
      return;
    }
    final last = _lastReading;
    _endedAt = last != null && last.isAfter(at) ? last : at;
    phase = interrupted ? EspressoPhase.interrupted : EspressoPhase.finished;
    holding = false;
    if (_startedAt != null) _sample(_endedAt!, force: true);
  }

  void reset() {
    phase = EspressoPhase.setup;
    yieldGrams = 0;
    holding = false;
    _lastIncreaseWeight = 0;
    _startedAt = _endedAt = _lastIncrease = _candidateAt = null;
    _pouringTime = Duration.zero;
    _canAutoFinish = false;
    _lastPoint = _lastReading = null;
    _flow.reset();
    _points.clear();
  }
}
