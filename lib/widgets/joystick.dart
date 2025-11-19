import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Joystick callback
/// x,y = -100..100
typedef JoystickMoveCallback = void Function(double x, double y);

class Joystick extends StatefulWidget {
  final double size; // ขนาดวงกลมใหญ่
  final double knobSize; // ขนาดปุ่มเล็ก
  final JoystickMoveCallback onMove;

  const Joystick({
    super.key,
    required this.onMove,
    this.size = 160,
    this.knobSize = 80,
  });

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetCtrl;
  Offset _knob = Offset.zero;

  @override
  void initState() {
    super.initState();
    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _resetCtrl.addListener(() {
      setState(() {
        // animate กลับศูนย์
        _knob = Offset.lerp(_knob, Offset.zero, _resetCtrl.value)!;

        widget.onMove(
          (_knob.dx / (widget.size / 2)) * 100,
          (_knob.dy / (widget.size / 2)) * 100,
        );
      });
    });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onDrag(Offset localPos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final offset = localPos - center;

    final maxDist = widget.size / 2;
    final dist = offset.distance;

    Offset clamped = offset;

    if (dist > maxDist) {
      final ratio = maxDist / dist;
      clamped = offset * ratio;
    }

    setState(() => _knob = clamped);

    // ส่งค่า -100..100
    final dx = (clamped.dx / maxDist) * 100;
    final dy = (clamped.dy / maxDist) * 100;

    widget.onMove(dx, dy);
  }

  void _onRelease() {
    _resetCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        onPointerDown: (e) => _onDrag(e.localPosition),
        onPointerMove: (e) => _onDrag(e.localPosition),
        onPointerUp: (_) => _onRelease(),
        onPointerCancel: (_) => _onRelease(),
        child: CustomPaint(
          painter: _JoystickPainter(
            knob: _knob,
            knobSize: widget.knobSize,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knob;
  final double knobSize;

  const _JoystickPainter({
    required this.knob,
    required this.knobSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rBig = size.width / 2;

    final paintBg = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.white.withOpacity(.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintKnob = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..style = PaintingStyle.fill;

    // วงกลมใหญ่
    canvas.drawCircle(center, rBig, paintBg);
    canvas.drawCircle(center, rBig, paintBorder);

    // ปุ่มเลื่อนเล็ก
    canvas.drawCircle(center + knob, knobSize / 2, paintKnob);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knob != knob;
}
