// lib/joystick/joystick_controller.dart

import 'joystick_packet.dart';

/// Controller เก็บสถานะของจอย 2 ข้าง
/// แล้ว build เป็น JoystickPacket เพื่อส่ง BLE ได้
class JoystickController {
  double _lx = 0.0;
  double _ly = 0.0;
  double _rx = 0.0;
  double _ry = 0.0;

  /// อัปเดตค่าจอยฝั่งซ้าย (-1..1)
  void setLeftJoystick(double x, double y) {
    _lx = x;
    _ly = y;
  }

  /// อัปเดตค่าจอยฝั่งขวา (-1..1)
  void setRightJoystick(double x, double y) {
    _rx = x;
    _ry = y;
  }

  /// สร้างแพ็กเกจสำหรับส่งผ่าน BLE
  JoystickPacket buildPacket() {
    return JoystickPacket(
      lx: _lx,
      ly: _ly,
      rx: _rx,
      ry: _ry,
    );
  }
}
