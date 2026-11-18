import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:dot_pour/ui/brew_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets(
    'mode and bottom navigation preserve preparation and active brew',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'app.language': 'ko',
        'scale.model': 'test',
      });
      final prefs = await SharedPreferences.getInstance();
      final scale = FakeScale('test', supportsTare: true)..emit(18);
      var now = Duration.zero;
      final controller = BrewController(
        prefs,
        session: BrewSession(now: () => now),
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      await tester.pumpWidget(
        DotPourApp(preferences: prefs, controller: controller),
      );
      expect(find.byKey(const Key('basic-scale')), findsOneWidget);
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      expect(find.byKey(const Key('weighing-panel')), findsOneWidget);
      controller.setDose(18);
      await tester.tap(find.text('Espresso'));
      await tester.pumpAndSettle();
      expect(find.text('준비 중'), findsOneWidget);
      expect(find.text('추출 시작'), findsNothing);
      await tester.tap(find.text('Pour over'));
      await tester.pumpAndSettle();
      expect(controller.confirmedDose, 18);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      now += const Duration(milliseconds: 100);
      scale.emit(1);
      now += const Duration(milliseconds: 100);
      scale.emit(2);
      now += const Duration(milliseconds: 100);
      scale.emit(3);
      await tester.pump();
      await tester.tap(find.text('레시피'));
      await tester.pumpAndSettle();
      expect(find.text('내 레시피'), findsOneWidget);
      now += const Duration(milliseconds: 100);
      scale.emit(4);
      await tester.tap(find.text('브루잉'));
      await tester.pumpAndSettle();
      expect(controller.brew.phase, BrewPhase.pouring);
      expect(controller.brew.water, 3);
      expect(find.byKey(const Key('brew-elapsed')), findsOneWidget);
      expect(find.text('추출 시간'), findsNothing);
      expect(find.text('Pour over'), findsNothing);
      expect(find.text('Espresso'), findsNothing);
      expect(
        tester.getBottomRight(find.byType(BrewChart)).dy,
        lessThan(tester.getTopLeft(find.text('추출 마치기')).dy),
      );
      controller.finish();
      controller.reset();
      await tester.pump();
      expect(find.text('Pour over'), findsOneWidget);
      expect(find.text('TARE'), findsNothing);
      expect(find.byKey(const Key('dose-step-beans')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('physical readings paint on the next frame during brewing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'app.language': 'ko',
      'scale.model': 'test',
    });
    final prefs = await SharedPreferences.getInstance();
    final scale = FakeScale('test', supportsTare: true);
    var now = Duration.zero;
    final c = BrewController(
      prefs,
      session: BrewSession(now: () => now),
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
    scale.emit(20);
    await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
    await tester.tap(find.text('Pour over'));
    await tester.pump();
    c.setDose(20);
    await c.start();
    await tester.pump();
    for (var g = 1.0; g <= 20; g++) {
      now += const Duration(milliseconds: 100);
      scale.emit(g);
      await tester.pump(); // No timer time elapses before this frame.
      if (g > 1) {
        expect(c.brew.water, g - 1);
        expect(
          find.text('${(g - 1).toStringAsFixed(1)} g', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('목표\n320 g'), findsOneWidget);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('connected scale battery stays visible on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PackageInfo.setMockInitialValues(
      appName: 'Dot Pour',
      packageName: 'dev.dotpour.dot_pour',
      version: '0.4.4',
      buildNumber: '9',
      buildSignature: 'test',
    );
    SharedPreferences.setMockInitialValues({
      'app.language': 'ko',
      'scale.model': 'test',
    });
    final prefs = await SharedPreferences.getInstance();
    final scale = FakeScale('test')..battery = 80;
    final c = BrewController(
      prefs,
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
    scale.emit(20);
    await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
    final battery = find.byKey(const Key('scale-battery'));
    expect(tester.widget<Text>(battery).data, '80%');
    expect(find.byType(BottomSheet), findsNothing);
    scale.battery = 71;
    scale.emit(20.1);
    await tester.pump();
    expect(tester.widget<Text>(battery).data, '71%');
    await tester.tap(find.text('연결됨'));
    await tester.pumpAndSettle();
    expect(find.text('Dot Pour 0.4.4+9'), findsOneWidget);
    expect(find.text('반응속도 진단'), findsNothing);
    await tester.tap(find.text('연결 해제'));
    await tester.pumpAndSettle();
    expect(battery, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
