// lib/UI/joystick_theme.dart
import 'package:flutter/material.dart';

class JoystickTheme {
  // ========== Size ==========
  final double size;
  final double knobSize;

  // ========== BG ==========
  final Color bgColor;
  final double bgOpacity;
  final Color borderColor;
  final double borderWidth;

  // ========== Knob colors (fallback) ==========
  final Color knobColorStart;
  final Color knobColorEnd;
  final double knobOpacity;
  final Color knobBorderColor;
  final double knobBorderWidth;

  // ========== Knob images (L/R) ==========
  final String? leftKnobImage;
  final String? rightKnobImage;

  // ========== Shadow ==========
  final double knobShadowBlur;
  final Color knobShadowColor;

  // ========== Debug ==========
  final Color debugBgColor;
  final Color debugTextColor;
  final double debugFontSize;
  final EdgeInsets debugPadding;
  final double debugRadius;
  final double debugMinWidth;

  const JoystickTheme({
    this.size = 280,
    this.knobSize = 90,

    this.bgColor = Colors.black,
    this.bgOpacity = 0.18,
    this.borderColor = const Color.fromARGB(82, 0, 0, 0),
    this.borderWidth = 2.0,

    this.knobColorStart = const Color(0xFF5C6BFF),
    this.knobColorEnd = const Color(0xFF2D39B5),
    this.knobOpacity = 0.90,
    this.knobBorderColor = Colors.white70,
    this.knobBorderWidth = 2.0,

    // ⭐ แยกซ้าย/ขวาแล้ว
    this.leftKnobImage,
    this.rightKnobImage,

    this.knobShadowBlur = 16,
    this.knobShadowColor = const Color(0x55000000),

    this.debugBgColor = Colors.black87,
    this.debugTextColor = Colors.greenAccent,
    this.debugFontSize = 16,
    this.debugPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.debugRadius = 14,
    this.debugMinWidth = 260,
  });
}

// ⭐ ใช้รูปจริงที่คุณให้มา
const joystickTheme = JoystickTheme(
  leftKnobImage:  "assets/icons/botton/knob_joystick_M.png",
  rightKnobImage: "assets/icons/botton/knob_joystick_WM.png",
);
