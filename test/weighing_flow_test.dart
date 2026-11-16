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
      scale.emit(18.5);
      await tester.pump();
      expect(find.text('18.5 g'), findsOneWidget);
      await tester.tap(find.text('추출 시작'));
      await tester.pump();
      expect(scale.tares, 2);
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
      expect(scale.tares, 2, reason: 'Tare cannot erase an active pour');
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
