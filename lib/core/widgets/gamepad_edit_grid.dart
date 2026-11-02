import 'package:flutter/material.dart';

import '../ui/gamepad_edit_metrics.dart';

/// Square grid for the controller layout editor.
///
/// Place it over exactly the area the controls are positioned in (the same
/// box whose size the editor uses to place and snap them), so its lines are
/// where [GamepadEditMetrics.snapToGrid] puts control centres. Every fourth
/// line is darker. It ignores touches.
class GamepadEditGrid extends StatelessWidget {
  const GamepadEditGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('gamepad-edit-grid'),
        painter: _GamepadEditGridPainter(
          minorColor: base.withValues(alpha: isDark ? 0.14 : 0.16),
          majorColor: base.withValues(alpha: isDark ? 0.24 : 0.30),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GamepadEditGridPainter extends CustomPainter {
  const _GamepadEditGridPainter({
    required this.minorColor,
    required this.majorColor,
  });

  final Color minorColor;
  final Color majorColor;

  static const int _majorEvery = 4;

  @override
  void paint(Canvas canvas, Size size) {
    const step = GamepadEditMetrics.gridStep;
    final paint = Paint()..strokeWidth = 1;
    var index = 1;
    for (var x = step; x < size.width; x += step, index++) {
      paint.color = index % _majorEvery == 0 ? majorColor : minorColor;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    index = 1;
    for (var y = step; y < size.height; y += step, index++) {
      paint.color = index % _majorEvery == 0 ? majorColor : minorColor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GamepadEditGridPainter oldDelegate) =>
      oldDelegate.minorColor != minorColor ||
      oldDelegate.majorColor != majorColor;
}
