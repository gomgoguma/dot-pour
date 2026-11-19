import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/espresso_session.dart';
import 'package:dot_pour/espresso_vessel.dart';
import 'package:dot_pour/main.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:dot_pour/ui/brew_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_scale.dart';

class _LiveTestScale extends FakeScale {
  _LiveTestScale() : super('test', supportsTare: true);

  @override
  bool get fresh => connected && measurementsReady && reading != null;
}

void main() {
  testWidgets('saved vessel is subtracted only after a fresh tare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'app.language': 'ko',
      'scale.model': 'test',
      EspressoVesselStore.key:
          '[{"id":"legacy","name":"이전 항목","kind":"dosingCup","grams":82.4}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final scale = _LiveTestScale()..emit(0);
    final c = BrewController(
      preferences,
      allowDemo: false,
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
    await tester.pumpWidget(
      DotPourApp(preferences: preferences, controller: c),
    );
    await tester.tap(find.byKey(const Key('home-mode-espresso')));
    await tester.pumpAndSettle();
    final manualDose = find.byKey(const Key('espresso-manual-dose'));
    final vessels = find.byKey(const Key('espresso-vessels'));
    final vesselPicker = find.byType(DropdownButtonFormField<String>);
    final useDose = find.byKey(const Key('espresso-use-dose'));
    final doseReadout = find.byKey(const Key('espresso-dose'));
    final readingGroup = find.byKey(const Key('espresso-dose-reading-group'));
    void expectCenteredBelowDose(Finder button) {
      expect(
        tester.getCenter(button).dx,
        closeTo(tester.getCenter(readingGroup).dx, 0.5),
      );
      expect(
        tester.getTopLeft(button).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(readingGroup).dy),
      );
    }

    expectCenteredBelowDose(manualDose);
    expect(
      tester.getBottomLeft(manualDose).dy,
      lessThan(tester.getTopLeft(vesselPicker).dy),
    );
    expect(
      tester.getBottomLeft(vesselPicker).dy,
      lessThanOrEqualTo(tester.getTopLeft(vessels).dy),
    );
    expect(useDose, findsNothing);

    await tester.tap(vessels);
    await tester.pumpAndSettle();
    expect(find.text('도징 방법 관리'), findsWidgets);
    expect(find.text('이전 항목'), findsOneWidget);
    expect(find.text('도징 방법 추가'), findsOneWidget);
    await tester.tap(find.byKey(const Key('espresso-register-tare')));
    await tester.pumpAndSettle();
    scale.emit(510);
    await tester.enterText(
      find.byKey(const Key('espresso-vessel-name')),
      '58 mm',
    );
    await tester.pump();
    final saveVessel = find.byKey(const Key('espresso-register-save'));
    expect(tester.widget<FilledButton>(saveVessel).onPressed, isNotNull);
    await tester.ensureVisible(saveVessel);
    await tester.tap(saveVessel);
    await tester.pumpAndSettle();
    final entries = EspressoVesselStore(preferences).load();
    expect(entries.length, 2);
    expect(entries.last.name, '이전 항목');
    expect(entries.last.grams, 82.4);
    final saved = entries.first;
    expect(saved.name, '58 mm');
    expect(saved.grams, 510);
    Navigator.of(
      tester.element(find.byKey(const Key('espresso-register-save'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('58 mm · 510.0 g').last);
    await tester.pumpAndSettle();
    scale.emit(528);
    await tester.pump();
    expect(c.espressoNetDose, isNull);
    scale.emit(0);
    await tester.tap(find.byKey(const Key('espresso-dose-tare')));
    await tester.pumpAndSettle();
    scale.emit(528);
    await tester.pump();
    expect(tester.widget<Text>(doseReadout).textSpan!.toPlainText(), '18.0 g');
    expect(c.espresso.dose, isNull);
    expect(find.text('이 원두량 사용'), findsOneWidget);
    expect(
      tester.getBottomLeft(vessels).dy,
      lessThanOrEqualTo(tester.getTopLeft(useDose).dy),
    );
    await tester.tap(useDose);
    await tester.pumpAndSettle();
    expect(c.espresso.dose, 18);
    expect(vesselPicker, findsNothing);
    expect(vessels, findsNothing);
    expect(find.text('바로 시작'), findsOneWidget);
    expect(find.text('첫 방울부터'), findsOneWidget);
    final editDose = find.byKey(const Key('espresso-edit-dose'));
    expectCenteredBelowDose(editDose);
    await tester.tap(editDose);
    await tester.pumpAndSettle();
    expect(vesselPicker, findsOneWidget);
    expect(find.text('바로 시작'), findsNothing);
    await tester.tap(find.byKey(const Key('espresso-cancel-dose')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(doseReadout).textSpan!.toPlainText(), '18.0 g');

    final start = find.byKey(const Key('espresso-auto-start'));
    final immediate = find.byKey(const Key('espresso-manual-start'));
    final liftCupHint = find.text('샷잔을 들면 자동으로 추출이 끝나요.');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(immediate).onPressed, isNull);
    expect(find.text('저울을 비워 주세요'), findsOneWidget);
    scale.emit(74);
    await tester.pump();
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    scale.emit(0);
    await tester.pump();
    expect(find.text('빈 샷잔을 올려 주세요'), findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    scale.emit(74);
    scale.lastReading = scale.lastReading!.add(
      const Duration(milliseconds: 250),
    );
    scale.emit(74);
    await tester.pump();
    expect(find.text('샷잔 준비 완료'), findsOneWidget);
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(c.espresso.phase, EspressoPhase.armed);
    expect(scale.tares, 3);
    expect(find.byKey(const Key('home-mode-espresso')), findsNothing);
    expect(liftCupHint, findsNothing);
    scale.emit(.1);
    scale.emit(.2);
    expect(c.espresso.phase, EspressoPhase.armed);
    scale.emit(.3);
    await tester.pump();
    expect(c.espresso.phase, EspressoPhase.brewing);
    expect(tester.widget<BrewChart>(find.byType(BrewChart)).showFlow, isTrue);
    expect(liftCupHint, findsOneWidget);
    final yieldTime = c.espresso.secondsAt(scale.lastReading!);
    scale.emit(1.3);
    scale.emit(-55);
    await tester.pump();
    expect(c.espresso.phase, EspressoPhase.brewing);
    scale.lastReading = scale.lastReading!.add(
      const Duration(milliseconds: 300),
    );
    scale.emit(-55);
    await tester.pumpAndSettle();
    expect(c.espresso.phase, EspressoPhase.finished);
    expect(c.espresso.yieldGrams, .3);
    expect(c.espresso.secondsAt(scale.lastReading!), yieldTime);
    expect(find.text('추출 완료'), findsOneWidget);
    expect(liftCupHint, findsNothing);
    c.resetEspresso();
    await tester.pump();
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(
      find.byKey(const Key('espresso-confirm-empty-scale')),
      findsOneWidget,
    );
    scale.emit(-74);
    await tester.tap(find.byKey(const Key('espresso-confirm-empty-scale')));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(immediate).onPressed, isNull);
    scale.emit(0);
    scale.lastReading = scale.lastReading!.add(
      const Duration(milliseconds: 250),
    );
    scale.emit(0);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(immediate).onPressed, isNotNull);
    scale.emit(-74);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(immediate).onPressed, isNull);
    scale.emit(0);
    scale.lastReading = scale.lastReading!.add(
      const Duration(milliseconds: 250),
    );
    scale.emit(0);
    await tester.pump();
    await tester.tap(immediate);
    await tester.pumpAndSettle();
    expect(c.espresso.phase, EspressoPhase.brewing);
    expect(scale.tares, 4);

    final clock = DateTime.now();
    final shotStart = clock.subtract(const Duration(seconds: 12));
    c.espresso.reset();
    c.espresso.start(baseline: 0, at: shotStart, automatic: false);
    for (var ms = 250; ms <= 5750; ms += 250) {
      c.espresso.observe(ms / 500, shotStart.add(Duration(milliseconds: ms)));
    }
    c.espresso.observe(11.5, clock);
    await tester.pump(const Duration(milliseconds: 100));
    final completion = find.text('추출 완료 · 더 추출하면 이어져요');
    final elapsed = find.text('00:05');
    final finish = find.byKey(const Key('espresso-finish'));
    expect(completion, findsOneWidget);
    expect(elapsed, findsOneWidget);
    expect(liftCupHint, findsOneWidget);
    expect(find.text('추출 마치기'), findsOneWidget);
    expect(
      tester.getBottomLeft(completion).dy,
      lessThanOrEqualTo(tester.getTopLeft(elapsed).dy),
    );
    expect(
      tester.getBottomLeft(liftCupHint).dy,
      lessThanOrEqualTo(tester.getTopLeft(finish).dy),
    );
    expect(c.espresso.active, isTrue);

    c.espresso.observe(11.6, clock.add(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('추출 중'), findsOneWidget);
    expect(completion, findsNothing);
    expect(find.text('00:12'), findsOneWidget);
    expect(c.espresso.phase, EspressoPhase.brewing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
