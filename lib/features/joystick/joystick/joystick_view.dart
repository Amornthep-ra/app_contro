// lib/shared/joystick/joystick_view.dart
import 'package:flutter/material.dart';
import 'joystick_controller.dart';
import 'joystick_theme.dart';

class JoystickView extends StatefulWidget {
  final JoystickController controller;
  final bool isLeft;
  final void Function(double x, double y)? onChanged;
  final String? knobImage;

  const JoystickView({
    super.key,
    required this.controller,
    this.isLeft = true,
    this.onChanged,
    this.knobImage,
  });

  @override
  State<JoystickView> createState() => _JoystickViewState();
}

class _JoystickViewState extends State<JoystickView>
    with SingleTickerProviderStateMixin {
  Offset _knob = Offset.zero;
  late AnimationController _resetCtrl;

  double get _size => joystickTheme.size;
  double get _knobSize => joystickTheme.knobSize;

  double get _radius => _size / 2;
  double get _knobRadius => _knobSize / 2;

  @override
  void initState() {
    super.initState();

    _resetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _resetCtrl.addListener(() {
      setState(() {
        _knob = Offset.lerp(_knob, Offset.zero, _resetCtrl.value)!;
        _emitToController(_knob);
      });
    });
  }

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) => _onDrag(d.localPosition);
  void _onPanUpdate(DragUpdateDetails d) => _onDrag(d.localPosition);
  void _onPanEnd(DragEndDetails d) => _onRelease();

  void _onDrag(Offset localPos) {
    final center = Offset(_radius, _radius);
    Offset delta = localPos - center;

    final maxDist = _radius - _knobRadius;
    if (delta.distance > maxDist) {
      delta = Offset.fromDirection(delta.direction, maxDist);
    }

    setState(() => _knob = delta);
    _emitToController(_knob);
  }

  void _onRelease() => _resetCtrl.forward(from: 0);

  void _emitToController(Offset knobOffset) {
    final maxDist = _radius - _knobRadius;
    final nx = (knobOffset.dx / maxDist).clamp(-1.0, 1.0);
    final ny = (knobOffset.dy / maxDist).clamp(-1.0, 1.0);

    if (widget.isLeft) {
      widget.controller.setLeftJoystick(nx, ny);
    } else {
      widget.controller.setRightJoystick(nx, ny);
    }
    widget.onChanged?.call(nx, ny);
  }

  @override
  Widget build(BuildContext context) {
    final themeB = Theme.of(context).brightness;
    final platformB = MediaQuery.of(context).platformBrightness;
    final isDark = themeB == Brightness.dark || platformB == Brightness.dark;

    const minOpacityLight = 0.22;
    const minOpacityDark = 0.30;
    final minOpacity = isDark ? minOpacityDark : minOpacityLight;
    final effectiveOpacity =
        joystickTheme.bgOpacity < minOpacity ? minOpacity : joystickTheme.bgOpacity;

    final bgColor = joystickTheme.bgColor.withOpacity(effectiveOpacity);

    final borderOpacity = isDark ? 0.95 : 0.60;
    final borderColor = joystickTheme.borderColor.withOpacity(borderOpacity);

    final knobFallbackColor =
        joystickTheme.knobColorStart.withOpacity(joystickTheme.knobOpacity);

    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _JoystickPainter(
                  widget.controller,
                  knob: _knob,
                  knobSize: _knobSize,
                  hideKnob: widget.knobImage != null,
                  bgColor: bgColor,
                  borderColor: borderColor,
                  borderWidth: joystickTheme.borderWidth,
                  knobColor: knobFallbackColor,
                  isDark: isDark,
                ),
              ),
            ),
            if (widget.knobImage != null)
              Positioned(
                left: _radius + _knob.dx - _knobRadius,
                top: _radius + _knob.dy - _knobRadius,
                child: SizedBox(
                  width: _knobSize,
                  height: _knobSize,
                  child: Image.asset(
                    widget.knobImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final JoystickController controller;
  final Offset knob;
  final double knobSize;
  final bool hideKnob;

  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final Color knobColor;
  final bool isDark;

  _JoystickPainter(
    this.controller, {
    required this.knob,
    required this.knobSize,
    this.hideKnob = false,
    required this.bgColor,
    required this.borderColor,
    required this.borderWidth,
    required this.knobColor,
    required this.isDark,
  });

  static const double _darkBorderMul = 5.0;
  static const double _lightBorderMul = 2.6;

  static const double _blurExtraW = 14.0;
  static const double _blurSigma = 18.0;
  static const double _shadowSigma = 20.0;
  static const double _glowSigma = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    if (!hideKnob) _drawKnob(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rBig = size.width / 2;

    final paintBg = Paint()..style = PaintingStyle.fill;

    if (isDark) {
      paintBg.shader = const RadialGradient(
        center: Alignment(-0.15, -0.2),
        radius: 1.1,
        colors: [
          Color(0xFF2A2F3A),
          Color(0xFF14161C),
          Color(0xFF0A0B0F),
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: rBig));
    } else {
      paintBg.color = bgColor;
    }

    final mainBorderW = isDark
        ? borderWidth * _darkBorderMul
        : borderWidth * _lightBorderMul;

    final paintBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mainBorderW
      ..color = borderColor;

    final paintShadow = Paint()
      ..color = Colors.black.withOpacity(isDark ? 0.55 : 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowSigma);

    canvas.drawCircle(center, rBig, paintShadow);
    canvas.drawCircle(center, rBig, paintBg);
    canvas.drawCircle(center, rBig, paintBorder);

    final blurBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mainBorderW + _blurExtraW
      ..color = borderColor.withOpacity(isDark ? 0.42 : 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blurSigma);

    canvas.drawCircle(center, rBig * 0.995, blurBorderPaint);

    if (isDark) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mainBorderW * 0.55
        ..color = const Color(0xFF6B7CFF).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowSigma);

      canvas.drawCircle(center, rBig * 0.98, glowPaint);
    }
  }

  void _drawKnob(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final paintKnob = Paint()
      ..color = knobColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center + knob, knobSize / 2, paintKnob);

    final paintKnobBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = joystickTheme.knobBorderWidth
      ..color = joystickTheme.knobBorderColor.withOpacity(isDark ? 0.9 : 0.6);

    canvas.drawCircle(center + knob, knobSize / 2, paintKnobBorder);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.knob != knob ||
        oldDelegate.hideKnob != hideKnob ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.knobColor != knobColor ||
        oldDelegate.isDark != isDark;
  }
}
