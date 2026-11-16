import 'dart:async';
import 'package:flutter/services.dart';

/// Optional statistics from the app's pinned Android BLE implementation.
/// A missing diagnostic channel must not affect weighing or connectivity.
Future<Map<String, Object?>> readAndroidLinkDiagnostics() async {
  try {
    return await const MethodChannel('dot_pour/ble_latency')
            .invokeMapMethod<String, Object?>('snapshot')
            .timeout(const Duration(seconds: 1)) ??
        {};
  } on MissingPluginException {
    return {'available': false, 'reason': 'unsupported'};
  } on TimeoutException {
    return {'available': false, 'reason': 'timeout'};
  } on PlatformException {
    return {'available': false, 'reason': 'platform_error'};
  }
}
