import 'dart:math' as math;

import 'package:flutter/material.dart';

class GamepadLayoutData {
  final double cx;
  final double cy;
  final double size;

  const GamepadLayoutData(this.cx, this.cy, this.size);
}

class GamepadEditResult {
  final GamepadLayoutData layout;
  final bool snappedX;
  final bool snappedY;
  final double? guideV;
  final double? guideH;
  final bool edgeLeft;
  final bool edgeRight;
  final bool edgeTop;
  final bool edgeBottom;
  final bool collides;

  const GamepadEditResult({
    required this.layout,
    required this.snappedX,
    required this.snappedY,
    required this.guideV,
    required this.guideH,
    required this.edgeLeft,
    required this.edgeRight,
    required this.edgeTop,
    required this.edgeBottom,
    required this.collides,
  });
}

class GamepadEditController {
  final double safeEdgePad;
  final double snapThresholdPx;
  final double gridStep;
  final double minSize;
  final double maxSize;
  final double edgeEpsilon;

  const GamepadEditController({
    this.safeEdgePad = 16,
    this.snapThresholdPx = 5,
    this.gridStep = 0.05,
    this.minSize = 0.18,
    this.maxSize = 0.60,
    this.edgeEpsilon = 0.6,
  });

  double _snapToGrid(double value) {
    if (gridStep <= 0) return value;
    return (value / gridStep).round() * gridStep;
  }

  GamepadEditResult updateButtonPosition(
    Offset newPos, {
    required Offset startFocal,
    required GamepadLayoutData startLayout,
    required Size panelSize,
    required double scale,
    required bool snapToGrid,
    required Map<String, GamepadLayoutData> allLayouts,
    required String selfId,
  }) {
    final w = panelSize.width;
    final h = panelSize.height;
    final safeW = math.max(1.0, w - safeEdgePad * 2);
    final safeH = math.max(1.0, h - safeEdgePad * 2);
    final s = math.min(safeW, safeH);

    final dx = newPos.dx - startFocal.dx;
    final dy = newPos.dy - startFocal.dy;

    final size = (startLayout.size * scale).clamp(minSize, maxSize);
    final sizePx = size * s;
    final half = sizePx / 2;

    double cx = safeEdgePad + startLayout.cx * safeW + dx;
    double cy = safeEdgePad + startLayout.cy * safeH + dy;

    if (snapToGrid) {
      final nx = _snapToGrid((cx - safeEdgePad) / safeW);
      final ny = _snapToGrid((cy - safeEdgePad) / safeH);
      cx = safeEdgePad + nx * safeW;
      cy = safeEdgePad + ny * safeH;
    }

    double? snapX;
    double? snapY;
    var bestDx = snapThresholdPx + 1;
    var bestDy = snapThresholdPx + 1;

    final centerX = safeEdgePad + safeW / 2;
    final centerY = safeEdgePad + safeH / 2;
    final dxCenter = (cx - centerX).abs();
    if (dxCenter <= snapThresholdPx) {
      snapX = centerX;
      bestDx = dxCenter;
    }
    final dyCenter = (cy - centerY).abs();
    if (dyCenter <= snapThresholdPx) {
      snapY = centerY;
      bestDy = dyCenter;
    }

    allLayouts.forEach((id, layout) {
      if (id == selfId) return;
      final ox = safeEdgePad + layout.cx * safeW;
      final oy = safeEdgePad + layout.cy * safeH;
      final dx = (cx - ox).abs();
      final dy = (cy - oy).abs();
      if (dx <= snapThresholdPx && dx < bestDx) {
        snapX = ox;
        bestDx = dx;
      }
      if (dy <= snapThresholdPx && dy < bestDy) {
        snapY = oy;
        bestDy = dy;
      }
    });

    if (snapX != null) cx = snapX!;
    if (snapY != null) cy = snapY!;

    final minX = safeEdgePad + half;
    final maxX = safeEdgePad + safeW - half;
    final minY = safeEdgePad + half;
    final maxY = safeEdgePad + safeH - half;

    cx = cx.clamp(minX, maxX);
    cy = cy.clamp(minY, maxY);

    final hitLeft = (cx - minX).abs() <= edgeEpsilon;
    final hitRight = (cx - maxX).abs() <= edgeEpsilon;
    final hitTop = (cy - minY).abs() <= edgeEpsilon;
    final hitBottom = (cy - maxY).abs() <= edgeEpsilon;

    final guideV = snapX != null ? (snapX! / w) : null;
    final guideH = snapY != null ? (snapY! / h) : null;

    final collides = checkCollisions(
      centerPx: Offset(cx, cy),
      size: size,
      panelSize: panelSize,
      allLayouts: allLayouts,
      selfId: selfId,
    );

    return GamepadEditResult(
      layout: GamepadLayoutData(
        (cx - safeEdgePad) / safeW,
        (cy - safeEdgePad) / safeH,
        size,
      ),
      snappedX: snapX != null,
      snappedY: snapY != null,
      guideV: guideV,
      guideH: guideH,
      edgeLeft: hitLeft,
      edgeRight: hitRight,
      edgeTop: hitTop,
      edgeBottom: hitBottom,
      collides: collides,
    );
  }

  bool checkCollisions({
    required Offset centerPx,
    required double size,
    required Size panelSize,
    required Map<String, GamepadLayoutData> allLayouts,
    required String selfId,
  }) {
    final safeW = math.max(1.0, panelSize.width - safeEdgePad * 2);
    final safeH = math.max(1.0, panelSize.height - safeEdgePad * 2);
    final s = math.min(safeW, safeH);
    final sizePx = size * s;

    for (final entry in allLayouts.entries) {
      if (entry.key == selfId) continue;
      final other = entry.value;
      final ox = safeEdgePad + other.cx * safeW;
      final oy = safeEdgePad + other.cy * safeH;
      final otherSizePx = other.size * s;
      final minDist = (sizePx / 2) + (otherSizePx / 2);
      final dx = centerPx.dx - ox;
      final dy = centerPx.dy - oy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minDist) return true;
    }
    return false;
  }
}
