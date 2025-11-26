// lib/features/joystick/joystick/joystick_theme.dart
import 'package:flutter/material.dart';

class JoystickTheme {
  final double size;
  final double knobSize;

  final Color bgColor;
  final double bgOpacity;
  final Color borderColor;
  final double borderWidth;

  final Color knobColorStart;
  final Color knobColorEnd;
  final double knobOpacity;
  final Color knobBorderColor;
  final double knobBorderWidth;

  final String? leftKnobImage;
  final String? rightKnobImage;

  final double knobShadowBlur;
  final Color knobShadowColor;

  final Color debugBgColor;
  final Color debugTextColor;
  final double debugFontSize;
  final EdgeInsets debugPadding;
  final double debugRadius;
  final double debugMinWidth;

  const JoystickTheme({
    this.size = 200,
    this.knobSize = 80,

    this.bgColor = const Color(0xFF0D0F14),
    this.bgOpacity = 0.26,

    this.borderColor = const Color(0xFF6B7CFF),
    this.borderWidth = 2.4,

    this.knobColorStart = const Color(0xFF8A5CFF),
    this.knobColorEnd = const Color(0xFF3D42D6),
    this.knobOpacity = 0.92,
    this.knobBorderColor = const Color(0xFFB9C6FF),
    this.knobBorderWidth = 2.0,

    this.leftKnobImage,
    this.rightKnobImage,

    this.knobShadowBlur = 16,
    this.knobShadowColor = const Color(0x66000000),

    this.debugBgColor = Colors.black87,
    this.debugTextColor = Colors.greenAccent,
    this.debugFontSize = 12,
    this.debugPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.debugRadius = 14,
    this.debugMinWidth = 18,
  });
}

const joystickTheme = JoystickTheme(
  size: 200,
  knobSize: 60,
  leftKnobImage:  "assets/icons/botton/knob_joystick_M.png",
  rightKnobImage: "assets/icons/botton/knob_joystick_WM.png",
);
