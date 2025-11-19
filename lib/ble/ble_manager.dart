import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../joystick/joystick_packet.dart';


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
  bool get isConnected => _device != null;

  // UUID prefix ของ Nordic UART
  static const uartServicePrefix = "6e400001";
  static const uartRxPrefix      = "6e400002"; // WRITE
  static const uartTxPrefix      = "6e400003"; // NOTIFY


  /// ===== ตั้งค่าอุปกรณ์เมื่อเชื่อมต่อ =====
  void setDevice(BluetoothDevice device) {
    _device = device;
    _connectionController.add(true);
  }

  /// ===== Discover services & characteristics =====
  Future<bool> discoverServices() async {
    if (_device == null) return false;

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

    print("✅ BLE UART พร้อมใช้งาน");
    return true;
  }

  /// ===== ส่งข้อมูลไปยัง ESP32 =====
  Future<void> send(String data) async {
    if (_rx == null) {
      print("❌ send() ถูกเรียก แต่ RX ยังเป็น null");
      return;
    }

    try {
      // 👇 จำเป็นต้อง \n !!!
      final msg = (data + "\n").codeUnits;

      await _rx!.write(msg, withoutResponse: true);
      print("📤 ส่ง → $data");
    } catch (e) {
      print("❌ ส่งข้อมูลล้มเหลว: $e");
    }
  }

  /// ===== ส่งข้อมูล Joystick ให้ ESP32 =====
  void sendJoystick(JoystickPacket packet) {
    final data = packet.toBleString();
    send(data); // ใช้ฟังก์ชันส่งเดิม
  }


  /// อ่าน notify จาก TX
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
  }
}
