import 'package:flutter/material.dart';
import 'gamepad_control_toolbar.dart';

import 'app_back_button.dart';
import 'gamepad_app_bar.dart';
import '../ui/app_assets.dart';
import '../ui/language_controller.dart';

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

OverlayEntry? _activeGamepadTopNotice;

enum GamepadNoticeStyle { ble, warning, error, success }

class _GamepadNoticePalette {
  const _GamepadNoticePalette({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.border,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final Color border;
}

_GamepadNoticePalette _noticePalette(GamepadNoticeStyle style) {
  switch (style) {
    case GamepadNoticeStyle.ble:
      return const _GamepadNoticePalette(
        icon: Icons.bluetooth_disabled_rounded,
        iconColor: Color(0xFF7256B6),
        gradient: [Color(0xFFFFFCFF), Color(0xFFF0E9FF)],
        border: Color(0xFFB79DFF),
      );
    case GamepadNoticeStyle.warning:
      return const _GamepadNoticePalette(
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFD97706),
        gradient: [Color(0xFFFFFCFF), Color(0xFFFFE8D2)],
        border: Color(0xFFFFB56B),
      );
    case GamepadNoticeStyle.error:
      return const _GamepadNoticePalette(
        icon: Icons.error_outline_rounded,
        iconColor: Color(0xFFF05264),
        gradient: [Color(0xFFFFFBFC), Color(0xFFFFE4E8)],
        border: Color(0xFFF7A0AB),
      );
    case GamepadNoticeStyle.success:
      return const _GamepadNoticePalette(
        icon: Icons.check_circle_outline_rounded,
        iconColor: Color(0xFF20A878),
        gradient: [Color(0xFFFBFFFD), Color(0xFFDDF9EE)],
        border: Color(0xFF78D8B2),
      );
  }
}

void showGamepadTopNotice(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
  GamepadNoticeStyle style = GamepadNoticeStyle.warning,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final palette = _noticePalette(style);
  _activeGamepadTopNotice?.remove();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) => IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.border.withAlpha(190),
                      width: 1.25,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x40A860B8),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                      BoxShadow(
                        color: palette.border.withAlpha(38),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(palette.icon, color: palette.iconColor, size: 20),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF261B39),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
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
        ),
      ),
    ),
  );

  _activeGamepadTopNotice = entry;
  overlay.insert(entry);
  Future<void>.delayed(duration).then((_) {
    if (!identical(_activeGamepadTopNotice, entry)) return;
    entry.remove();
    _activeGamepadTopNotice = null;
  });
}

class GamepadGlassTopPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Key? pillKey;
  final EdgeInsets padding;

  const GamepadGlassTopPill({
    super.key,
    required this.child,
    this.onTap,
    this.pillKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final metrics = GamepadAppBarMetrics.forWidth(
      MediaQuery.of(context).size.width,
    );

    final radius = BorderRadius.circular(999);
    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return _opacity(const Color(0xFFA66BDC), isDark ? 0.28 : 0.20);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return _opacity(const Color(0xFFA66BDC), isDark ? 0.18 : 0.12);
      }
      return null;
    });

    return SizedBox(
      width: metrics.labelButtonWidth,
      height: metrics.tapTargetExtent,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: _opacity(
                    const Color(0xFF9B6BCC),
                    isDark ? 0.22 : 0.18,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                key: const ValueKey('gamepad-visual-control-surface'),
                width: metrics.labelButtonWidth,
                height: metrics.controlHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF31234A).withAlpha(242),
                            const Color(0xFF181426).withAlpha(242),
                          ]
                        : [
                            Colors.white.withAlpha(240),
                            const Color(0xFFF4E9FF).withAlpha(232),
                          ],
                  ),
                  borderRadius: radius,
                  border: Border.all(
                    color: _opacity(
                      isDark
                          ? const Color(0xFFD7B7FF)
                          : const Color(0xFFD8BCEF),
                      isDark ? 0.50 : 0.78,
                    ),
                  ),
                ),
                child: InkWell(
                  key: pillKey,
                  borderRadius: radius,
                  overlayColor: overlay,
                  splashColor: _opacity(
                    const Color(0xFFA66BDC),
                    isDark ? 0.38 : 0.30,
                  ),
                  highlightColor: Colors.transparent,
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GamepadStartStopControlButton extends StatelessWidget {
  static const Color startColor = Color(0xFF22C55E);
  static const Color emergencyStopColor = Color(0xFFEF4444);

  final double diameter;
  final String heroTag;
  final bool isStarted;
  final bool isBusy;
  final VoidCallback? onPressed;

  const GamepadStartStopControlButton({
    super.key,
    this.diameter = 48,
    required this.heroTag,
    required this.isStarted,
    this.isBusy = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    final label = isBusy
        ? (isThai ? 'Starting control' : 'Starting control')
        : isStarted
        ? (isThai ? 'Stop control' : 'Stop control')
        : (isThai ? 'Start control' : 'Start control');
    final actionLabel = isStarted
        ? (isThai ? 'Emergency Stop' : 'Emergency Stop')
        : label;
    return _buildButton(
      heroTag: heroTag,
      label: actionLabel,
      asset: isStarted ? AppAssets.controlStop : AppAssets.controlStart,
      fallback: isStarted
          ? Icons.stop_circle_rounded
          : Icons.play_circle_rounded,
      color: isStarted ? emergencyStopColor : startColor,
      isBusy: isBusy,
      onPressed: isBusy ? null : onPressed,
    );
  }

  Widget _buildButton({
    required String heroTag,
    required String label,
    required String asset,
    required IconData fallback,
    required Color color,
    required bool isBusy,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Tooltip(
        message: label,
        child: Hero(
          tag: heroTag,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: diameter < 48 ? 48 : diameter,
                height: diameter < 48 ? 48 : diameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Emergency Stop gets a solid red halo so it reads as the
                    // most important control on the pad.
                    if (color == emergencyStopColor && onPressed != null)
                      Container(
                        width: diameter * .96,
                        height: diameter * .96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: emergencyStopColor.withAlpha(190),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: emergencyStopColor.withAlpha(110),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: diameter * .75,
                      height: diameter * .75,
                      decoration: BoxDecoration(
                        color: color.withAlpha(isBusy ? 38 : 24),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(
                              onPressed == null ? 45 : 150,
                            ),
                            blurRadius: isBusy ? 24 : 18,
                            spreadRadius: isBusy ? 3 : 1,
                          ),
                        ],
                      ),
                    ),
                    Opacity(
                      opacity: onPressed == null ? 0.4 : 1,
                      child: Image.asset(
                        asset,
                        width: diameter,
                        height: diameter,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(fallback, size: diameter * .83, color: color),
                      ),
                    ),
                    if (isBusy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
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

class GamepadActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? iconAsset;
  final Color accent;
  final VoidCallback? onTap;
  final Key? pillKey;
  final bool iconOnly;
  final bool compact;

  const GamepadActionPill({
    super.key,
    required this.label,
    required this.icon,
    this.iconAsset,
    required this.accent,
    required this.onTap,
    this.pillKey,
    this.iconOnly = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (GamepadControlScope.of(context) != null && iconOnly) {
      return GamepadControlIcon(
        showTooltip: false,
        label: label,
        asset: iconAsset ?? '',
        fallback: icon,
        onTap: onTap,
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onTap != null;
    final horizontalPadding = compact
        ? (iconOnly ? 8.0 : 10.0)
        : (iconOnly ? 10.0 : 12.0);
    const iconSize = 18.0;
    final iconOnlySize = iconAsset == null ? 18.0 : 28.0;
    const fontSize = 12.0;
    final gap = compact ? 5.0 : 6.0;
    final textColor =
        Color.lerp(
          accent,
          isDark ? Colors.white : theme.colorScheme.onSurface,
          0.4,
        ) ??
        Colors.white;

    final content = iconOnly
        ? _buildIcon(iconOnlySize, accent)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(iconSize, accent),
              SizedBox(width: gap),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          );
    final button = GamepadGlassTopPill(
      pillKey: pillKey,
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0),
      child: content,
    );

    return Opacity(opacity: enabled ? 1 : 0.46, child: button);
  }

  Widget _buildIcon(double size, Color color) {
    if (iconAsset == null) return Icon(icon, size: size, color: color);
    return Image.asset(
      iconAsset!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(icon, size: size, color: color),
    );
  }
}

class GamepadOverflowAction {
  const GamepadOverflowAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool active;
}

class GamepadEditMoreButton extends StatelessWidget {
  const GamepadEditMoreButton({super.key, required this.actions});

  final List<GamepadOverflowAction> actions;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'More edit actions',
      child: Semantics(
        button: true,
        label: 'More edit actions',
        child: PopupMenuButton<int>(
          key: const ValueKey('gamepad-edit-more'),
          tooltip: 'More edit actions',
          onSelected: (index) => actions[index].onTap?.call(),
          itemBuilder: (context) => [
            for (int index = 0; index < actions.length; index++)
              PopupMenuItem<int>(
                value: index,
                enabled: actions[index].onTap != null,
                child: Row(
                  children: [
                    Icon(
                      actions[index].active
                          ? Icons.check_circle_rounded
                          : actions[index].icon,
                      size: 18,
                      color: actions[index].accent,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        actions[index].label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: SizedBox(
            width: GamepadAppBarMetrics.minimumTapTargetExtent,
            height: GamepadAppBarMetrics.minimumTapTargetExtent,
            child: Center(
              child: GamepadGlassTopPill(
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GamepadAppBarActionItem {
  final Key? key;
  final String label;
  final IconData icon;
  final String? iconAsset;
  final Color accent;
  final VoidCallback? onTap;
  final bool iconOnly;
  final bool compact;
  final bool compactOnNarrow;

  const GamepadAppBarActionItem({
    this.key,
    required this.label,
    required this.icon,
    this.iconAsset,
    required this.accent,
    required this.onTap,
    this.iconOnly = false,
    this.compact = false,
    this.compactOnNarrow = true,
  });
}

class GamepadModeSelector extends StatelessWidget {
  final bool precisionSelected;
  final VoidCallback? onPrecisionTap;
  final VoidCallback? onPresetTap;

  const GamepadModeSelector({
    super.key,
    required this.precisionSelected,
    required this.onPrecisionTap,
    required this.onPresetTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'Gamepad control mode',
      child: Container(
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(210),
          border: Border.all(color: scheme.outlineVariant.withAlpha(175)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSegment(
              label: '8 BTN',
              tooltip: '8-button control',
              icon: Icons.grid_view_rounded,
              selected: precisionSelected,
              color: const Color(0xFF06B6D4),
              onTap: onPrecisionTap,
            ),
            _ModeSegment(
              label: '4 BTN',
              tooltip: '4-button control',
              icon: Icons.gamepad_rounded,
              selected: !precisionSelected,
              color: const Color(0xFF84CC16),
              onTap: onPresetTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _ModeSegment({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: selected ? color.withAlpha(58) : Colors.transparent,
              border: Border.all(
                color: selected ? color.withAlpha(175) : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : scheme.onSurfaceVariant,
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

class GamepadAppBarActionGroup extends StatelessWidget {
  final List<GamepadAppBarActionItem> items;
  final double gap;
  final double compactBreakpoint;

  const GamepadAppBarActionGroup({
    super.key,
    required this.items,
    required this.gap,
    this.compactBreakpoint = 720,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < compactBreakpoint;
    final children = <Widget>[
      for (final item in items)
        Tooltip(
          message: item.label,
          child: GamepadActionPill(
            pillKey: item.key,
            label: item.label,
            icon: item.icon,
            iconAsset: item.iconAsset,
            accent: item.accent,
            onTap: item.onTap,
            iconOnly: item.iconOnly || (isNarrow && item.compactOnNarrow),
            compact: item.compact || isNarrow,
          ),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class GamepadAppBarBackButton extends StatelessWidget {
  final Key? buttonKey;
  final VoidCallback onPressed;
  final GamepadAppBarMetrics? metrics;

  const GamepadAppBarBackButton({
    super.key,
    this.buttonKey,
    required this.onPressed,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (GamepadControlScope.of(context) != null) {
      return GamepadControlIcon(
        key: buttonKey,
        label: 'Back',
        asset: AppAssets.controlBack,
        fallback: Icons.chevron_left_rounded,
        onTap: onPressed,
      );
    }
    final resolvedMetrics =
        metrics ??
        GamepadAppBarMetrics.forWidth(MediaQuery.of(context).size.width);

    return AppBackButton(
      buttonKey: buttonKey,
      width: resolvedMetrics.iconButtonExtent,
      height: resolvedMetrics.tapTargetExtent,
      iconSize: resolvedMetrics.iconSize,
      borderRadius: BorderRadius.circular(resolvedMetrics.iconButtonExtent / 2),
      onPressed: onPressed,
      child: GamepadGlassTopPill(
        padding: EdgeInsets.zero,
        child: Image.asset(
          AppAssets.controlBack,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.chevron_left_rounded, size: 24),
        ),
      ),
    );
  }
}

class GamepadSpeedTogglePill extends StatelessWidget {
  final Key? pillKey;
  final bool expanded;
  final VoidCallback onTap;
  final Color accent;
  final String label;
  final String? iconAsset;

  const GamepadSpeedTogglePill({
    super.key,
    this.pillKey,
    required this.expanded,
    required this.onTap,
    required this.accent,
    this.label = 'SPD',
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    if (GamepadControlScope.of(context) != null) {
      return GamepadControlPill(
        selected: expanded,
        accent: const Color(0xFFA66BDC),
        key: pillKey,
        label: label,
        onTap: onTap,
        semanticLabel: 'Speed: $label',
        trailing: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
        ),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        Color.lerp(
          accent,
          isDark ? Colors.white : theme.colorScheme.onSurface,
          0.35,
        ) ??
        Colors.white;
    final displayLabel = label
        .replaceFirst('DRV ', 'D')
        .replaceFirst('TRN ', 'T')
        .replaceFirst(' / ', '  ');
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            displayLabel,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 16,
          color: textColor,
        ),
      ],
    );
    return Semantics(
      button: true,
      label: 'Speed, $label',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Speed: $label',
        child: GamepadGlassTopPill(
          pillKey: pillKey,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: content,
        ),
      ),
    );
  }
}

class GamepadToolIconPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final Key? pillKey;
  final bool active;

  const GamepadToolIconPill({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.pillKey,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onTap != null;
    final fallback = isDark
        ? Colors.white38
        : theme.colorScheme.onSurface.withAlpha((0.35 * 255).round());
    final iconColor = enabled
        ? (active
              ? accent
              : (Color.lerp(
                      accent,
                      isDark ? Colors.white : theme.colorScheme.onSurface,
                      0.28,
                    ) ??
                    accent))
        : fallback;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        // The pill draws at the short visual height, but the whole 48 px
        // slot around it takes the tap, so a tap just above or below the
        // pill still works. Taps on the pill itself keep its ripple.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: GamepadGlassTopPill(
              pillKey: pillKey,
              onTap: onTap,
              padding: EdgeInsets.zero,
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class GamepadSizeToolPill extends StatelessWidget {
  final Key? pillKey;
  final bool isThai;
  final bool enabled;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const GamepadSizeToolPill({
    super.key,
    this.pillKey,
    required this.isThai,
    required this.enabled,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF38BDF8);
    final fallback = isDark
        ? Colors.white38
        : theme.colorScheme.onSurface.withAlpha((0.35 * 255).round());
    final color = enabled
        ? (Color.lerp(
                accent,
                isDark ? Colors.white : theme.colorScheme.onSurface,
                0.32,
              ) ??
              accent)
        : fallback;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GamepadGlassTopPill(
        pillKey: pillKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isThai ? 'Size' : 'Size',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onDecrease : null,
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Icon(Icons.remove, size: 14, color: color),
              ),
            ),
            const SizedBox(width: 2),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onIncrease : null,
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Icon(Icons.add, size: 14, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
