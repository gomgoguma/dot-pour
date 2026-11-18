import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/recipe.dart';
import 'package:dot_pour/recipe_store.dart';
import 'package:dot_pour/ui/recipe_editor.dart';
import 'package:dot_pour/ui/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'finish keeps the result until explicitly saved, then allows replay',
    (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({
        'app.language': 'ko',
        'scale.model': 'timemore-dot',
      });
      final prefs = await SharedPreferences.getInstance();
      var now = Duration.zero;
      final brew = BrewSession(now: () => now);
      final controller = BrewController(prefs, session: brew)..demo = true;
      controller.setDose(20);
      await tester.pumpWidget(
        DotPourApp(preferences: prefs, controller: controller),
      );
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      await tester.tap(find.text('추출 시작'));
      brew.update(1);
      brew.update(2);
      for (var t = 1; t <= 10; t++) {
        now = Duration(seconds: t);
        brew.update(t * 6, flowGramsPerSecond: 6);
      }
      controller.demoWeight = 60;
      await tester.pump();
      await tester.tap(find.text('추출 마치기'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(brew.phase, BrewPhase.finished);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('새 추출'), findsOneWidget);
      expect(RecipeStore(prefs).load(), isEmpty);
      await tester.tap(find.text('레시피로 저장'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('레시피 저장'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AlertDialog), findsNothing);
      expect(brew.water, 60);
      expect(controller.canSave, true);
      await tester.tap(find.text('레시피로 저장'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('레시피 저장'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('save-recipe-name')),
        '테스트 한 잔',
      );
      await tester.enterText(
        find.byKey(const Key('save-recipe-beans')),
        '에티오피아 예가체프',
      );
      await tester.enterText(
        find.byKey(const Key('save-recipe-memo')),
        '93도, 분쇄도 24. 달콤한 여운.',
      );
      await tester.ensureVisible(find.byKey(const Key('rating-acidity-4')));
      await tester.tap(find.byKey(const Key('rating-acidity-4')));
      await tester.ensureVisible(find.byKey(const Key('rating-sweetness-5')));
      await tester.tap(find.byKey(const Key('rating-sweetness-5')));
      await tester.ensureVisible(find.byKey(const Key('rating-body-3')));
      await tester.tap(find.byKey(const Key('rating-body-3')));
      await tester.tap(find.text('저장', skipOffstage: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(RecipeStore(prefs).load().single.trace.last.grams, 60);
      expect(RecipeStore(prefs).load().single.isDemo, true);
      final notes = RecipeStore(prefs).load().single.notes;
      expect(notes.beans, '에티오피아 예가체프');
      expect(notes.memo, '93도, 분쇄도 24. 달콤한 여운.');
      expect([notes.acidity, notes.sweetness, notes.body], [4, 5, 3]);
      expect(find.text('저장 완료'), findsOneWidget);
      await tester.tap(find.text('새 추출'));
      await tester.pump();
      await tester.tap(find.text('레시피'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 한 잔'));
      await tester.pumpAndSettle();
      expect(find.text('에티오피아 예가체프'), findsOneWidget);
      expect(find.text('93도, 분쇄도 24. 달콤한 여운.'), findsOneWidget);
      await tester.tap(find.text('이 레시피로 추출'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.reference?.name, '테스트 한 잔');
      expect(find.byKey(const Key('weighing-panel')), findsOneWidget);
      expect(controller.brew.phase, BrewPhase.setup);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'manual editor converts percent to grams and rejects wrong totals',
    (tester) async {
      phone(tester);
      BrewRecipe? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: pourTheme(),
          home: RecipeEditor(
            dose: 20,
            ratio: 15,
            onSave: (recipe) async {
              saved = recipe;
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('recipe-name')), '3번 붓기');
      final addPour = find.text('붓기 차수 추가');
      await tester.ensureVisible(addPour);
      await tester.tap(addPour);
      await tester.pump();
      expect(find.text('붓기 계획 · 4차'), findsOneWidget);
      final removePour = find.byTooltip('4차 삭제');
      await tester.ensureVisible(removePour);
      await tester.tap(removePour);
      await tester.pump();
      expect(find.text('붓기 계획 · 3차'), findsOneWidget);
      final gramMode = find.text('질량 · g');
      await tester.ensureVisible(gramMode);
      await tester.tap(gramMode);
      await tester.pump();
      final amounts = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '추가 · g',
      );
      expect(amounts, findsNWidgets(3));
      expect(tester.widget<TextField>(amounts.at(0)).controller!.text, '60');
      await tester.ensureVisible(amounts.at(0));
      await tester.enterText(amounts.at(0), '50');
      await tester.tap(find.text('레시피 저장'));
      await tester.pump();
      expect(saved, isNull);
      expect(find.text('차수별 물의 무게 합계를 목표와 맞춰 주세요.'), findsOneWidget);
      await tester.enterText(amounts.at(0), '60');
      await tester.tap(find.text('레시피 저장'));
      await tester.pump();
      expect(saved?.plannedGrams, 300);
      expect(saved?.steps.length, 3);
      expect(saved?.unit, PourUnit.grams);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home ratio is editable and updates the target on a narrow phone',
    (tester) async {
      phone(tester, width: 320);
      SharedPreferences.setMockInitialValues({
        'app.language': 'ko',
        'scale.model': 'timemore-dot',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = BrewController(prefs)..demo = true;
      controller.setDose(20);
      await tester.pumpWidget(
        DotPourApp(preferences: prefs, controller: controller),
      );
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      final input = find.byKey(const Key('ratio-input'));
      expect(tester.widget<TextField>(input).controller!.text, '16');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('dose-input')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('increase-ratio')));
      await tester.tap(find.byKey(const Key('increase-ratio')));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '16.5');
      expect(find.text('원두 20g · 1:16.5 · 물 330g'), findsOneWidget);
      await tester.tap(find.byKey(const Key('decrease-ratio')));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '16');

      final icePreset = find.byKey(const Key('ratio-preset-10'));
      await tester.ensureVisible(icePreset);
      await tester.tap(icePreset);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '10');
      expect(find.text('원두 20g · 1:10 · 물 200g'), findsOneWidget);
      expect(prefs.getDouble('ratio'), 10);

      final preset = find.byKey(const Key('ratio-preset-17'));
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '17');
      expect(controller.brew.ratio, 17);
      expect(find.text('원두 20g · 1:17 · 물 340g'), findsOneWidget);
      expect(prefs.getDouble('ratio'), 17);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(input, '16.7');
      await tester.pump();
      expect(find.text('원두 20g · 1:16.7 · 물 334g'), findsOneWidget);
      expect(prefs.getDouble('ratio'), 16.7);
      expect(prefs.getDouble('dose'), isNull);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
