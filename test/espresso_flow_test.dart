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

    await tester.tap(find.byKey(const Key('espresso-vessels')));
    await tester.pumpAndSettle();
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
    final saved = EspressoVesselStore(preferences).load().single;
    expect(saved.name, '58 mm');
    expect(saved.grams, 510);
    expect(saved.kind, EspressoVesselKind.portafilter);
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
    expect(find.text('18.0g 사용'), findsOneWidget);
    await tester.tap(find.byKey(const Key('espresso-use-dose')));
    await tester.pumpAndSettle();
    expect(c.espresso.dose, 18);

    scale.emit(74);
    final start = find.byKey(const Key('espresso-auto-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(c.espresso.phase, EspressoPhase.armed);
    expect(scale.tares, 3);
    expect(find.byKey(const Key('home-mode-espresso')), findsNothing);
    scale.emit(.1);
    scale.emit(.2);
    expect(c.espresso.phase, EspressoPhase.armed);
    scale.emit(.3);
    await tester.pump();
    expect(c.espresso.phase, EspressoPhase.brewing);
    expect(tester.widget<BrewChart>(find.byType(BrewChart)).showFlow, isTrue);
    await tester.ensureVisible(find.byKey(const Key('espresso-finish')));
    await tester.tap(find.byKey(const Key('espresso-finish')));
    await tester.pumpAndSettle();
    expect(c.espresso.phase, EspressoPhase.finished);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
