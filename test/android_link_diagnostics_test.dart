import 'dart:convert';
import 'package:dot_pour/brew_diagnostics.dart';
import 'package:dot_pour/scales/android_link_diagnostics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dot_pour/ble_latency');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native capture uses explicit start and stop without changing the BLE subscription',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return {'available': true};
      });
      await readAndroidLinkDiagnostics(method: 'capture_start');
      await readAndroidLinkDiagnostics(method: 'capture_stop');
      expect(calls, ['capture_start', 'capture_stop']);
    },
  );

  test(
    'native interval and dispatch timing are retained in diagnostic export',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'snapshot');
        return {
          'source': 'android_gatt_callback',
          'links': [
            {
              'requested_priority': 'high',
              'priority_request_accepted': true,
              'native_interval_mean_ms': 100.0,
              'main_dispatch_max_ms': 2.0,
            },
          ],
        };
      });
      final snapshot = await readAndroidLinkDiagnostics();
      final report = jsonDecode(
        BrewDiagnostics().export(
          version: 'test',
          platform: 'android',
          connection: snapshot,
        ),
      );
      expect(
        report['connection_snapshot_at_export']['links'][0]['native_interval_mean_ms'],
        100.0,
      );
      expect(
        report['connection_snapshot_at_export']['links'][0]['main_dispatch_max_ms'],
        2.0,
      );
    },
  );

  test(
    'older builds without the optional channel can still export diagnostics',
    () async {
      final snapshot = await readAndroidLinkDiagnostics();
      expect(snapshot, {'available': false, 'reason': 'unsupported'});
    },
  );

  test(
    'native errors are nonfatal and do not expose identifiers in export',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'failure',
          message: 'sensitive native details',
        );
      });
      expect(await readAndroidLinkDiagnostics(), {
        'available': false,
        'reason': 'platform_error',
      });
    },
  );
}
