// lib/core/widgets/gamepad_edit_hint.dart
import 'package:flutter/material.dart';

import '../ui/lavender_glass.dart';

/// Floating tip at the top of the layout editor.
///
/// The edit toolbar is icon-only (names are in tooltips), so this says what
/// to do next. It never takes touches and sits behind the controls.
class GamepadEditHint extends StatelessWidget {
  const GamepadEditHint({super.key, required this.hasSelection});

  final bool hasSelection;

  static const idleMessage =
      'Tap a control to select it · Long-press a tool to see its name';
  static const selectedMessage =
      'Drag to move · − / + to resize · Done when finished';

  @override
  Widget build(BuildContext context) {
    final message = hasSelection ? selectedMessage : idleMessage;
    return Positioned(
      top: 6,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: MediaQuery.withClampedTextScaling(
              key: ValueKey(hasSelection),
              maxScaleFactor: 1.3,
              child: Container(
                key: const ValueKey('gamepad-edit-hint'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: LavenderPalette.violetDeep.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSelection
                          ? Icons.open_with_rounded
                          : Icons.touch_app_rounded,
                      size: 16,
                      color: LavenderPalette.violet,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LavenderPalette.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
