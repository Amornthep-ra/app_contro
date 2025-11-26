// lib/joystick/joystick_controller.dart
import '../../../core/ble/joystick_packet.dart';

class JoystickController {
  double _lx = 0.0;
  double _ly = 0.0;
  double _rx = 0.0;
  double _ry = 0.0;

  void setLeftJoystick(double x, double y) {
    _lx = x;
    _ly = y;
  }

  void setRightJoystick(double x, double y) {
    _rx = x;
    _ry = y;
  }

  JoystickPacket buildPacket() {
    return JoystickPacket(
      lx: _lx,
      ly: _ly,
      rx: _rx,
      ry: _ry,
    );
  }
}
