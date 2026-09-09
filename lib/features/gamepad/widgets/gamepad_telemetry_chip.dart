import 'package:flutter/material.dart';
import '../../../core/widgets/gamepad_control_toolbar.dart';

import '../../../core/widgets/gamepad_app_bar.dart';

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

class GamepadTelemetryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final GamepadAppBarMetrics? metrics;
  final Color? accentColor;
  final String? iconAsset;
  final bool subdued;
  final bool showLabel;

  const GamepadTelemetryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.metrics,
    this.accentColor,
    this.iconAsset,
    this.subdued = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (GamepadControlScope.of(context) != null) {
      return GamepadControlPill(
        label: showLabel && label.isNotEmpty ? '$label $value' : value,
        accent: label == 'JL'
            ? const Color(0xFF69BFD1)
            : const Color(0xFF9B6BCC),
      );
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appBarMetrics =
        metrics ??
        GamepadAppBarMetrics.forWidth(MediaQuery.of(context).size.width);
    final accent = accentColor ?? cs.primary;
    final textTarget = isDark ? Colors.white : cs.onSurface;
    final surface =
        Color.lerp(
          isDark ? const Color(0xFF101827) : cs.surface,
          isDark ? Colors.white : Colors.black,
          isDark ? 0.04 : 0.02,
        ) ??
        cs.surface;
    final border = _opacity(cs.outline, isDark ? 0.45 : 0.22);
    final labelColor =
        Color.lerp(accent, textTarget, isDark ? 0.42 : 0.62) ?? textTarget;
    final valueColor =
        Color.lerp(accent, textTarget, isDark ? 0.56 : 0.74) ?? textTarget;

    return SizedBox(
      width: appBarMetrics.labelButtonWidth,
      child: Container(
        key: const ValueKey('gamepad-visual-control-surface'),
        constraints: BoxConstraints(minHeight: appBarMetrics.controlHeight),
        alignment: Alignment.center,
        padding: appBarMetrics.contentPadding,
        decoration: BoxDecoration(
          color: _opacity(surface, subdued ? 0.72 : (isDark ? 0.92 : 0.97)),
          borderRadius: appBarMetrics.borderRadius,
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: _opacity(
                Colors.black,
                subdued ? 0.035 : (isDark ? 0.22 : 0.06),
              ),
              blurRadius: subdued ? 5 : 10,
              offset: Offset(0, subdued ? 2 : 4),
            ),
            BoxShadow(
              color: _opacity(Colors.white, isDark ? 0.06 : 0.16),
              blurRadius: 10,
              spreadRadius: 0.4,
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                if (showLabel && label.isNotEmpty)
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      fontSize: appBarMetrics.telemetryLabelFontSize,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                      letterSpacing: 0.12,
                    ),
                  ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: appBarMetrics.telemetryValueFontSize,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: valueColor,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(height: 1),
          ),
        ),
      ),
    );
  }
}
