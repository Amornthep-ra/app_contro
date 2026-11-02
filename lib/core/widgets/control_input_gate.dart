import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Locks only the driving surface, leaving Start and settings accessible.
///
/// While locked the controls are shown desaturated (still recognisable, not a
/// muddy grey), input never reaches them, and a tap calls [onLockedTap] so the
/// page can explain why ("Tap Start to drive").
class ControlInputGate extends StatefulWidget {
  const ControlInputGate({
    super.key,
    required this.started,
    required this.editing,
    required this.suspended,
    required this.child,
    this.onLockedTap,
  });
  final bool started;
  final bool editing;
  final ValueListenable<bool> suspended;
  final Widget child;
  final VoidCallback? onLockedTap;

  static const double lockedOpacity = 0.72;

  @override
  State<ControlInputGate> createState() => _ControlInputGateState();
}

class _ControlInputGateState extends State<ControlInputGate> {
  /// Keeps the controls' state when the locked look is added or removed.
  final _childKey = GlobalKey();

  /// Keeps ~30% of the colour so arrows and symbols stay readable.
  static const List<double> _lockedSaturation = <double>[
    0.5134, 0.5009, 0.0857, 0, 0, //
    0.1484, 0.8659, 0.0857, 0, 0, //
    0.1484, 0.5009, 0.4507, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.suspended,
    builder: (context, isSuspended, _) {
      final enabled = widget.editing || (widget.started && !isSuspended);
      final child = KeyedSubtree(key: _childKey, child: widget.child);
      Widget content = Opacity(
        opacity: enabled ? 1 : ControlInputGate.lockedOpacity,
        child: enabled
            ? child
            : ColorFiltered(
                key: const ValueKey('control-locked-look'),
                colorFilter: const ColorFilter.matrix(_lockedSaturation),
                child: child,
              ),
      );
      content = ExcludeFocus(
        excluding: !enabled,
        child: AbsorbPointer(absorbing: !enabled, child: content),
      );
      final onTap = widget.onLockedTap;
      if (enabled || onTap == null) return content;
      return GestureDetector(
        key: const ValueKey('control-locked-tap'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    },
  );
}
