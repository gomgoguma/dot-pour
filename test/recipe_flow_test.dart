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
  testWidgets('finish saves actual trace and library loads it for replay', (
    tester,
  ) async {
    phone(tester);
    SharedPreferences.setMockInitialValues({'scale.model': 'timemore-dot'});
    final prefs = await SharedPreferences.getInstance();
    var now = Duration.zero;
    final brew = BrewSession(now: () => now);
    final controller = BrewController(prefs, session: brew)..demo = true;
    await tester.pumpWidget(
      DotPourApp(preferences: prefs, controller: controller),
    );
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
    expect(find.text('레시피 저장'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('save-recipe-name')),
      '테스트 한 잔',
    );
    await tester.tap(find.text('저장', skipOffstage: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(RecipeStore(prefs).load().single.trace.last.grams, 60);
    expect(RecipeStore(prefs).load().single.isDemo, true);
    expect(find.text('저장 완료'), findsOneWidget);
    await tester.tap(find.text('새 추출'));
    await tester.pump();
    await tester.tap(find.byTooltip('내 레시피'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트 한 잔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 레시피로 추출'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.reference?.name, '테스트 한 잔');
    expect(find.byKey(const Key('weighing-panel')), findsOneWidget);
    expect(controller.brew.phase, BrewPhase.setup);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
    'compact settings on a narrow phone use exactly the requested presets',
    (tester) async {
      phone(tester, width: 320);
      SharedPreferences.setMockInitialValues({'scale.model': 'timemore-dot'});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(DotPourApp(preferences: prefs));
      expect(find.text('남은 물'), findsNothing);
      expect(find.byKey(const Key('dose-input')), findsNothing);
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      for (final ratio in ['1:9', '1:10', '1:11', '1:15', '1:16.7', '1:17']) {
        expect(find.text(ratio), findsOneWidget);
      }
      expect(find.byKey(const Key('dose-input')), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.ensureVisible(find.text('1:16.7'));
      await tester.tap(find.text('1:16.7'));
      await tester.ensureVisible(find.text('설정 완료'));
      await tester.tap(find.text('설정 완료'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(prefs.getDouble('ratio'), 16.7);
      expect(prefs.getDouble('dose'), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
