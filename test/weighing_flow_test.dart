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
      void settleWeight(double grams) {
        scale.emit(grams);
        scale.lastReading = scale.lastReading!.add(
          const Duration(milliseconds: 1500),
        );
        scale.emit(grams);
      }

      settleWeight(380);
      await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
      expect(find.text('380.0 g'), findsOneWidget);
      final illustration = find.byKey(const Key('setup-illustration'));
      expect(
        tester.widget<Image>(illustration).semanticLabel,
        '저울 위에 놓인 서버와 드리퍼',
      );
      expect(c.canStart, false);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(find.text('0.0 g'), findsOneWidget);
      expect(c.canStart, false);
      expect(find.text('원두를 담아 무게를 확인해 주세요.'), findsOneWidget);
      expect(tester.widget<Image>(illustration).semanticLabel, '커피 원두');
      scale.emit(18);
      c.setDose(18);
      await tester.pump();
      await tester.tap(find.text('처음부터'));
      await tester.pump();
      expect(scale.tares, 2, reason: 'Restart must actually zero the scale');
      expect(c.currentGrams, 0);
      expect(c.confirmedDose, isNull);
      expect(find.text('서버와 드리퍼를 올리고\nTARE를 눌러 주세요.'), findsOneWidget);
      expect(
        tester.widget<Image>(illustration).semanticLabel,
        '저울 위에 놓인 서버와 드리퍼',
      );
      scale.emit(-398);
      await tester.pump(const Duration(seconds: 1));
      expect(scale.tares, 2, reason: 'Lifting equipment must not auto-tare');
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(c.currentGrams, 0);
      expect(c.isDoseTared, false);
      expect(c.canStart, false);
      expect(
        tester.widget<Image>(illustration).semanticLabel,
        '저울 위에 놓인 서버와 드리퍼',
      );
      expect(find.byKey(const Key('enter-dose-weighing')), findsOneWidget);
      settleWeight(380);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(find.text('원두를 담아 무게를 확인해 주세요.'), findsOneWidget);
      scale.emit(18.5);
      await tester.pump();
      expect(find.text('18.5 g'), findsOneWidget);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(scale.tares, 5);
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
      await c.restartDoseSetup();
      expect(
        scale.tares,
        5,
        reason: 'Tare and restart cannot erase an active pour',
      );
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
    expect(find.text('0.0 g'), findsOneWidget);
    expect(c.canStart, false);
    final from = DateTime.now().subtract(const Duration(milliseconds: 1750));
    void send(double grams, int offset) {
      scale.lastReading = from.add(Duration(milliseconds: offset));
      scale.emit(grams);
    }

    send(300, 0);
    send(300, 1500);
    expect(c.hasSetupWeight, true);
    await tester.pump();
    expect(find.text('세팅 안정'), findsNothing);
    expect(tester.widget(find.byKey(const Key('tare'))), isA<FilledButton>());
    send(318.4, 1600);
    send(318.4, 2400);
    await tester.pump();
    expect(find.text('원두를 담으셨나요? 18.4g 늘었어요.'), findsOneWidget);
    expect(c.canStart, false);
    await tester.tap(find.byKey(const Key('apply-suggested-dose')));
    await tester.pump();
    expect(
      tester
          .widget<Image>(find.byKey(const Key('setup-illustration')))
          .semanticLabel,
      '커피 원두',
    );
    expect(c.canStart, true);
    expect(find.text('원두 18.4g · 1:16 · 물 294.4g'), findsOneWidget);
    await tester.tap(find.text('추출 시작'));
    await tester.pump();
    expect(c.brew.dose, 18.4);
    expect(c.brew.water, 0);
    expect(scale.tares, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dose suggestions return after restarting setup and after tare', (
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
    scale.emit(18);
    c.setDose(18);
    await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
    var at = DateTime.now();
    void send(double grams, int elapsed) {
      at = at.add(Duration(milliseconds: elapsed));
      scale.lastReading = at;
      scale.emit(grams);
    }

    for (final tareAgain in [false, true]) {
      await tester.tap(find.byKey(const Key('restart-scale-setup')));
      await tester.pump();
      send(18, 100);
      expect(c.canStart, false, reason: 'Restart must not reuse an old dose');
      if (tareAgain) {
        await tester.tap(find.byKey(const Key('tare')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('enter-dose-weighing')));
        await tester.pump();
        expect(c.isDoseTared, true);
      }
      send(70, 100);
      send(70, 1500);
      send(88, 100);
      send(88, 800);
      await tester.pump();
      expect(find.text('세팅 안정'), findsNothing);
      expect(find.text('원두를 담으셨나요? 18g 늘었어요.'), findsOneWidget);
      expect(c.canStart, false, reason: 'An inferred dose needs confirmation');
      await tester.tap(find.byKey(const Key('apply-suggested-dose')));
      await tester.pump();
      expect(c.setupDose, 18);
      expect(c.canStart, true);
      send(90, 100);
      send(90, 800);
      await tester.pump();
      expect(c.setupDose, 18, reason: 'Keep the dose the user confirmed');
      expect(find.byKey(const Key('apply-suggested-dose')), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'zeroed equipment can enter weighing explicitly; zero noise does not reset it',
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
        allowDemo: false,
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      scale.emit(300);
      await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
      await tester.tap(find.text('처음부터'));
      await tester.pump();
      expect(c.currentGrams, 0);
      expect(c.isDoseTared, false);
      expect(c.canStart, false);
      expect(find.text('원두량을 확인해 주세요'), findsOneWidget);

      scale.emit(-.2);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(
        c.isDoseTared,
        false,
        reason: 'Repeated zeroing must not assume equipment is present',
      );
      await tester.tap(find.text('원두 계량으로'));
      await tester.pump();
      expect(c.isDoseTared, true);
      expect(
        scale.tares,
        2,
        reason: 'Explicit phase selection does not tare again',
      );
      expect(c.canStart, false);
      scale.emit(-.2);
      await tester.tap(find.byKey(const Key('tare')));
      await tester.pump();
      expect(
        c.isDoseTared,
        true,
        reason: 'Small zero noise is not equipment removal',
      );
      scale.emit(18);
      await tester.pump();
      expect(c.canStart, true);
      final conditions = find.descendant(
        of: find.byKey(const Key('start-brew')),
        matching: find.text('원두 18g · 1:16 · 물 288g'),
      );
      expect(conditions, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'failed restart preserves the current dose and does not claim a new zero',
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
      scale.emit(318);
      c.setDose(18);
      await c.restartDoseSetup();
      expect(scale.tares, 1);
      expect(c.currentGrams, 318);
      expect(c.confirmedDose, 18);
      expect(c.canEnterDoseWeighing, false);
      expect(c.taring, false);
      expect(c.notice, contains('영점을 확인하지 못했습니다'));
    },
  );

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
      expect(find.text('원두 18g · 1:16 · 물 288g'), findsOneWidget);
      expect(
        tester
            .widget<Image>(find.byKey(const Key('setup-illustration')))
            .semanticLabel,
        '커피 원두',
      );
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
