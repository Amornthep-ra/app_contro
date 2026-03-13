import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/widgets/edit_toolbar.dart';

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

class GamepadEditControls extends StatelessWidget {
  final bool visible;
  final double top;
  final double gap;
  final Key? barKey;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool isGridVisible;
  final VoidCallback onToggleGrid;
  final bool sizeEnabled;
  final VoidCallback? onSizeDown;
  final VoidCallback? onSizeUp;
  final String sizeLabel;
  final bool showLock;
  final bool lockEnabled;
  final bool locked;
  final VoidCallback? onToggleLock;
  final Key? undoKey;
  final Key? redoKey;
  final Key? gridKey;
  final Key? sizeKey;
  final Key? sizeBarKey;
  final Key? lockKey;
  final VoidCallback? onSave;
  final VoidCallback? onReset;
  final bool showPrimaryActions;

  const GamepadEditControls({
    super.key,
    this.visible = true,
    this.top = 6,
    this.gap = 8,
    this.barKey,
    required this.canUndo,
    required this.canRedo,
    this.onUndo,
    this.onRedo,
    required this.isGridVisible,
    required this.onToggleGrid,
    required this.sizeEnabled,
    this.onSizeDown,
    this.onSizeUp,
    this.sizeLabel = 'Size',
    this.showLock = false,
    this.lockEnabled = false,
    this.locked = false,
    this.onToggleLock,
    this.undoKey,
    this.redoKey,
    this.gridKey,
    this.sizeKey,
    this.sizeBarKey,
    this.lockKey,
    this.onSave,
    this.onReset,
    this.showPrimaryActions = false,
  });

  Widget _actionPill(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = _opacity(cs.surface, isDark ? 0.35 : 0.72);
    final border = _opacity(cs.outline, isDark ? 0.4 : 0.5);

    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Icon(icon, size: 14, color: cs.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final toolbar = EditToolbar(
      barKey: barKey,
      canUndo: canUndo,
      canRedo: canRedo,
      onUndo: onUndo,
      onRedo: onRedo,
      showGrid: isGridVisible,
      onToggleGrid: onToggleGrid,
      sizeEnabled: sizeEnabled,
      onSizeDown: onSizeDown,
      onSizeUp: onSizeUp,
      sizeLabel: sizeLabel,
      showLock: showLock,
      lockEnabled: lockEnabled,
      locked: locked,
      onToggleLock: onToggleLock,
      undoKey: undoKey,
      redoKey: redoKey,
      gridKey: gridKey,
      sizeKey: sizeKey,
      sizeBarKey: sizeBarKey,
      lockKey: lockKey,
    );

    final hasPrimaryActions = onSave != null || onReset != null;
    final showPrimary = showPrimaryActions && hasPrimaryActions;

    final content = showPrimary
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSave != null)
                _actionPill(
                  context,
                  icon: Icons.save_outlined,
                  tooltip: 'Save',
                  onTap: onSave!,
                ),
              if (onSave != null && onReset != null) SizedBox(width: gap),
              if (onReset != null)
                _actionPill(
                  context,
                  icon: Icons.restart_alt,
                  tooltip: 'Reset',
                  onTap: onReset!,
                ),
              SizedBox(width: gap),
              toolbar,
            ],
          )
        : toolbar;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(child: content),
    );
  }
}
