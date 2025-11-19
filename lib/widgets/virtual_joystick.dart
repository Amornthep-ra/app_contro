// lib/widgets/virtual_joystick.dart
import 'package:flutter/material.dart';
import '../UI/joystick_theme.dart';

class VirtualJoystick extends StatefulWidget {
  final JoystickTheme theme;

  /// TRUE = joystick left → ใช้รูป leftKnobImage
  final bool isLeft;

  final Function(Offset offset) onChanged;
  final VoidCallback? onReset;

  const VirtualJoystick({
    super.key,
    required this.onChanged,
    required this.isLeft,
    this.theme = joystickTheme,
    this.onReset,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _pos = Offset.zero;

  double get radius => widget.theme.size / 2;
  double get knobRadius => widget.theme.knobSize / 2;

  void _update(Offset localPos) {
    final center = Offset(radius, radius);
    Offset delta = localPos - center;

    final maxDist = radius - knobRadius;
    if (delta.distance > maxDist) {
      delta = Offset.fromDirection(delta.direction, maxDist);
    }

    setState(() => _pos = delta);

    final nx = (_pos.dx / maxDist).clamp(-1, 1);
    final ny = (_pos.dy / maxDist).clamp(-1, 1);

    widget.onChanged(Offset(nx.toDouble(), ny.toDouble()));
  }

  void _reset() {
    setState(() => _pos = Offset.zero);
    widget.onChanged(const Offset(0, 0));
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    // ⭐ เลือกรูปตามฝั่ง
    final knobImage =
        widget.isLeft ? t.leftKnobImage : t.rightKnobImage;

    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: t.size,
        height: t.size,
        child: Stack(
          children: [
            // BG circle
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.bgColor.withOpacity(t.bgOpacity),
                border: Border.all(
                  color: t.borderColor,
                  width: t.borderWidth,
                ),
              ),
            ),

            // knob
            Positioned(
              left: radius + _pos.dx - knobRadius,
              top: radius + _pos.dy - knobRadius,
              child: SizedBox(
                width: t.knobSize,
                height: t.knobSize,
                child: knobImage != null
                    ? Image.asset(knobImage, fit: BoxFit.contain)
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              t.knobColorStart.withOpacity(t.knobOpacity),
                              t.knobColorEnd.withOpacity(t.knobOpacity),
                            ],
                          ),
                          border: Border.all(
                            color: t.knobBorderColor,
                            width: t.knobBorderWidth,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
