import 'package:flutter/foundation.dart';
import 'scale_models.dart';
export 'scale_models.dart';

/// Contract for a connected coffee scale. Notify listeners on state changes.
///
/// Each implementation owns discovery, permissions, handshakes, packet decoding
/// and commands. A connected device is usable only once [measurementsReady] is
/// true and a fresh normalized reading exists. Missing flow is derived by the
/// brew session. [disconnect] must be safe to call repeatedly; [dispose] must
/// cancel subscriptions and release any remaining native resources.
abstract class CoffeeScale extends ChangeNotifier {
  ScaleInfo get info;
  List<ScaleDevice> get devices;
  bool get scanning;
  bool get busy;
  bool get connected;
  bool get measurementsReady;
  String? get error;
  String get deviceName;
  int? get battery;
  ScaleReading? get reading;
  DateTime? get lastReading;
  String get discoveryStatus => scanning ? '주변 기기 검색 중' : '검색 대기';
  bool get canOpenSettings => false;
  Future<void> openSettings() async {}
  Future<Map<String, Object?>> connectionDiagnostics() async => {};

  /// Optional transport timing. Unsupported adapters keep normal weighing.
  Future<Map<String, Object?>> beginDiagnosticCapture() async => {};
  Future<Map<String, Object?>> endDiagnosticCapture() async => {};

  Duration get readingTimeout => const Duration(seconds: 2);
  bool get fresh =>
      connected &&
      measurementsReady &&
      reading != null &&
      lastReading != null &&
      DateTime.now().difference(lastReading!) < readingTimeout;

  Future<void> scan();
  Future<void> stopScan();
  Future<void> connect(ScaleDevice device);
  Future<void> tare();
  Future<void> disconnect();
}
