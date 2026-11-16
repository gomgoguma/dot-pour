import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:dot_pour/ui/scale_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets('physical readings paint on the next frame during brewing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'scale.model': 'test'});
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
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('diagnostics stay off until requested and fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
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
    SharedPreferences.setMockInitialValues({'scale.model': 'test'});
    final prefs = await SharedPreferences.getInstance();
    final scale = FakeScale('test')..battery = 80;
    final c = BrewController(
      prefs,
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
    scale.emit(20);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ScaleStatusSheet(controller: c))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dot Pour 0.4.4+9'), findsOneWidget);
    expect(c.diagnostics.recording, false);
    await tester.tap(find.text('반응속도 진단'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 진단 기록 시작'));
    await tester.pump();
    scale.emit(21);
    await tester.pump();
    expect(c.diagnostics.recording, true);
    expect(find.text('21g'), findsOneWidget);
    await tester.tap(find.text('기록 중지'));
    await tester.pump();
    expect(c.diagnostics.recording, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
