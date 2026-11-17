import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets(
    'tare vessel, weigh beans, start zeroes and derives dose and target',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'scale.model': 'test',
        'ratio': 16.7,
      });
      final prefs = await SharedPreferences.getInstance();
      final scale = FakeScale('test', supportsTare: true);
      final c = BrewController(
        prefs,
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      scale.emit(380);
      await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
      expect(find.text('380.0 g'), findsOneWidget);
      expect(c.canStart, false);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(find.text('0.0 g'), findsOneWidget);
      expect(c.canStart, false);
      expect(find.text('원두를 담아 무게를 확인해 주세요.'), findsOneWidget);
      scale.emit(-380);
      await tester.pump();
      await tester.tap(find.byKey(const Key('restart-scale-setup')));
      await tester.pump();
      expect(find.text('서버와 드리퍼를 올리고\nTARE를 눌러 주세요.'), findsOneWidget);
      scale.emit(18);
      expect(c.canStart, false, reason: 'The former tare zero is now stale');
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(find.text('원두를 담아 무게를 확인해 주세요.'), findsOneWidget);
      scale.emit(18.5);
      await tester.pump();
      expect(find.text('18.5 g'), findsOneWidget);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(scale.tares, 3);
      expect(c.brew.dose, 18.5);
      expect(c.brew.target, closeTo(308.95, .001));
      expect(c.brew.water, 0);
      expect(c.brew.phase, BrewPhase.ready);
      expect(find.byKey(const Key('weighing-panel')), findsNothing);
      for (var grams = 4.0; grams <= 40; grams += 4) {
        scale.emit(grams);
      }
      scale.emit(40); // One following notification validates the final weight.
      await tester.pump();
      expect(c.brew.water, 40);
      await c.tare();
      expect(scale.tares, 3, reason: 'Tare cannot erase an active pour');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a stable addition needs confirmation before the brew starts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'scale.model': 'test'});
    final prefs = await SharedPreferences.getInstance();
    final scale = FakeScale('test', supportsTare: true);
    final c = BrewController(
      prefs,
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
    await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
    final from = DateTime.now().subtract(const Duration(milliseconds: 1750));
    void send(double grams, int offset) {
      scale.lastReading = from.add(Duration(milliseconds: offset));
      scale.emit(grams);
    }

    send(300, 0);
    send(300, 1500);
    expect(c.hasSetupWeight, true);
    await tester.pump();
    expect(find.text('세팅 안정'), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('tare'))), isA<FilledButton>());
    send(318.4, 1600);
    send(318.4, 2400);
    await tester.pump();
    expect(find.text('원두를 담으셨나요? 18.4g 늘었어요.'), findsOneWidget);
    expect(c.canStart, false);
    await tester.tap(find.byKey(const Key('apply-suggested-dose')));
    await tester.pump();
    expect(c.canStart, true);
    expect(find.text('원두 18.4g · 목표 물 294.4g'), findsOneWidget);
    await tester.tap(find.text('추출 시작'));
    await tester.pump();
    expect(c.brew.dose, 18.4);
    expect(c.brew.water, 0);
    expect(scale.tares, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'manual dose uses the tare baseline and shows live scale weight',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'scale.model': 'test'});
      final prefs = await SharedPreferences.getInstance();
      final scale = FakeScale('test', supportsTare: true);
      final c = BrewController(
        prefs,
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      scale.emit(418);
      await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
      expect(c.canStart, false);
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
      expect(find.text('원두 18g · 목표 물 288g'), findsOneWidget);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(c.brew.dose, 18);
      expect(c.brew.target, 288);
      expect(c.brew.water, 0);
      final liveWeight = find.byKey(const Key('brew-live-weight'));
      expect(tester.widget<Text>(liveWeight).data, '저울 0.0 g');
      scale.emit(-300);
      await tester.pump();
      expect(tester.widget<Text>(liveWeight).data, '저울 -300.0 g');
      expect(c.brew.water, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'failed automatic tare preserves setup and does not start recording',
    () async {
      SharedPreferences.setMockInitialValues({'scale.model': 'test'});
      final scale = FakeScale('test', supportsTare: true)..tareFails = true;
      final c = BrewController(
        await SharedPreferences.getInstance(),
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      addTearDown(c.dispose);
      scale.emit(20);
      await c.start();
      expect(c.brew.phase, BrewPhase.setup);
      expect(c.starting, false);
      expect(c.notice, contains('시작하지 않았습니다'));
    },
  );
}
