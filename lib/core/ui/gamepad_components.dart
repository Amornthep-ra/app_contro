  //lib/core/ui/gamepad_components.dart
  import 'package:flutter/material.dart';

  /// =========================
  ///  Helper ปรับสีสว่าง/เข้ม
  /// =========================
  Color lighten(Color c, [double amt = .12]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  Color darken(Color c, [double amt = .14]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  /// =========================
  ///  Config ของปุ่มแบบ Hold
  /// =========================
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
      );
    }
  }

  /// =========================
  ///  Config ปุ่ม Speed (Tap)
  /// =========================
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

  /// =========================
  ///  Config การ์ด Command
  /// =========================
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

  /// =========================
  ///  ปุ่มกดค้าง (Hold)
  /// =========================
  class GamepadHoldButton extends StatefulWidget {
    final BtnCfg cfg;
    final void Function(bool down) onChange;
    const GamepadHoldButton({
      super.key,
      required this.cfg,
      required this.onChange,
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
      final on = _activePointers > 0;
      final cfg = widget.cfg;
      final top = lighten(cfg.baseColor, 0.14);
      final Color bottom = darken(cfg.baseColor, 0.12);

      final Widget content = (cfg.iconAsset != null)
          ? Padding(
              padding: cfg.iconPadding,
              child: Image.asset(
                cfg.iconAsset!,
                fit: cfg.iconFit,
                errorBuilder: (ctx, err, st) {
                  debugPrint('❌ Image load failed: ${cfg.iconAsset} -> $err');
                  return Container(
                    color: Colors.red.withOpacity(.2),
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
                      color: Colors.black.withOpacity(.25),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );

      return Padding(
        padding: cfg.margin,
        child: SizedBox(
          width: cfg.width,
          height: cfg.height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _update(true),
            onPointerUp: (_) => _update(false),
            onPointerCancel: (_) => _update(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [top, on ? cfg.baseColor : darken(cfg.baseColor, .02)],
                ),
                borderRadius: BorderRadius.circular(cfg.radius),
                border: Border.all(
                  color: lighten(cfg.borderColor, .08).withOpacity(on ? .95 : .6),
                  width: on ? cfg.borderWidthOn : cfg.borderWidthOff,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: on ? cfg.glowBlurOn : cfg.glowBlurOff,
                    spreadRadius: on ? cfg.glowSpreadOn : cfg.glowSpreadOff,
                    offset: on ? cfg.shadowOffsetOn : cfg.shadowOffsetOff,
                    color: on ? cfg.glowColor : Colors.black.withOpacity(.22),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cfg.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      color: on
                          ? cfg.pressOverlayColor.withOpacity(
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

  /// =========================
  ///  ปุ่ม Tap สำหรับเลือก Speed
  /// =========================
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
                    color: cfg.border.withOpacity(selected ? 1 : .6),
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
                            color: Colors.black.withOpacity(.2),
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
      final hasSpeed = speed.trim().isNotEmpty; // <= เช็คว่ามี speed จริงไหม

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
                const Text('Command: '),
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
                    'Speed: $speed',
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
