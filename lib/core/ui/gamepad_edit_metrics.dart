import 'dart:math' as math;

import 'package:flutter/material.dart';

class GamepadEditMetrics {
  static const double safeEdgePad = 12.0;
  static const double safeTopEdgePad = 4.0;
  static const double edgeWarnThresholdPx = 12.0;
  static const double maxPanelUnit = 520.0;
  static const double phoneLandscapeAspect = 844.0 / 390.0;

  /// Side of one square cell of the layout-editor grid, in logical pixels.
  static const double gridStep = 12.0;

  /// Snaps [offset] (logical pixels from the pad's top or left edge) to the
  /// nearest grid line. The grid is drawn from the same pad corner, so a
  /// snapped control centre sits exactly on a drawn line.
  static double snapToGrid(double offset) =>
      (offset / gridStep).roundToDouble() * gridStep;

  /// Smallest clear space the layout editor keeps between two controls'
  /// visible edges, in logical pixels (see [buttonVisibleRadius]).
  static const double minControlGap = 4.0;

  /// Share of a button image that is the visible round face. The button
  /// PNGs (`assets/icons/Gamepad_Mode_Edit/`) are about 11.5 % transparent
  /// on each side (10-15 %), so the face spans ~77 % of the image.
  static const double buttonArtworkFraction = 0.766;

  /// Inset of the image inside a drive-mode image button's box
  /// (`GamepadImageHoldButton`, the Joystick face buttons).
  static const double buttonImageInset = 2.0;

  /// Radius of the visible face of an image button drawn in a square box
  /// of side [boxSide] (image [buttonImageInset] inside, BoxFit.contain).
  static double buttonVisibleRadius(double boxSide) =>
      math.max(0.0, boxSide - 2 * buttonImageInset) * buttonArtworkFraction / 2;

  /// Touch radius for a control at [centre]: its visible circle plus half
  /// the clear space to the nearest of [others] (centre, visible radius),
  /// never more than [maxRadius] (the control's box) and never less than
  /// its visible circle. Two neighbours' touch circles therefore never
  /// overlap, however close they are placed.
  static double touchRadius({
    required Offset centre,
    required double visibleRadius,
    required double maxRadius,
    required Iterable<(Offset, double)> others,
  }) {
    var radius = maxRadius;
    for (final (otherCentre, otherRadius) in others) {
      final gap = (centre - otherCentre).distance - visibleRadius - otherRadius;
      radius = math.min(radius, visibleRadius + math.max(0.0, gap) / 2);
    }
    return math.max(radius, math.min(visibleRadius, maxRadius));
  }

  /// The point closest to [to] on the straight way from [from] that
  /// [blocked] accepts, so a drag into a neighbour slides up to it instead
  /// of stopping where the last accepted update happened to be.
  static Offset slideToward({
    required Offset from,
    required Offset to,
    required bool Function(Offset centre) blocked,
  }) {
    if (!blocked(to)) return to;
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      if (blocked(Offset.lerp(from, to, mid)!)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return Offset.lerp(from, to, lo)!;
  }

  /// Whether moving or resizing a round control from ([fromCentre],
  /// [fromRadius]) to ([toCentre], [toRadius]) crowds a neighbour at
  /// [otherCentre] with [otherRadius]: the edge-to-edge gap ends up below
  /// [minControlGap] and smaller than it already was.
  ///
  /// Changes that keep or widen the gap are always allowed, so controls an
  /// older layout placed closer together can still be pulled apart.
  static bool crowdsNeighbour({
    required Offset fromCentre,
    required double fromRadius,
    required Offset toCentre,
    required double toRadius,
    required Offset otherCentre,
    required double otherRadius,
  }) {
    final gapAfter = (toCentre - otherCentre).distance - toRadius - otherRadius;
    if (gapAfter >= minControlGap) return false;
    final gapBefore =
        (fromCentre - otherCentre).distance - fromRadius - otherRadius;
    return gapAfter < gapBefore - 0.01;
  }

  /// Where to put a control that is being added to the pad.
  ///
  /// [preferred] (kept inside [centreArea]) when it leaves at least
  /// [minControlGap] to every control in [others] (centre, radius);
  /// otherwise the nearest point of the editor grid inside [centreArea]
  /// that does. When nothing is free, [preferred] is returned and the user
  /// can drag the control apart (moves that widen a gap are always allowed).
  static Offset freeSpotFor({
    required Offset preferred,
    required double radius,
    required Rect centreArea,
    required Iterable<(Offset, double)> others,
  }) {
    if (centreArea.width < 0 || centreArea.height < 0) return preferred;
    final placed = others.toList();
    bool isFree(Offset centre) => placed.every(
      (other) =>
          (centre - other.$1).distance - radius - other.$2 >= minControlGap,
    );
    final start = Offset(
      preferred.dx.clamp(centreArea.left, centreArea.right),
      preferred.dy.clamp(centreArea.top, centreArea.bottom),
    );
    if (isFree(start)) return start;
    Offset? best;
    var bestDistance = double.infinity;
    final firstX = (centreArea.left / gridStep).ceil() * gridStep;
    final firstY = (centreArea.top / gridStep).ceil() * gridStep;
    for (var x = firstX; x <= centreArea.right; x += gridStep) {
      for (var y = firstY; y <= centreArea.bottom; y += gridStep) {
        final candidate = Offset(x, y);
        final distance = (candidate - start).distanceSquared;
        if (distance >= bestDistance || !isFree(candidate)) continue;
        best = candidate;
        bestDistance = distance;
      }
    }
    return best ?? start;
  }

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
