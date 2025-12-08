//lib/core/ble/ble_manager.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
        print(
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
      print("Device state changed: $state");

      if (state == BluetoothConnectionState.disconnected) {
        print("BLE device disconnected");

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
        print("TX/RX characteristic not found");
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
            print("TX notify error: $e");
          },
        );
      }

      _startHeartbeat();
      return true;
    } catch (e) {
      print("discoverServices error: $e");
      return false;
    }
  }

  Future<void> send(String data) async {
    if (!isConnected) {
      print("send() called but BLE not ready");
      return;
    }

    final rx = _rx!;
    final msg = (data + "\n").codeUnits;
    final mustAck = data == '0';

    await _enqueueWrite(() async {
      try {
        await rx.write(msg, withoutResponse: !mustAck);
        _lastTxTime = DateTime.now();
      } catch (e) {
        print("Send failed: $e");
      }
    });
  }

  void sendJoystick(JoystickPacket packet) {
    send(packet.toBleString());
  }

  Future<void> sendJoystickBinary({
    required JoystickPacket packet,
    required Set<int> pressedButtons,
  }) async {
    if (!isConnected) {
      print("sendJoystickBinary() called but BLE not ready");
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
        print("Send binary failed: $e");
      }
    });
  }

  Stream<List<int>>? onData() => _tx?.lastValueStream;

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

    print("Disconnected");
  }
}
