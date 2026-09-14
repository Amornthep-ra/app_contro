import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Locks only the driving surface, leaving Start and settings accessible.
class ControlInputGate extends StatelessWidget {
  const ControlInputGate({
    super.key,
    required this.started,
    required this.editing,
    required this.suspended,
    required this.child,
  });
  final bool started;
  final bool editing;
  final ValueListenable<bool> suspended;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: suspended,
    child: child,
    builder: (context, isSuspended, child) {
      final enabled = editing || (started && !isSuspended);
      return ExcludeFocus(
        excluding: !enabled,
        child: AbsorbPointer(
          absorbing: !enabled,
          child: Opacity(opacity: enabled ? 1 : 0.4, child: child),
        ),
      );
    },
  );
}
