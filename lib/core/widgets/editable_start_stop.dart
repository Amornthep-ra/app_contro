import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../ui/ambient_motion.dart';
import 'gamepad_appbar_controls.dart';

const startStopEditId = 'system:start_stop';

@immutable
class StartStopPlacement {
  const StartStopPlacement({
    this.cx = .5,
    this.cy = 1,
    this.scale = defaultScale,
  });
  final double cx;
  final double cy;
  final double scale;

  /// 72 px: Start/Stop is the emergency stop, so it is the largest system
  /// control by default.
  static const double defaultScale = 1.5;

  /// Size every page saved automatically before [defaultScale] existed.
  static const double _legacyDefaultScale = 1;

  /// Bumped when saved data must be told apart from older app versions.
  static const int _formatVersion = 2;

  static StartStopPlacement fromJson(Object? value) {
    if (value is! Map) return const StartStopPlacement();
    double read(String key, double fallback, double min, double max) {
      final raw = value[key];
      return raw is num && raw.isFinite
          ? raw.toDouble().clamp(min, max)
          : fallback;
    }

    var scale = read('scale', defaultScale, .75, 2);
    // Older versions saved the 48 px default on every visit, so an untouched
    // legacy 1.0 means "never resized": use the new default. Sizes the user
    // actually chose (anything else, or data saved by this version) stay.
    if (value['v'] == null && scale == _legacyDefaultScale) {
      scale = defaultScale;
    }
    return StartStopPlacement(
      cx: read('cx', .5, 0, 1),
      cy: read('cy', 1, 0, 1),
      scale: scale,
    );
  }

  Map<String, num> toJson() => {
    'v': _formatVersion,
    'cx': cx,
    'cy': cy,
    'scale': scale,
  };
  double get diameter => 48 * scale;
  double get hitSize => math.max(48, diameter);
}

/// Marks the actual control bounds for collision checks, including defaults.
class StartStopObstacle extends SingleChildRenderObjectWidget {
  const StartStopObstacle({super.key, required super.child});
  @override
  RenderProxyBox createRenderObject(BuildContext context) => _ObstacleBox();
}

class _ObstacleBox extends RenderProxyBox {}

class EditableStartStopSurface extends StatefulWidget {
  const EditableStartStopSurface({
    super.key,
    required this.placement,
    required this.editing,
    required this.selected,
    required this.snapToGrid,
    required this.started,
    required this.busy,
    required this.onPressed,
    required this.onSelect,
    required this.onBeginChange,
    required this.onChanged,
    required this.onBlocked,
    required this.child,
    this.startHint = 'Tap Start to drive',
  });
  final StartStopPlacement placement;

  /// Shown next to Start while control is off. Null hides it.
  final String? startHint;
  final bool editing, selected, snapToGrid, started, busy;
  final VoidCallback? onPressed;
  final VoidCallback onSelect, onBeginChange, onBlocked;
  final ValueChanged<StartStopPlacement> onChanged;
  final Widget child;

  static bool blocks(BuildContext context, Rect localRect) {
    final state = context
        .findAncestorStateOfType<EditableStartStopSurfaceState>();
    return state?.blocksRect(localRect) ?? false;
  }

  @override
  State<EditableStartStopSurface> createState() =>
      EditableStartStopSurfaceState();
}

class EditableStartStopSurfaceState extends State<EditableStartStopSurface> {
  final _controlsKey = GlobalKey();
  Size _size = Size.zero;
  Rect _displayRect = Rect.zero;
  StartStopPlacement? _drag;
  Offset? _dragCenter;
  List<Rect> _obstacles = [];
  bool _scanScheduled = false;
  bool _wasEditing = false;
  Rect? _editRect;

  @override
  void didUpdateWidget(covariant EditableStartStopSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.placement;
    final next = widget.placement;
    if (_drag == null &&
        (old.cx != next.cx || old.cy != next.cy || old.scale != next.scale)) {
      _editRect = _size.isEmpty ? null : _clamp(next);
    }
  }

  Rect _clamp(StartStopPlacement value) {
    final side = value.hitSize;
    final x = (value.cx * _size.width).clamp(
      math.min(side / 2 + 12, _size.width / 2),
      math.max(_size.width - side / 2 - 12, _size.width / 2),
    );
    final y = (value.cy * _size.height).clamp(
      math.min(side / 2 + 12, _size.height / 2),
      math.max(_size.height - side / 2 - 12, _size.height / 2),
    );
    return Rect.fromCenter(
      center: Offset(x.toDouble(), y.toDouble()),
      width: side,
      height: side,
    );
  }

  bool blocksRect(Rect rect) => rect.overlaps(_displayRect);

  bool _clear(Rect rect) => !_obstacles.any((other) => rect.overlaps(other));
  Rect _resolve(StartStopPlacement value) {
    final requested = _clamp(value);
    if (_clear(requested)) return requested;
    // Search deterministic nearest free space without changing saved placement.
    Rect? best;
    var distance = double.infinity;
    for (
      double y = 12 + value.hitSize / 2;
      y <= _size.height - 12 - value.hitSize / 2;
      y += 8
    ) {
      for (
        double x = 12 + value.hitSize / 2;
        x <= _size.width - 12 - value.hitSize / 2;
        x += 8
      ) {
        final rect = Rect.fromCenter(
          center: Offset(x, y),
          width: value.hitSize,
          height: value.hitSize,
        );
        final d = (rect.center - requested.center).distanceSquared;
        if (d < distance && _clear(rect)) {
          best = rect;
          distance = d;
        }
      }
    }
    // In a completely packed old layout the system button stays on top,
    // so Stop remains reachable rather than disappearing.
    return best ?? requested;
  }

  void _scan() {
    _scanScheduled = false;
    if (!mounted) return;
    final root = context.findRenderObject();
    final controls = _controlsKey.currentContext?.findRenderObject();
    if (root is! RenderBox || controls == null) return;
    final next = <Rect>[];
    void visit(RenderObject object) {
      if (object is _ObstacleBox && object.hasSize) {
        final origin = root.globalToLocal(object.localToGlobal(Offset.zero));
        next.add(origin & object.size);
      } else {
        object.visitChildren(visit);
      }
    }

    visit(controls);
    if (next.length != _obstacles.length ||
        List.generate(
          next.length,
          (i) => next[i] != _obstacles[i],
        ).any((v) => v)) {
      setState(() => _obstacles = next);
    }
  }

  void adjustSize(double delta) {
    if (!widget.editing || _size.isEmpty) return;
    final scale = (widget.placement.scale + delta).clamp(.75, 2.0);
    if (scale == widget.placement.scale) {
      widget.onBlocked();
      return;
    }
    final next = StartStopPlacement(
      cx: _displayRect.center.dx / _size.width,
      cy: _displayRect.center.dy / _size.height,
      scale: scale,
    );
    final rect = _clamp(next);
    if (!_clear(rect) || (rect.center - _displayRect.center).distance > .1) {
      widget.onBlocked();
      return;
    }
    widget.onBeginChange();
    _editRect = rect;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final value = _drag ?? widget.placement;
      if (widget.editing && !_wasEditing) {
        _editRect = _displayRect.isEmpty ? _resolve(value) : _displayRect;
      } else if (!widget.editing) {
        _editRect = null;
      }
      _wasEditing = widget.editing;
      _displayRect = _drag != null
          ? _clamp(value)
          : widget.editing
          ? (_editRect ?? _clamp(value))
          : _resolve(value);
      if (!_scanScheduled) {
        _scanScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
      }
      final waitingForStart =
          !widget.editing && !widget.started && !widget.busy;
      final Widget button = _StartPulse(
        active: waitingForStart && AmbientMotion.enabledFor(context),
        diameter: value.diameter,
        child: GamepadStartStopControlButton(
          heroTag: 'editable_start_stop',
          diameter: value.diameter,
          isStarted: widget.editing ? false : widget.started,
          isBusy: widget.editing ? false : widget.busy,
          onPressed: widget.editing ? () {} : widget.onPressed,
        ),
      );
      final hint = widget.startHint;
      return Stack(
        children: [
          KeyedSubtree(key: _controlsKey, child: widget.child),
          Positioned.fromRect(
            rect: _displayRect,
            child: widget.editing
                ? GestureDetector(
                    key: const ValueKey('start-stop-edit-handle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSelect,
                    onPanStart: (_) {
                      widget.onSelect();
                      widget.onBeginChange();
                      _dragCenter = _displayRect.center;
                    },
                    onPanUpdate: (event) {
                      final rawCenter = _dragCenter! + event.delta;
                      var center = rawCenter;
                      if (widget.snapToGrid) {
                        center = Offset(
                          (center.dx / 12).round() * 12.0,
                          (center.dy / 12).round() * 12.0,
                        );
                      }
                      final candidate = StartStopPlacement(
                        cx: center.dx / _size.width,
                        cy: center.dy / _size.height,
                        scale: value.scale,
                      );
                      final rect = _clamp(candidate);
                      if (!_clear(rect)) return;
                      _dragCenter = rawCenter;
                      setState(
                        () => _drag = StartStopPlacement(
                          cx: rect.center.dx / _size.width,
                          cy: rect.center.dy / _size.height,
                          scale: value.scale,
                        ),
                      );
                    },
                    onPanEnd: (_) {
                      final next = _drag;
                      setState(() {
                        if (next != null) _editRect = _clamp(next);
                        _drag = null;
                        _dragCenter = null;
                      });
                      if (next != null) widget.onChanged(next);
                    },
                    onPanCancel: () => setState(() {
                      _drag = null;
                      _dragCenter = null;
                    }),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: widget.selected
                            ? Border.all(
                                color: const Color(0xFFFACC15),
                                width: 2,
                              )
                            : null,
                      ),
                      child: ExcludeSemantics(
                        child: IgnorePointer(child: button),
                      ),
                    ),
                  )
                : button,
          ),
          if (waitingForStart && hint != null && !_displayRect.isEmpty)
            ?_StartHint.place(
              context: context,
              label: hint,
              anchor: _displayRect,
              area: _size,
              obstacles: _obstacles,
            ),
        ],
      );
    },
  );
}

/// Small glass label pointing at Start, so a dimmed pad explains itself.
class _StartHint extends StatelessWidget {
  const _StartHint({
    required this.label,
    required this.rect,
    required this.above,
    required this.textScaler,
  });

  final String label;
  final Rect rect;
  final bool above;
  final TextScaler textScaler;

  static const double _height = 34;
  static const double _gap = 8;
  static const TextStyle _style = TextStyle(
    color: Color(0xFF261B39),
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  /// Places the label above Start, else below; returns null when neither
  /// spot is free, so it never covers a control.
  static Widget? place({
    required BuildContext context,
    required String label,
    required Rect anchor,
    required Size area,
    required List<Rect> obstacles,
  }) {
    // Keep the label compact even with very large system text.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    // Measure with the same style the Text below resolves to.
    final style = DefaultTextStyle.of(context).style.merge(_style);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    // Text + horizontal padding + icon + gap + border, rounded up.
    final width = (painter.width + 14 * 2 + 16 + 6 + 2).ceilToDouble() + 2;
    painter.dispose();
    if (width > area.width - 8) return null;
    final left = (anchor.center.dx - width / 2).clamp(
      4.0,
      area.width - width - 4,
    );
    Rect at(double top) => Rect.fromLTWH(left, top, width, _height);
    // Labels around controls (e.g. joystick X+/Y-) grow with system text.
    final clearance = 12 * MediaQuery.textScalerOf(context).scale(1);
    final candidates = [
      (at(anchor.top - _gap - _height), true),
      (at(anchor.bottom + _gap), false),
    ];
    for (final (rect, above) in candidates) {
      final inside = rect.top >= 4 && rect.bottom <= area.height - 4;
      // Keep clear of controls and the labels drawn just outside them.
      final clear = !obstacles.any((o) => o.inflate(clearance).overlaps(rect));
      if (inside && clear) {
        return _StartHint(
          label: label,
          rect: rect,
          above: above,
          textScaler: scaler,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label: label,
          child: Container(
            key: const ValueKey('start-hint'),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  above
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                  color: const Color(0xFF15803D),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: textScaler,
                    style: _style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft green ring that breathes around Start until control begins.
class _StartPulse extends StatefulWidget {
  const _StartPulse({
    required this.active,
    required this.diameter,
    required this.child,
  });

  final bool active;
  final double diameter;
  final Widget child;

  @override
  State<_StartPulse> createState() => _StartPulseState();
}

class _StartPulseState extends State<_StartPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_StartPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_controller.value);
            final size = widget.diameter * (0.9 + 0.45 * t);
            return IgnorePointer(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF22C55E,
                    ).withValues(alpha: 0.55 * (1 - t)),
                    width: 3,
                  ),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}
