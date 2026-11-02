import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class GamepadButtonLayout {
  final double cx;
  final double cy;
  final double size;

  const GamepadButtonLayout(this.cx, this.cy, this.size);

  GamepadButtonLayout copyWith({double? cx, double? cy, double? size}) {
    return GamepadButtonLayout(cx ?? this.cx, cy ?? this.cy, size ?? this.size);
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'size': size};
}

class GamepadEditSpec<TVisual> {
  final String label;
  final String sendValue;
  final TVisual visual;

  const GamepadEditSpec(this.label, this.sendValue, this.visual);
}

Map<String, String> buildGamepadSuffixIdMap(List<String> ids) {
  final suffixMap = <String, String>{};
  for (final id in ids) {
    final parts = id.split(':');
    final key = parts.length > 1 ? parts[1] : id;
    suffixMap[key] = id;
  }
  return suffixMap;
}

Map<String, GamepadButtonLayout> buildDualClusterDefaultLayout(
  Size size,
  List<String> ids,
) {
  final w = size.width;
  final h = size.height;
  final s = math.min(w, h);
  final btn = s * 0.40;
  final gap = s * 0.10;
  final cy = h / 2;

  GamepadButtonLayout make(double x, double y) {
    return GamepadButtonLayout(x / w, y / h, btn / s);
  }

  final suffixMap = buildGamepadSuffixIdMap(ids);
  final out = <String, GamepadButtonLayout>{};
  final hasMove =
      suffixMap.containsKey('up') ||
      suffixMap.containsKey('down') ||
      suffixMap.containsKey('left') ||
      suffixMap.containsKey('right');
  final hasAction =
      suffixMap.containsKey('triangle') ||
      suffixMap.containsKey('cross') ||
      suffixMap.containsKey('square') ||
      suffixMap.containsKey('circle');

  if (hasMove) {
    final cxLeft = w * 0.28;
    if (suffixMap.containsKey('up')) {
      out[suffixMap['up']!] = make(cxLeft, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('down')) {
      out[suffixMap['down']!] = make(cxLeft, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('left')) {
      out[suffixMap['left']!] = make(cxLeft - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('right')) {
      out[suffixMap['right']!] = make(cxLeft + gap + btn / 2, cy);
    }
  }

  if (hasAction) {
    final cxRight = w * 0.72;
    if (suffixMap.containsKey('triangle')) {
      out[suffixMap['triangle']!] = make(cxRight, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('cross')) {
      out[suffixMap['cross']!] = make(cxRight, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('square')) {
      out[suffixMap['square']!] = make(cxRight - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('circle')) {
      out[suffixMap['circle']!] = make(cxRight + gap + btn / 2, cy);
    }
  }

  return out;
}

Map<String, GamepadButtonLayout> buildFourButtonDefaultLayout(
  Size safeSize,
  List<String> ids, {
  double buttonScale = 0.56,
}) {
  final w = safeSize.width;
  final h = safeSize.height;

  GamepadButtonLayout make(double xPx, double yPx) {
    return GamepadButtonLayout(
      (xPx / w).clamp(0.0, 1.0),
      (yPx / h).clamp(0.0, 1.0),
      buttonScale,
    );
  }

  final upDownX = w * 0.15;
  final upDownCenterY = h * 0.53;
  final upDownGap = h * 0.53;

  final leftRightCenterX = w * 0.84;
  final leftRightCenterY = h * 0.53;
  final leftRightGap = w * 0.17;

  final upY = upDownCenterY - (upDownGap / 2);
  final downY = upDownCenterY + (upDownGap / 2);
  final leftBtnX = leftRightCenterX - (leftRightGap / 2);
  final rightBtnX = leftRightCenterX + (leftRightGap / 2);

  final out = <String, GamepadButtonLayout>{};
  if (ids.contains('L:up')) {
    out['L:up'] = make(upDownX, upY);
  }
  if (ids.contains('L:down')) {
    out['L:down'] = make(upDownX, downY);
  }
  if (ids.contains('L:left')) {
    out['L:left'] = make(leftBtnX, leftRightCenterY);
  }
  if (ids.contains('L:right')) {
    out['L:right'] = make(rightBtnX, leftRightCenterY);
  }

  return out;
}

class GamepadEditGridPainter extends CustomPainter {
  final double step;
  final Color minorColor;
  final Color majorColor;

  const GamepadEditGridPainter({
    required this.step,
    required this.minorColor,
    required this.majorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (step <= 0) return;

    final minorPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = majorColor
      ..strokeWidth = 1.2;

    final countX = math.max(1, (1 / step).round());
    final countY = math.max(1, (1 / step).round());

    for (int i = 0; i <= countX; i++) {
      final x = size.width * i / countX;
      final paint = i % 2 == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int i = 0; i <= countY; i++) {
      final y = size.height * i / countY;
      final paint = i % 2 == 0 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamepadEditGridPainter oldDelegate) {
    return oldDelegate.step != step ||
        oldDelegate.minorColor != minorColor ||
        oldDelegate.majorColor != majorColor;
  }
}

class GamepadDashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const GamepadDashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(
      0.0,
      math.min(size.width, size.height) / 2 - strokeWidth,
    );
    final circumference = 2 * math.pi * radius;
    final dashWithGap = dashLength + gapLength;
    final count = math.max(1, (circumference / dashWithGap).floor());

    for (int i = 0; i < count; i++) {
      final startAngle = (i * dashWithGap / circumference) * 2 * math.pi;
      final sweepAngle = (dashLength / circumference) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GamepadDashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class GamepadEditAlignmentGuidesPainter extends CustomPainter {
  final Color color;
  final bool showVertical;
  final bool showHorizontal;
  final double? verticalX;
  final double? horizontalY;
  final double strokeWidth;

  const GamepadEditAlignmentGuidesPainter({
    required this.color,
    required this.showVertical,
    required this.showHorizontal,
    required this.verticalX,
    required this.horizontalY,
    this.strokeWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    if (showVertical && verticalX != null) {
      final x = verticalX!.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    if (showHorizontal && horizontalY != null) {
      final y = horizontalY!.clamp(0.0, 1.0) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamepadEditAlignmentGuidesPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.showVertical != showVertical ||
        oldDelegate.showHorizontal != showHorizontal ||
        oldDelegate.verticalX != verticalX ||
        oldDelegate.horizontalY != horizontalY ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class GamepadEditAlphaGlowLayer extends StatelessWidget {
  final Widget mask;
  final Color color;
  final double blurSigma;
  final double opacity;

  const GamepadEditAlphaGlowLayer({
    super.key,
    required this.mask,
    required this.color,
    required this.blurSigma,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: mask,
        ),
      ),
    );
  }
}

class GamepadEditSelectionVisual extends StatelessWidget {
  static const selectionColor = Color(0xFF00F0FF);
  static const warningColor = Color(0xFFEF4444);
  static const dimmedOpacity = 0.65;
  static const selectedScale = 1.03;
  static const haloBorderWidth = 2.5;
  static const outerGlowBlur = 7.0;
  static const outerGlowOpacity = 0.35;
  static const innerGlowBlur = 2.0;
  static const innerGlowOpacity = 0.80;
  static const animationDuration = Duration(milliseconds: 120);
  static const haloKey = ValueKey<String>('gamepad-edit-selection-halo');
  static const alphaGlowKey = ValueKey<String>(
    'gamepad-edit-selection-alpha-glow',
  );

  final bool selected;
  final bool dimmed;
  final bool warning;
  final Widget? selectionMask;
  final Widget child;

  const GamepadEditSelectionVisual({
    super.key,
    required this.selected,
    required this.dimmed,
    required this.warning,
    this.selectionMask,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final showHalo = selected || warning;
    final haloColor = warning ? warningColor : selectionColor;
    final fallbackShadows = !showHalo
        ? const <BoxShadow>[]
        : warning
        ? [
            BoxShadow(
              color: warningColor.withValues(alpha: 0.46),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ]
        : [
            BoxShadow(
              color: selectionColor.withValues(alpha: 0.28),
              blurRadius: 12,
            ),
          ];

    return AnimatedOpacity(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      opacity: dimmed ? dimmedOpacity : 1,
      child: AnimatedScale(
        duration: animationDuration,
        curve: Curves.easeOutCubic,
        scale: selected ? selectedScale : 1,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (selectionMask != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: animationDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: showHalo
                        ? Stack(
                            key: ValueKey<int>(haloColor.toARGB32()),
                            fit: StackFit.expand,
                            children: [
                              GamepadEditAlphaGlowLayer(
                                key: alphaGlowKey,
                                mask: selectionMask!,
                                color: haloColor,
                                blurSigma: outerGlowBlur,
                                opacity: outerGlowOpacity,
                              ),
                              GamepadEditAlphaGlowLayer(
                                mask: selectionMask!,
                                color: haloColor,
                                blurSigma: innerGlowBlur,
                                opacity: innerGlowOpacity,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(
                            key: ValueKey<String>('no-alpha-glow'),
                          ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    key: haloKey,
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: showHalo
                          ? Border.all(
                              color: haloColor,
                              width: warning ? 3 : haloBorderWidth,
                            )
                          : null,
                      boxShadow: fallbackShadows,
                    ),
                  ),
                ),
              ),
            ColorFiltered(
              colorFilter: selected
                  ? const ColorFilter.matrix([
                      1,
                      0,
                      0,
                      0,
                      16,
                      0,
                      1,
                      0,
                      0,
                      16,
                      0,
                      0,
                      1,
                      0,
                      16,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ])
                  : const ColorFilter.matrix([
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

String gamepadEditLockLabel({required bool isThai, required bool locked}) {
  if (locked) return isThai ? 'Unlock' : 'Unlock';
  return isThai ? 'Lock' : 'Lock';
}

class GamepadEditButtonShell extends StatelessWidget {
  final double left;
  final double top;
  final bool locked;
  final bool selected;
  final double selectedScale;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final VoidCallback? onTap;
  final List<BoxShadow> selectedShadows;
  final Widget child;

  const GamepadEditButtonShell({
    super.key,
    required this.left,
    required this.top,
    required this.locked,
    required this.selected,
    required this.selectedScale,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onTap,
    required this.selectedShadows,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onScaleStart: locked ? null : onScaleStart,
        onScaleUpdate: locked ? null : onScaleUpdate,
        onScaleEnd: locked ? null : onScaleEnd,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            selected ? selectedScale : 1.0,
            selected ? selectedScale : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            boxShadow: selected ? selectedShadows : const [],
          ),
          child: child,
        ),
      ),
    );
  }
}

class GamepadEditableButtonFrame extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final bool locked;
  final bool selected;
  final bool dimmed;
  final bool warning;
  final Widget? selectionMask;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final VoidCallback? onTap;
  final Widget child;

  const GamepadEditableButtonFrame({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.locked,
    required this.selected,
    required this.dimmed,
    required this.warning,
    this.selectionMask,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        // The whole frame takes taps and drags. The Joystick page wraps its
        // buttons in IgnorePointer (so they do not fire while editing); with
        // the default deferToChild nothing in the frame was hittable and
        // those buttons could never be selected, moved or deleted.
        behavior: HitTestBehavior.opaque,
        onScaleStart: locked ? null : onScaleStart,
        onScaleUpdate: locked ? null : onScaleUpdate,
        onScaleEnd: locked ? null : onScaleEnd,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: GamepadEditSelectionVisual(
            selected: selected,
            dimmed: dimmed,
            warning: warning,
            selectionMask: selectionMask,
            child: child,
          ),
        ),
      ),
    );
  }
}

class GamepadEditablePanel<T extends GamepadButtonLayout>
    extends StatefulWidget {
  final List<String> ids;
  final Map<String, T> layout;
  final ValueChanged<Map<String, T>> onLayoutChanged;
  final ValueChanged<Size> onPanelSize;
  final Map<String, T> Function(Size size, List<String> ids)
  defaultLayoutBuilder;
  final String? selectedId;
  final bool dimOthersWhenSelected;
  final List<String> Function(List<String> ids, Map<String, T> layout)?
  orderedIdsBuilder;
  final Widget Function(
    BuildContext context,
    String id,
    bool selected,
    bool dimmed,
    T layout,
    Map<String, T> allLayouts,
    Size panelSize,
  )
  itemBuilder;

  const GamepadEditablePanel({
    super.key,
    required this.ids,
    required this.layout,
    required this.onLayoutChanged,
    required this.onPanelSize,
    required this.defaultLayoutBuilder,
    this.selectedId,
    this.dimOthersWhenSelected = false,
    this.orderedIdsBuilder,
    required this.itemBuilder,
  });

  @override
  State<GamepadEditablePanel<T>> createState() =>
      _GamepadEditablePanelState<T>();
}

class _GamepadEditablePanelState<T extends GamepadButtonLayout>
    extends State<GamepadEditablePanel<T>> {
  late Map<String, T> _layout;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _layout = Map<String, T>.from(widget.layout);
  }

  @override
  void didUpdateWidget(covariant GamepadEditablePanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layout, widget.layout)) {
      _layout = Map<String, T>.from(widget.layout);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        widget.onPanelSize(size);
        final defaults = widget.defaultLayoutBuilder(size, widget.ids);

        bool changed = false;
        if (!_initialized) {
          _initialized = true;
        }

        for (final id in widget.ids) {
          final def = defaults[id];
          if (def != null && _layout[id] == null) {
            _layout[id] = def;
            changed = true;
          }
        }

        _layout.removeWhere((k, _) => !widget.ids.contains(k));

        if (changed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {});
            widget.onLayoutChanged(_layout);
          });
        }

        final orderedIds =
            widget.orderedIdsBuilder?.call(widget.ids, _layout) ?? widget.ids;

        return Stack(
          children: [
            for (final id in orderedIds)
              if (_layout[id] != null)
                widget.itemBuilder(
                  context,
                  id,
                  widget.selectedId == id,
                  widget.dimOthersWhenSelected &&
                      widget.selectedId != null &&
                      widget.selectedId != id,
                  _layout[id] as T,
                  _layout,
                  size,
                ),
          ],
        );
      },
    );
  }
}

class GamepadEditGestureController<T extends GamepadButtonLayout> {
  Offset? _startFocal;
  T? _startLayout;
  bool _isDragging = false;

  Offset get startFocal => _startFocal!;
  T get startLayout => _startLayout!;
  bool get isDragging => _isDragging;

  bool begin({
    required bool locked,
    required bool selected,
    required Offset focalPoint,
    required T layout,
    VoidCallback? onTapWhenUnselected,
    VoidCallback? onStart,
  }) {
    if (locked) return false;

    if (!selected) {
      onTapWhenUnselected?.call();
      return false;
    }

    _startFocal = focalPoint;
    _startLayout = layout;
    _isDragging = false;
    onStart?.call();
    return true;
  }

  void markDraggingIfMoved(
    Offset focalPoint, {
    double threshold = 1,
    ValueChanged<bool>? onDragState,
  }) {
    final start = _startFocal;
    if (start == null || _isDragging) return;
    final dx = focalPoint.dx - start.dx;
    final dy = focalPoint.dy - start.dy;
    final moved = dx.abs() > threshold || dy.abs() > threshold;
    if (moved) {
      _isDragging = true;
      onDragState?.call(true);
    }
  }

  void finish({ValueChanged<bool>? onDragState}) {
    if (_isDragging) {
      onDragState?.call(false);
    }
    _isDragging = false;
  }
}
