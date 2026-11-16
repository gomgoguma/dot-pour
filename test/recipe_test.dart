import 'dart:convert';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/recipe.dart';
import 'package:dot_pour/recipe_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

BrewRecipe plan({PourUnit unit = PourUnit.percent, List<PourStep>? steps}) =>
    BrewRecipe(
      id: 'plan-1',
      name: '아침의 세 번 붓기',
      dose: 20,
      ratio: 15,
      unit: unit,
      steps:
          steps ??
          const [
            PourStep(start: 0, duration: 10, amount: 20),
            PourStep(start: 45, duration: 20, amount: 40),
            PourStep(start: 90, duration: 20, amount: 40),
          ],
      duration: 180,
      createdAt: DateTime(2026, 11, 16),
    );

void main() {
  test('percent amounts are per pour; interpolation respects pauses', () {
    final recipe = plan();
    expect(recipe.validate(), isNull);
    expect(recipe.cumulativeAt(0), 60);
    expect(recipe.cumulativeAt(1), 180);
    expect(recipe.plannedGrams, 300);
    expect(recipe.expectedGrams(5), 30);
    expect(recipe.expectedGrams(30), 60);
    expect(recipe.expectedGrams(55), 120);
    expect(recipe.expectedGrams(250), 300);
  });
  test(
    'guide keeps unfinished pours and waits before the next scheduled pour',
    () {
      final recipe = plan();
      final waiting = PourGuide(recipe, 20, 60);
      expect(waiting.stepIndex, 1);
      expect(waiting.waiting, true);
      expect(waiting.stepTarget, 180);
      expect(waiting.targetFlow, 6);
      expect(PourGuide(recipe, 70, 100).stepIndex, 1);
      expect(PourGuide(recipe, 120, 300).poursDone, true);
    },
  );
  test('grams and percentages scale consistently when changing dose', () {
    final percent = plan().scaled(15, 15);
    final grams = plan(
      unit: PourUnit.grams,
      steps: const [
        PourStep(start: 0, duration: 10, amount: 60),
        PourStep(start: 45, duration: 20, amount: 120),
        PourStep(start: 90, duration: 20, amount: 120),
      ],
    ).scaled(15, 15);
    expect(percent.plannedGrams, 225);
    expect(grams.steps[0].amount, 45);
    expect(grams.expectedGrams(55), percent.expectedGrams(55));
    expect(grams.steps[1].start, 45);
  });
  test(
    'reject incomplete totals, overlapping times, late first pour and invalid values',
    () {
      expect(
        plan(
          steps: const [PourStep(start: 0, duration: 10, amount: 99)],
        ).validate(),
        isNotNull,
      );
      expect(
        plan(
          steps: const [
            PourStep(start: 0, duration: 10, amount: 50),
            PourStep(start: 5, duration: 10, amount: 50),
          ],
        ).validate(),
        isNotNull,
      );
      expect(
        plan(
          steps: const [PourStep(start: 2, duration: 10, amount: 100)],
        ).validate(),
        isNotNull,
      );
      expect(
        plan(
          steps: [const PourStep(start: 0, duration: 0, amount: 100)],
        ).validate(),
        isNotNull,
      );
      expect(
        plan(
          steps: [PourStep(start: 0, duration: 10, amount: double.nan)],
        ).validate(),
        isNotNull,
      );
    },
  );
  test('record captures time/mass/flow, holds, and the final endpoint', () {
    var time = Duration.zero;
    final brew = BrewSession(now: () => time)
      ..start(rawGrams: 100, dose: 20, ratio: 15);
    brew.update(100.6, flowGramsPerSecond: 6);
    brew.update(101.2, flowGramsPerSecond: 6);
    time = const Duration(seconds: 5);
    brew.update(130, flowGramsPerSecond: 6);
    time = const Duration(seconds: 10);
    brew.update(160, flowGramsPerSecond: 6);
    time = const Duration(seconds: 20);
    brew.update(160, flowGramsPerSecond: 0);
    time = const Duration(seconds: 25);
    brew.finish();
    final recipe = brew.toRecipe('내 기록');
    expect(recipe.validate(), isNull);
    expect(recipe.trace.first.seconds, 0);
    expect(recipe.trace.last.seconds, 25);
    expect(recipe.trace.last.grams, 60);
    expect(recipe.trace[1].flow, 6);
    expect(recipe.steps.length, 1);
    expect(recipe.expectedGrams(15), 60);
    expect(recipe.scaled(10, 15).trace.last.grams, 30);
    time = const Duration(seconds: 50);
    expect(brew.seconds, 25);
  });
  test('infer distinct pours through a two-second pause', () {
    final steps = BrewRecipe.inferPours(const [
      BrewPoint(0, 0, 0),
      BrewPoint(1, 5, 5),
      BrewPoint(2, 10, 5),
      BrewPoint(3, 10, 0),
      BrewPoint(4, 10, 0),
      BrewPoint(5, 15, 5),
      BrewPoint(6, 20, 5),
    ]);
    expect(steps.length, 2);
    expect(steps.first.amount, 10);
    expect(steps.last.start, 4);
    expect(steps.last.amount, 10);
  });
  test(
    'library round-trips manual and recorded recipes across a new store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final recipe = plan();
      var now = Duration.zero;
      final brew = BrewSession(now: () => now)
        ..start(rawGrams: 0, dose: 20, ratio: 15);
      brew.update(1);
      brew.update(2);
      now = const Duration(seconds: 10);
      brew.update(60, flowGramsPerSecond: 6);
      brew.finish();
      await RecipeStore(prefs).save([recipe, brew.toRecipe('실제 기록')]);
      final library = RecipeStore(prefs).load();
      final loaded = library.first;
      expect(loaded.name, recipe.name);
      expect(loaded.expectedGrams(55), 120);
      expect(loaded.unit, PourUnit.percent);
      expect(library.last.trace.last.grams, 60);
      expect(library.last.trace.last.flow, 6);
      expect(library.last.duration, 10);
      await RecipeStore(prefs).save([]);
      expect(RecipeStore(prefs).load(), isEmpty);
    },
  );
  test('malformed storage is preserved before replacement', () async {
    SharedPreferences.setMockInitialValues({RecipeStore.key: '{broken'});
    final prefs = await SharedPreferences.getInstance();
    final store = RecipeStore(prefs);
    expect(store.load, throwsFormatException);
    await store.save([plan()]);
    final backups = prefs.getKeys().where((key) => key.contains('.backup.'));
    expect(backups.length, 1);
    expect(prefs.getString(backups.single), '{broken');
    expect(jsonDecode(prefs.getString(RecipeStore.key)!)['version'], 1);
  });
  test('long records are bounded while preserving origin and end', () {
    var time = Duration.zero;
    final brew = BrewSession(now: () => time)
      ..start(rawGrams: 0, dose: 20, ratio: 15);
    brew.update(1);
    brew.update(2);
    for (var i = 1; i <= 5000; i++) {
      time = Duration(milliseconds: i * 250);
      brew.update(2 + i / 100);
    }
    brew.finish();
    expect(brew.points.length, lessThanOrEqualTo(2400));
    expect(brew.points.first.seconds, 0);
    expect(brew.points.last.seconds, 1250);
    expect(brew.points.last.grams, 52);
  });
}
