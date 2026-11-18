import 'package:dot_pour/espresso_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final origin = DateTime.utc(2026);
  DateTime at(int ms) => origin.add(Duration(milliseconds: ms));

  test('auto-start requires two readings at least 0.2 g above zero', () {
    final shot = EspressoSession()..dose = 18;
    shot.start(baseline: .1, at: origin, automatic: true);
    shot.observe(.3, at(100));
    shot.observe(.29, at(200));
    expect(shot.phase, EspressoPhase.armed);
    shot.observe(.3, at(300));
    expect(shot.phase, EspressoPhase.armed);
    shot.observe(.4, at(400));
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(400)), closeTo(.1, 0.001));
    shot.observe(36.1, at(800));
    expect(shot.ratio, closeTo(2, .001));
  });

  test('plateau ends a sustained shot, including flow on the trace', () {
    final shot = EspressoSession()..dose = 18;
    shot.start(baseline: 0, at: origin, automatic: false);
    for (var ms = 250; ms <= 5750; ms += 250) {
      shot.observe(ms / 500, at(ms));
    }
    expect(shot.points.any((point) => point.flow > 1), isTrue);
    for (var ms = 6000; ms <= 9750; ms += 250) {
      shot.observe(11.5, at(ms));
    }
    expect(shot.phase, EspressoPhase.finished);
    expect(shot.yieldGrams, 11.5);
    expect(shot.secondsAt(at(12000)), 9.75);
    expect(shot.points.last.flow, 0);
  });

  test('short bursts and cup removal preserve the shot', () {
    final shot = EspressoSession()..dose = 18;
    shot.start(baseline: 0, at: origin, automatic: false);
    for (var ms = 500; ms <= 2500; ms += 500) {
      shot.observe(ms / 500, at(ms));
    }
    for (var ms = 3000; ms <= 8000; ms += 500) {
      shot.observe(5, at(ms));
    }
    expect(shot.phase, EspressoPhase.brewing);
    for (var ms = 8500; ms <= 14000; ms += 500) {
      shot.observe(-100, at(ms));
    }
    expect(shot.holding, isTrue);
    expect(shot.yieldGrams, 5);
    shot.observe(5, at(14500));
    expect(shot.holding, isFalse);
    expect(shot.flowAt(at(14500)), 0);
    expect(shot.phase, EspressoPhase.brewing);
    shot.finish(at(15000));
    expect(shot.phase, EspressoPhase.finished);
  });
}
