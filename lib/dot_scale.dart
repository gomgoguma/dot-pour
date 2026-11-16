import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'timemore_protocol.dart';

class DotScale extends ChangeNotifier {
  CentralManager? _manager;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final decoder = DotFrameDecoder();
  final devices = <String, DiscoveredEventArgs>{};
  final _acks = <int, Completer<bool>>{};
  Peripheral? _peripheral;
  GATTCharacteristic? _write;
  Timer? _scanTimer;
  bool scanning = false;
  bool busy = false;
  bool connected = false;
  bool gramsConfirmed = false;
  String? error;
  String deviceName = '';
  String? model;
  int? battery;
  ScaleReading? reading;
  DateTime? lastReading;
  bool _disposed = false;

  bool get fresh =>
      connected &&
      gramsConfirmed &&
      reading != null &&
      DateTime.now().difference(lastReading!) < const Duration(seconds: 2);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _initialize() {
    if (_manager != null) return;
    final manager = _manager = CentralManager();
    _subscriptions.add(
      manager.discovered.listen((event) {
        final key = event.peripheral.uuid.toString();
        // Preserve the scan response's name when a later advertisement omits it.
        if (event.advertisement.name != null || !devices.containsKey(key)) {
          devices[key] = event;
          _changed();
        }
      }),
    );
    _subscriptions.add(
      manager.stateChanged.listen((event) {
        if (event.state != BluetoothLowEnergyState.poweredOn && connected) {
          _lostConnection('블루투스 연결이 끊겼습니다.');
        }
        _changed();
      }),
    );
    _subscriptions.add(
      manager.connectionStateChanged.listen((event) {
        if (event.peripheral.uuid == _peripheral?.uuid &&
            event.state == ConnectionState.disconnected) {
          _lostConnection('도트와 연결이 끊겼습니다. 다시 연결해 주세요.');
        }
      }),
    );
    _subscriptions.add(
      manager.characteristicNotified.listen((event) {
        if (event.peripheral.uuid != _peripheral?.uuid ||
            event.characteristic.uuid != UUID.fromString(DotProtocol.notify)) {
          return;
        }
        for (final frame in decoder.add(event.value)) {
          if (frame.opcode == 3 && frame.payload.length == 1) {
            final ack = _acks.remove(frame.command);
            ack?.complete(frame.payload[0] == 1);
          }
          if ([1, 2].contains(frame.opcode)) {
            if (frame.command == 6 && frame.payload.length == 1) {
              gramsConfirmed = frame.payload[0] == 0;
              if (!gramsConfirmed) error = '저울 단위가 g이 아닙니다. 다시 연결해 주세요.';
            }
            if (frame.command == 5 && frame.payload.length == 2) {
              battery = frame.payload[1].clamp(0, 100);
            }
            final next = ScaleReading.fromFrame(frame);
            if (next != null && gramsConfirmed) {
              reading = next;
              lastReading = DateTime.now();
            }
          }
        }
        _changed();
      }),
    );
  }

  void _lostConnection(String message) {
    connected = false;
    gramsConfirmed = false;
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

  Future<void> scan() async {
    if (busy || scanning || connected) return;
    busy = true;
    error = null;
    _changed();
    try {
      _initialize();
      final manager = _manager!;
      if (Platform.isAndroid && !await manager.authorize()) {
        throw StateError('설정에서 근처 기기 / 블루투스 권한을 허용해 주세요.');
      }
      // Native initialization and iOS permission prompts are asynchronous.
      if (manager.state == BluetoothLowEnergyState.unknown) {
        await manager.stateChanged
            .firstWhere((e) => e.state != BluetoothLowEnergyState.unknown)
            .timeout(const Duration(seconds: 15));
      }
      if (manager.state != BluetoothLowEnergyState.poweredOn) {
        throw StateError('블루투스를 켜고 앱의 블루투스 권한을 확인해 주세요.');
      }
      devices.clear();
      await manager.startDiscovery();
      scanning = true;
      _scanTimer = Timer(const Duration(seconds: 12), stopScan);
    } catch (e) {
      error = '검색 실패: $e';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    if (!scanning) return;
    scanning = false;
    try {
      await _manager?.stopDiscovery();
    } catch (e) {
      error = '검색 중지 실패: $e';
    }
    _changed();
  }

  static bool likelyDot(DiscoveredEventArgs device) {
    final name = (device.advertisement.name ?? '').toLowerCase();
    return name.contains('dot') ||
        name.contains('tes017') ||
        name.contains('timemore') ||
        device.advertisement.serviceUUIDs.contains(
          UUID.fromString(DotProtocol.service),
        );
  }

  Future<void> connect(DiscoveredEventArgs device) async {
    if (busy || connected) return;
    busy = true;
    error = null;
    _changed();
    try {
      await stopScan();
      reading = null;
      lastReading = null;
      gramsConfirmed = false;
      model = null;
      battery = null;
      decoder.clear();
      _peripheral = device.peripheral;
      deviceName = device.advertisement.name ?? 'TIMEMORE Dot';
      final manager = _manager!;
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
      gramsConfirmed = true;
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
