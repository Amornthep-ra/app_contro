//lib/core/ble/ble_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'joystick_packet.dart';

class BleManager {
  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _device != null && _tx != null && _rx != null;

  String? get currentDeviceName => _device?.platformName;
  String? get currentDeviceId => _device?.remoteId.str;

  static const uartServicePrefix = "6e400001";
  static const uartRxPrefix = "6e400002";
  static const uartTxPrefix = "6e400003";

  Timer? _heartbeatTimer;
  DateTime? _lastRxTime;
  StreamSubscription<List<int>>? _txSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<ScanResult>>? _autoScanSub;
  bool _autoConnectRunning = false;

  static const Duration _heartbeatInterval = Duration(seconds: 4);
  static const Duration _heartbeatTimeout = Duration(seconds: 15);

  Future<void> _sendLock = Future.value();
  DateTime _lastTxTime = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime _lastJoySend = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _enqueueWrite(Future<void> Function() task) {
    _sendLock = _sendLock
        .then((_) async {
          await task();
        })
        .catchError((_) {});
    return _sendLock;
  }

  void _startHeartbeat() {
    _lastRxTime = DateTime.now();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!isConnected) {
        _stopHeartbeat();
        return;
      }

      final now = DateTime.now();
      if (_lastRxTime != null &&
          now.difference(_lastRxTime!) > _heartbeatTimeout) {
        debugPrint(
          "Heartbeat timeout – no data from board for > $_heartbeatTimeout",
        );
      }

      if (now.difference(_lastTxTime) > const Duration(seconds: 1)) {
        await send("PING");
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void setDevice(BluetoothDevice device) {
    _device = device;
    _connectionController.add(true);

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      debugPrint("Device state changed: $state");

      if (state == BluetoothConnectionState.disconnected) {
        debugPrint("BLE device disconnected");

        _stopHeartbeat();
        await _txSub?.cancel();
        _txSub = null;

        _device = null;
        _tx = null;
        _rx = null;

        _connectionController.add(false);
      }
    });
  }

  Future<bool> discoverServices() async {
    if (_device == null) return false;

    try {
      final services = await _device!.discoverServices();

      for (var s in services) {
        final suuid = s.uuid.str.toLowerCase();

        if (suuid.startsWith(uartServicePrefix)) {
          for (var c in s.characteristics) {
            final cuuid = c.uuid.str.toLowerCase();

            if (cuuid.startsWith(uartTxPrefix)) {
              _tx = c;
            } else if (cuuid.startsWith(uartRxPrefix)) {
              _rx = c;
            }
          }
        }
      }

      if (_tx == null || _rx == null) {
        debugPrint("TX/RX characteristic not found");
        return false;
      }

      if (_tx!.properties.notify) {
        await _tx!.setNotifyValue(true);

        _txSub?.cancel();
        _txSub = _tx!.lastValueStream.listen(
          (data) {
            if (data.isNotEmpty) {
              _lastRxTime = DateTime.now();
            }
          },
          onError: (e) {
            debugPrint("TX notify error: $e");
          },
        );
      }

      _startHeartbeat();
      return true;
    } catch (e) {
      debugPrint("discoverServices error: $e");
      return false;
    }
  }

  Future<void> send(String data) async {
    if (!isConnected) {
      debugPrint("send() called but BLE not ready");
      return;
    }

    final rx = _rx!;
    final msg = "$data\n".codeUnits;
    final mustAck = data == '0';

    await _enqueueWrite(() async {
      try {
        await rx.write(msg, withoutResponse: !mustAck);
        _lastTxTime = DateTime.now();
      } catch (e) {
        debugPrint("Send failed: $e");
      }
    });
  }

  Future<List<int>> readTx() async {
    if (_tx == null) return [];
    try {
      return await _tx!.read();
    } catch (e) {
      debugPrint("Read TX failed: $e");
      return [];
    }
  }

  void sendJoystick(JoystickPacket packet) {
    send(packet.toBleString());
  }

  Future<void> sendJoystickBinary({
    required JoystickPacket packet,
    required Set<int> pressedButtons,
  }) async {
    if (!isConnected) {
      debugPrint("sendJoystickBinary() called but BLE not ready");
      return;
    }

    final rx = _rx!;
    final now = DateTime.now();
    if (now.difference(_lastJoySend) < const Duration(milliseconds: 20)) {
      return;
    }
    _lastJoySend = now;

    final bytes = packet.toBinaryPacket(pressedButtons);

    await _enqueueWrite(() async {
      try {
        await rx.write(bytes, withoutResponse: true);
        _lastTxTime = DateTime.now();
      } catch (e) {
        debugPrint("Send binary failed: $e");
      }
    });
  }

  Stream<List<int>>? onData() => _tx?.lastValueStream;

  Future<void> autoConnectLastDevice({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_autoConnectRunning || isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('ble_last_device_id');
    if (lastId == null || lastId.isEmpty) return;

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) return;

    _autoConnectRunning = true;

    try {
      await _autoScanSub?.cancel();
      _autoScanSub = FlutterBluePlus.scanResults.listen((list) async {
        if (!_autoConnectRunning || isConnected) return;
        for (final r in list) {
          if (r.device.remoteId.str != lastId) continue;

          _autoConnectRunning = false;
          await _autoScanSub?.cancel();
          _autoScanSub = null;

          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}

          await disconnect();
          try {
            await r.device.disconnect();
          } catch (_) {}

          await r.device.connect(
            license: License.free,
            timeout: const Duration(seconds: 10),
            autoConnect: false,
          );

          setDevice(r.device);
          final ok = await discoverServices();
          if (ok) {
            send("HELLO_APP");
          }
          return;
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (_) {
    } finally {
      await _autoScanSub?.cancel();
      _autoScanSub = null;
      _autoConnectRunning = false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _tx = null;
    _rx = null;

    _stopHeartbeat();
    await _txSub?.cancel();
    _txSub = null;

    await _connSub?.cancel();
    _connSub = null;

    _connectionController.add(false);

    debugPrint("Disconnected");
  }
}
