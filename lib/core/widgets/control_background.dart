// lib/core/widgets/control_background.dart
import 'package:flutter/material.dart';

import '../ui/app_assets.dart';
import '../ui/lavender_glass.dart';

/// Landscape background for the control pages (`assets/BG.png`, unchanged).
///
/// On short screens the controls end up on top of the cat artwork in the
/// bottom corners, so a soft lavender veil fades those corners back. The
/// veil starts below 400 px of height and is full strength at 340 px.
class ControlBackground extends StatelessWidget {
  const ControlBackground({super.key});

  static const double veilStartHeight = 400;
  static const double veilFullHeight = 340;

  /// 0 (no veil) … 1 (full veil) for a screen of [height] logical pixels.
  static double veilStrengthFor(double height) =>
      ((veilStartHeight - height) / (veilStartHeight - veilFullHeight)).clamp(
        0.0,
        1.0,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final strength = veilStrengthFor(constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.controlBackground,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            if (strength > 0)
              IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('control-background-veil'),
                  painter: _CornerVeilPainter(strength),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CornerVeilPainter extends CustomPainter {
  const _CornerVeilPainter(this.strength);

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    // Bottom-left cat with yarn, bottom-right cat house.
    for (final center in [
      Offset(size.width * 0.09, size.height * 0.92),
      Offset(size.width * 0.89, size.height * 0.92),
    ]) {
      final radius = size.width * 0.24;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              LavenderPalette.background.withValues(alpha: 0.78 * strength),
              LavenderPalette.background.withValues(alpha: 0.5 * strength),
              LavenderPalette.background.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_CornerVeilPainter oldDelegate) =>
      oldDelegate.strength != strength;
}
