import 'package:flutter/material.dart';

import '../ui/gamepad_components.dart';
import 'gamepad_app_bar.dart';
import 'gamepad_appbar_controls.dart';
import 'gamepad_edit_shared.dart';

/// The one-row layout editor toolbar of the control pages: Done, Buttons,
/// Lock, size -/+, Grid, Undo, Redo, Reset and Delete.
class GamepadEditToolbar extends StatelessWidget {
  /// Key of the Buttons pill (tests and per-mode menus find it by this).
  final Key buttonsKey;

  /// Whether a control is selected, and whether that one is locked.
  final bool hasSelection;
  final bool selectedLocked;

  final bool showGrid;
  final bool canUndo;
  final bool canRedo;

  /// Buzz on every pill. When false only Buttons buzzes (4 BTN).
  final bool buzzOnTap;

  final VoidCallback onDone;
  final VoidCallback onButtons;
  final VoidCallback onToggleLock;
  final ValueChanged<double> onChangeSize;
  final VoidCallback onToggleGrid;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  /// Size step of the -/+ pills (factor of the control's base size).
  static const sizeStep = 0.05;

  const GamepadEditToolbar({
    super.key,
    required this.buttonsKey,
    required this.hasSelection,
    required this.selectedLocked,
    required this.showGrid,
    required this.canUndo,
    required this.canRedo,
    required this.buzzOnTap,
    required this.onDone,
    required this.onButtons,
    required this.onToggleLock,
    required this.onChangeSize,
    required this.onToggleGrid,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sizeEnabled = hasSelection && !selectedLocked;
    VoidCallback tap(VoidCallback action) {
      if (!buzzOnTap) return action;
      return () {
        gamepadBuzz();
        action();
      };
    }

    return GamepadCenteredToolbar(
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      singleRow: true,
      children: [
        GamepadToolIconPill(
          icon: Icons.done_rounded,
          label: 'Done',
          accent: const Color(0xFF60A5FA),
          onTap: tap(onDone),
        ),
        // Show or hide controls, e.g. bring back one that was deleted
        // without resetting the whole layout.
        GamepadToolIconPill(
          pillKey: buttonsKey,
          icon: Icons.videogame_asset_outlined,
          label: 'Buttons',
          accent: const Color(0xFF34D399),
          onTap: () {
            gamepadBuzz();
            onButtons();
          },
        ),
        GamepadToolIconPill(
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          label: gamepadEditLockLabel(locked: selectedLocked),
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? tap(onToggleLock) : null,
        ),
        GamepadToolIconPill(
          icon: Icons.remove,
          label: 'Decrease size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? tap(() => onChangeSize(-sizeStep)) : null,
        ),
        GamepadToolIconPill(
          icon: Icons.add,
          label: 'Increase size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? tap(() => onChangeSize(sizeStep)) : null,
        ),
        GamepadToolIconPill(
          icon: showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          label: 'Grid',
          accent: const Color(0xFF38BDF8),
          active: showGrid,
          onTap: tap(onToggleGrid),
        ),
        GamepadToolIconPill(
          icon: Icons.undo_rounded,
          label: 'Undo',
          accent: const Color(0xFFA78BFA),
          onTap: canUndo ? tap(onUndo) : null,
        ),
        GamepadToolIconPill(
          icon: Icons.redo_rounded,
          label: 'Redo',
          accent: const Color(0xFFA78BFA),
          onTap: canRedo ? tap(onRedo) : null,
        ),
        GamepadToolIconPill(
          icon: Icons.restart_alt,
          label: 'Reset',
          accent: const Color(0xFFF59E0B),
          onTap: tap(onReset),
        ),
        GamepadToolIconPill(
          icon: Icons.delete_outline,
          label: 'Delete',
          accent: const Color(0xFFF87171),
          onTap: hasSelection ? tap(onDelete) : null,
        ),
      ],
    );
  }
}
