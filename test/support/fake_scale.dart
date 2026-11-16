import 'package:dot_pour/scales/scale.dart';

/// A vendor-independent adapter for testing the public scale contract.
class FakeScale extends CoffeeScale {
  @override
  final ScaleInfo info;
  FakeScale(String id, {double capacity = 1200})
    : info = ScaleInfo(
        id: id,
        manufacturer: 'TEST',
        name: id,
        shortName: id,
        modelCode: id,
        capacityGrams: capacity,
        capabilities: const ScaleCapabilities(),
      );
  @override
  List<ScaleDevice> devices = [];
  @override
  bool scanning = false;
  @override
  bool busy = false;
  @override
  bool connected = false;
  @override
  bool measurementsReady = false;
  @override
  String? error;
  @override
  String deviceName = 'Test scale';
  @override
  int? battery;
  @override
  ScaleReading? reading;
  @override
  DateTime? lastReading;
  bool disposed = false;
  bool get hasObservers => hasListeners;
  int disconnects = 0;

  void emit(double grams, {double? flow}) {
    connected = true;
    measurementsReady = true;
    reading = ScaleReading(grams: grams, flow: flow);
    lastReading = (lastReading ?? DateTime.now()).add(
      const Duration(microseconds: 1),
    );
    notifyListeners();
  }

  @override
  Future<void> scan() async {
    scanning = true;
    notifyListeners();
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
    notifyListeners();
  }

  @override
  Future<void> connect(ScaleDevice device) async {
    connected = true;
    notifyListeners();
  }

  @override
  Future<void> tare() async => throw UnsupportedError('No tare capability');
  @override
  Future<void> disconnect() async {
    disconnects++;
    connected = false;
    scanning = false;
    measurementsReady = false;
    reading = null;
    lastReading = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
