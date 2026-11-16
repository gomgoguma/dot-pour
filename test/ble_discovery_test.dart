import 'dart:async';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:dot_pour/scales/timemore_dot/timemore_dot_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

class TestManager implements CentralManager {
  @override
  // Match the plugin's named logger instead of silently accepting invalid
  // configuration. Setting its level throws with Dart's default logging setup.
  set logLevel(Level? value) => Logger('$runtimeType').level = value;
  final states =
      StreamController<BluetoothLowEnergyStateChangedEventArgs>.broadcast();
  final discoveries = StreamController<DiscoveredEventArgs>.broadcast();
  bool failStateSubscriptionOnce = false;
  @override
  BluetoothLowEnergyState state = BluetoothLowEnergyState.unknown;
  @override
  Stream<BluetoothLowEnergyStateChangedEventArgs> get stateChanged {
    if (failStateSubscriptionOnce) {
      failStateSubscriptionOnce = false;
      throw StateError('Simulated subscription failure');
    }
    return states.stream;
  }

  @override
  Stream<DiscoveredEventArgs> get discovered => discoveries.stream;
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
    'scan receives devices with the default logging configuration',
    () async {
      expect(hierarchicalLoggingEnabled, isFalse);
      final manager = TestManager()..state = BluetoothLowEnergyState.poweredOn;
      final scale = TimemoreDotScale(createManager: () => manager);
      addTearDown(() async {
        scale.dispose();
        await manager.states.close();
        await manager.discoveries.close();
      });

      await scale.scan();
      expect(scale.error, isNull);
      expect(scale.scanning, isTrue);
      manager.discoveries.add(
        DiscoveredEventArgs(
          Peripheral(
            uuid: UUID.fromString('00000000-0000-0000-0000-60d877c3510f'),
          ),
          -42,
          Advertisement(name: 'TIMEMORE_Dot'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(scale.devices.single.name, 'TIMEMORE_Dot');
      await scale.stopScan();
    },
  );

  test('failed initialization releases listeners and can retry', () async {
    final manager =
        TestManager()
          ..state = BluetoothLowEnergyState.poweredOn
          ..failStateSubscriptionOnce = true;
    final scale = TimemoreDotScale(createManager: () => manager);
    addTearDown(() async {
      scale.dispose();
      await manager.states.close();
      await manager.discoveries.close();
    });

    await scale.scan();
    expect(scale.error, contains('Simulated subscription failure'));
    expect(scale.scanning, isFalse);
    expect(scale.busy, isFalse);
    expect(manager.discoveries.hasListener, isFalse);
    expect(manager.starts, 0);

    await scale.scan();
    expect(scale.error, isNull);
    expect(scale.scanning, isTrue);
    expect(manager.discoveries.hasListener, isTrue);
    expect(manager.states.hasListener, isTrue);
    expect(manager.starts, 1);
    await scale.stopScan();
  });

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
