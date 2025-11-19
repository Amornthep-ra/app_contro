// lib/pages/joystick_control_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../ble/ble_manager.dart';
import '../joystick/joystick_controller.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/connection_status_badge.dart';
import '../UI/joystick_theme.dart';
import '../utils/orientation_utils.dart';

class JoystickControlPage extends StatefulWidget {
  const JoystickControlPage({super.key});

  @override
  State<JoystickControlPage> createState() => _JoystickControlPageState();
}

class _JoystickControlPageState extends State<JoystickControlPage> {
  final JoystickController _controller = JoystickController();
  Timer? _timer;

  // smoothing values
  double _smoothLX = 0.0, _smoothLY = 0.0;
  double _smoothRX = 0.0, _smoothRY = 0.0;

  // last sent
  double _lastLX = 0.0, _lastLY = 0.0;
  double _lastRX = 0.0, _lastRY = 0.0;

  static const double _deadZone = 0.08;
  static const double _smoothing = 0.15;
  static const double _deltaThreshold = 0.02;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _leftDebug = "JL: (0,0)";
  String _rightDebug = "JR: (0,0)";

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final pkt = _controller.buildPacket();

      final changed =
          (pkt.lx - _lastLX).abs() > _deltaThreshold ||
          (pkt.ly - _lastLY).abs() > _deltaThreshold ||
          (pkt.rx - _lastRX).abs() > _deltaThreshold ||
          (pkt.ry - _lastRY).abs() > _deltaThreshold;

      if (!changed) return;

      _lastLX = pkt.lx;
      _lastLY = pkt.ly;
      _lastRX = pkt.rx;
      _lastRY = pkt.ry;

      BleManager.instance.sendJoystick(pkt);

      setState(() {
        _leftDebug =
            "JL: (${pkt.lx.toStringAsFixed(2)}, ${pkt.ly.toStringAsFixed(2)})";
        _rightDebug =
            "JR: (${pkt.rx.toStringAsFixed(2)}, ${pkt.ry.toStringAsFixed(2)})";
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    OrientationUtils.setPortrait();
    super.dispose();
  }

  (double, double) _process(double rawX, double rawY, double sx, double sy) {
    final x = (rawX.abs() < _deadZone) ? 0.0 : rawX;
    final y = (rawY.abs() < _deadZone) ? 0.0 : rawY;

    final fx = _lerp(sx, x, _smoothing);
    final fy = _lerp(sy, y, _smoothing);

    return (fx, fy);
  }

  /// Debug Box (one line)
  Widget _buildDebugBox(String text) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: joystickTheme.debugBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: joystickTheme.debugTextColor,
            fontSize: joystickTheme.debugFontSize,
            fontFamily: "monospace",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = joystickTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Joystick Control (Dual)"),
        actions: const [ConnectionStatusBadge()],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                 // LEFT STICK
VirtualJoystick(
  isLeft: true,          // ⭐ บอกว่าเป็นจอยซ้าย
  theme: t,
  onChanged: (offset) {
    final (sx, sy) =
        _process(offset.dx, offset.dy, _smoothLX, _smoothLY);

    _smoothLX = sx;
    _smoothLY = sy;

    _controller.setLeftJoystick(sx, sy);
  },

  onReset: () {
    _smoothLX = 0;
    _smoothLY = 0;
    _controller.setLeftJoystick(0, 0);
    setState(() => _leftDebug = "JL: (0,0)");
  },
),

// RIGHT STICK
VirtualJoystick(
  isLeft: false,         // ⭐ บอกว่าเป็นจอยขวา
  theme: t,
  onChanged: (offset) {
    final (sx, sy) =
        _process(offset.dx, offset.dy, _smoothRX, _smoothRY);

    _smoothRX = sx;
    _smoothRY = sy;

    _controller.setRightJoystick(sx, sy);
  },

  onReset: () {
    _smoothRX = 0;
    _smoothRY = 0;
    _controller.setRightJoystick(0, 0);
    setState(() => _rightDebug = "JR: (0,0)");
  },
),

                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDebugBox(_leftDebug),
                const SizedBox(width: 20),
                _buildDebugBox(_rightDebug),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
