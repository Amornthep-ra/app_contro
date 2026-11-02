// lib/core/widgets/ble_status_orb.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ble/ble_presentation_state.dart';
import '../ui/lavender_glass.dart';
import 'ble_presentation_icon.dart';

/// Round Bluetooth status indicator used by Home and the BLE page.
///
/// Connected/busy: violet → cyan orb (a comet ring spins while busy).
/// Failure: soft coral. Idle: white glass with a violet icon.
class BleStatusOrb extends StatefulWidget {
  const BleStatusOrb({
    super.key,
    required this.presentation,
    required this.animate,
    this.size = 58,
  });

  final BlePresentationState presentation;
  final bool animate;
  final double size;

  @override
  State<BleStatusOrb> createState() => _BleStatusOrbState();
}

class _BleStatusOrbState extends State<BleStatusOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(BleStatusOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final busy = widget.presentation.isBusy && widget.animate;
    if (busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!busy && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.presentation;
    final tone = presentation.tone;
    final icon = materialIconForBlePresentation(presentation.icon);
    final filled =
        tone == BlePresentationTone.connected ||
        tone == BlePresentationTone.busy;

    final Decoration decoration = switch (tone) {
      BlePresentationTone.connected ||
      BlePresentationTone.busy => BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LavenderPalette.violet, LavenderPalette.cyan],
        ),
        boxShadow: [
          BoxShadow(
            color: LavenderPalette.cyan.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      BlePresentationTone.failure => BoxDecoration(
        shape: BoxShape.circle,
        color: LavenderPalette.coral.withValues(alpha: 0.12),
        border: Border.all(
          color: LavenderPalette.coral.withValues(alpha: 0.30),
        ),
      ),
      BlePresentationTone.neutral => BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            const Color(0xFFEDE5FF),
          ],
        ),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: LavenderPalette.violetDeep.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    };

    final iconColor = switch (tone) {
      BlePresentationTone.failure => LavenderPalette.coral,
      BlePresentationTone.neutral => LavenderPalette.violet,
      _ => Colors.white,
    };

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: DecoratedBox(decoration: decoration)),
          if (filled)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: RotationTransition(
                  turns: _spin,
                  child: CustomPaint(
                    painter: _OrbRingPainter(sweep: presentation.isBusy),
                  ),
                ),
              ),
            ),
          Icon(icon, size: widget.size * 0.45, color: iconColor),
        ],
      ),
    );
  }
}

/// Inner light ring: a full soft ring when connected, a comet arc when busy.
class _OrbRingPainter extends CustomPainter {
  const _OrbRingPainter({required this.sweep});

  final bool sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    if (sweep) {
      paint.shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.95),
        ],
      ).createShader(rect);
      canvas.drawArc(rect.deflate(1), 0, math.pi * 1.6, false, paint);
    } else {
      paint.color = Colors.white.withValues(alpha: 0.45);
      canvas.drawOval(rect.deflate(1), paint);
    }
  }

  @override
  bool shouldRepaint(_OrbRingPainter oldDelegate) => oldDelegate.sweep != sweep;
}
