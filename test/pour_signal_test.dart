import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/recipe.dart';
import 'package:dot_pour/scales/scale_models.dart';
import 'package:flutter_test/flutter_test.dart';

class PourFixture {
  Duration now = Duration.zero;
  late final brew = BrewSession(now: () => now)
    ..start(rawGrams: 0, dose: 20, ratio: 16);
  void send(
    double grams, {
    int repeats = 1,
    bool overloaded = false,
    double flow = 8,
  }) {
    for (var i = 0; i < repeats; i++) {
      now += const Duration(milliseconds: 100);
      brew.ingestScaleReading(
        ScaleReading(grams: grams, flow: flow, overloaded: overloaded),
      );
      brew.tick();
    }
  }

  void reach(double grams) {
    for (var g = 0.0; g <= grams; g++) {
      send(g);
    }
    send(grams);
  }
}

void main() {
  test('reapplying pressure after zero does not inflate poured water', () {
    final f = PourFixture()..reach(60);
    f.send(0, repeats: 5);
    expect(f.brew.water, 60);
    for (var raw = 0.0; raw <= 60; raw += 2) {
      f.send(raw);
    }
    f.send(60, repeats: 5);
    expect(f.brew.water, 60);
    for (var raw = 62.0; raw <= 80; raw += 2) {
      f.send(raw);
    }
    f.send(80);
    expect(f.brew.water, 80);
  });

  test(
    'repeated moving returns preserve an established offset without adding more',
    () {
      for (final step in [.5, 2.0, 5.0]) {
        final f = PourFixture()..reach(60);
        f.send(-300, repeats: 5);
        f.send(56, repeats: 5);
        expect(f.brew.water, 60);
        expect(f.brew.holdingMeasurement, false);
        for (var cycle = 0; cycle < 3; cycle++) {
          f.send(0, repeats: 5);
          for (var raw = 0.0; raw <= 56; raw += step) {
            f.send(raw);
            expect(f.brew.water, 60);
          }
          f.send(56, repeats: 5);
          expect(f.brew.water, 60);
          expect(f.brew.holdingMeasurement, false);
        }
        for (var raw = 57.0; raw <= 76; raw++) {
          f.send(raw);
        }
        f.send(76);
        expect(f.brew.water, 80);
        expect(f.brew.points.every((point) => point.grams <= 80), true);
        f.brew.finish();
        expect(f.brew.toRecipe('repeated return').validate(), isNull);
      }
    },
  );

  test('a small downward wobble does not wait for the pour to stop', () {
    final f = PourFixture()..reach(100);
    f.send(103);
    f.send(100); // Water moving in the server, not lifting the server.
    for (var i = 1; i <= 30; i++) {
      final raw = 100 + i * .6;
      f.send(raw);
      expect(f.brew.holdingMeasurement, false);
      expect(raw - f.brew.water, lessThanOrEqualTo(.61));
    }
    f.send(118, repeats: 5);
    expect(f.brew.water, 118);
    expect(f.brew.flow, 0);
  });

  test('a fast pour recovers without publishing a duplicate sample', () {
    final f = PourFixture()..reach(160);
    f.send(-350, repeats: 8);
    f.send(320); // Landing bounce must not become poured water.
    f.send(170);
    f.send(175);
    expect(f.brew.water, 160);
    f.send(180);
    expect(f.brew.holdingMeasurement, false);
    expect(f.brew.water, 175);
    f.send(185);
    expect(f.brew.water, 180);
    f.send(190);
    expect(f.brew.water, 185);
    f.send(190);
    expect(f.brew.water, 190);
    expect(f.brew.points.every((p) => p.grams <= 190), true);
    expect(f.brew.points.any((p) => p.breakBefore), true);
    f.brew.finish();
    expect(f.brew.toRecipe('moving return').validate(), isNull);
  });

  test(
    'a small settled offset after lifting does not freeze the next pour',
    () {
      final f = PourFixture()..reach(160);
      f.send(-350, repeats: 5);
      for (final raw in [148.0, 150.0, 152.0]) {
        f.send(raw);
        expect(f.brew.water, 160);
        expect(f.brew.holdingMeasurement, true);
      }
      f.send(154, repeats: 5);
      expect(f.brew.holdingMeasurement, false);
      expect(f.brew.water, 160);
      for (var raw = 155.0; raw <= 174; raw++) {
        f.send(raw);
      }
      f.send(174);
      expect(f.brew.water, 180);
      expect(f.brew.points.every((p) => p.grams <= 180), true);
    },
  );

  test('recovery also works when notifications arrive 400ms apart', () {
    final f = PourFixture()..reach(160);
    f.send(-350);
    for (var i = 0; i < 4; i++) {
      f.now += const Duration(milliseconds: 300);
      f.send(160);
    }
    expect(f.brew.holdingMeasurement, false);
  });

  test(
    'holding after a display tick cannot insert an out-of-order endpoint',
    () {
      final f = PourFixture()..reach(160);
      f.now += const Duration(milliseconds: 400);
      f.brew.tick();
      f.send(0);
      f.brew.finish();
      expect(f.brew.toRecipe('after tick').validate(), isNull);
      expect(f.brew.points.last.grams, 160);
    },
  );

  test('long-record compaction preserves excluded measurement gaps', () {
    final f = PourFixture()..reach(100);
    f.send(0);
    f.send(100, repeats: 5);
    for (var i = 0; i < 3000; i++) {
      f.now += const Duration(milliseconds: 300);
      f.brew.update(100, flowGramsPerSecond: 0);
    }
    f.brew.finish();
    expect(f.brew.points.length, lessThanOrEqualTo(2400));
    expect(f.brew.points.any((p) => p.breakBefore), true);
    expect(f.brew.toRecipe('long').validate(), isNull);
  });
  test(
    'normal 10Hz pour has one-sample latency and stops flow within 0.5s',
    () {
      final f = PourFixture();
      for (var i = 0; i <= 40; i++) {
        final input = i * .5;
        f.send(input);
        expect(input - f.brew.water, lessThanOrEqualTo(.51));
        expect(f.brew.holdingMeasurement, false);
      }
      expect(f.brew.flow, closeTo(5, .01));
      f.send(
        20,
        repeats: 5,
        flow: 9,
      ); // Device flow intentionally keeps lagging.
      expect(f.brew.water, 20);
      expect(f.brew.flow, 0);
    },
  );

  test(
    'at 50 percent, lift/zero/swirl retain water and timer; bad values never enter trace',
    () {
      final f = PourFixture()..reach(160);
      final before = f.brew.seconds;
      for (final bad in [-400.0, -200.0, 0.0, 390.0, 20.0, -5.0]) {
        f.send(bad);
        expect(f.brew.water, 160);
        expect(f.brew.percent, 50);
        expect(f.brew.phase, BrewPhase.pouring);
        expect(f.brew.holdingMeasurement, true);
        expect(f.brew.flow, 0);
      }
      expect(f.brew.seconds, greaterThan(before));
      final plateau = f.brew.points.where((p) => p.seconds > before).toList();
      expect(plateau, isNotEmpty);
      expect(
        plateau.every((p) => p.grams == 160 && p.flow == 0 && !p.breakBefore),
        true,
      );
      expect(f.brew.points.last.grams, 160);
      f.send(160, repeats: 5);
      expect(f.brew.holdingMeasurement, false);
      expect(f.brew.points.any((p) => p.breakBefore), true);
      expect(f.brew.points.every((p) => p.grams <= 160), true);
      for (var g = 161.0; g <= 200; g++) {
        f.send(g);
      }
      f.send(200);
      f.brew.finish();
      final recipe = f.brew.toRecipe('swirl');
      expect(recipe.trace.last.grams, 200);
      expect(recipe.validate(), isNull);
      final restored = BrewRecipe.fromJson(recipe.toJson());
      expect(restored.trace.where((p) => p.breakBefore).length, 1);
      expect(restored.scaled(10, 16).trace.any((p) => p.breakBefore), true);
    },
  );

  test(
    'an overload spike cannot stop the brew or add a false target alert',
    () {
      final f = PourFixture()..reach(100);
      f.send(1800, overloaded: true);
      f.send(900, repeats: 10);
      expect(f.brew.water, 100);
      expect(f.brew.reached, false);
      expect(f.brew.active, true);
      f.send(100, repeats: 5);
      expect(f.brew.holdingMeasurement, false);
      expect(f.brew.points.every((p) => p.grams <= 100), true);
    },
  );

  test(
    'permanent zero is held, never silently rebased or written to the saved endpoint',
    () {
      final f = PourFixture()..reach(160);
      f.send(0, repeats: 100);
      expect(f.brew.holdingMeasurement, true);
      expect(f.brew.percent, 50);
      expect(f.brew.active, true);
      f.brew.finish();
      final endpoint = f.brew.toRecipe('zero').trace.last;
      expect(endpoint.grams, 160);
      expect(endpoint.seconds, f.brew.seconds);
    },
  );

  test(
    'small single-sample pressure spike is rejected before it can be recorded',
    () {
      final f = PourFixture()..reach(100);
      f.send(106);
      f.send(100, repeats: 5);
      expect(f.brew.water, 100);
      expect(f.brew.points.every((p) => p.grams <= 100), true);
    },
  );

  test(
    'old points load, gap interpolation and pour inference never invent a pour',
    () {
      expect(BrewPoint.fromJson([1, 10, 2]).breakBefore, false);
      final points = [
        const BrewPoint(0, 0, 0),
        const BrewPoint(10, 100, 10),
        const BrewPoint(20, 110, 0, breakBefore: true),
        const BrewPoint(21, 120, 10),
      ];
      expect(BrewRecipe.interpolate(points, 15), 100);
      expect(BrewRecipe.interpolate(points, 20), 110);
      expect(
        BrewRecipe.inferPours(points).fold(0.0, (sum, s) => sum + s.amount),
        110,
      );
    },
  );
}
