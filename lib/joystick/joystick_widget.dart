  import 'package:flutter/material.dart';
  import 'dart:math' as math;

  /// callback: ส่งค่า normalized X,Y (-1..1)
  typedef JoystickCallback = void Function(double x, double y);

  /// วิดเจ็ต Joystick แบบ drag ส่งค่า x,y
  class JoystickWidget extends StatefulWidget {
    final double size;
    final double knobSize;
    final JoystickCallback onChanged;

    const JoystickWidget({
      super.key,
      required this.onChanged,
      this.size = 180,
      this.knobSize = 72,
    });

    @override
    State<JoystickWidget> createState() => _JoystickWidgetState();
  }

  class _JoystickWidgetState extends State<JoystickWidget> {
    Offset _pos = Offset.zero;

    double get radius => widget.size / 2;
    double get knobRadius => widget.knobSize / 2;

    void _update(Offset localPos) {
      final center = Offset(radius, radius);
      Offset delta = localPos - center;

      // จำกัดไม่ให้เกินวงกลม
      if (delta.distance > radius - knobRadius) {
        delta = Offset.fromDirection(
          delta.direction,
          radius - knobRadius,
        );
      }

      setState(() => _pos = delta);

      // แปลงเป็น -1..1
      final nx = (_pos.dx / (radius - knobRadius)).clamp(-1, 1);
      final ny = (_pos.dy / (radius - knobRadius)).clamp(-1, 1);

      widget.onChanged(nx.toDouble(), ny.toDouble());

    }

    void _reset() {
      setState(() => _pos = Offset.zero);
      widget.onChanged(0, 0);
    }

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onPanStart: (d) => _update(d.localPosition),
        onPanUpdate: (d) => _update(d.localPosition),
        onPanEnd: (_) => _reset(),
        onPanCancel: _reset,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // พื้นวงนอก
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.16),
                  border: Border.all(color: Colors.black54, width: 2),
                ),
              ),

              // ปุ่มวงใน
              Positioned(
                left: radius + _pos.dx - knobRadius,
                top: radius + _pos.dy - knobRadius,
                child: Container(
                  width: widget.knobSize,
                  height: widget.knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C6BFF), Color(0xFF2D39B5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(.35),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
