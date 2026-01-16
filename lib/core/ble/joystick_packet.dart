// lib/joystick/joystick_packet.dart
import 'dart:typed_data';

const int kBleBtnUp = 1;
const int kBleBtnDown = 2;
const int kBleBtnLeft = 3;
const int kBleBtnRight = 4;
const int kBleBtnTriangle = 5;
const int kBleBtnCross = 6;
const int kBleBtnSquare = 7;
const int kBleBtnCircle = 8;
const int kBleBtnSpeedLow = 9;
const int kBleBtnSpeedMid = 10;
const int kBleBtnSpeedHigh = 11;

class JoystickPacket {
  final double lx;
  final double ly;
  final double rx;
  final double ry;

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

  String toBleString() {
    final slx = _clamp(lx).toStringAsFixed(2);
    final sly = _clamp(ly).toStringAsFixed(2);
    final srx = _clamp(rx).toStringAsFixed(2);
    final sry = _clamp(ry).toStringAsFixed(2);

    return 'J:$slx,$sly;$srx,$sry';
  }

  Uint8List toBinaryPacket(Set<int> pressedButtons) {
    int _axisToInt8(double v) {
      final clamped = _clamp(v);
      return (clamped * 100).round();
    }

    final int lxInt = _axisToInt8(lx);
    final int lyInt = _axisToInt8(ly);
    final int rxInt = _axisToInt8(rx);
    final int ryInt = _axisToInt8(ry);

    int btnLow = 0;
    int btnHigh = 0;

    for (final b in pressedButtons) {
      if (b < 1 || b > 16) continue;
      final bitIndex = b - 1;
      if (bitIndex < 8) {
        btnLow |= (1 << bitIndex);
      } else {
        btnHigh |= (1 << (bitIndex - 8));
      }
    }

    final pkt = Uint8List(10);
    pkt[0] = 0xAA;
    pkt[1] = 0x55;
    pkt[2] = 0x01;
    pkt[3] = lxInt & 0xFF;
    pkt[4] = lyInt & 0xFF;
    pkt[5] = rxInt & 0xFF;
    pkt[6] = ryInt & 0xFF;
    pkt[7] = btnLow & 0xFF;
    pkt[8] = btnHigh & 0xFF;

    int cs = 0;
    for (int i = 2; i <= 8; i++) {
      cs = (cs + pkt[i]) & 0xFF;
    }
    pkt[9] = cs & 0xFF;

    return pkt;
  }
}
