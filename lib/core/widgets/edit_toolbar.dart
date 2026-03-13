import 'dart:ui';
import 'package:flutter/material.dart';

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

class EditToolbar extends StatelessWidget {
    const EditToolbar({
      super.key,
      this.barKey,
      required this.canUndo,
      required this.canRedo,
      required this.onUndo,
      required this.onRedo,
    required this.showGrid,
    required this.onToggleGrid,
    required this.sizeEnabled,
    required this.onSizeDown,
    required this.onSizeUp,
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
    });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool showGrid;
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
    final Key? barKey;
    final Key? lockKey;

  Widget _iconButton(
    IconData icon,
    VoidCallback? onTap,
    Color color, {
    Key? key,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final disabled = _opacity(cs.onSurface, 0.35);
    final undoColor = canUndo ? cs.onSurface : disabled;
    final redoColor = canRedo ? cs.onSurface : disabled;
    final sizeColor = sizeEnabled ? cs.onSurface : disabled;
    final gridColor = showGrid ? cs.primary : cs.onSurface;
    final lockColor = lockEnabled
        ? (locked ? cs.secondary : cs.onSurface)
        : disabled;

    final surface = _opacity(cs.surface, isDark ? 0.35 : 0.72);
    final border = _opacity(cs.outline, isDark ? 0.4 : 0.5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            key: barKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconButton(
                Icons.undo,
                canUndo ? onUndo : null,
                undoColor,
                key: undoKey,
              ),
              const SizedBox(width: 2),
              _iconButton(
                Icons.redo,
                canRedo ? onRedo : null,
                redoColor,
                key: redoKey,
              ),
              const SizedBox(width: 6),
              _iconButton(
                showGrid ? Icons.grid_on : Icons.grid_off,
                onToggleGrid,
                gridColor,
                key: gridKey,
              ),
              const SizedBox(width: 8),
              Container(
                key: sizeBarKey,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: sizeKey,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sizeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _iconButton(
                            Icons.remove,
                            sizeEnabled ? onSizeDown : null,
                            sizeColor,
                          ),
                          const SizedBox(width: 2),
                          _iconButton(
                            Icons.add,
                            sizeEnabled ? onSizeUp : null,
                            sizeColor,
                          ),
                        ],
                      ),
                    ),
                    if (showLock) ...[
                      const SizedBox(width: 8),
                      _iconButton(
                        locked ? Icons.lock : Icons.lock_open,
                        lockEnabled ? onToggleLock : null,
                        lockColor,
                        key: lockKey,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

