  //lib/core/ui/gamepad_components.dart
  import 'dart:math' as math;
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:vibration/vibration.dart';

  ///  Helper ปรับสีสว่าง/เข้ม
  Color lighten(Color c, [double amt = .12]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  Color darken(Color c, [double amt = .14]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

DateTime? _lastHapticAt;
const _hapticCooldown = Duration(milliseconds: 15);

void _buzz() {
  final now = DateTime.now();
  if (_lastHapticAt != null &&
      now.difference(_lastHapticAt!) < _hapticCooldown) {
    return;
  }
  _lastHapticAt = now;
  try {
    Vibration.vibrate(duration: 40, amplitude: 255);
  } catch (_) {}
  try {
    HapticFeedback.heavyImpact();
  } catch (_) {}
  try {
    SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}

void gamepadBuzz() => _buzz();

LinearGradient buildNeumorphicGradient({
  required Color base,
  required bool isPressed,
  required bool isDark,
}) {
  final light = lighten(base, isDark ? 0.08 : 0.14);
  final dark = darken(base, isDark ? 0.20 : 0.16);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isPressed ? [dark, light] : [light, dark],
  );
}

List<BoxShadow> buildNeumorphicShadows({
  required Color base,
  required bool isPressed,
  required bool isDark,
  bool neonGlow = false,
}) {
  final light = _opacity(lighten(base, isDark ? 0.10 : 0.22), isDark ? 0.55 : 0.85);
  final dark = _opacity(darken(base, isDark ? 0.28 : 0.20), isDark ? 0.85 : 0.35);

  if (isPressed) {
    final shadows = <BoxShadow>[
      BoxShadow(
        color: dark,
        offset: const Offset(2, 2),
        blurRadius: 6,
        spreadRadius: isDark ? -1 : -2,
      ),
      BoxShadow(
        color: light,
        offset: const Offset(-2, -2),
        blurRadius: 6,
        spreadRadius: isDark ? -1 : -2,
      ),
    ];
    if (neonGlow) {
      shadows.add(
        BoxShadow(
          color: _opacity(const Color(0xFF00F0FF), 0.7),
          blurRadius: 22,
          spreadRadius: 1,
        ),
      );
    }
    return shadows;
  }

  return [
    BoxShadow(
      color: light,
      offset: const Offset(-6, -6),
      blurRadius: 12,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: dark,
      offset: const Offset(6, 6),
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];
}

  ///  Config ของปุ่มแบบ Hold
  class BtnCfg {
    final double width;
    final double height;
    final EdgeInsets margin;
    final double radius;
    final Color baseColor;
    final Color borderColor;
    final double borderWidthOn;
    final double borderWidthOff;
    final double glowBlurOn;
    final double glowSpreadOn;
    final double glowBlurOff;
    final double glowSpreadOff;
    final Offset shadowOffsetOn;
    final Offset shadowOffsetOff;
    final Color glowColor;
    final String? iconAsset;
    final BoxFit iconFit;
    final EdgeInsets iconPadding;
    final String label;
    final double labelFontSize;
    final Color labelColor;
    final Color pressOverlayColor;
    final double pressOverlayOpacity;
    final bool transparentIdle;

    const BtnCfg({
      required this.width,
      required this.height,
      required this.margin,
      required this.radius,
      required this.baseColor,
      required this.borderColor,
      required this.borderWidthOn,
      required this.borderWidthOff,
      required this.glowBlurOn,
      required this.glowSpreadOn,
      required this.glowBlurOff,
      required this.glowSpreadOff,
      required this.shadowOffsetOn,
      required this.shadowOffsetOff,
      required this.glowColor,
      required this.iconAsset,
      required this.iconFit,
      required this.iconPadding,
      required this.label,
      required this.labelFontSize,
      required this.labelColor,
      required this.pressOverlayColor,
      required this.pressOverlayOpacity,
      this.transparentIdle = false,
    });

    BtnCfg copyWith({
      double? width,
      double? height,
      EdgeInsets? margin,
      double? radius,
      Color? baseColor,
      Color? borderColor,
      double? borderWidthOn,
      double? borderWidthOff,
      double? glowBlurOn,
      double? glowSpreadOn,
      double? glowBlurOff,
      double? glowSpreadOff,
      Offset? shadowOffsetOn,
      Offset? shadowOffsetOff,
      Color? glowColor,
      String? iconAsset,
      BoxFit? iconFit,
      EdgeInsets? iconPadding,
      String? label,
      double? labelFontSize,
      Color? labelColor,
      Color? pressOverlayColor,
      double? pressOverlayOpacity,
      bool? transparentIdle,
    }) {
      return BtnCfg(
        width: width ?? this.width,
        height: height ?? this.height,
        margin: margin ?? this.margin,
        radius: radius ?? this.radius,
        baseColor: baseColor ?? this.baseColor,
        borderColor: borderColor ?? this.borderColor,
        borderWidthOn: borderWidthOn ?? this.borderWidthOn,
        borderWidthOff: borderWidthOff ?? this.borderWidthOff,
        glowBlurOn: glowBlurOn ?? this.glowBlurOn,
        glowSpreadOn: glowSpreadOn ?? this.glowSpreadOn,
        glowBlurOff: glowBlurOff ?? this.glowBlurOff,
        glowSpreadOff: glowSpreadOff ?? this.glowSpreadOff,
        shadowOffsetOn: shadowOffsetOn ?? this.shadowOffsetOn,
        shadowOffsetOff: shadowOffsetOff ?? this.shadowOffsetOff,
        glowColor: glowColor ?? this.glowColor,
        iconAsset: iconAsset ?? this.iconAsset,
        iconFit: iconFit ?? this.iconFit,
        iconPadding: iconPadding ?? this.iconPadding,
        label: label ?? this.label,
        labelFontSize: labelFontSize ?? this.labelFontSize,
        labelColor: labelColor ?? this.labelColor,
        pressOverlayColor: pressOverlayColor ?? this.pressOverlayColor,
        pressOverlayOpacity: pressOverlayOpacity ?? this.pressOverlayOpacity,
        transparentIdle: transparentIdle ?? this.transparentIdle,
      );
    }
  }

  ///  Config ปุ่ม Speed (Tap)
  class TapCfg {
    final double width, height;
    final EdgeInsets margin;
    final double radius;

    final List<Color> gradient;
    final Color border;
    final double borderWidthSelected;
    final double borderWidthUnselected;

    final double glowBlurSelected;
    final double glowBlurUnselected;
    final Offset shadowOffsetSelected;
    final Offset shadowOffsetUnselected;
    final Color glowColor;

    final String label;
    final double fontSize;
    final Color textOn;
    final Color textOff;

    const TapCfg({
      required this.width,
      required this.height,
      required this.margin,
      required this.radius,
      required this.gradient,
      required this.border,
      required this.borderWidthSelected,
      required this.borderWidthUnselected,
      required this.glowBlurSelected,
      required this.glowBlurUnselected,
      required this.shadowOffsetSelected,
      required this.shadowOffsetUnselected,
      required this.glowColor,
      required this.label,
      required this.fontSize,
      required this.textOn,
      required this.textOff,
    });

    TapCfg copyWith({
      double? width,
      double? height,
      EdgeInsets? margin,
      double? radius,
      List<Color>? gradient,
      Color? border,
      double? borderWidthSelected,
      double? borderWidthUnselected,
      double? glowBlurSelected,
      double? glowBlurUnselected,
      Offset? shadowOffsetSelected,
      Offset? shadowOffsetUnselected,
      Color? glowColor,
      String? label,
      double? fontSize,
      Color? textOn,
      Color? textOff,
    }) {
      return TapCfg(
        width: width ?? this.width,
        height: height ?? this.height,
        margin: margin ?? this.margin,
        radius: radius ?? this.radius,
        gradient: gradient ?? this.gradient,
        border: border ?? this.border,
        borderWidthSelected: borderWidthSelected ?? this.borderWidthSelected,
        borderWidthUnselected:
            borderWidthUnselected ?? this.borderWidthUnselected,
        glowBlurSelected: glowBlurSelected ?? this.glowBlurSelected,
        glowBlurUnselected: glowBlurUnselected ?? this.glowBlurUnselected,
        shadowOffsetSelected: shadowOffsetSelected ?? this.shadowOffsetSelected,
        shadowOffsetUnselected:
            shadowOffsetUnselected ?? this.shadowOffsetUnselected,
        glowColor: glowColor ?? this.glowColor,
        label: label ?? this.label,
        fontSize: fontSize ?? this.fontSize,
        textOn: textOn ?? this.textOn,
        textOff: textOff ?? this.textOff,
      );
    }
  }

  ///  Config การ์ด Command
  class CommandCardCfg {
    final double width;
    final EdgeInsets margin;
    final EdgeInsets padding;

    final List<Color> background;
    final double radius;

    final Color borderColor;
    final double borderWidth;

    final double shadowBlur;
    final Offset shadowOffset;
    final Color shadowColor;

    final double titleFont;
    final double valueFont;
    final Color textColor;
    final Color valueColor;
    final Color dividerColor;

    const CommandCardCfg({
      required this.width,
      required this.margin,
      required this.padding,
      required this.background,
      required this.radius,
      required this.borderColor,
      required this.borderWidth,
      required this.shadowBlur,
      required this.shadowOffset,
      required this.shadowColor,
      required this.titleFont,
      required this.valueFont,
      required this.textColor,
      required this.valueColor,
      required this.dividerColor,
    });

    CommandCardCfg copyWith({
      double? width,
      EdgeInsets? margin,
      EdgeInsets? padding,
      List<Color>? background,
      double? radius,
      Color? borderColor,
      double? borderWidth,
      double? shadowBlur,
      Offset? shadowOffset,
      Color? shadowColor,
      double? titleFont,
      double? valueFont,
      Color? textColor,
      Color? valueColor,
      Color? dividerColor,
    }) {
      return CommandCardCfg(
        width: width ?? this.width,
        margin: margin ?? this.margin,
        padding: padding ?? this.padding,
        background: background ?? this.background,
        radius: radius ?? this.radius,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        shadowBlur: shadowBlur ?? this.shadowBlur,
        shadowOffset: shadowOffset ?? this.shadowOffset,
        shadowColor: shadowColor ?? this.shadowColor,
        titleFont: titleFont ?? this.titleFont,
        valueFont: valueFont ?? this.valueFont,
        textColor: textColor ?? this.textColor,
        valueColor: valueColor ?? this.valueColor,
        dividerColor: dividerColor ?? this.dividerColor,
      );
    }
  }

  ///  ปุ่มกดค้าง (Hold)
  class GamepadHoldButton extends StatefulWidget {
    final BtnCfg cfg;
    final void Function(bool down) onChange;
    final bool? forceOn;
    const GamepadHoldButton({
      super.key,
      required this.cfg,
      required this.onChange,
      this.forceOn,
    });

    @override
    State<GamepadHoldButton> createState() => _GamepadHoldButtonState();
  }

  class _GamepadHoldButtonState extends State<GamepadHoldButton> {
    int _activePointers = 0;

    void _update(bool down) {
      if (down) {
        _activePointers++;
        if (_activePointers == 1) widget.onChange(true);
      } else {
        _activePointers = (_activePointers - 1).clamp(0, 999);
        if (_activePointers == 0) widget.onChange(false);
      }
    }

    @override
    Widget build(BuildContext context) {
      final on = widget.forceOn ?? _activePointers > 0;
      final cfg = widget.cfg;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final top = lighten(cfg.baseColor, 0.14);

      final Widget content = (cfg.iconAsset != null)
          ? Padding(
              padding: cfg.iconPadding,
              child: Image.asset(
                cfg.iconAsset!,
                fit: cfg.iconFit,
                errorBuilder: (ctx, err, st) {
                  debugPrint('❌ Image load failed: ${cfg.iconAsset} -> $err');
                  return Container(
                    color: _opacity(Colors.red, .2),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                cfg.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: cfg.labelFontSize,
                  fontWeight: FontWeight.w800,
                  color: cfg.labelColor,
                  shadows: [
                    Shadow(
                      color: _opacity(Colors.black, .25),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );

      final bool transparentIdle = cfg.transparentIdle;
      final bool showFill = !transparentIdle || (!isDark && on);

      final BoxDecoration decoration = transparentIdle
          ? BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(cfg.radius),
              gradient: showFill
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        top,
                        on ? cfg.baseColor : darken(cfg.baseColor, .02),
                      ],
                    )
                  : null,
              border: on
                  ? Border.all(
                      color: _opacity(
                        lighten(cfg.borderColor, .08),
                        on ? .95 : .6,
                      ),
                      width: on ? cfg.borderWidthOn : cfg.borderWidthOff,
                    )
                  : Border.all(color: Colors.transparent, width: 0),
              boxShadow: on
                  ? [
                      BoxShadow(
                        blurRadius: cfg.glowBlurOn,
                        spreadRadius: cfg.glowSpreadOn,
                        offset: cfg.shadowOffsetOn,
                        color: isDark ? cfg.glowColor : _opacity(Colors.black, .22),
                      ),
                    ]
                  : const [],
            )
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, on ? cfg.baseColor : darken(cfg.baseColor, .02)],
              ),
              borderRadius: BorderRadius.circular(cfg.radius),
              border: Border.all(
                color: _opacity(
                  lighten(cfg.borderColor, .08),
                  on ? .95 : .6,
                ),
                width: on ? cfg.borderWidthOn : cfg.borderWidthOff,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: on ? cfg.glowBlurOn : cfg.glowBlurOff,
                  spreadRadius: on ? cfg.glowSpreadOn : cfg.glowSpreadOff,
                  offset: on ? cfg.shadowOffsetOn : cfg.shadowOffsetOff,
                  color: on ? cfg.glowColor : _opacity(Colors.black, .22),
                ),
              ],
            );

      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _buzz();
          _update(true);
        },
        onPointerUp: (_) => _update(false),
        onPointerCancel: (_) => _update(false),
        child: Padding(
          padding: cfg.margin,
          child: SizedBox(
            width: cfg.width,
            height: cfg.height,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: decoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cfg.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      color: on
                          ? _opacity(
                              cfg.pressOverlayColor,
                              cfg.pressOverlayOpacity,
                            )
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  ///  ปุ่ม Tap สำหรับเลือก Speed
class GamepadImageHoldButton extends StatefulWidget {
  final String label;
  final String sendValue;
  final String asset;
  final double diameter;
  final bool showLabel;
  final bool lightImpactBeforeBuzz;
  final void Function(String id, bool isDown)? onPressChanged;

  const GamepadImageHoldButton({
    super.key,
    required this.label,
    required this.sendValue,
    required this.asset,
    this.diameter = 120,
    this.showLabel = true,
    this.lightImpactBeforeBuzz = false,
    this.onPressChanged,
  });

  @override
  State<GamepadImageHoldButton> createState() => _GamepadImageHoldButtonState();
}

class _GamepadImageHoldButtonState extends State<GamepadImageHoldButton> {
  bool _pressed = false;

  void _onDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    if (widget.lightImpactBeforeBuzz) {
      HapticFeedback.lightImpact();
    }
    _buzz();
    widget.onPressChanged?.call(widget.sendValue, true);
  }

  void _onUpOrCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onPressChanged?.call(widget.sendValue, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _pressed ? 0.95 : 1.0;
    final glowColor = _opacity(
      theme.colorScheme.primary,
      theme.brightness == Brightness.dark ? 0.65 : 0.45,
    );

    final coreButton = SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ColorFiltered(
              colorFilter: _pressed
                  ? const ColorFilter.matrix([
                      1, 0, 0, 0, 51,
                      0, 1, 0, 0, 51,
                      0, 0, 1, 0, 51,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.matrix([
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: Image.asset(
                widget.asset,
                fit: BoxFit.contain,
                errorBuilder: (context, _, __) {
                  return SizedBox.expand(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _opacity(theme.colorScheme.onSurface, 0.35),
                          width: 1.4,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    return Listener(
      onPointerDown: (e) {
        final r = widget.diameter / 2;
        final dx = e.localPosition.dx - r;
        final dy = e.localPosition.dy - r;
        if (dx * dx + dy * dy > r * r) return;
        _onDown();
      },
      onPointerMove: (e) {
        if (!_pressed) return;
        final r = widget.diameter / 2;
        final dx = e.localPosition.dx - r;
        final dy = e.localPosition.dy - r;
        final tolerance = r * 1.3;
        if (dx * dx + dy * dy > tolerance * tolerance) {
          _onUpOrCancel();
        }
      },
      onPointerUp: (_) => _onUpOrCancel(),
      onPointerCancel: (_) => _onUpOrCancel(),
      child: widget.showLabel
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                coreButton,
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
            )
          : coreButton,
    );
  }
}

class GamepadTapButton extends StatelessWidget {
    final TapCfg cfg;
    final bool selected;
    final VoidCallback onTap;
    const GamepadTapButton({
      super.key,
      required this.cfg,
      required this.selected,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: cfg.margin,
        child: SizedBox(
          width: cfg.width,
          height: cfg.height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(cfg.radius),
                    onTapDown: (_) => _buzz(),
                    onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: cfg.gradient,
                  ),
                  borderRadius: BorderRadius.circular(cfg.radius),
                  border: Border.all(
                    color: _opacity(cfg.border, selected ? 1 : .6),
                    width: selected
                        ? cfg.borderWidthSelected
                        : cfg.borderWidthUnselected,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: selected
                          ? cfg.glowBlurSelected
                          : cfg.glowBlurUnselected,
                      offset: selected
                          ? cfg.shadowOffsetSelected
                          : cfg.shadowOffsetUnselected,
                      color: cfg.glowColor,
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cfg.label,
                      style: TextStyle(
                        fontSize: cfg.fontSize,
                        fontWeight: FontWeight.w900,
                        color: selected ? cfg.textOn : cfg.textOff,
                        letterSpacing: .2,
                        shadows: [
                          Shadow(
                            color: _opacity(Colors.black, .2),
                            offset: const Offset(0, 1),
                            blurRadius: 1.5,
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
      );
    }
  }

  class GamepadCommandCard extends StatelessWidget {
    final CommandCardCfg cfg;
    final String command;
    final String speed;
    const GamepadCommandCard({
      super.key,
      required this.cfg,
      required this.command,
      required this.speed,
    });

    @override
    Widget build(BuildContext context) {
      final hasSpeed = speed.trim().isNotEmpty;

      return Container(
        width: cfg.width,
        padding: cfg.padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cfg.background,
          ),
          borderRadius: BorderRadius.circular(cfg.radius),
          border: Border.all(color: cfg.borderColor, width: cfg.borderWidth),
          boxShadow: [
            BoxShadow(
              blurRadius: cfg.shadowBlur,
              offset: cfg.shadowOffset,
              color: cfg.shadowColor,
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: cfg.textColor, fontSize: cfg.titleFont),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cmd: '),
                Text(
                  command,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: cfg.valueFont,
                    color: cfg.valueColor,
                  ),
                ),

                if (hasSpeed) ...[
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: cfg.valueFont,
                    color: cfg.dividerColor,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Spd: $speed',
                    style: TextStyle(
                      color: cfg.textColor,
                      fontSize: cfg.titleFont,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  }

class GamepadTutorialCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isThai;
  final bool isLast;
  final bool showBack;
  final Color surfaceColor;
  final Color ctaColor;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final double maxWidth;
  final double? minHeight;
  final bool roomyCompact;
  final bool compact;

  const GamepadTutorialCard({
    super.key,
    required this.title,
    required this.body,
    required this.isThai,
    required this.isLast,
    required this.showBack,
    required this.surfaceColor,
    required this.ctaColor,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
    this.maxWidth = 420,
    this.minHeight,
    this.roomyCompact = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color withOpacity(Color color, double opacity) =>
        color.withAlpha((opacity * 255).round());
    final double cardWidth = math.min<double>(
      MediaQuery.of(context).size.width - 40,
      maxWidth,
    );
    final double padH = compact ? (roomyCompact ? 14 : 10) : 20;
    final double padTop = compact ? (roomyCompact ? 14 : 10) : 20;
    final double padBottom = compact ? (roomyCompact ? 12 : 8) : 18;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: compact
          ? (roomyCompact ? (isThai ? 16.5 : 16.0) : (isThai ? 15.0 : 14.5))
          : (isThai ? 19.0 : 18.0),
      fontWeight: FontWeight.w800,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
      height: 1.15,
    );
    final bodyStyle = TextStyle(
      color: const Color(0xFFD3DAE6),
      fontSize: compact
          ? (roomyCompact ? (isThai ? 12.5 : 12.0) : (isThai ? 11.5 : 11.0))
          : (isThai ? 14.5 : 14.0),
      fontWeight: FontWeight.w500,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
      height: compact ? (roomyCompact ? 1.4 : 1.35) : 1.45,
    );
    final linkStyle = TextStyle(
      color: const Color(0xFFB6BEC9),
      fontSize: compact
          ? (roomyCompact ? (isThai ? 12.5 : 12.0) : (isThai ? 11.5 : 11.0))
          : (isThai ? 13.5 : 13.0),
      fontWeight: FontWeight.w500,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
    );
    final ctaStyle = TextStyle(
      color: Colors.white,
      fontSize: compact
          ? (roomyCompact ? (isThai ? 12.5 : 12.0) : (isThai ? 11.5 : 11.0))
          : (isThai ? 13.5 : 13.0),
      fontWeight: FontWeight.w700,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
    );

    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          border: Border.all(color: withOpacity(Colors.white, 0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: withOpacity(Colors.black, 0.34),
              blurRadius: compact ? 20 : 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: (minHeight != null)
            ? SizedBox(
                height: minHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    padH,
                    padTop,
                    padH,
                    padBottom,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            SizedBox(height: compact ? (roomyCompact ? 6 : 4) : 10),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  bottom: compact ? (roomyCompact ? 44 : 38) : 56,
                                ),
                                child: Text(body, style: bodyStyle),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: onSkip,
                              child: Text(isThai ? 'ข้าม' : 'Skip', style: linkStyle),
                            ),
                            const Spacer(),
                            if (showBack) ...[
                              TextButton(
                                onPressed: onBack,
                                child:
                                    Text(isThai ? 'ย้อนกลับ' : 'Back', style: linkStyle),
                              ),
                              SizedBox(width: compact ? 4 : 8),
                            ],
                            ElevatedButton(
                              onPressed: onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ctaColor,
                                foregroundColor: Colors.white,
                                padding: compact
                                    ? (roomyCompact
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          )
                                        : const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ))
                                    : null,
                                minimumSize: compact
                                    ? (roomyCompact
                                        ? const Size(0, 30)
                                        : const Size(0, 28))
                                    : null,
                                tapTargetSize: compact
                                    ? MaterialTapTargetSize.shrinkWrap
                                    : null,
                              ),
                              child: Text(
                                isLast
                                    ? (isThai ? 'เสร็จสิ้น' : 'Finish')
                                    : (isThai ? 'ถัดไป' : 'Next'),
                                style: ctaStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  padH,
                  padTop,
                  padH,
                  padBottom,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle),
                        SizedBox(height: compact ? (roomyCompact ? 6 : 4) : 10),
                        Text(body, style: bodyStyle),
                        SizedBox(height: compact ? (roomyCompact ? 10 : 6) : 18),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onSkip,
                              child: Text(isThai ? 'ข้าม' : 'Skip', style: linkStyle),
                            ),
                            const Spacer(),
                            if (showBack) ...[
                              TextButton(
                                onPressed: onBack,
                                child:
                                    Text(isThai ? 'ย้อนกลับ' : 'Back', style: linkStyle),
                              ),
                              SizedBox(width: compact ? 4 : 8),
                            ],
                            ElevatedButton(
                              onPressed: onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ctaColor,
                                foregroundColor: Colors.white,
                                padding: compact
                                    ? (roomyCompact
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          )
                                        : const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ))
                                    : null,
                                minimumSize: compact
                                    ? (roomyCompact
                                        ? const Size(0, 30)
                                        : const Size(0, 28))
                                    : null,
                                tapTargetSize: compact
                                    ? MaterialTapTargetSize.shrinkWrap
                                    : null,
                              ),
                              child: Text(
                                isLast
                                    ? (isThai ? 'เสร็จสิ้น' : 'Finish')
                                    : (isThai ? 'ถัดไป' : 'Next'),
                                style: ctaStyle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
