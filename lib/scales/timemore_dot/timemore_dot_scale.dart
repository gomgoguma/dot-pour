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
  String discoveryStatus = '검색 대기';
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
        name: device.advertisement.name ?? '이름 없는 BLE 기기',
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
            _lostConnection('블루투스 연결이 끊겼습니다.');
          }
          if (event.state != BluetoothLowEnergyState.poweredOn && scanning) {
            error = '블루투스가 꺼졌거나 권한이 해제되어 검색을 중단했습니다.';
            unawaited(stopScan());
          }
          _changed();
        }),
      );
      subscriptions.add(
        manager.connectionStateChanged.listen((event) {
          if (event.peripheral.uuid == _peripheral?.uuid &&
              event.state == ConnectionState.disconnected) {
            _lostConnection('도트와 연결이 끊겼습니다. 다시 연결해 주세요.');
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
                if (!_gramsConfirmed) error = '저울 단위가 g이 아닙니다. 다시 연결해 주세요.';
              }
              if (frame.command == 5 && frame.payload.length == 2) {
                battery = frame.payload[1].clamp(0, 100);
              }
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
    discoveryStatus = '블루투스 초기화 중';
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
        discoveryStatus = '근처 기기 권한 확인 중';
        _changed();
        if (!await manager.authorize().timeout(const Duration(seconds: 45))) {
          throw StateError('앱 설정에서 근처 기기 권한을 허용해 주세요.');
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
          BluetoothLowEnergyState.unsupported =>
            '이 기기는 Bluetooth LE를 지원하지 않습니다.',
          BluetoothLowEnergyState.unauthorized => '앱의 블루투스 권한을 허용해 주세요.',
          _ => '블루투스를 켜고 다시 검색해 주세요.',
        });
      }
      _devices.clear();
      discoveryStatus = '검색 시작 중';
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
      discoveryStatus = '주변 기기 검색 중 · 12초';
      _scanTimer = Timer(const Duration(seconds: 12), stopScan);
    } catch (e) {
      if (current()) {
        error =
            e is TimeoutException
                ? '$discoveryStatus 응답이 지연되었습니다. 앱을 다시 열고 권한을 확인해 주세요.'
                : '검색 실패: $e';
        await stopScan();
        discoveryStatus = '검색을 시작하지 못했습니다';
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
    discoveryStatus = '검색 종료 · ${_devices.length}개 수신';
    try {
      if (requested) {
        await _manager?.stopDiscovery().timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      error = '검색 중지 실패: $e';
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
      error = '검색 목록에서 기기를 찾지 못했습니다. 다시 검색해 주세요.';
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
        discoveryStatus = 'Windows 페어링 확인 중';
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
        throw StateError('도트의 BLE 서비스를 찾지 못했습니다.');
      }
      if (model != null &&
          model!.isNotEmpty &&
          !model!.toUpperCase().contains('TES017')) {
        throw StateError('지원하지 않는 저울 모델입니다: $model');
      }
      await manager
          .setCharacteristicNotifyState(device.peripheral, uplink, state: true)
          .timeout(const Duration(seconds: 5));
      if (!await _sendWrite(6, [0])) {
        throw StateError('저울의 g 단위 설정을 확인하지 못했습니다.');
      }
      _gramsConfirmed = true;
      connected = true;
      await _send(2, 5);
      await _send(2, 6);
    } catch (e) {
      await disconnect();
      error = '연결 실패: $e';
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
      throw StateError('연결된 저울이 없습니다.');
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
  Future<void> tare() async {
    if (busy || !connected) return;
    busy = true;
    error = null;
    _changed();
    try {
      if (!await _sendWrite(0x0d, [])) throw StateError('영점 명령이 거부되었습니다.');
      // Acknowledgement alone is not a fresh weight measurement.
      reading = null;
      lastReading = null;
    } catch (e) {
      error = '영점 설정 실패: $e';
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
