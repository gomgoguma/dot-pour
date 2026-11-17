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
    'first launch chooses Dot; restart skips selection; change remains available',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'dose': 18.0, 'ratio': 16.7});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(DotPourApp(preferences: prefs));
      expect(find.text('저울 모델 선택'), findsOneWidget);
      expect(find.text('Black Mirror Dot'), findsOneWidget);
      expect(ScaleRegistry.standard().models.length, 1);
      expect(prefs.getString(BrewController.selectedScaleKey), isNull);
      await tester.tap(find.text('이 저울로 시작'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('basic-scale')), findsOneWidget);
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      expect(prefs.getString(BrewController.selectedScaleKey), 'timemore-dot');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ratio-input')))
            .controller!
            .text,
        '16.7',
      );
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-scale')));
      await tester.pumpAndSettle();
      expect(find.text('저울 선택'), findsOneWidget);
      await tester.tap(find.text('이 저울 사용'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(DotPourApp(preferences: prefs));
      expect(find.text('저울 모델 선택'), findsNothing);
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('change-scale')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'unknown saved model requires a new choice without clearing settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'scale.model': 'unsupported',
        'dose': 18.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final c = BrewController(prefs);
      addTearDown(c.dispose);
      expect(c.scale, isNull);
      expect(c.usable, false);
      expect(c.brew.dose, 18);
      await c.selectScale('timemore-dot');
      expect(c.scale?.info.id, 'timemore-dot');
      expect(c.brew.dose, 18);
      expect(c.scale?.connected, false);
      expect(c.scale?.scanning, false);
    },
  );

  test(
    'controller uses contract readings, derives missing flow and safely replaces adapters',
    () async {
      SharedPreferences.setMockInitialValues({'scale.model': 'test-a'});
      final prefs = await SharedPreferences.getInstance();
      final a = FakeScale('test-a'), b = FakeScale('test-b');
      final registry = ScaleRegistry([
        ScaleRegistration(a.info, () => a),
        ScaleRegistration(b.info, () => b),
      ]);
      var now = Duration.zero;
      final c = BrewController(
        prefs,
        scaleRegistry: registry,
        session: BrewSession(now: () => now),
      );
      addTearDown(c.dispose);
      a.emit(20);
      c.setDose(20);
      await c.start();
      now = const Duration(milliseconds: 100);
      a.emit(21);
      now = const Duration(milliseconds: 200);
      a.emit(22);
      now = const Duration(milliseconds: 300);
      a.emit(27);
      now = const Duration(milliseconds: 400);
      a.emit(28);
      now = const Duration(milliseconds: 500);
      a.emit(28);
      expect(c.brew.water, 8);
      expect(c.brew.flow, greaterThan(0));
      await expectLater(c.selectScale('test-b'), throwsStateError);
      expect(c.scale, same(a));
      c.finish();
      await c.selectScale('test-b');
      expect(a.disconnects, 1);
      expect(a.disposed, true);
      expect(a.hasObservers, false);
      expect(c.scale, same(b));
      expect(c.brew.water, 8);
      expect(c.brew.phase, BrewPhase.finished);
      await c.saveFinished('변경 전의 한 잔');
      expect(c.store.load().single.trace.last.grams, 8);
      expect(prefs.getString(BrewController.selectedScaleKey), 'test-b');
      c.reset();
      b.emit(50);
      c.setDose(50);
      c.start();
      b.emit(55);
      b.emit(60);
      b.emit(60);
      expect(c.brew.water, 10);
      b.measurementsReady = false;
      b.notifyListeners();
      expect(c.brew.phase, BrewPhase.interrupted);
    },
  );

  test(
    'capacity comes from the selected scale rather than Dot constants',
    () async {
      SharedPreferences.setMockInitialValues({'scale.model': 'small'});
      final prefs = await SharedPreferences.getInstance();
      final small = FakeScale('small', capacity: 1200);
      final large = FakeScale('large', capacity: 3000);
      final c = BrewController(
        prefs,
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(small.info, () => small),
          ScaleRegistration(large.info, () => large),
        ]),
      );
      addTearDown(c.dispose);
      await expectLater(c.configure(100, 20), throwsArgumentError);
      await c.selectScale('large');
      await c.configure(100, 20);
      expect(c.brew.target, 2000);
      large.emit(100);
      c.setDose(100);
      await c.start();
      expect(c.brew.phase, BrewPhase.ready);
      c.finish();
    },
  );

  test('freshness requires readiness and a recent normalized reading', () {
    final scale = FakeScale('fresh');
    addTearDown(scale.dispose);
    scale.emit(123);
    expect(scale.fresh, true);
    scale.measurementsReady = false;
    expect(scale.fresh, false);
    scale.measurementsReady = true;
    scale.lastReading = DateTime.now().subtract(const Duration(seconds: 3));
    expect(scale.fresh, false);
  });
}
