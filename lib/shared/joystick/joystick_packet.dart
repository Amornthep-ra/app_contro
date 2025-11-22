// lib/joystick/joystick_packet.dart

/// แพ็กเกจที่ใช้ส่งค่าจอย 2 ข้าง ผ่าน BLE ไปหา ESP32
/// ค่าแต่ละแกนอยู่ช่วง -1.0 ถึง 1.0
class JoystickPacket {
  final double lx; // left stick X
  final double ly; // left stick Y
  final double rx; // right stick X
  final double ry; // right stick Y

  JoystickPacket({
    required this.lx,
    required this.ly,
    required this.rx,
    required this.ry,
  });

  double _clamp(double v) {
    if (v > 1.0) return 1.0;
    if (v < -1.0) return -1.0;
    return v;
  }

  /// แปลงเป็นสตริงสำหรับส่งทาง BLE
  ///
  /// รูปแบบ:
  ///   J:<LX>,<LY>;<RX>,<RY>
  ///
  /// ตัวอย่าง:
  ///   J:-0.50,0.80;0.10,-0.20
  String toBleString() {
    final slx = _clamp(lx).toStringAsFixed(2);
    final sly = _clamp(ly).toStringAsFixed(2);
    final srx = _clamp(rx).toStringAsFixed(2);
    final sry = _clamp(ry).toStringAsFixed(2);

    return 'J:$slx,$sly;$srx,$sry';
  }
}
