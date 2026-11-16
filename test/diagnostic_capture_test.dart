import 'dart:convert';
import 'package:dot_pour/brew_controller.dart';
import 'package:dot_pour/scales/scale_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_scale.dart';

class _DiagnosticScale extends FakeScale {
  _DiagnosticScale() : super('test');
  int starts = 0, stops = 0;
  bool fail = false;
  double delay = 950;

  @override
  Future<Map<String, Object?>> beginDiagnosticCapture() async {
    starts++;
    if (fail) throw StateError('optional capture failed');
    return {'available': true};
  }

  @override
  Future<Map<String, Object?>> endDiagnosticCapture() async {
    stops++;
    if (fail) throw StateError('optional capture failed');
    return {'channel_roundtrip_ms': delay};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BrewController> controller(_DiagnosticScale scale) async {
    SharedPreferences.setMockInitialValues({'scale.model': 'test'});
    return BrewController(
      await SharedPreferences.getInstance(),
      scaleRegistry: ScaleRegistry([
        ScaleRegistration(scale.info, () => scale),
      ]),
    );
  }

  test(
    'start and stop capture transport automatically and preserve stopped results',
    () async {
      final scale = _DiagnosticScale();
      final c = await controller(scale);
      try {
        await c.toggleDiagnostics();
        scale.emit(20);
        await c.toggleDiagnostics();
        expect(scale.starts, 1);
        expect(scale.stops, 1);
        expect(c.diagnosticBusy, false);
        scale.delay = 1;
        scale.emit(30);
        final data = jsonDecode(
          c.diagnostics.export(version: 'test', platform: 'android'),
        );
        expect(data['connection_capture_at_stop']['channel_roundtrip_ms'], 950);
        expect(
          (data['events'] as List).where((e) => e['kind'] == 'input').length,
          1,
        );
        await c.toggleDiagnostics();
        expect(c.diagnostics.connectionCapture, isNull);
        await c.toggleDiagnostics();
        expect(c.diagnostics.connectionCapture!['channel_roundtrip_ms'], 1);
      } finally {
        c.dispose();
      }
    },
  );

  test(
    'transport diagnostic failures preserve weighing and app-side records',
    () async {
      final scale = _DiagnosticScale()..fail = true;
      final c = await controller(scale);
      try {
        await c.toggleDiagnostics();
        scale.emit(20);
        expect(c.currentGrams, 20);
        expect(c.diagnostics.recording, true);
        await c.toggleDiagnostics();
        expect(c.diagnostics.recording, false);
        expect(c.diagnosticBusy, false);
        expect(c.diagnostics.count, greaterThan(2));
        expect(
          c.diagnostics.connectionCapture!['reason'],
          'capture_stop_failed',
        );
      } finally {
        c.dispose();
      }
    },
  );
}
