/// Values shared by every scale adapter. No vendor frames or BLE objects leak
/// into the brew session or UI; adapters normalize mass to g and flow to g/s.
class ScaleReading {
  final double grams;
  final double? flow;
  final int? seconds;
  final bool overloaded;
  const ScaleReading({
    required this.grams,
    this.flow,
    this.seconds,
    this.overloaded = false,
  });
}

class ScaleCapabilities {
  final bool tare, flow, battery;
  const ScaleCapabilities({
    this.tare = false,
    this.flow = false,
    this.battery = false,
  });
}

class ScaleInfo {
  /// Stable key saved in preferences, independent of the app's display name.
  final String id, manufacturer, name, shortName, modelCode;
  final double capacityGrams;
  final ScaleCapabilities capabilities;
  const ScaleInfo({
    required this.id,
    required this.manufacturer,
    required this.name,
    required this.shortName,
    required this.modelCode,
    required this.capacityGrams,
    required this.capabilities,
  });
}

class ScaleDevice {
  /// Opaque identifier resolved by the adapter that discovered this device.
  final String id, name;
  final int rssi;
  final bool recommended;
  const ScaleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.recommended,
  });
}
