// lib/core/widgets/control_start_stop.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gamepad_appbar_controls.dart';
import 'gamepad_control_toolbar.dart';

/// Start / Emergency Stop in the control toolbar.
///
/// Same 48 px as Back and Settings and always in the same place: right after
/// Back. Only the artwork: no glow, halo or breathing ring (they were cut
/// off by the cat ears, paw and tail). "Tap Start to drive" points at it
/// while control is off.
class ControlStartStopButton extends StatelessWidget {
  const ControlStartStopButton({
    super.key,
    required this.started,
    required this.busy,
    required this.onPressed,
  });

  static const double size = 48;

  final bool started;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GamepadStartStopControlButton(
      diameter: size,
      isStarted: started,
      isBusy: busy,
      onPressed: onPressed,
    );
  }
}

/// "Tap Start to drive" label just under the toolbar, pointing up at Start.
///
/// Place it as a child of the Stack that holds the controls (directly below
/// the app bar). It ignores touches; the controls are locked while it shows.
class ControlStartHint extends StatelessWidget {
  const ControlStartHint({
    super.key,
    required this.visible,
    required this.anchorX,
    this.label = 'Tap Start to drive',
  });

  final bool visible;

  /// Horizontal centre of the Start button, from the left of the body.
  final double anchorX;
  final String label;

  /// Centre of the Start slot in a toolbar measured with
  /// `leadingCount: 2` (Back, then Start/Stop), including its 12 px padding.
  static double anchorXFor(GamepadControlLayout layout) =>
      12 + layout.widths[0] + layout.gapBefore(1) + layout.widths[1] / 2;

  @override
  Widget build(BuildContext context) {
    // Arrow sits under Start: chip padding (12) + half the icon (8).
    return Positioned(
      left: math.max(4, anchorX - 20),
      top: 6,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: !visible
              ? const SizedBox.shrink()
              : MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Semantics(
                    liveRegion: true,
                    label: label,
                    child: Container(
                      key: const ValueKey('start-hint'),
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: Color(0xFF15803D),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Tap Start to drive',
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFF261B39),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
