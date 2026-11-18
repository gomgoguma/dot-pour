import 'package:dot_pour/l10n/language.dart';
import 'package:dot_pour/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('language change applies immediately and survives restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      AppLanguage.preferenceKey: 'es',
      'scale.model': 'timemore-dot',
      'ratio': 16.7,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(DotPourApp(preferences: prefs));
    expect(find.text('Peso actual'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-language')));
    await tester.pumpAndSettle();
    final wheel = find.byKey(const Key('language-wheel'));
    await tester.drag(wheel, const Offset(0, -56));
    await tester.pumpAndSettle();
    expect(find.text('Concluir'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply-language')));
    await tester.pumpAndSettle();

    expect(prefs.getString(AppLanguage.preferenceKey), 'pt');
    expect(prefs.getString('scale.model'), 'timemore-dot');
    expect(prefs.getDouble('ratio'), 16.7);
    expect(find.text('Configurações'), findsWidgets);
    expect(find.byKey(const Key('language-wheel')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(DotPourApp(preferences: prefs));
    expect(find.text('Peso atual'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
