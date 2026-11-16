import 'dart:async';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dot_pour/scales/timemore_dot/timemore_dot_scale.dart';
import 'package:flutter_test/flutter_test.dart';

class TestManager implements CentralManager {
  @override
  set logLevel(dynamic value) {}
  final states =
      StreamController<BluetoothLowEnergyStateChangedEventArgs>.broadcast();
  @override
  BluetoothLowEnergyState state = BluetoothLowEnergyState.unknown;
  @override
  Stream<BluetoothLowEnergyStateChangedEventArgs> get stateChanged =>
      states.stream;
  @override
  Stream<DiscoveredEventArgs> get discovered => const Stream.empty();
  @override
  Stream<PeripheralConnectionStateChangedEventArgs>
  get connectionStateChanged => const Stream.empty();
  @override
  Stream<GATTCharacteristicNotifiedEventArgs> get characteristicNotified =>
      const Stream.empty();
  int authorizations = 0, starts = 0, stops = 0;
  Completer<bool>? permission;
  Completer<void>? starting;
  void setState(BluetoothLowEnergyState value) {
    state = value;
    states.add(BluetoothLowEnergyStateChangedEventArgs(value));
  }

  @override
  Future<bool> authorize() async {
    expect(
      state,
      isNot(BluetoothLowEnergyState.unknown),
      reason:
          'Native initialization must finish before permission callbacks are registered',
    );
    authorizations++;
    final allowed = await (permission?.future ?? Future.value(true));
    if (allowed) setState(BluetoothLowEnergyState.poweredOn);
    return allowed;
  }

  @override
  Future<void> startDiscovery({List<UUID>? serviceUUIDs}) async {
    starts++;
    await starting?.future;
  }

  @override
  Future<void> stopDiscovery() async {
    stops++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'first scan waits for initialization before Android authorization',
    () async {
      final manager = TestManager();
      final scale = TimemoreDotScale(
        createManager: () => manager,
        requestAuthorization: true,
      );
      final scan = scale.scan();
      expect(manager.authorizations, 0);
      manager.setState(BluetoothLowEnergyState.unauthorized);
      await scan;
      expect(manager.authorizations, 1);
      expect(manager.starts, 1);
      expect(scale.scanning, true);
      await scale.stopScan();
      await scale.scan();
      expect(
        manager.authorizations,
        1,
        reason: 'Already granted permissions do not need another dialog',
      );
      expect(manager.starts, 2);
      await scale.stopScan();
      scale.dispose();
      await manager.states.close();
    },
  );

  test(
    'closing picker during permission request never starts a hidden scan',
    () async {
      final manager =
          TestManager()..state = BluetoothLowEnergyState.unauthorized;
      manager.permission = Completer<bool>();
      final scale = TimemoreDotScale(
        createManager: () => manager,
        requestAuthorization: true,
      );
      final scan = scale.scan();
      await scale.stopScan();
      manager.permission!.complete(true);
      await scan;
      expect(manager.starts, 0);
      expect(scale.scanning, false);
      expect(scale.busy, false);
      scale.dispose();
      await manager.states.close();
    },
  );

  test(
    'closing picker while native scan is starting stops late discovery',
    () async {
      final manager = TestManager()..state = BluetoothLowEnergyState.poweredOn;
      manager.starting = Completer<void>();
      final scale = TimemoreDotScale(
        createManager: () => manager,
        requestAuthorization: true,
      );
      final scan = scale.scan();
      await scale.stopScan();
      manager.starting!.complete();
      await scan;
      expect(scale.scanning, false);
      expect(scale.busy, false);
      expect(manager.stops, greaterThanOrEqualTo(1));
      scale.dispose();
      await manager.states.close();
    },
  );
}
