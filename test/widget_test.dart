import 'package:dot_pour/brew_controller.dart';
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
    SharedPreferences.setMockInitialValues({'scale.model': 'timemore-dot'});
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
    expect(find.text('50.0 %', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('brew-progress')),
          )
          .value,
      .5,
    );
    final headerTop = tester.getTopLeft(find.byKey(const Key('brew-header')));
    await tester.drag(
      find.byKey(const Key('brew-scroll')),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('brew-header'))), headerTop);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(352);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('110.0 %', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('brew-progress')),
          )
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'APK configuration hides demo and ratio confirmation clears system UI',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'scale.model': 'timemore-dot'});
      final prefs = await SharedPreferences.getInstance();
      final controller = BrewController(prefs, allowDemo: false);
      await controller.toggleDemo();
      expect(controller.demo, false);
      await tester.pumpWidget(
        DotPourApp(preferences: prefs, controller: controller),
      );
      expect(find.text('저울 없이 데모로 체험'), findsNothing);
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-ratio'));
      expect(tester.getBottomRight(confirm).dy, lessThanOrEqualTo(780 - 48));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(confirm).dy, lessThanOrEqualTo(780 - 300));
      await tester.tap(find.text('1:17'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(controller.brew.ratio, 17);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
