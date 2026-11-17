import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/brew_session.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/manual_timer.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets(
    'automatic first pour respects mode, pause, reset, tare and disconnect',
    (tester) async {
      SharedPreferences.setMockInitialValues({'scale.model': 'test'});
      final prefs = await SharedPreferences.getInstance();
      final scale = FakeScale('test', supportsTare: true);
      var now = Duration.zero;
      final c = BrewController(
        prefs,
        allowDemo: false,
        scaleTimer: ManualTimer(now: () => now),
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      var at = DateTime.now();
      void send(double grams) {
        at = at.add(const Duration(milliseconds: 100));
        scale.lastReading = at;
        scale.emit(grams);
      }

      void zero() {
        for (var i = 0; i < 5; i++) {
          send(0);
        }
      }

      await c.setScaleAutoStart(true);
      expect(prefs.getBool('scale.autoStart'), true);
      c.setScaleMode(false);
      zero();
      send(1);
      send(2);
      expect(c.scaleTimer.running, false);
      c.setScaleMode(true);
      zero();
      send(.7);
      send(1.4);
      expect(c.scaleTimer.running, true);
      now = const Duration(seconds: 3);
      c.toggleScaleTimer();
      zero();
      send(1);
      send(2);
      expect(c.scaleTimer.running, false);
      expect(c.scaleTimer.elapsed.inSeconds, 3);
      c.resetScaleTimer();
      send(3);
      send(4);
      expect(c.scaleTimer.running, false);
      await c.tare();
      zero();
      send(.8);
      send(1.6);
      expect(c.scaleTimer.running, true);
      c.resetScaleTimer();
      zero();
      await scale.disconnect();
      send(1);
      send(2);
      expect(c.scaleTimer.running, false);
      await c.setScaleAutoStart(false);
      zero();
      send(1);
      send(2);
      expect(c.scaleTimer.running, false);
      c.dispose();
    },
  );

  testWidgets(
    'basic scale is the default; timer is manual and survives tabs, tare and navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'scale.model': 'test'});
      final prefs = await SharedPreferences.getInstance();
      var now = Duration.zero;
      final scale = FakeScale('test', supportsTare: true);
      final c = BrewController(
        prefs,
        allowDemo: false,
        scaleTimer: ManualTimer(now: () => now),
        scaleRegistry: ScaleRegistry([
          ScaleRegistration(scale.info, () => scale),
        ]),
      );
      scale.emit(42);
      await tester.pumpWidget(DotPourApp(preferences: prefs, controller: c));
      expect(find.byKey(const Key('basic-scale')), findsOneWidget);
      expect(find.byKey(const Key('ratio-input')), findsNothing);
      expect(find.text('추출 시작'), findsNothing);
      expect(find.text('00:00.0'), findsOneWidget);
      expect(
        tester.getBottomRight(find.byKey(const Key('manual-timer-toggle'))).dy,
        lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy - 12),
        reason:
            'Both scale cards and timer controls fit above navigation without scrolling',
      );
      scale.emit(43.2);
      await tester.pump();
      expect(find.text('43.2 g'), findsOneWidget);
      expect(
        c.scaleTimer.running,
        false,
        reason: 'Weight changes never start the manual timer',
      );
      await tester.tap(find.byKey(const Key('manual-timer-toggle')));
      await tester.pump();
      now = const Duration(milliseconds: 5400);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('00:05.4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('basic-scale-tare')));
      await tester.pump();
      expect(c.currentGrams, 0);
      expect(c.scaleTimer.running, true);
      expect(find.text('00:05.4'), findsOneWidget);
      await tester.tap(find.text('Pour over'));
      await tester.pump();
      expect(find.byKey(const Key('weighing-panel')), findsOneWidget);
      await tester.tap(find.text('설정'));
      await tester.pump();
      now = const Duration(milliseconds: 7400);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('브루잉'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('home-mode-scale')));
      await tester.pump();
      expect(find.text('00:07.4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-timer-toggle')));
      await tester.pump();
      now = const Duration(seconds: 20);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('00:07.4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-timer-toggle')));
      now = const Duration(seconds: 22);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('00:09.4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-timer-reset')));
      await tester.pump();
      expect(find.text('00:00.0'), findsOneWidget);
      expect(c.scaleTimer.running, false);
      expect(scale.tares, 1);
      expect(c.brew.phase, BrewPhase.setup);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
