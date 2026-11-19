import 'dart:math' as math;

import 'recipe.dart';
import 'scale_flow.dart';

enum EspressoPhase { setup, armed, brewing, finished, interrupted }

class EspressoSession {
  static const startThreshold = 0.2;
  static const _weightStep = 0.1;
  static const _minimumPour = Duration(seconds: 5);
  static const _pourContinuityGap = Duration(seconds: 4);
  static const _completionDisplayDelay = Duration(seconds: 1);
  static const _graphInterval = Duration(milliseconds: 200);
  static const _cupRemovalDwell = Duration(milliseconds: 300);
  static const _cupReadingGap = Duration(milliseconds: 600);

  final _points = <BrewPoint>[];
  final _flow = ScaleFlow();
  EspressoPhase phase = EspressoPhase.setup;
  double? dose;
  double yieldGrams = 0;
  bool holding = false;
  double _baseline = 0;
  double? _cupRemovalThreshold;
  double _lastIncreaseWeight = 0;
  DateTime? _startedAt, _endedAt, _lastIncrease, _candidateAt;
  DateTime? _cupRemovalSince, _lastYieldAt;
  ({double grams, DateTime at})? _pendingGain;
  bool _sustainedPour = false;
  bool _waitingForResume = false;
  Duration _pouringTime = Duration.zero;
  DateTime? _lastReading, _lastPoint;

  bool get active =>
      phase == EspressoPhase.armed || phase == EspressoPhase.brewing;
  bool showsCompletionAt(DateTime at) {
    final lastIncrease = _lastIncrease;
    return phase == EspressoPhase.brewing &&
        !holding &&
        _waitingForResume &&
        lastIncrease != null &&
        at.difference(lastIncrease) >= _completionDisplayDelay;
  }

  List<BrewPoint> get points => List.unmodifiable(_points);
  double? get ratio => dose == null ? null : yieldGrams / dose!;
  static bool validDose(double dose) =>
      dose.isFinite && dose >= .1 && dose <= 100;

  double secondsAt(DateTime at) =>
      _startedAt == null
          ? 0
          : math.max(
            0,
            _displayTime(at).difference(_startedAt!).inMicroseconds / 1e6,
          );

  // After a sustained pour, the display follows the latest weight gain.
  // Reading timestamps keep advancing so a resumed pour includes the pause.
  DateTime _displayTime(DateTime at) =>
      _endedAt ?? (_sustainedPour ? _lastIncrease : null) ?? at;

  double flowAt(DateTime at) =>
      phase == EspressoPhase.brewing && !holding && !_waitingForResume
          ? _flow.flowAt(at)
          : 0;

  void start({
    required double baseline,
    double? emptyScaleGrams,
    required DateTime at,
    required bool automatic,
  }) {
    if (phase != EspressoPhase.setup || dose == null) return;
    _baseline = baseline;
    if (emptyScaleGrams != null &&
        emptyScaleGrams.isFinite &&
        emptyScaleGrams < baseline) {
      final cupWeight = baseline - emptyScaleGrams;
      _cupRemovalThreshold = -cupWeight * (2 / 3);
    }
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
    final previousReading = _lastReading;
    if (!active || (previousReading != null && !at.isAfter(previousReading))) {
      return;
    }
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

    final removalThreshold = _cupRemovalThreshold;
    final readingGap =
        previousReading == null ? null : at.difference(previousReading);
    if (removalThreshold != null &&
        _lastYieldAt != null &&
        yieldGrams >= startThreshold &&
        net != null &&
        net <= removalThreshold) {
      if (readingGap == null || readingGap > _cupReadingGap) {
        _cupRemovalSince = null;
      }
      final since = _cupRemovalSince ??= at;
      if (at.difference(since) >= _cupRemovalDwell) {
        _end(_lastYieldAt!, EspressoPhase.finished);
        return;
      }
    } else {
      _cupRemovalSince = null;
    }

    if (_cupRemovalSince != null ||
        net == null ||
        net < -.4 ||
        net < yieldGrams - 1) {
      _pendingGain = null;
      if (!holding) {
        _flow.reset();
        if (!_sustainedPour) {
          _lastIncrease = null;
          _pouringTime = Duration.zero;
        }
        _waitingForResume = false;
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

    final pending = _pendingGain;
    _pendingGain = null;
    if (pending != null &&
        at.difference(pending.at) <= _cupReadingGap &&
        net >= pending.grams - 1e-6) {
      _recordYield(pending.grams, pending.at);
    }
    final increase = net - yieldGrams;
    final abruptRise =
        readingGap != null &&
        increase >= .8 &&
        increase > 8 * readingGap.inMicroseconds / 1e6;
    if (removalThreshold != null &&
        _lastYieldAt != null &&
        increase >= _weightStep - 1e-6 &&
        (_waitingForResume || abruptRise)) {
      // Confirm a rise after a pause or a sudden jump with another reading.
      // A press followed by lifting the cup must not inflate the result.
      _pendingGain = (grams: net, at: at);
      return;
    }
    _recordYield(net, at);
  }

  void _recordYield(double net, DateTime at) {
    final last = _lastIncrease;
    final pause = last == null ? Duration.zero : at.difference(last);
    if (net > yieldGrams + 1e-6) {
      yieldGrams = net;
      _lastYieldAt = at;
    }
    _flow.observe(net, at);
    final weightStep = _sustainedPour ? _weightStep : startThreshold;
    if (yieldGrams - _lastIncreaseWeight >= weightStep - 1e-6) {
      final previous = last ?? _candidateAt;
      if (previous != null && !_sustainedPour) {
        final interval = at.difference(previous);
        if (interval >= _pourContinuityGap) {
          _pouringTime = Duration.zero;
        } else {
          _pouringTime += interval;
        }
      }
      _candidateAt = null;
      _lastIncrease = at;
      _lastIncreaseWeight = yieldGrams;
      if (_pouringTime >= _minimumPour) _sustainedPour = true;
      final resumed = _waitingForResume;
      _waitingForResume = false;
      _sample(at, force: resumed, breakBefore: resumed);
    } else if (_sustainedPour) {
      if (!_waitingForResume && pause >= _graphInterval) {
        _waitingForResume = true;
        _sample(at, force: true);
      }
    } else {
      _sample(at);
    }
  }

  void _sample(DateTime at, {bool force = false, bool breakBefore = false}) {
    final pointAt = _displayTime(at);
    if (!force &&
        _lastPoint != null &&
        pointAt.difference(_lastPoint!) < _graphInterval) {
      return;
    }
    final seconds = secondsAt(pointAt);
    final replacing = _points.isNotEmpty && _points.last.seconds == seconds;
    final point = BrewPoint(
      seconds,
      yieldGrams,
      flowAt(at),
      breakBefore: breakBefore || (replacing && _points.last.breakBefore),
    );
    if (replacing) {
      _points[_points.length - 1] = point;
    } else {
      _points.add(point);
    }
    _lastPoint = pointAt;
  }

  void finish(DateTime at, {bool interrupted = false}) {
    if (!active) return;
    if (phase == EspressoPhase.armed && !interrupted) {
      reset();
      return;
    }
    final last = _lastReading;
    final time = last != null && last.isAfter(at) ? last : at;
    _end(
      (_waitingForResume || holding ? _lastIncrease : null) ?? time,
      interrupted ? EspressoPhase.interrupted : EspressoPhase.finished,
    );
  }

  void _end(DateTime at, EspressoPhase result) {
    _endedAt = at;
    phase = result;
    holding = false;
    _waitingForResume = false;
    if (_startedAt != null) {
      final seconds = secondsAt(at);
      while (_points.isNotEmpty && _points.last.seconds > seconds) {
        _points.removeLast();
      }
      _sample(at, force: true);
    }
  }

  void reset() {
    phase = EspressoPhase.setup;
    yieldGrams = 0;
    holding = false;
    _lastIncreaseWeight = 0;
    _cupRemovalThreshold = null;
    _cupRemovalSince = _lastYieldAt = null;
    _pendingGain = null;
    _startedAt = _endedAt = _lastIncrease = _candidateAt = null;
    _pouringTime = Duration.zero;
    _sustainedPour = false;
    _waitingForResume = false;
    _lastPoint = _lastReading = null;
    _flow.reset();
    _points.clear();
  }
}
