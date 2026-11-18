import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets('phone-sized demo holds its chart on lift and keeps overshoot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'app.language': 'ko',
      'scale.model': 'timemore-dot',
    });
    final preferences = await SharedPreferences.getInstance();
    var now = Duration.zero;
    final brew = BrewSession(now: () => now);
    final controller = BrewController(preferences, session: brew);
    Future<void> pumpTicks(int count) async {
      for (var i = 0; i < count; i++) {
        now += const Duration(milliseconds: 100);
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      DotPourApp(preferences: preferences, controller: controller),
    );
    await tester.tap(find.text('Pour over'));
    await tester.pump();
    final demo = find.text('저울 없이 데모로 체험');
    await tester.scrollUntilVisible(
      demo,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(demo);
    await tester.pump();
    controller.setDose(20);
    await tester.pump();
    final start = find.text('추출 시작');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(160);
    await pumpTicks(42);
    expect(find.text('50.0 %', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('brew-progress')),
          )
          .value,
      .5,
    );
    final headerTop = tester.getTopLeft(find.byKey(const Key('brew-header')));
    await tester.drag(
      find.byKey(const Key('brew-scroll')),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('brew-header'))), headerTop);
    await tester.ensureVisible(find.text('기구 들기'));
    await tester.tap(find.text('기구 들기'));
    final liftedAt = brew.seconds;
    await pumpTicks(10);
    expect(find.byKey(const Key('weight-hold-indicator')), findsOneWidget);
    expect(find.text('무게 안정 대기 · 기록 유지'), findsNothing);
    expect(brew.water, 160);
    expect(brew.points.last.seconds, greaterThan(liftedAt));
    expect(brew.points.last.grams, 160);
    await tester.tap(find.text('기구 놓기'));
    await pumpTicks(4);
    expect(brew.holdingMeasurement, false);
    expect(find.byKey(const Key('weight-hold-indicator')), findsNothing);
    expect(brew.water, 160);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(352);
    await pumpTicks(50);
    expect(find.text('110.0 %', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('brew-progress')),
          )
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'APK configuration hides demo and inline ratio protects brew start',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'app.language': 'ko',
        'scale.model': 'test',
      });
      final prefs = await SharedPreferences.getInstance();
      final scale = FakeScale('test', supportsTare: true)..emit(20);
      final controller = BrewController(
        prefs,
        allowDemo: false,
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      await controller.toggleDemo();
      expect(controller.demo, false);
      await tester.pumpWidget(
        DotPourApp(preferences: prefs, controller: controller),
      );
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      controller.setDose(20);
      await tester.pump();
      expect(find.text('저울 없이 데모로 체험'), findsNothing);
      final input = find.byKey(const Key('ratio-input'));
      final start = find.ancestor(
        of: find.text('추출 시작'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding();
      await tester.ensureVisible(input);
      await tester.enterText(input, '31');
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(input).dy, lessThanOrEqualTo(780 - 300));
      expect(find.text('비율은 1:1~1:30으로 입력해 주세요.'), findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(controller.brew.ratio, 16);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '16');

      await tester.enterText(input, '17');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(controller.brew.ratio, 17);
      expect(prefs.getDouble('ratio'), 17);
      await tester.tap(find.text('추출 시작'));
      await tester.pumpAndSettle();
      expect(controller.brew.target, 340);
      expect(input, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
