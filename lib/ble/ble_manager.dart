// lib/ble/ble_manager.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../shared/joystick/joystick_packet.dart';

class BleManager {
  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx; // notify
  BluetoothCharacteristic? _rx; // write

  /// ===== Stream สำหรับสถานะการเชื่อมต่อ =====
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  /// ===== สถานะว่าเชื่อมต่อครบจริงไหม =====
  bool get isConnected =>
      _device != null && _tx != null && _rx != null;

  /// ===== ข้อมูลอุปกรณ์ที่เชื่อมต่ออยู่ =====
  String? get currentDeviceName => _device?.platformName;
  String? get currentDeviceId => _device?.remoteId.str;

  // UUID prefix ของ Nordic UART
  static const uartServicePrefix = "6e400001";
  static const uartRxPrefix = "6e400002"; // WRITE
  static const uartTxPrefix = "6e400003"; // NOTIFY

  /// ===== ตั้งค่าอุปกรณ์เมื่อเชื่อมต่อ =====
  void setDevice(BluetoothDevice device) {
    _device = device;
    _connectionController.add(true);

    // ⭐ ฟังสถานะ BLE ตลอดเวลา — disconnect แบบ real-time
    device.connectionState.listen((state) {
      print("🔄 Device state changed → $state");

      if (state == BluetoothConnectionState.disconnected) {
        print("⚠️ BLE Device Disconnected!");

        _device = null;
        _tx = null;
        _rx = null;

        _connectionController.add(false);
      }
    });
  }

  /// ===== Discover UART Services =====
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
        print("❌ ไม่พบ TX/RX characteristic");
        return false;
      }

      if (_tx!.properties.notify) {
        await _tx!.setNotifyValue(true);
        print("✅ TX notify subscribed");
      }

      print("✅ BLE พร้อมใช้งานแล้ว");
      return true;

    } catch (e) {
      print("❌ discoverServices error: $e");
      return false;
    }
  }

  /// ===== ส่งข้อมูลปกติ =====
  Future<void> send(String data) async {
    if (!isConnected) {
      print("⚠️ send() ถูกเรียก แต่ BLE ยังไม่พร้อม");
      return;
    }

    try {
      final msg = (data + "\n").codeUnits;
      await _rx!.write(msg, withoutResponse: true);
      print("📤 ส่ง → $data");

    } catch (e) {
      print("❌ ส่งข้อมูลล้มเหลว: $e");
    }
  }

  /// ===== ส่งข้อมูล Joystick =====
  void sendJoystick(JoystickPacket packet) {
    send(packet.toBleString());
  }

  /// ===== อ่าน notify จาก TX =====
  Stream<List<int>>? onData() => _tx?.lastValueStream;

  /// ===== ปิดการเชื่อมต่อ =====
  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _tx = null;
    _rx = null;

    _connectionController.add(false);

    print("🔌 Disconnected");
  }
}
