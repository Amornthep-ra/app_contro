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

  /// Smallest clear space the layout editor keeps between two controls'
  /// touch areas, in logical pixels.
  static const double minControlGap = 6.0;

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

  /// A control's saved position read back from storage: centre as
  /// fractions of the pad (kept within 0..1) and size kept within
  /// [minSize]..[maxSize] ([defaultSize] when missing). Null when the entry
  /// is unusable, so the control falls back to its default spot.
  static ({double cx, double cy, double size})? readSavedLayout(
    Object? raw, {
    required double minSize,
    required double maxSize,
    required double defaultSize,
  }) {
    if (raw is! Map) return null;
    double? finite(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : null;
    final cx = finite(raw['cx']);
    final cy = finite(raw['cy']);
    if (cx == null || cy == null) return null;
    final size = finite(raw['size']) ?? defaultSize;
    return (
      cx: cx.clamp(0.0, 1.0),
      cy: cy.clamp(0.0, 1.0),
      size: size.clamp(minSize, maxSize),
    );
  }

  /// Fits round controls (centre, radius) into [panel], in order.
  ///
  /// Each centre is kept far enough inside [pad] for the whole control to
  /// show. A control that then overlaps one placed before it moves to the
  /// nearest free spot ([freeSpotFor]). Layouts saved on another screen size
  /// or shape can otherwise land past the edge or on top of each other.
  /// Controls that are merely closer than [minControlGap] stay where they
  /// are, as the editor allows. Returns the centres in the same order.
  static List<Offset> fitLayout({
    required Size panel,
    required EdgeInsets pad,
    required List<(Offset, double)> controls,
  }) {
    final placed = <(Offset, double)>[];
    for (final (centre, radius) in controls) {
      final area = Rect.fromLTRB(
        pad.left + radius,
        pad.top + radius,
        panel.width - pad.right - radius,
        panel.height - pad.bottom - radius,
      );
      double fit(double value, double min, double max) =>
          max < min ? (min + max) / 2 : value.clamp(min, max);
      var spot = Offset(
        fit(centre.dx, area.left, area.right),
        fit(centre.dy, area.top, area.bottom),
      );
      final overlaps = placed.any(
        (other) => (spot - other.$1).distance < radius + other.$2 - 0.5,
      );
      if (overlaps) {
        spot = freeSpotFor(
          preferred: spot,
          radius: radius,
          centreArea: area,
          others: placed,
        );
      }
      placed.add((spot, radius));
    }
    return [for (final p in placed) p.$1];
  }

  /// [ids] with the ones that have a saved spot ([isSaved]) first, so
  /// [fitLayout] keeps where the user put a control and moves a control
  /// sitting at its default spot instead. Order is otherwise kept.
  static List<String> savedFirst(
    Iterable<String> ids,
    bool Function(String id) isSaved,
  ) => [...ids.where(isSaved), ...ids.where((id) => !isSaved(id))];

  static double panelUnit(Size panel) {
    return math.min(panel.width, panel.height).clamp(0.0, maxPanelUnit);
  }

  /// Smallest diameter a button is drawn and touched at, in logical pixels:
  /// the common minimum touch target (Material 48 dp, Apple 44 pt).
  static const double minTouchDiameter = 48.0;

  /// Diameter of a control whose size is [sizeFactor] × [basePx], never
  /// below [minDiameter], so a layout from a larger screen stays pressable.
  static double diameterFor(
    double sizeFactor,
    double basePx, {
    double minDiameter = minTouchDiameter,
  }) => math.max(sizeFactor * basePx, minDiameter);

  /// Smallest size factor the editor offers on this screen: [minFactor],
  /// raised so the control is still at least [minDiameter] across.
  static double minSizeFactor(
    double minFactor,
    double basePx, {
    double minDiameter = minTouchDiameter,
  }) => basePx <= 0 ? minFactor : math.max(minFactor, minDiameter / basePx);

  /// [diameter], but no larger than fits inside [panel] with [margin] on
  /// both sides (a very short pad, e.g. under a large-text toolbar, would
  /// otherwise get a control taller than itself).
  static double fitDiameter(double diameter, Size panel, double margin) =>
      math.min(diameter, math.max(0.0, panel.shortestSide - 2 * margin));

  /// Diameter of a gamepad button of [sizeFactor] on [panel].
  static double sizePx(Size panel, double sizeFactor) {
    return fitDiameter(
      diameterFor(sizeFactor, panelUnit(panel)),
      panel,
      (safeEdgePad + safeTopEdgePad) / 2,
    );
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
