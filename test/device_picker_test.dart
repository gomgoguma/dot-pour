import 'package:dot_pour/scales/scale_models.dart';
import 'package:dot_pour/ui/device_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_scale.dart';

void main() {
  testWidgets('the picker shows supported devices without an all-BLE list', (
    tester,
  ) async {
    final scale = FakeScale('test')
      ..devices = const [
        ScaleDevice(
          id: 'dot',
          name: 'TIMEMORE_Dot',
          rssi: -30,
          recommended: true,
        ),
        ScaleDevice(
          id: 'other',
          name: 'Headphones',
          rssi: -20,
          recommended: false,
        ),
      ];
    addTearDown(scale.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDevicePicker(context, scale),
                  child: const Text('연결'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('연결'));
    await tester.pump();
    await scale.stopScan();
    await tester.pumpAndSettle();
    expect(find.text('TIMEMORE_Dot'), findsOneWidget);
    expect(find.text('Headphones'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('전체'), findsNothing);
    await tester.tap(find.text('TIMEMORE_Dot'));
    await tester.pumpAndSettle();
    expect(scale.connected, true);
  });
}
