import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart';
import '../scale.dart';
import 'protocol.dart';

class TimemoreDotScale extends CoffeeScale {
  final CentralManager Function() _createManager;
  final bool _requestAuthorization;
  TimemoreDotScale({
    CentralManager Function()? createManager,
    bool? requestAuthorization,
  }) : _createManager = createManager ?? CentralManager.new,
       _requestAuthorization = requestAuthorization ?? Platform.isAndroid;
  static const _platform = MethodChannel('dot_pour/ble_platform');
  int _scanGeneration = 0;
  bool _discoveryRequested = false;
  @override
  late String discoveryStatus = strings.scanIdle;
  @override
  bool get canOpenSettings => Platform.isAndroid || Platform.isIOS;
  @override
  Future<void> openSettings() async {
    _initialize();
    await _manager!.showAppSettings();
  }

  static const modelInfo = ScaleInfo(
    id: 'timemore-dot',
    manufacturer: 'TIMEMORE',
    name: 'Black Mirror Dot',
    shortName: 'Dot',
    modelCode: 'TES017',
    capacityGrams: 1200,
    capabilities: ScaleCapabilities(tare: true, flow: true, battery: true),
  );
  @override
  ScaleInfo get info => modelInfo;
  CentralManager? _manager;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final decoder = DotFrameDecoder();
  final _devices = <String, DiscoveredEventArgs>{};
  @override
  List<ScaleDevice> get devices => List.unmodifiable(
    _devices.values.map(
      (device) => ScaleDevice(
        id: device.peripheral.uuid.toString(),
        name: device.advertisement.name ?? strings.unnamedDevice,
        rssi: device.rssi,
        recommended: _likelyDot(device),
      ),
    ),
  );
  final _acks = <int, Completer<bool>>{};
  Peripheral? _peripheral;
  GATTCharacteristic? _write;
  Timer? _scanTimer;
  @override
  bool scanning = false;
  @override
  bool busy = false;
  @override
  bool connected = false;
  bool _gramsConfirmed = false;
  @override
  bool get measurementsReady => _gramsConfirmed;
  @override
  String? error;
  @override
  String deviceName = '';
  String? model;
  @override
  int? battery;
  @override
  ScaleReading? reading;
  @override
  DateTime? lastReading;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _initialize() {
    if (_manager != null) return;
    final manager = _createManager();
    final subscriptions = <StreamSubscription<dynamic>>[];
    try {
      subscriptions.add(
        manager.discovered.listen((event) {
          if (!_discoveryRequested) return;
          final key = event.peripheral.uuid.toString();
          // Preserve the scan response's name when a later advertisement omits it.
          if (event.advertisement.name != null || !_devices.containsKey(key)) {
            _devices[key] = event;
            _changed();
          }
        }),
      );
      subscriptions.add(
        manager.stateChanged.listen((event) {
          if (event.state != BluetoothLowEnergyState.poweredOn && connected) {
            _lostConnection(strings.bluetoothDisconnected);
          }
          if (event.state != BluetoothLowEnergyState.poweredOn && scanning) {
            error = strings.scanPermissionLost;
            unawaited(stopScan());
          }
          _changed();
        }),
      );
      subscriptions.add(
        manager.connectionStateChanged.listen((event) {
          if (event.peripheral.uuid == _peripheral?.uuid &&
              event.state == ConnectionState.disconnected) {
            _lostConnection(strings.dotDisconnected);
          }
        }),
      );
      subscriptions.add(
        manager.characteristicNotified.listen((event) {
          if (event.peripheral.uuid != _peripheral?.uuid ||
              event.characteristic.uuid !=
                  UUID.fromString(DotProtocol.notify)) {
            return;
          }
          for (final frame in decoder.add(event.value)) {
            if (frame.opcode == 3 && frame.payload.length == 1) {
              final ack = _acks.remove(frame.command);
              ack?.complete(frame.payload[0] == 1);
            }
            if ([1, 2].contains(frame.opcode)) {
              if (frame.command == 6 && frame.payload.length == 1) {
                _gramsConfirmed = frame.payload[0] == 0;
                if (!_gramsConfirmed) error = strings.scaleUnitMismatch;
              }
              final percentage = DotProtocol.batteryFromFrame(frame);
              if (percentage != null) battery = percentage;
              final next = DotProtocol.readingFromFrame(frame);
              if (next != null && _gramsConfirmed) {
                reading = next;
                lastReading = DateTime.now();
              }
            }
          }
          _changed();
        }),
      );
      // Only reuse the manager once every event listener is installed.
      // Otherwise a failed initialization can leave later scans silent.
      _subscriptions.addAll(subscriptions);
      _manager = manager;
    } catch (_) {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      rethrow;
    }
  }

  void _lostConnection(String message) {
    connected = false;
    _gramsConfirmed = false;
    reading = null;
    lastReading = null;
    _write = null;
    error = message;
    for (final ack in _acks.values) {
      if (!ack.isCompleted) ack.complete(false);
    }
    _acks.clear();
    decoder.clear();
    _changed();
  }

  @override
  Future<void> scan() async {
    if (busy || scanning || connected) return;
    busy = true;
    error = null;
    final generation = ++_scanGeneration;
    bool current() => !_disposed && generation == _scanGeneration;
    discoveryStatus = strings.initializingBluetooth;
    _changed();
    try {
      _initialize();
      final manager = _manager!;
      // Android initialize() clears pending authorization callbacks. Wait for
      // its first state BEFORE requesting permissions, including on first use.
      if (manager.state == BluetoothLowEnergyState.unknown) {
        await manager.stateChanged
            .firstWhere((e) => e.state != BluetoothLowEnergyState.unknown)
            .timeout(const Duration(seconds: 15));
      }
      if (!current()) return;
      if (_requestAuthorization &&
          manager.state == BluetoothLowEnergyState.unauthorized) {
        discoveryStatus = strings.checkingNearbyPermission;
        _changed();
        if (!await manager.authorize().timeout(const Duration(seconds: 45))) {
          throw StateError(strings.grantNearbyPermission);
        }
        if (!current()) return;
        // The plugin refreshes Android state when the permission dialog closes.
        if (manager.state == BluetoothLowEnergyState.unauthorized) {
          await manager.stateChanged
              .firstWhere(
                (e) =>
                    e.state != BluetoothLowEnergyState.unauthorized &&
                    e.state != BluetoothLowEnergyState.unknown,
              )
              .timeout(const Duration(seconds: 5));
        }
      }
      if (!current()) return;
      if (manager.state != BluetoothLowEnergyState.poweredOn) {
        throw StateError(switch (manager.state) {
          BluetoothLowEnergyState.unsupported => strings.bleUnsupported,
          BluetoothLowEnergyState.unauthorized =>
            strings.grantBluetoothPermission,
          _ => strings.enableBluetooth,
        });
      }
      _devices.clear();
      discoveryStatus = strings.startingScan;
      _discoveryRequested = true;
      _changed();
      final starting = manager.startDiscovery();
      // A late native completion after timeout/cancellation must not leak a scan.
      unawaited(
        starting
            .then((_) async {
              if (!current()) await manager.stopDiscovery();
            })
            .catchError((Object _) {}),
      );
      await starting.timeout(const Duration(seconds: 8));
      if (!current()) return;
      scanning = true;
      discoveryStatus = strings.scanningDot;
      _scanTimer = Timer(const Duration(seconds: 12), stopScan);
    } catch (e) {
      if (current()) {
        error =
            e is TimeoutException
                ? strings.scanTimeout(discoveryStatus)
                : strings.scanError(e);
        await stopScan();
        discoveryStatus = strings.scanStartError;
      }
    } finally {
      if (!current() && _discoveryRequested) await stopScan();
      busy = false;
      _changed();
    }
  }

  @override
  Future<void> stopScan() async {
    ++_scanGeneration;
    _scanTimer?.cancel();
    final requested = _discoveryRequested;
    _discoveryRequested = false;
    scanning = false;
    discoveryStatus = strings.scanEnded;
    try {
      if (requested) {
        await _manager?.stopDiscovery().timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      error = strings.scanStopError(e);
    }
    _changed();
  }

  static bool _likelyDot(DiscoveredEventArgs device) {
    final name = (device.advertisement.name ?? '').toLowerCase();
    return name.contains('dot') ||
        name.contains('tes017') ||
        name.contains('timemore') ||
        device.advertisement.serviceUUIDs.contains(
          UUID.fromString(DotProtocol.service),
        );
  }

  @override
  Future<void> connect(ScaleDevice candidate) async {
    if (busy || connected) return;
    final device = _devices[candidate.id];
    if (device == null) {
      error = strings.deviceNotFound;
      _changed();
      return;
    }
    busy = true;
    error = null;
    _changed();
    try {
      await stopScan();
      reading = null;
      lastReading = null;
      _gramsConfirmed = false;
      model = null;
      battery = null;
      decoder.clear();
      _peripheral = device.peripheral;
      deviceName = device.advertisement.name ?? 'TIMEMORE Dot';
      final manager = _manager!;
      if (Platform.isWindows) {
        discoveryStatus = strings.checkingWindowsPairing;
        _changed();
        await _platform
            .invokeMethod<void>('pair', device.peripheral.uuid.toString())
            .timeout(const Duration(seconds: 40));
      }
      await manager
          .connect(device.peripheral)
          .timeout(const Duration(seconds: 15));
      final services = await manager
          .discoverGATT(device.peripheral)
          .timeout(const Duration(seconds: 12));
      GATTCharacteristic? uplink;
      for (final service in services) {
        if (service.uuid == UUID.fromString(DotProtocol.service)) {
          for (final c in service.characteristics) {
            if (c.uuid == UUID.fromString(DotProtocol.notify)) uplink = c;
            if (c.uuid == UUID.fromString(DotProtocol.write)) _write = c;
          }
        }
        if (service.uuid ==
            UUID.fromString('0000180a-0000-1000-8000-00805f9b34fb')) {
          for (final c in service.characteristics) {
            if (c.uuid ==
                UUID.fromString('00002a24-0000-1000-8000-00805f9b34fb')) {
              final bytes = await manager
                  .readCharacteristic(device.peripheral, c)
                  .timeout(const Duration(seconds: 5));
              model =
                  utf8
                      .decode(bytes, allowMalformed: true)
                      .replaceAll('\u0000', '')
                      .trim();
            }
          }
        }
      }
      if (uplink == null || _write == null) {
        throw StateError(strings.dotServiceMissing);
      }
      if (model != null &&
          model!.isNotEmpty &&
          !model!.toUpperCase().contains('TES017')) {
        throw StateError(strings.scaleModelUnsupported(model ?? '—'));
      }
      if (Platform.isAndroid) {
        try {
          await manager
              .requestMTU(device.peripheral, mtu: 247)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // DOT's normal frames also fit in the default ATT MTU.
        }
      }
      await manager
          .setCharacteristicNotifyState(device.peripheral, uplink, state: true)
          .timeout(const Duration(seconds: 5));
      if (!await _sendWrite(6, [0])) {
        throw StateError(strings.cannotConfirmUnit);
      }
      _gramsConfirmed = true;
      if (Platform.isAndroid) {
        // Beanconqueror's DOT setup selects standard weighing mode after grams.
        // The public DOT protocol does not list this command on every firmware.
        try {
          await _send(3, 0x08, [0x01, 0x00]);
        } catch (_) {
          // Keep a working notification stream if the mode command is refused.
        }
      }
      connected = true;
      await _send(2, 5);
      await _send(2, 6);
    } catch (e) {
      await disconnect();
      error = strings.connectError(e);
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _send(
    int opcode,
    int command, [
    List<int> data = const [],
  ]) async {
    final peripheral = _peripheral;
    final characteristic = _write;
    if (peripheral == null || characteristic == null) {
      throw StateError(strings.noConnectedScale);
    }
    await _manager!
        .writeCharacteristic(
          peripheral,
          characteristic,
          value: DotProtocol.command(opcode, command, data),
          type: GATTCharacteristicWriteType.withoutResponse,
        )
        .timeout(const Duration(seconds: 4));
  }

  Future<bool> _sendWrite(int command, List<int> data) async {
    final completer = Completer<bool>();
    _acks[command] = completer;
    try {
      await _send(3, command, data);
      return await completer.future.timeout(const Duration(seconds: 4));
    } finally {
      _acks.remove(command);
    }
  }

  @override
  Future<void> refreshBattery() async {
    if (!connected || busy) return;
    try {
      await _send(2, 5);
    } catch (_) {
      // Keep the last valid battery reading if this optional query fails.
    }
  }

  @override
  Future<void> tare() async {
    if (busy || !connected) return;
    busy = true;
    error = null;
    _changed();
    try {
      if (!await _sendWrite(0x0d, [])) throw StateError(strings.tareRejected);
      // Acknowledgement alone is not a fresh weight measurement.
      reading = null;
      lastReading = null;
    } catch (e) {
      error = strings.tareError(e);
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  Future<void> disconnect() async {
    await stopScan();
    final peripheral = _peripheral;
    _peripheral = null;
    _lostConnection('');
    error = null;
    if (peripheral != null) {
      try {
        await _manager
            ?.disconnect(peripheral)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* The device may already be out of range. */
      }
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(disconnect());
    super.dispose();
  }
}
