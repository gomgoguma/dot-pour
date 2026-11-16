import 'package:dot_pour/brew_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('20g at 1:16 reports 50% after 160g, excluding the vessel', () {
    final brew = BrewSession()..start(rawGrams: 450, dose: 20, ratio: 16);
    brew.update(610);
    expect(brew.target, 320);
    expect(brew.water, 160);
    expect(brew.percent, 50);
    expect(brew.remaining, 160);
  });
  test('noise does not start the clock; two pour samples do', () {
    final brew = BrewSession()..start(rawGrams: 100, dose: 20, ratio: 16);
    for (final value in [100.1, 100.5, 100.0, 100.3, 100.7]) {
      brew.update(value);
      expect(brew.phase, BrewPhase.ready);
    }
    brew.update(101);
    expect(brew.phase, BrewPhase.pouring);
  });
  test('overshoot remains visible and finish freezes the result', () {
    final brew = BrewSession()..start(rawGrams: 0, dose: 20, ratio: 16);
    brew.update(352);
    expect(brew.percent, closeTo(110, 1e-9));
    expect(brew.extra, 32);
    expect(brew.remaining, 0);
    brew.finish();
    brew.update(400);
    expect(brew.water, 352);
  });
  test('negative readings never create negative progress', () {
    final brew = BrewSession()..start(rawGrams: 200, dose: 20, ratio: 16);
    brew.update(199.8);
    expect(brew.percent, 0);
    expect(brew.vesselRemoved(0), isTrue);
  });
  test('disconnect freezes the brew; a new session takes a new baseline', () {
    final brew = BrewSession()..start(rawGrams: 200, dose: 20, ratio: 16);
    brew.update(360);
    brew.interrupt();
    brew.update(500);
    expect(brew.water, 160);
    brew.reset();
    brew.start(rawGrams: 500, dose: 15, ratio: 15);
    brew.update(725);
    expect(brew.percent, 100);
  });
  test('reject invalid inputs and impossible target weights', () {
    for (final dose in [0.0, -1.0, double.nan, double.infinity, 101.0]) {
      expect(BrewSession.validate(dose, 16), isNotNull);
    }
    expect(BrewSession.validate(20, 0), isNotNull);
    expect(BrewSession.validate(100, 30, maxWater: 1200), isNotNull);
    expect(BrewSession.validate(100, 30, maxWater: 3000), isNull);
    expect(BrewSession.validate(18, 16.7), isNull);
  });
}
