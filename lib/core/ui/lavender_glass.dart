// lib/core/ui/lavender_glass.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// "Lavender Glass" colors, picked from the lavender cat background
/// (`assets/BG_Portrait.png`). One violet → cyan family only.
class LavenderPalette {
  LavenderPalette._();

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
    this.shadowColor = LavenderPalette.violetDeep,
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

/// Content of an action pill: icon (or spinner) + label, scaled down to fit.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
            )
          else
            Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary call to action: violet → cyan pill with a soft glow.
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 50,
    this.busy = false,
    this.gradient = LavenderPalette.brandGradient,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;
  final bool busy;
  final Gradient gradient;

  static const dangerGradient = LinearGradient(
    colors: [Color(0xFFE8455A), Color(0xFFFF8A80)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height / 2);
    final enabled = onPressed != null;
    final glow = gradient == dangerGradient
        ? LavenderPalette.coral
        : LavenderPalette.violet;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled || busy ? 1 : 0.5,
        duration: const Duration(milliseconds: 160),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: enabled ? 0.30 : 0.12),
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
                      child: _ActionLabel(
                        label: label,
                        icon: icon,
                        color: Colors.white,
                        busy: busy,
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

/// Secondary action: light glass pill with violet (or [accent]) text.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 50,
    this.busy = false,
    this.accent = LavenderPalette.violet,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;
  final bool busy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height / 2);
    final enabled = onPressed != null;
    final textColor = accent == LavenderPalette.violet
        ? LavenderPalette.violetDeep
        : accent;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled || busy ? 1 : 0.5,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: Colors.white.withValues(alpha: 0.62),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: accent.withValues(alpha: 0.24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.06),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: _ActionLabel(
                    label: label,
                    icon: icon,
                    color: textColor,
                    busy: busy,
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

/// Small rounded status label, e.g. "✓ Paired" or "Last used".
class LavenderChip extends StatelessWidget {
  const LavenderChip({
    super.key,
    required this.label,
    this.icon,
    this.color = LavenderPalette.violet,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass confirmation dialog. Resolves to true only when confirmed.
Future<bool> showLavenderConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: LavenderPalette.ink.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) {
      final accent = destructive
          ? LavenderPalette.coral
          : LavenderPalette.violet;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                type: MaterialType.transparency,
                child: GlassPanel(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: 26),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: LavenderPalette.displayFont,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: LavenderPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: LavenderPalette.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GlassActionButton(
                              label: cancelLabel,
                              icon: Icons.close_rounded,
                              height: 48,
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GradientActionButton(
                              label: confirmLabel,
                              icon: destructive
                                  ? Icons.delete_outline_rounded
                                  : Icons.check_rounded,
                              height: 48,
                              gradient: destructive
                                  ? GradientActionButton.dangerGradient
                                  : LavenderPalette.brandGradient,
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}
