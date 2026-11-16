import 'package:dot_pour/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('phone-sized demo goes from recipe to 50% and keeps overshoot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(DotPourApp(preferences: preferences));
    final demo = find.text('저울 없이 데모로 체험');
    await tester.scrollUntilVisible(
      demo,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(demo);
    await tester.pump();
    final start = find.text('추출 시작');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(160);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('50.0%'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(352);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('110.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
