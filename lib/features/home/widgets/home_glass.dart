// lib/features/home/widgets/home_glass.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Colors for the home screen, picked from the lavender cat background
/// (`assets/BG_Portrait.png`). One violet → cyan family only.
class HomePalette {
  HomePalette._();

  static const background = Color(0xFFF3EEFF);
  static const ink = Color(0xFF261B39);
  static const inkSoft = Color(0xA3261B39);
  static const inkMuted = Color(0x7A261B39);
  static const violet = Color(0xFF7256B6);
  static const violetDeep = Color(0xFF5B3FA0);
  static const violetBright = Color(0xFF8B6CF2);
  static const cyan = Color(0xFF37D8FF);
  static const cyanDeep = Color(0xFF0C8DB4);
  static const success = Color(0xFF1FBF95);
  static const warning = Color(0xFFF2A33A);
  static const coral = Color(0xFFF05264);

  static const brandGradient = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const String displayFont = 'Kanit';
}

/// Frosted-glass surface that lets the background show through.
///
/// The drop shadow is painted only *outside* the rounded shape, so it never
/// shows up as a square edge or muddies the translucent fill.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.tintStrength = 0.14,
    this.blurSigma = 18,
    this.shadowColor = HomePalette.violetDeep,
    this.shadowStrength = 1,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double tintStrength;
  final double blurSigma;
  final Color shadowColor;
  final double shadowStrength;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final filter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
    final tintColor = tint;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.44),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: tintColor == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tintColor.withValues(alpha: tintStrength),
                    tintColor.withValues(alpha: tintStrength * 0.25),
                  ],
                ),
        ),
        child: CustomPaint(
          foregroundPainter: _GlassRimPainter(radius: radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final group = BackdropGroup.of(context);
    return CustomPaint(
      painter: _OuterShadowPainter(
        radius: radius,
        color: shadowColor,
        strength: shadowStrength,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: group == null
            ? BackdropFilter(filter: filter, child: surface)
            : BackdropFilter.grouped(filter: filter, child: surface),
      ),
    );
  }
}

/// Thin light rim: bright on the top-left, fading toward the bottom-right,
/// like light catching the edge of glass.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(radius - 0.6),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.28),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({
    required this.radius,
    required this.color,
    required this.strength,
  });

  final double radius;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(80))
        ..addRRect(shape),
    );
    final shadows = <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.16 * strength),
        blurRadius: 30,
        spreadRadius: -6,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.07 * strength),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.strength != strength;
}

/// Primary call to action: violet → cyan pill with a soft glow.
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 50,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: HomePalette.brandGradient,
          boxShadow: [
            BoxShadow(
              color: HomePalette.violet.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DecoratedBox(
          // Top sheen for a glossy, lit-from-above finish.
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.6],
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              splashColor: Colors.white.withValues(alpha: 0.22),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: light glass pill with violet text.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 50,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: HomePalette.violet.withValues(alpha: 0.22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: HomePalette.violet.withValues(alpha: 0.12),
          highlightColor: HomePalette.violet.withValues(alpha: 0.06),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 19, color: HomePalette.violet),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: HomePalette.violetDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
