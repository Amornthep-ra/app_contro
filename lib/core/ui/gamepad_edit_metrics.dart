import 'dart:math' as math;

import 'package:flutter/material.dart';

class GamepadEditMetrics {
  static const double safeEdgePad = 12.0;
  static const double safeTopEdgePad = 4.0;
  static const double edgeWarnThresholdPx = 12.0;
  static const double maxPanelUnit = 520.0;
  static const double phoneLandscapeAspect = 844.0 / 390.0;

  /// Side of one square cell of the layout-editor grid, in logical pixels.
  static const double gridStep = 24.0;

  /// Snaps [offset] (logical pixels from the pad's top or left edge) to the
  /// nearest grid line. The grid is drawn from the same pad corner, so a
  /// snapped control centre sits exactly on a drawn line.
  static double snapToGrid(double offset) =>
      (offset / gridStep).roundToDouble() * gridStep;

  static double panelUnit(Size panel) {
    return math.min(panel.width, panel.height).clamp(0.0, maxPanelUnit);
  }

  static double sizePx(Size panel, double sizeFactor) {
    return sizeFactor * panelUnit(panel);
  }

  static Rect defaultLayoutFrame(Size panel) {
    final unit = panelUnit(panel);
    final frameWidth = math.min(panel.width, unit * phoneLandscapeAspect);
    final frameHeight = math.min(panel.height, unit);
    final left = (panel.width - frameWidth) / 2;
    final top = (panel.height - frameHeight) / 2;
    return Rect.fromLTWH(left, top, frameWidth, frameHeight);
  }
}
