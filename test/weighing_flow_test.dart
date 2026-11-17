import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

Future<({BrewController c, FakeScale scale})> openPour(
  WidgetTester tester, {
  double grams = 380,
  double width = 390,
  double ratio = 16.7,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'scale.model': 'test',
    'ratio': ratio,
  });
  final prefs = await SharedPreferences.getInstance();
  final scale = FakeScale('test', supportsTare: true);
  final c = BrewController(
    prefs,
    allowDemo: false,
    scaleRegistry: ScaleRegistry([ScaleRegistration(scale.info, () => scale)]),
  );
  scale.emit(grams);
  await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
  expect(find.byKey(const Key('basic-scale')), findsOneWidget);
  await tester.tap(find.text('Pour over'));
  await tester.pump();
  return (c: c, scale: scale);
}

void main() {
  testWidgets(
    'explicit steps measure the added beans without taring the equipment',
    (tester) async {
      final (:c, :scale) = await openPour(tester);
      expect(find.text('380.0 g'), findsOneWidget);
      expect(c.canStart, false);
      await tester.tap(find.byKey(const Key('enter-dose-weighing')));
      await tester.pump();
      expect(scale.tares, 0);
      expect(c.isDoseWeighing, true);
      expect(c.setupDose, 0);
      expect(find.text('저울 전체 380.0 g'), findsOneWidget);
      final image = find.byKey(const Key('setup-illustration'));
      expect(tester.widget<Image>(image).semanticLabel, '커피 원두');
      scale.emit(398.5);
      await tester.pump();
      expect(find.text('18.5 g'), findsOneWidget);
      expect(find.text('저울 전체 398.5 g'), findsOneWidget);
      expect(c.setupDose, 18.5);
      expect(c.canStart, true);
      expect(find.byKey(const Key('tare')), findsNothing);
      expect(find.byKey(const Key('manual-dose')), findsOneWidget);
      expect(find.text('직접 입력'), findsNothing);
      await tester.tap(find.byKey(const Key('manual-dose')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('manual-dose-field')))
            .initialValue,
        '18.5',
      );
      await tester.enterText(find.byKey(const Key('manual-dose-field')), '20');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(c.setupDose, 18.5);
      expect(scale.tares, 0);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(scale.tares, 1);
      expect(c.brew.dose, 18.5);
      expect(c.brew.target, closeTo(308.95, .001));
      expect(c.brew.phase, BrewPhase.ready);
      expect(c.brew.water, 0);
      for (var grams = 4.0; grams <= 40; grams += 4) {
        scale.emit(grams);
      }
      scale.emit(40);
      await tester.pump();
      expect(c.brew.water, 40);
      await c.tare();
      c.returnToEquipment();
      expect(
        scale.tares,
        1,
        reason: 'Active brewing cannot be tared or moved to preparation',
      );
      expect(c.brew.active, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tare only zeroes the scale and preserves both the stage and bean difference',
    (tester) async {
      final (:c, :scale) = await openPour(tester, width: 320, ratio: 15);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(c.currentGrams, 0);
      expect(c.isDoseWeighing, false);
      expect(c.canStart, false);
      scale.emit(-380);
      await c.tare();
      await tester.pump();
      expect(c.isDoseWeighing, false);
      scale.emit(300);
      await tester.tap(find.byKey(const Key('dose-step-beans')));
      await tester.pump();
      scale.emit(318);
      await tester.pump();
      expect(c.setupDose, 18);
      await tester.tap(find.byKey(const Key('home-mode-scale')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('basic-scale-tare')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('home-mode-pourOver')));
      await tester.pump();
      expect(c.isDoseWeighing, true);
      expect(c.currentGrams, 0);
      expect(c.setupDose, 18);
      expect(find.text('18.0 g'), findsOneWidget);
      expect(find.text('저울 전체 0.0 g'), findsOneWidget);
      scale.emit(2);
      await tester.pump();
      expect(c.setupDose, 20);
      expect(find.text('원두 20g · 1:15 · 물 300g'), findsOneWidget);
      final tares = scale.tares;
      await tester.tap(find.byKey(const Key('dose-step-equipment')));
      await tester.pump();
      expect(c.isDoseWeighing, false);
      expect(c.setupDose, isNull);
      expect(c.currentGrams, 2);
      expect(scale.tares, tares, reason: 'Step navigation never sends tare');
      await tester.tap(find.byKey(const Key('enter-dose-weighing')));
      await tester.pump();
      scale.emit(20);
      await tester.pump();
      expect(
        c.setupDose,
        18,
        reason: 'The new step takes the current value as its baseline',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'automatic additions remain suggestions until explicitly accepted, including repeated setups',
    (tester) async {
      final (:c, :scale) = await openPour(tester, grams: 300, ratio: 16);
      var at = DateTime.now();
      void send(double grams, int elapsed) {
        at = at.add(Duration(milliseconds: elapsed));
        scale.lastReading = at;
        scale.emit(grams);
      }

      for (var cycle = 0; cycle < 2; cycle++) {
        send(300, 100);
        send(300, 1500);
        send(318.4, 100);
        send(318.4, 800);
        await tester.pump();
        expect(find.text('원두를 담으셨나요? 18.4g 늘었어요.'), findsOneWidget);
        expect(c.isDoseWeighing, false);
        expect(c.canStart, false);
        await tester.tap(find.byKey(const Key('apply-suggested-dose')));
        await tester.pump();
        expect(c.isDoseWeighing, true);
        expect(c.setupDose, 18.4);
        expect(find.text('원두 18.4g · 1:16 · 물 294.4g'), findsOneWidget);
        send(320, 100);
        await tester.pump();
        expect(
          c.setupDose,
          18.4,
          reason: 'Explicit dose is not overwritten by later readings',
        );
        await tester.tap(find.byKey(const Key('dose-step-equipment')));
        await tester.pump();
      }
      expect(scale.tares, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'manual dose is separate from total weight and starts with the confirmed amount',
    (tester) async {
      final (:c, :scale) = await openPour(
        tester,
        grams: 418,
        width: 320,
        ratio: 16,
      );
      await tester.tap(find.byKey(const Key('manual-dose')));
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('manual-dose-field'));
      await tester.enterText(input, '0');
      await tester.tap(find.text('원두량 적용'));
      await tester.pumpAndSettle();
      expect(find.text('원두량은 0.1~100g으로 입력해 주세요.'), findsOneWidget);
      await tester.enterText(input, '18');
      await tester.tap(find.text('원두량 적용'));
      await tester.pumpAndSettle();
      expect(c.isDoseWeighing, true);
      expect(find.text('18.0 g'), findsOneWidget);
      expect(find.text('저울 전체 418.0 g'), findsOneWidget);
      expect(find.text('원두 18g · 1:16 · 물 288g'), findsOneWidget);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(c.brew.dose, 18);
      expect(c.brew.target, 288);
      scale.emit(-300);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('brew-live-weight'))).data,
        '저울 -300.0 g',
      );
      expect(c.brew.water, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed tare keeps the preparation baseline and never changes stage',
    (tester) async {
      final (:c, :scale) = await openPour(tester, grams: 300);
      c.enterDoseWeighing();
      scale.emit(318);
      scale.tareFails = true;
      await c.tare();
      expect(c.currentGrams, 318);
      expect(c.setupDose, 18);
      expect(c.isDoseWeighing, true);
      expect(c.taring, false);
      expect(c.notice, contains('영점을 확인하지 못했습니다'));
      await c.start();
      expect(c.brew.phase, BrewPhase.setup);
      expect(c.notice, contains('시작하지 않았습니다'));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reconnection does not reuse a possibly changed equipment baseline',
    (tester) async {
      final (:c, :scale) = await openPour(tester, grams: 300);
      c.enterDoseWeighing();
      scale.emit(318);
      expect(c.setupDose, 18);
      await scale.disconnect();
      scale.emit(18);
      expect(c.setupDose, isNull);
      expect(c.canStart, false);
      c.returnToEquipment();
      c.enterDoseWeighing();
      scale.emit(36);
      expect(c.setupDose, 18);
      expect(c.canStart, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
