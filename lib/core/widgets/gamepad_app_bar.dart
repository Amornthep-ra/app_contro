import 'dart:ui';

import 'package:flutter/material.dart';
import 'gamepad_control_toolbar.dart';
import 'package:flutter/services.dart';

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

@immutable
class GamepadAppBarMetrics {
  static const double toolbarHeight = 56.0;
  static const double minimumTapTargetExtent = 48.0;
  static const double compactVisualHeight = 36.0;
  static const double uniformControlWidth = 80.0;
  static const double uniformGap = 8.0;

  final double controlHeight;
  final double tapTargetExtent;
  final double iconButtonExtent;
  final double labelButtonWidth;
  final double controlGap;
  final double sectionGap;
  final EdgeInsets contentPadding;
  final double iconSize;
  final BorderRadius borderRadius;
  final double labelIconGap;
  final double telemetryLabelFontSize;
  final double telemetryValueFontSize;
  final double telemetryValueMaxWidth;

  const GamepadAppBarMetrics({
    required this.controlHeight,
    this.tapTargetExtent = minimumTapTargetExtent,
    required this.iconButtonExtent,
    required this.labelButtonWidth,
    required this.controlGap,
    required this.sectionGap,
    required this.contentPadding,
    required this.iconSize,
    required this.borderRadius,
    required this.labelIconGap,
    required this.telemetryLabelFontSize,
    required this.telemetryValueFontSize,
    required this.telemetryValueMaxWidth,
  });

  factory GamepadAppBarMetrics.forWidth(double width) {
    final ultra = width >= 900;
    const controlHeight = compactVisualHeight;

    return GamepadAppBarMetrics(
      controlHeight: controlHeight,
      tapTargetExtent: minimumTapTargetExtent,
      iconButtonExtent: uniformControlWidth,
      labelButtonWidth: uniformControlWidth,
      controlGap: uniformGap,
      sectionGap: uniformGap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      iconSize: 18.0,
      borderRadius: BorderRadius.circular(999),
      labelIconGap: 5.0,
      telemetryLabelFontSize: 14.0,
      telemetryValueFontSize: 14.0,
      telemetryValueMaxWidth: ultra ? 56.0 : 50.0,
    );
  }

  double get leadingWidth => iconButtonExtent + sectionGap;

  double get titleSpacing => controlGap;
}

@immutable
class GamepadToolbarLayout {
  const GamepadToolbarLayout({
    required this.columns,
    required this.rows,
    required this.itemWidth,
    required this.itemHeight,
    required this.gap,
    required this.toolbarHeight,
  });

  final int columns;
  final int rows;
  final double itemWidth;
  final double itemHeight;
  final double gap;
  final double toolbarHeight;

  factory GamepadToolbarLayout.calculate({
    required double width,
    required int itemCount,
    required double textScaleFactor,
    bool singleRow = false,
  }) {
    if (itemCount <= 0) {
      return const GamepadToolbarLayout(
        columns: 1,
        rows: 1,
        itemWidth: GamepadAppBarMetrics.uniformControlWidth,
        itemHeight: GamepadAppBarMetrics.minimumTapTargetExtent,
        gap: GamepadAppBarMetrics.uniformGap,
        toolbarHeight: GamepadAppBarMetrics.toolbarHeight,
      );
    }
    const horizontalPadding = 24.0;
    final availableWidth = (width - horizontalPadding).clamp(
      GamepadAppBarMetrics.uniformControlWidth,
      double.infinity,
    );
    if (!singleRow) {
      const gap = GamepadAppBarMetrics.uniformGap;
      final columns =
          ((availableWidth + gap) /
                  (GamepadAppBarMetrics.uniformControlWidth + gap))
              .floor()
              .clamp(1, itemCount);
      final rows = (itemCount / columns).ceil();
      final itemHeight = gamepadToolbarHeightForTextScale(textScaleFactor) - 8;
      return GamepadToolbarLayout(
        columns: columns,
        rows: rows,
        itemWidth: GamepadAppBarMetrics.uniformControlWidth,
        itemHeight: itemHeight,
        gap: gap,
        toolbarHeight: 8 + (rows * itemHeight) + ((rows - 1) * gap),
      );
    }
    final gap = itemCount == 1
        ? 0.0
        : ((availableWidth -
                      (itemCount *
                          GamepadAppBarMetrics.minimumTapTargetExtent)) /
                  (itemCount - 1))
              .clamp(4.0, GamepadAppBarMetrics.uniformGap);
    final itemWidth = ((availableWidth - (gap * (itemCount - 1))) / itemCount)
        .clamp(
          GamepadAppBarMetrics.minimumTapTargetExtent,
          GamepadAppBarMetrics.uniformControlWidth,
        );
    final itemHeight = gamepadToolbarHeightForTextScale(textScaleFactor) - 8;
    return GamepadToolbarLayout(
      columns: itemCount,
      rows: 1,
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      gap: gap,
      toolbarHeight: 8 + itemHeight,
    );
  }
}

class GamepadCenteredToolbar extends StatelessWidget {
  const GamepadCenteredToolbar({
    super.key,
    required this.children,
    required this.textScaleFactor,
    this.singleRow = false,
  });

  final List<Widget> children;
  final double textScaleFactor;
  final bool singleRow;

  @override
  Widget build(BuildContext context) {
    final controlLayout = GamepadControlScope.of(context);
    if (controlLayout != null) {
      return GamepadControlRows(layout: controlLayout, children: children);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = GamepadToolbarLayout.calculate(
          width: constraints.maxWidth,
          itemCount: children.length,
          textScaleFactor: textScaleFactor,
          singleRow: singleRow,
        );
        if (!singleRow) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < layout.rows; row++) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = _rowStart(layout, row);
                        index < _rowEnd(layout, row);
                        index++
                      ) ...[
                        _slot(layout, index),
                        if (index + 1 < _rowEnd(layout, row))
                          SizedBox(width: layout.gap),
                      ],
                    ],
                  ),
                  if (row + 1 < layout.rows) SizedBox(height: layout.gap),
                ],
              ],
            ),
          );
        }
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                _slot(layout, index),
                if (index + 1 < children.length) SizedBox(width: layout.gap),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _slot(GamepadToolbarLayout layout, int index) => SizedBox(
    key: ValueKey('gamepad-toolbar-slot-$index'),
    width: layout.itemWidth,
    height: layout.itemHeight,
    child: Center(child: children[index]),
  );

  int _rowStart(GamepadToolbarLayout layout, int row) {
    final shortLength = children.length ~/ layout.rows;
    final longerRows = children.length % layout.rows;
    return (row * shortLength) + (row < longerRows ? row : longerRows);
  }

  int _rowEnd(GamepadToolbarLayout layout, int row) {
    final shortLength = children.length ~/ layout.rows;
    final longerRows = children.length % layout.rows;
    return _rowStart(layout, row) + shortLength + (row < longerRows ? 1 : 0);
  }
}

double gamepadToolbarHeightForTextScale(double textScaleFactor) {
  if (textScaleFactor <= 1.3) return GamepadAppBarMetrics.toolbarHeight;
  final progress = ((textScaleFactor - 1.3) / 0.7).clamp(0.0, 1.0);
  return GamepadAppBarMetrics.toolbarHeight + (16 * progress);
}

class GamepadUnifiedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final GamepadControlLayout? controlLayout;
  final Widget? leading;
  final Widget? toolbarContent;
  final Widget? speedToggle;
  final Widget? cmdChip;
  final Widget? drvChip;
  final Widget? trnChip;
  final Widget? modeSelector;
  final Widget? bleBadge;
  final Widget? flexibleSpace;
  final Widget Function(double gap)? actionsBuilder;
  final List<Widget>? actions;
  final double? actionsMaxWidth;
  final String? title;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry toolbarPadding;
  final bool centerTitle;
  final bool useGlassBackground;
  final double? glassOpacity;
  final double textScaleFactor;
  final double? viewportWidth;
  final int? toolbarItemCount;
  final bool singleRowToolbar;

  const GamepadUnifiedAppBar({
    super.key,
    this.controlLayout,
    this.leading,
    this.toolbarContent,
    this.speedToggle,
    this.cmdChip,
    this.drvChip,
    this.trnChip,
    this.modeSelector,
    this.bleBadge,
    this.flexibleSpace,
    this.actionsBuilder,
    this.actions,
    this.actionsMaxWidth,
    this.title,
    this.titleStyle,
    this.toolbarPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.centerTitle = false,
    this.useGlassBackground = true,
    this.glassOpacity,
    this.textScaleFactor = 1,
    this.viewportWidth,
    this.toolbarItemCount,
    this.singleRowToolbar = false,
  });

  @override
  Size get preferredSize {
    if (controlLayout != null) return Size.fromHeight(controlLayout!.height);
    final count = toolbarItemCount ?? _derivedToolbarItemCount;
    final width = viewportWidth;
    if (width == null || count <= 0) {
      return Size.fromHeight(gamepadToolbarHeightForTextScale(textScaleFactor));
    }
    return Size.fromHeight(
      GamepadToolbarLayout.calculate(
        width: width,
        itemCount: count,
        textScaleFactor: textScaleFactor,
        singleRow: singleRowToolbar,
      ).toolbarHeight,
    );
  }

  int get _derivedToolbarItemCount =>
      (leading == null ? 0 : 1) +
      (speedToggle == null ? 0 : 1) +
      (cmdChip == null ? 0 : 1) +
      (drvChip == null ? 0 : 1) +
      (trnChip == null ? 0 : 1) +
      (modeSelector == null ? 0 : 1) +
      (bleBadge == null ? 0 : 1) +
      (actionsBuilder == null ? (actions?.length ?? 0) : 1);

  bool get _hasTelemetry =>
      speedToggle != null ||
      cmdChip != null ||
      drvChip != null ||
      trnChip != null;

  bool get _usesUnifiedControlLayout =>
      _hasTelemetry || modeSelector != null || bleBadge != null;

  Widget _buildGlassBackground(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final opacity = glassOpacity ?? (isDark ? 0.94 : 0.97);
    final translucent = glassOpacity != null;
    final baseColor = isDark
        ? _opacity(const Color(0xFF111827), opacity)
        : _opacity(
            Color.lerp(const Color(0xFFF8FAFC), cs.surface, 0.55) ?? cs.surface,
            opacity,
          );
    final border = _opacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      translucent ? (isDark ? 0.18 : 0.08) : (isDark ? 0.28 : 0.16),
    );
    final topLine = _opacity(
      Colors.white,
      translucent ? (isDark ? 0.08 : 0.24) : (isDark ? 0.1 : 0.45),
    );
    final bottomLine = _opacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      translucent ? (isDark ? 0.18 : 0.08) : (isDark ? 0.32 : 0.18),
    );

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            border: Border(
              top: BorderSide(color: topLine, width: 0.8),
              bottom: BorderSide(color: border, width: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: _opacity(
                  Colors.black,
                  translucent ? (isDark ? 0.12 : 0.03) : (isDark ? 0.24 : 0.08),
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 1, color: bottomLine),
          ),
        ),
      ),
    );
  }

  Widget? _buildTelemetryRow(BuildContext context) {
    final chipWidgets = <Widget>[
      if (cmdChip != null) cmdChip!,
      if (trnChip != null) trnChip!,
      if (drvChip != null) drvChip!,
    ];

    final telemetryChildren = <Widget>[
      if (speedToggle != null) speedToggle!,
      ...chipWidgets,
    ];

    if (telemetryChildren.isEmpty) {
      return null;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: telemetryChildren);
  }

  Widget _buildUnifiedToolbar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final metrics = GamepadAppBarMetrics.forWidth(width);
    final items = <Widget>[
      if (leading != null) leading!,
      if (speedToggle != null) speedToggle!,
      if (cmdChip != null) cmdChip!,
      if (trnChip != null) trnChip!,
      if (drvChip != null) drvChip!,
      if (modeSelector != null) modeSelector!,
      if (bleBadge != null) bleBadge!,
    ];
    final builtActions = actionsBuilder != null
        ? actionsBuilder!(metrics.controlGap)
        : (actions != null && actions!.isNotEmpty
              ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
              : null);
    if (builtActions != null) items.add(builtActions);
    return Padding(
      padding: toolbarPadding,
      child: GamepadCenteredToolbar(
        textScaleFactor: textScaleFactor,
        singleRow: singleRowToolbar,
        children: items,
      ),
    );
  }

  Widget _buildStandardTitle(BuildContext context) {
    if (_hasTelemetry) {
      final telemetryRow = _buildTelemetryRow(context);
      return telemetryRow ?? const SizedBox.shrink();
    }
    if (title != null && title!.trim().isNotEmpty) {
      return Text(title!, style: titleStyle);
    }
    return const SizedBox.shrink();
  }

  List<Widget> _buildStandardActions(BuildContext context) {
    if (actionsBuilder != null) {
      final width = MediaQuery.of(context).size.width;
      final metrics = GamepadAppBarMetrics.forWidth(width);
      final maxWidth =
          actionsMaxWidth ?? (width < 640 ? width * 0.42 : width * 0.48);
      final actionsWidget = actionsBuilder!(metrics.controlGap);
      return [
        Padding(
          padding: EdgeInsets.only(right: metrics.sectionGap),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: actionsWidget,
          ),
        ),
      ];
    }
    return actions ?? const [];
  }

  Widget _buildTitleWidget(BuildContext context) {
    if (toolbarContent != null) {
      return Padding(padding: toolbarPadding, child: toolbarContent);
    }
    if (_usesUnifiedControlLayout) {
      return _buildUnifiedToolbar(context);
    }
    return _buildStandardTitle(context);
  }

  List<Widget> _buildActions(BuildContext context) {
    if (toolbarContent != null) {
      return const [];
    }
    if (_usesUnifiedControlLayout) {
      return const [];
    }
    return _buildStandardActions(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metrics = GamepadAppBarMetrics.forWidth(
      MediaQuery.of(context).size.width,
    );
    final flexSpace =
        flexibleSpace ??
        (useGlassBackground ? _buildGlassBackground(context) : null);
    final toolbarHeight = preferredSize.height;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: toolbarHeight,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      centerTitle: centerTitle,
      titleSpacing: _usesUnifiedControlLayout || toolbarContent != null
          ? 0
          : metrics.titleSpacing,
      flexibleSpace: flexSpace,
      leading: toolbarContent == null && !_usesUnifiedControlLayout
          ? leading
          : null,
      leadingWidth:
          toolbarContent == null &&
              !_usesUnifiedControlLayout &&
              leading != null
          ? metrics.leadingWidth
          : null,
      title: controlLayout == null
          ? _buildTitleWidget(context)
          : GamepadControlScope(
              layout: controlLayout!,
              child: _buildTitleWidget(context),
            ),
      actions: _buildActions(context),
    );
  }
}
