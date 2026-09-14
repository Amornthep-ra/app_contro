import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'gamepad_appbar_controls.dart';

const startStopEditId = 'system:start_stop';

@immutable
class StartStopPlacement {
  const StartStopPlacement({this.cx = .5, this.cy = 1, this.scale = 1});
  final double cx;
  final double cy;
  final double scale;

  static StartStopPlacement fromJson(Object? value) {
    if (value is! Map) return const StartStopPlacement();
    double read(String key, double fallback, double min, double max) {
      final raw = value[key];
      return raw is num && raw.isFinite
          ? raw.toDouble().clamp(min, max)
          : fallback;
    }

    return StartStopPlacement(
      cx: read('cx', .5, 0, 1),
      cy: read('cy', 1, 0, 1),
      scale: read('scale', 1, .75, 2),
    );
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'scale': scale};
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
  });
  final StartStopPlacement placement;
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
      final button = GamepadStartStopControlButton(
        heroTag: 'editable_start_stop',
        diameter: value.diameter,
        isStarted: widget.editing ? false : widget.started,
        isBusy: widget.editing ? false : widget.busy,
        onPressed: widget.editing ? () {} : widget.onPressed,
      );
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
        ],
      );
    },
  );
}
