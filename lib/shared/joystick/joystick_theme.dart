// lib/shared/joystick/joystick_theme.dart
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

    // ✅ base BG (จะถูกใช้เป็น fallback ใน Light mode
    // ใน Dark mode วงใหญ่ใช้ RadialGradient ใน joystick_view.dart อยู่แล้ว)
    this.bgColor = const Color(0xFF0D0F14),
    this.bgOpacity = 0.26,

    // ✅ ขอบวงใหญ่ — ตั้งเป็น “neon-ish” ในโทนดำ
    // joystick_view.dart จะเอาไป withOpacity เพิ่ม/ลดตาม dark-light อีกที
    this.borderColor = const Color(0xFF6B7CFF), // ฟ้าอมม่วงแบบปุ่ม
    this.borderWidth = 2.4,

    // ✅ สี knob fallback (ถ้าไม่ได้ใช้รูป)
    this.knobColorStart = const Color(0xFF8A5CFF),
    this.knobColorEnd = const Color(0xFF3D42D6),
    this.knobOpacity = 0.92,
    this.knobBorderColor = const Color(0xFFB9C6FF),
    this.knobBorderWidth = 2.0,

    // ⭐ แยกซ้าย/ขวาแล้ว
    this.leftKnobImage,
    this.rightKnobImage,

    this.knobShadowBlur = 16,
    this.knobShadowColor = const Color(0x66000000),

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
