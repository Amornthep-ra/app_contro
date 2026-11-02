import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ble/ble_presentation_state.dart';

TextStyle gamepadControlTextStyle(BuildContext context) =>
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Measurements are shared by PreferredSize and the rendered rows.
///
/// The first [leadingCount] items (Back, then Start/Stop) are pinned to the
/// left edge and the last item (Settings) to the right edge; the items in
/// between are centred. Pinned items keep the larger [edgeGap] around them.
class GamepadControlLayout {
  static const double controlGap = 6;
  static const double edgeActionGap = 16;

  GamepadControlLayout(
    this.widths,
    this.rows,
    this.itemHeight,
    this.visualHeight,
    this.edgeGap, {
    this.leadingCount = 1,
    this.compactBle = false,
  });
  final List<double> widths;
  final List<List<int>> rows;
  final double itemHeight;
  final double visualHeight;
  final double edgeGap;
  final int leadingCount;

  /// True when the BLE badge shows short labels so the toolbar fits one row.
  final bool compactBle;

  double get height =>
      8 + rows.length * itemHeight + (rows.length - 1) * controlGap;

  double gapBefore(int index) =>
      gapBeforeIndex(index, widths.length, edgeGap, leadingCount: leadingCount);

  factory GamepadControlLayout.measure(
    BuildContext context,
    List<String> labels, {
    int leadingCount = 1,
  }) {
    final full = _measure(context, labels, leadingCount, compactBle: false);
    if (full.rows.length == 1 || !labels.contains('@ble')) return full;
    final compact = _measure(context, labels, leadingCount, compactBle: true);
    return compact.rows.length < full.rows.length ? compact : full;
  }

  static GamepadControlLayout _measure(
    BuildContext context,
    List<String> labels,
    int leadingCount, {
    required bool compactBle,
  }) {
    final style = gamepadControlTextStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    Iterable<String> bleLabels() => BlePresentationKind.values.map((kind) {
      final state = BlePresentationState(kind);
      return compactBle ? state.shortLabel : state.label;
    });

    final available = math.max(
      48.0,
      MediaQuery.sizeOf(context).width -
          MediaQuery.paddingOf(context).horizontal -
          24,
    );
    final widths = labels.map((label) {
      if (label.isEmpty) return 48.0;
      if (label == '@ble') {
        return math.max(48.0, bleLabels().map(measure).reduce(math.max) + 38);
      }
      if (label.startsWith('@speed:')) {
        return math.max(48.0, measure(label.substring(7)) + 36);
      }
      return math.max(48.0, measure(label) + 18);
    }).toList();
    double visualHeight = math.max(30.0, scaler.scale(12) + 12);
    for (var i = 0; i < widths.length; i++) {
      widths[i] = math.min(
        widths[i],
        labels[i] == '@ble' ? math.max(48, available - 54) : available,
      );
      final label = labels[i];
      final samples = label == '@ble'
          ? bleLabels()
          : [label.startsWith('@speed:') ? label.substring(7) : label];
      final extra = label == '@ble'
          ? 40
          : label.startsWith('@speed:')
          ? 36
          : 18;
      for (final sample in samples) {
        final painter = TextPainter(
          text: TextSpan(text: sample, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: math.max(1, widths[i] - extra));
        visualHeight = math.max(visualHeight, painter.height + 12);
        painter.dispose();
      }
    }
    final edgeGap = scaler.scale(1) <= 1.3 ? edgeActionGap : controlGap;
    final rows = <List<int>>[[]];
    double used = 0;
    for (var i = 0; i < widths.length; i++) {
      final gap = gapBeforeIndex(
        i,
        widths.length,
        edgeGap,
        leadingCount: leadingCount,
      );
      if (rows.last.isNotEmpty && used + gap + widths[i] > available) {
        rows.add([]);
        used = 0;
      }
      used += (rows.last.isEmpty ? 0 : gap) + widths[i];
      rows.last.add(i);
    }
    return GamepadControlLayout(
      widths,
      rows,
      math.max(48, visualHeight),
      visualHeight,
      edgeGap,
      leadingCount: leadingCount,
      compactBle: compactBle,
    );
  }

  /// Pinned items (the leading group and the last item) get [edgeGap] on
  /// their inner side; items in the middle get [controlGap].
  static double gapBeforeIndex(
    int index,
    int itemCount,
    double edgeGap, {
    int leadingCount = 1,
  }) => (index >= 1 && index <= leadingCount) || index == itemCount - 1
      ? edgeGap
      : controlGap;
}

class GamepadControlScope extends InheritedWidget {
  const GamepadControlScope({
    super.key,
    required this.layout,
    required super.child,
  });
  final GamepadControlLayout layout;
  static GamepadControlLayout? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GamepadControlScope>()?.layout;
  @override
  bool updateShouldNotify(GamepadControlScope oldWidget) =>
      layout != oldWidget.layout;
}

/// Lays out the control toolbar.
///
/// The first item (Back) is pinned to the left edge and the last item
/// (Settings) to the right edge, like a normal app bar; everything else is
/// centred between them. Rows wrap when the text is too large to fit.
class GamepadControlRows extends StatelessWidget {
  const GamepadControlRows({
    super.key,
    required this.layout,
    required this.children,
  });
  final GamepadControlLayout layout;
  final List<Widget> children;

  Widget _slot(int i) => SizedBox(
    key: ValueKey('gamepad-control-slot-$i'),
    width: layout.widths[i],
    height: layout.itemHeight,
    child: children[i],
  );

  Widget _centredRun(List<int> items) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final i in items) ...[
        if (i != items.first) SizedBox(width: layout.gapBefore(i)),
        _slot(i),
      ],
    ],
  );

  Widget _row(List<int> row, {required bool pinEdges}) {
    final last = layout.widths.length - 1;
    final leading = [
      if (pinEdges)
        for (final i in row)
          if (i < layout.leadingCount && i != last) i,
    ];
    final pinEnd = pinEdges && row.last == last && last >= layout.leadingCount;
    final middle = [
      for (final i in row)
        if (!leading.contains(i) && !(pinEnd && i == last)) i,
    ];
    if (leading.isEmpty && !pinEnd) return _centredRun(row);
    final leadingRun = leading.isEmpty ? null : _centredRun(leading);
    if (middle.isEmpty) {
      return Row(
        mainAxisAlignment: leadingRun != null && pinEnd
            ? MainAxisAlignment.spaceBetween
            : (leadingRun != null
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end),
        children: [?leadingRun, if (pinEnd) _slot(last)],
      );
    }
    // Widths and gaps match GamepadControlLayout.measure, so a row that fit
    // there fits here; the spare width is split evenly around the middle.
    return Row(
      children: [
        ?leadingRun,
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: leadingRun != null ? layout.gapBefore(middle.first) : 0,
              right: pinEnd ? layout.gapBefore(last) : 0,
            ),
            child: Center(child: _centredRun(middle)),
          ),
        ),
        if (pinEnd) _slot(last),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(children.length == layout.widths.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Pinning needs a bounded width and at least Back + Settings.
        final pinEdges =
            constraints.hasBoundedWidth && layout.widths.length >= 2;
        final rows = [
          for (var r = 0; r < layout.rows.length; r++) ...[
            if (r > 0) const SizedBox(height: GamepadControlLayout.controlGap),
            _row(layout.rows[r], pinEdges: pinEdges),
          ],
        ];
        if (!pinEdges) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          );
        }
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        );
      },
    );
  }
}

class GamepadControlPill extends StatelessWidget {
  const GamepadControlPill({
    super.key,
    required this.label,
    this.onTap,
    this.onTapDown,
    this.icon,
    this.trailing,
    this.color,
    this.backgroundColor,
    this.accent = const Color(0xFF9B6BCC),
    this.selected = false,
    this.semanticLabel,
  });
  final String label;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final Widget? icon;
  final Widget? trailing;
  final Color? color;
  final Color? backgroundColor;
  final Color accent;
  final bool selected;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? Color.lerp(const Color(0xFF35206B), accent, .12)!;
    final layout = GamepadControlScope.of(context)!;
    return Semantics(
      button: onTap != null,
      onTap: onTap,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel ?? label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onTapDown: onTapDown,
            borderRadius: BorderRadius.circular(999),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return accent.withValues(alpha: .16);
              }
              if (states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.hovered)) {
                return accent.withValues(alpha: .09);
              }
              return null;
            }),
            child: Center(
              child: Ink(
                key: const ValueKey('gamepad-control-surface'),
                width: double.infinity,
                height: layout.visualHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor ?? Colors.white.withValues(alpha: .94),
                      backgroundColor ??
                          Color.lerp(
                            const Color(0xFFF8EEFF),
                            accent,
                            selected ? .18 : .05,
                          )!.withValues(alpha: .92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0xFFDCC5F0),
                      accent,
                      selected ? .65 : .20,
                    )!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFB889E5,
                      ).withValues(alpha: selected ? .22 : .12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 6)],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: gamepadControlTextStyle(
                          context,
                        ).copyWith(color: ink),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 2),
                      IconTheme(
                        data: IconThemeData(color: ink),
                        child: trailing!,
                      ),
                    ],
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

class GamepadControlIcon extends StatelessWidget {
  const GamepadControlIcon({
    super.key,
    required this.label,
    this.showTooltip = true,
    required this.asset,
    required this.fallback,
    required this.onTap,
  });
  final String label;
  final bool showTooltip;
  final String asset;
  final IconData fallback;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: showTooltip ? label : null,
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Image.asset(
      asset,
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) => Icon(fallback, size: 48),
    ),
  );
}
