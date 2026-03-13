// lib/features/joystick/joystick/joystick_view.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'joystick_controller.dart';
import 'joystick_theme.dart';

class JoystickView extends StatefulWidget {
  final JoystickController controller;
  final bool isLeft;
  final void Function(double x, double y)? onChanged;
  final String? knobImage;
  final String? baseImage;
  final JoystickAxisLock axisLock;

  const JoystickView({
    super.key,
    required this.controller,
    this.isLeft = true,
    this.onChanged,
    this.knobImage,
    this.baseImage,
    this.axisLock = JoystickAxisLock.none,
  });

  @override
  State<JoystickView> createState() => _JoystickViewState();
}

class _JoystickViewState extends State<JoystickView>
    with SingleTickerProviderStateMixin {
  Offset _knob = Offset.zero;
  late AnimationController _resetCtrl;

  Size _lastSize = Size.zero;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  Widget _axisBadge({
    required String label,
    required Color accent,
    required bool isDark,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _opacity(const Color(0xFF0F172A), isDark ? 0.46 : 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _opacity(accent, isDark ? 0.34 : 0.24),
          width: 1,
        ),
      ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            label,
            style: TextStyle(
              color: isDark
                  ? _opacity(Colors.white, 0.96)
                  : _opacity(const Color(0xFF0F172A), 0.92),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
      ),
    );
  }

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
        _emitCurrent();
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
    if (_lastSize.width <= 0 || _lastSize.height <= 0) return;

    final side = _lastSize.shortestSide;
    final radius = side / 2;

    final knobSizePx = side * (joystickTheme.knobSize / joystickTheme.size);
    final knobRadius = knobSizePx / 2;

    final center = Offset(radius, radius);
    Offset delta = localPos - center;

    if (widget.axisLock == JoystickAxisLock.yOnly) {
      delta = Offset(0, delta.dy);
    } else if (widget.axisLock == JoystickAxisLock.xOnly) {
      delta = Offset(delta.dx, 0);
    }

    final maxDist = radius - knobRadius;
    if (maxDist <= 0) return;

    if (delta.distance > maxDist) {
      delta = Offset.fromDirection(delta.direction, maxDist);
    }

    setState(() => _knob = delta);
    _emitWith(maxDist);
  }

  void _onRelease() => _resetCtrl.forward(from: 0);

  void _emitCurrent() {
    if (_lastSize.width <= 0 || _lastSize.height <= 0) return;

    final side = _lastSize.shortestSide;
    final radius = side / 2;
    final knobSizePx = side * (joystickTheme.knobSize / joystickTheme.size);
    final knobRadius = knobSizePx / 2;
    final maxDist = radius - knobRadius;
    if (maxDist <= 0) return;

    _emitWith(maxDist);
  }

  void _emitWith(double maxDist) {
    var nx = (_knob.dx / maxDist).clamp(-1.0, 1.0);
    var ny = (_knob.dy / maxDist).clamp(-1.0, 1.0);

    if (widget.axisLock == JoystickAxisLock.yOnly) {
      nx = 0.0;
    } else if (widget.axisLock == JoystickAxisLock.xOnly) {
      ny = 0.0;
    }

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

    final bgColor = _opacity(joystickTheme.bgColor, effectiveOpacity);

    final borderOpacity = isDark ? 0.95 : 0.60;
    final borderColor = _opacity(joystickTheme.borderColor, borderOpacity);

    final knobFallbackColor =
        _opacity(joystickTheme.knobColorStart, joystickTheme.knobOpacity);
    final knobAccent =
        widget.isLeft ? const Color(0xFF3BCBFF) : const Color(0xFFB06CFF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final size = side > 0 ? side : joystickTheme.size;

        _lastSize = Size(size, size);

        final radius = size / 2;
        final knobSizePx = size * (joystickTheme.knobSize / joystickTheme.size);
        final knobRadius = knobSizePx / 2;

        return SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (widget.baseImage != null)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(size * 0.01),
                      child: Image.asset(widget.baseImage!, fit: BoxFit.contain),
                    ),
                  ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _JoystickPainter(
                      widget.controller,
                      knob: _knob,
                      knobSize: knobSizePx,
                      hideKnob: widget.knobImage != null,
                      hideBackground: widget.baseImage != null,
                      bgColor: bgColor,
                      borderColor: borderColor,
                      borderWidth: joystickTheme.borderWidth,
                      knobColor: knobFallbackColor,
                      isDark: isDark,
                      axisLock: widget.axisLock,
                    ),
                  ),
                ),
                Positioned(
                  top: -24,
                  left: (size / 2) - 16,
                  child: _axisBadge(
                    label: 'Y-',
                    accent: knobAccent,
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  bottom: -24,
                  left: (size / 2) - 16,
                  child: _axisBadge(
                    label: 'Y+',
                    accent: knobAccent,
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  left: -28,
                  top: (size / 2) - 10,
                  child: _axisBadge(
                    label: 'X-',
                    accent: knobAccent,
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  right: -28,
                  top: (size / 2) - 10,
                  child: _axisBadge(
                    label: 'X+',
                    accent: knobAccent,
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  left: radius + _knob.dx - knobRadius,
                  top: radius + _knob.dy - knobRadius,
                  child: SizedBox(
                    width: knobSizePx,
                    height: knobSizePx,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.22, -0.26),
                          radius: 1.0,
                          colors: [
                            _opacity(Colors.white, isDark ? 0.92 : 0.98),
                            _opacity(knobAccent, isDark ? 0.34 : 0.24),
                            _opacity(const Color(0xFFD6DEEB), isDark ? 0.24 : 0.38),
                          ],
                          stops: const [0.0, 0.52, 1.0],
                        ),
                        border: Border.all(
                          color: _opacity(Colors.white, isDark ? 0.42 : 0.72),
                          width: joystickTheme.knobBorderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _opacity(knobAccent, isDark ? 0.30 : 0.20),
                            blurRadius: joystickTheme.knobShadowBlur,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: joystickTheme.knobShadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: knobSizePx * 0.28,
                          height: knobSizePx * 0.28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _opacity(knobAccent, isDark ? 0.92 : 0.78),
                            boxShadow: [
                              BoxShadow(
                                color: _opacity(knobAccent, isDark ? 0.50 : 0.32),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum JoystickAxisLock {
  none,
  xOnly,
  yOnly,
}

class _JoystickPainter extends CustomPainter {
  final JoystickController controller;
  final Offset knob;
  final double knobSize;
  final bool hideKnob;
  final bool hideBackground;

  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final Color knobColor;
  final bool isDark;
  final JoystickAxisLock axisLock;

  _JoystickPainter(
    this.controller, {
    required this.knob,
    required this.knobSize,
    this.hideKnob = false,
    this.hideBackground = false,
    required this.bgColor,
    required this.borderColor,
    required this.borderWidth,
    required this.knobColor,
    required this.isDark,
    required this.axisLock,
  });

  static const double _darkBorderMul = 5.0;
  static const double _lightBorderMul = 2.6;

  static const double _blurExtraW = 14.0;
  static const double _blurSigma = 18.0;
  static const double _shadowSigma = 20.0;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  @override
  void paint(Canvas canvas, Size size) {
    if (!hideBackground) _drawBackground(canvas, size);
    _drawCrossAxisGuides(canvas, size);
    _drawAxisGuide(canvas, size);
    if (!hideKnob) _drawKnob(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rBig = size.width / 2;
    final mainBorderW = isDark
        ? borderWidth * _darkBorderMul
        : borderWidth * _lightBorderMul;
    final outerShadowPaint = Paint()
      ..color = _opacity(Colors.black, isDark ? 0.34 : 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _shadowSigma)
      ..isAntiAlias = true;
    canvas.drawCircle(center, rBig * 0.98, outerShadowPaint);

    final outerFill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(-0.18, -0.22),
        radius: 1.05,
        colors: isDark
            ? const [
                Color(0xFF384254),
                Color(0xFF1C2330),
                Color(0xFF0B111B),
              ]
            : [
                _opacity(const Color(0xFFF7FBFF), 0.98),
                _opacity(const Color(0xFFDCE6F7), 0.95),
                _opacity(const Color(0xFFBCCBEB), 0.90),
              ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: rBig));
    canvas.drawCircle(center, rBig, outerFill);

    final innerDiscRadius = rBig * 0.9;
    final innerDisc = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(0, 0),
        radius: 0.9,
        colors: isDark
            ? const [
                Color(0xFF202938),
                Color(0xFF141B26),
                Color(0x00000000),
              ]
            : [
                _opacity(const Color(0xFFF5F8FF), 0.35),
                _opacity(const Color(0xFFD4DCF0), 0.16),
                const Color(0x00000000),
              ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerDiscRadius));
    canvas.drawCircle(center, innerDiscRadius, innerDisc);

    final centerWell = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(0, 0),
        radius: 0.72,
        colors: isDark
            ? const [
                Color(0x2AFFFFFF),
                Color(0x14131B26),
                Color(0x66090D14),
              ]
            : [
                _opacity(Colors.white, 0.68),
                _opacity(const Color(0xFFC3CCD8), 0.22),
                _opacity(const Color(0xFF8D99AE), 0.18),
              ],
        stops: const [0.0, 0.38, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: rBig * 0.62));
    canvas.drawCircle(center, rBig * 0.62, centerWell);

    final rimStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mainBorderW
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF8B7CFF),
                Color(0xFF57C7FF),
                Color(0xFF7AF0D2),
              ]
            : const [
                Color(0xFF7E6BFF),
                Color(0xFF3DBBFF),
                Color(0xFF42E6C8),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: rBig))
      ..isAntiAlias = true;
    canvas.drawCircle(center, rBig - (mainBorderW / 2), rimStroke);

    final rimGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mainBorderW + _blurExtraW
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _opacity(const Color(0xFF7C8CFF), isDark ? 0.42 : 0.28),
          _opacity(const Color(0xFF49C6FF), isDark ? 0.38 : 0.24),
          _opacity(const Color(0xFF52E6D4), isDark ? 0.34 : 0.22),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: rBig))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blurSigma)
      ..isAntiAlias = true;
    canvas.drawCircle(center, rBig * 0.99, rimGlow);

    final highlightArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = mainBorderW * 0.5
      ..color = _opacity(Colors.white, isDark ? 0.12 : 0.38)
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rBig * 0.9),
      -2.45,
      1.1,
      false,
      highlightArc,
    );

    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, mainBorderW * 0.2)
      ..color = _opacity(Colors.white, isDark ? 0.10 : 0.20)
      ..isAntiAlias = true;
    canvas.drawCircle(center, rBig * 0.78, innerRing);
  }

  void _drawCrossAxisGuides(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rBig = size.width / 2;
    final guideExtent = rBig * 0.82;
    final guideColor = isDark
        ? _opacity(const Color(0xFFF8FAFC), 0.20)
        : _opacity(const Color(0xFF334155), 0.24);
    final guideGlow = isDark
        ? _opacity(borderColor, 0.22)
        : _opacity(borderColor, 0.14);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..color = guideGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.35
      ..color = guideColor
      ..isAntiAlias = true;

    final horizontalStart = Offset(center.dx - guideExtent, center.dy);
    final horizontalEnd = Offset(center.dx + guideExtent, center.dy);
    final verticalStart = Offset(center.dx, center.dy - guideExtent);
    final verticalEnd = Offset(center.dx, center.dy + guideExtent);

    canvas.drawLine(horizontalStart, horizontalEnd, glowPaint);
    canvas.drawLine(verticalStart, verticalEnd, glowPaint);
    canvas.drawLine(horizontalStart, horizontalEnd, guidePaint);
    canvas.drawLine(verticalStart, verticalEnd, guidePaint);

    final centerDot = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark
          ? _opacity(borderColor, 0.34)
          : _opacity(borderColor, 0.30)
      ..isAntiAlias = true;
    canvas.drawCircle(center, 1.8, centerDot);
  }

  void _drawAxisGuide(Canvas canvas, Size size) {
    if (axisLock == JoystickAxisLock.none) return;
    final center = size.center(Offset.zero);
    final rBig = size.width / 2;
    final guideLen = rBig * 1.5;
    final guideColor = isDark
        ? _opacity(borderColor, 0.72)
        : _opacity(borderColor, 0.56);

    final paintGuide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 2.6 : 2.2
      ..strokeCap = StrokeCap.round
      ..color = guideColor
      ..isAntiAlias = true;

    if (axisLock == JoystickAxisLock.yOnly) {
      canvas.drawLine(
        Offset(center.dx, center.dy - guideLen / 2),
        Offset(center.dx, center.dy + guideLen / 2),
        paintGuide,
      );
    } else if (axisLock == JoystickAxisLock.xOnly) {
      canvas.drawLine(
        Offset(center.dx - guideLen / 2, center.dy),
        Offset(center.dx + guideLen / 2, center.dy),
        paintGuide,
      );
    }
  }

  void _drawKnob(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final paintKnob = Paint()
      ..color = knobColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center + knob, knobSize / 2, paintKnob);

    final paintKnobBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = joystickTheme.knobBorderWidth
      ..color = _opacity(
        joystickTheme.knobBorderColor,
        isDark ? 0.9 : 0.6,
      )
      ..isAntiAlias = true;

    canvas.drawCircle(center + knob, knobSize / 2, paintKnobBorder);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.knob != knob ||
        oldDelegate.hideKnob != hideKnob ||
        oldDelegate.hideBackground != hideBackground ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.knobColor != knobColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.knobSize != knobSize ||
        oldDelegate.axisLock != axisLock;
  }
}


