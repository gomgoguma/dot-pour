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

  EspressoSession sustainedShot({double? emptyScaleGrams}) {
    final shot = EspressoSession()..dose = 18;
    shot.start(
      baseline: 0,
      emptyScaleGrams: emptyScaleGrams,
      at: origin,
      automatic: false,
    );
    for (var ms = 250; ms <= 5750; ms += 250) {
      shot.observe(ms / 500, at(ms));
    }
    return shot;
  }

  test('plateau holds the timer and shows completion without ending', () {
    final shot = sustainedShot();
    expect(shot.secondsAt(at(5900)), 5.75);
    expect(shot.points.any((point) => point.flow > 1), isTrue);
    shot.observe(11.5, at(6000));
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(6250)), 5.75);
    expect(shot.flowAt(at(6000)), 0);
    shot.observe(11.5, at(6500));
    expect(shot.showsCompletionAt(at(6749)), isFalse);
    shot.observe(11.5, at(6750));
    expect(shot.showsCompletionAt(at(6750)), isTrue);
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.active, isTrue);
    expect(shot.yieldGrams, 11.5);
    expect(shot.secondsAt(at(12000)), 5.75);
    expect(shot.points.last.seconds, 5.75);
    expect(shot.points.last.flow, 0);
    shot.finish(at(12000));
    expect(shot.phase, EspressoPhase.finished);
    expect(shot.secondsAt(at(12000)), 5.75);
  });

  test('drop within the grace period resumes at actual elapsed time', () {
    final shot = sustainedShot();
    shot.observe(11.5, at(6000));
    expect(shot.secondsAt(at(6500)), 5.75);
    shot.observe(11.6, at(6500));
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(6500)), 6.5);
    expect(shot.points.last.seconds, 6.5);
    expect(shot.points.last.breakBefore, isTrue);
    shot.observe(11.5, at(6750));
    shot.finish(at(7000));
    expect(shot.secondsAt(at(7200)), 6.5);
    expect(shot.points.last.breakBefore, isTrue);
  });

  test('a drop after completion is shown still resumes the same shot', () {
    final shot = sustainedShot();
    shot.observe(11.5, at(6000));
    shot.observe(11.5, at(10000));
    expect(shot.showsCompletionAt(at(10000)), isTrue);
    expect(shot.secondsAt(at(10000)), 5.75);
    shot.observe(11.6, at(12000));
    expect(shot.showsCompletionAt(at(12000)), isFalse);
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(12000)), 12);
    expect(shot.yieldGrams, 11.6);
    expect(shot.points.last.breakBefore, isTrue);
  });

  test('cup lift does not advance or finalize a held timer', () {
    final shot = sustainedShot();
    shot.observe(11.5, at(6000));
    shot.observe(-100, at(6250));
    shot.observe(-100, at(7000));
    expect(shot.holding, isTrue);
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(7000)), 5.75);
    shot.observe(11.5, at(7250));
    expect(shot.phase, EspressoPhase.brewing);
    shot.observe(11.7, at(7500));
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.secondsAt(at(7500)), 7.5);
  });

  test(
    'removal allows residual load and excludes a squeeze before the lift',
    () {
      final shot = sustainedShot(emptyScaleGrams: -75);
      shot.observe(11.5, at(6000));
      shot.observe(11.5, at(6750));
      shot.observe(11.6, at(6850));
      expect(shot.yieldGrams, 11.5);

      shot.observe(-60, at(6950));
      expect(shot.phase, EspressoPhase.brewing);
      shot.observe(-59, at(7100));
      shot.observe(-59.5, at(7250));
      expect(shot.phase, EspressoPhase.finished);
      expect(shot.yieldGrams, 11.5);
      expect(shot.secondsAt(at(8000)), 5.75);
      expect(shot.points.last.seconds, 5.75);
      expect(shot.points.every((point) => point.grams <= 11.5), isTrue);
    },
  );

  test('partial unloading and isolated dips keep the shot resumable', () {
    final shot = sustainedShot(emptyScaleGrams: -75);
    shot.observe(0, at(6000));
    shot.observe(-35, at(6350));
    shot.observe(-35, at(6700));
    shot.observe(-55, at(6800));
    shot.observe(null, at(7050));
    shot.observe(-55, at(7150));
    shot.observe(11.5, at(7400));
    shot.observe(11.6, at(7550));
    shot.observe(11.7, at(7700));
    expect(shot.phase, EspressoPhase.brewing);
    expect(shot.yieldGrams, 11.7);
    expect(shot.secondsAt(at(7700)), 7.7);
  });

  test('a confirmed gain after a pause starts at its first reading', () {
    final shot = sustainedShot(emptyScaleGrams: -75);
    shot.observe(11.5, at(6000));
    shot.observe(11.5, at(12000));
    shot.observe(11.6, at(12100));
    expect(shot.secondsAt(at(12100)), 5.75);
    shot.observe(11.6, at(12200));
    expect(shot.secondsAt(at(12200)), 12.1);
    expect(shot.points.last.breakBefore, isTrue);
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
