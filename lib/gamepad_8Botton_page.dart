// lib/gamepad_8Botton_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ble_manager.dart'; // ⬅ ใช้ BLE
import 'UI/gamepad_assets.dart';
import 'UI/gamepad_components.dart';
import 'widgets/logo_corner.dart';
import 'widgets/connection_status_badge.dart';
import 'utils/orientation_utils.dart';

// ==================== PROTOCOL CONFIG ====================

// ไม่กดอะไรเลย → ส่ง "0"
const String kIdle = '0';

// ส่งซ้ำทุก 120 ms
const int kRepeatMs = 120;

// ตัวย่อคำสั่งปุ่ม
const String kCmdUp = 'U';
const String kCmdDown = 'D';
const String kCmdLeft = 'L';
const String kCmdRight = 'R';

const String kCmdTriangle = 'T';
const String kCmdCross = 'X';
const String kCmdSquare = 'SQ';
const String kCmdCircle = 'C';

class Gamepad_8Botton extends StatefulWidget {
  const Gamepad_8Botton({super.key});
  @override
  State<Gamepad_8Botton> createState() => _Gamepad_8BottonState();
}

class _Gamepad_8BottonState extends State<Gamepad_8Botton> {
  List<DeviceOrientation>? _prev;

  // คำสั่งล่าสุดที่ส่งแสดงบนการ์ด
  String _command = kIdle;

  // timer สำหรับส่งซ้ำ (เหมือน gamepad 4)
  Timer? _tick;

  // state ปุ่มฝั่งซ้าย (ทิศ)
  bool _up = false;
  bool _down = false;
  bool _left = false;
  bool _right = false;

  // state ปุ่มฝั่งขวา (สัญลักษณ์)
  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape(); // ← บังคับแนวนอน

    // ส่งคำสั่งซ้ำทุก kRepeatMs ms ตาม state ปุ่มปัจจุบัน
    _tick = Timer.periodic(
      const Duration(milliseconds: kRepeatMs),
      (_) => _sendLoop(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    OrientationUtils.setPortrait(); // ← คืนแนวตั้งตอนออก
    super.dispose();
  }

  // (ของเดิม - ไม่ได้ใช้แล้ว แต่คงไว้ไม่แตะส่วนอื่น)
  Future<void> _lockLandscape() async {
    _prev = const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreOrientation() async {
    await SystemChrome.setPreferredOrientations(
      _prev ??
          const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
    );
  }

  // ---------- callback จากปุ่มฝั่งซ้าย (U/D/L/R) ----------
  void _onLeftPress(String id, bool isDown) {
    setState(() {
      // กดปุ่มใหม่ → ปิดปุ่มอื่นฝั่งซ้าย เหลือได้ 1 ปุ่ม
      if (isDown) {
        _up = id == kCmdUp;
        _down = id == kCmdDown;
        _left = id == kCmdLeft;
        _right = id == kCmdRight;
      } else {
        // ปล่อยปุ่ม: ปิดเฉพาะตัวเอง
        if (id == kCmdUp) _up = false;
        if (id == kCmdDown) _down = false;
        if (id == kCmdLeft) _left = false;
        if (id == kCmdRight) _right = false;
      }
    });
  }

  // ---------- callback จากปุ่มฝั่งขวา (T/X/SQ/C) ----------
  void _onRightPress(String id, bool isDown) {
    setState(() {
      // กดปุ่มใหม่ → ปิดปุ่มอื่นฝั่งขวา เหลือได้ 1 ปุ่ม
      if (isDown) {
        _triangle = id == kCmdTriangle;
        _cross = id == kCmdCross;
        _square = id == kCmdSquare;
        _circle = id == kCmdCircle;
      } else {
        // ปล่อยปุ่ม: ปิดเฉพาะตัวเอง
        if (id == kCmdTriangle) _triangle = false;
        if (id == kCmdCross) _cross = false;
        if (id == kCmdSquare) _square = false;
        if (id == kCmdCircle) _circle = false;
      }
    });
  }

  // ---------- สร้างคำสั่งจาก state ปัจจุบัน + ส่ง BLE ----------
  void _sendLoop() {
    // เลือกปุ่มฝั่งซ้าย 1 ปุ่ม (ถ้ามี)
    String left = '';
    if (_up) {
      left = kCmdUp;
    } else if (_down) {
      left = kCmdDown;
    } else if (_left) {
      left = kCmdLeft;
    } else if (_right) {
      left = kCmdRight;
    }

    // เลือกปุ่มฝั่งขวา 1 ปุ่ม (ถ้ามี)
    String right = '';
    if (_triangle) {
      right = kCmdTriangle;
    } else if (_cross) {
      right = kCmdCross;
    } else if (_square) {
      right = kCmdSquare;
    } else if (_circle) {
      right = kCmdCircle;
    }

    String cmd;

    if (left.isEmpty && right.isEmpty) {
      // ไม่กดอะไรเลย
      cmd = kIdle; // "0"
    } else if (left.isNotEmpty && right.isEmpty) {
      // กดเฉพาะฝั่งซ้าย
      cmd = left;
    } else if (left.isEmpty && right.isNotEmpty) {
      // กดเฉพาะฝั่งขวา
      cmd = right;
    } else {
      // ซ้าย 1 ปุ่ม + ขวา 1 ปุ่ม
      cmd = '$left+$right';
    }

    // ส่ง BLE
    BleManager.instance.send(cmd);

    // อัปเดตโชว์บน Command Card เฉพาะตอนเปลี่ยน
    if (cmd != _command) {
      setState(() {
        _command = cmd;
      });
    }
  }

  void _updateCommand(String cmd) {
    // เดิมใช้จากปุ่ม → ตอนนี้ไม่จำเป็นแล้ว
    setState(() => _command = cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Gamepad(8 Button)'),
        actions: const [ConnectionStatusBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, cons) {
                final theme = Theme.of(context);
                final base = theme.colorScheme.surfaceVariant.withOpacity(.70);

                final cardCfg = CommandCardCfg(
                  width: math.min(cons.maxWidth * 0.25, 240),
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  background: [lighten(base, .06), darken(base, .06)],
                  radius: 16,
                  borderColor:
                      theme.colorScheme.outlineVariant.withOpacity(.45),
                  borderWidth: 1.2,
                  shadowBlur: 10,
                  shadowOffset: const Offset(0, 4),
                  shadowColor: Colors.black.withOpacity(.12),
                  titleFont: 14,
                  valueFont: 18,
                  textColor:
                      theme.textTheme.bodyMedium?.color ?? Colors.white,
                  valueColor:
                      theme.textTheme.bodyLarge?.color ?? Colors.white,
                  dividerColor:
                      theme.colorScheme.outlineVariant.withOpacity(.6),
                );

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // ฝั่งซ้าย: ปุ่มทิศทาง U/D/L/R
                      Expanded(
                        child: _DpadPanel(
                          up: const _BtnSpec('Up', kCmdUp, kGamepad8AssetUp),
                          down: const _BtnSpec(
                              'Down', kCmdDown, kGamepad8AssetDown),
                          left: const _BtnSpec(
                              'Left', kCmdLeft, kGamepad8AssetLeft),
                          right: const _BtnSpec(
                              'Right', kCmdRight, kGamepad8AssetRight),
                          onPressChanged: _onLeftPress,
                        ),
                      ),
                      // การ์ดแสดงคำสั่ง
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: cardCfg.width,
                          maxWidth: cardCfg.width,
                        ),
                        child: Center(
                          child: GamepadCommandCard(
                            cfg: cardCfg,
                            command: _command,
                            speed: '',
                          ),
                        ),
                      ),
                      // ฝั่งขวา: ปุ่ม Triangle / Cross / Square / Circle
                      Expanded(
                        child: _DpadPanel(
                          up: const _BtnSpec(
                              'Triangle', kCmdTriangle, kGamepad8AssetTriangle),
                          down: const _BtnSpec(
                              'Cross', kCmdCross, kGamepad8AssetCross),
                          left: const _BtnSpec(
                              'Square', kCmdSquare, kGamepad8AssetSquare),
                          right: const _BtnSpec(
                              'Circle', kCmdCircle, kGamepad8AssetCircle),
                          onPressChanged: _onRightPress,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const LogoCorner(),
          ],
        ),
      ),
    );
  }
}

// ==================== WIDGETS (UI เดิมทั้งหมด) ====================

class _BtnSpec {
  final String label, sendValue, asset;
  const _BtnSpec(this.label, this.sendValue, this.asset);
}

class _DpadPanel extends StatelessWidget {
  final _BtnSpec up, down, left, right;

  // callback: ส่ง id + กด/ปล่อย กลับขึ้นไปให้ parent
  final void Function(String id, bool isDown) onPressChanged;

  const _DpadPanel({
    super.key,
    required this.up,
    required this.down,
    required this.left,
    required this.right,
    required this.onPressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final s = math.min(c.maxWidth, c.maxHeight);
        final btn = s * 0.35;
        final gap = s * 0.10;
        final cx = s / 2, cy = s / 2;

        return Center(
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              children: [
                Positioned(
                  left: cx - btn / 2,
                  top: cy - gap - btn,
                  child: _ImagePressHoldButton(
                    label: up.label,
                    sendValue: up.sendValue,
                    asset: up.asset,
                    diameter: btn,
                    showLabel: false,
                    onPressChanged: onPressChanged,
                  ),
                ),
                Positioned(
                  left: cx - btn / 2,
                  top: cy + gap,
                  child: _ImagePressHoldButton(
                    label: down.label,
                    sendValue: down.sendValue,
                    asset: down.asset,
                    diameter: btn,
                    showLabel: false,
                    onPressChanged: onPressChanged,
                  ),
                ),
                Positioned(
                  left: cx - gap - btn,
                  top: cy - btn / 2,
                  child: _ImagePressHoldButton(
                    label: left.label,
                    sendValue: left.sendValue,
                    asset: left.asset,
                    diameter: btn,
                    showLabel: false,
                    onPressChanged: onPressChanged,
                  ),
                ),
                Positioned(
                  left: cx + gap,
                  top: cy - btn / 2,
                  child: _ImagePressHoldButton(
                    label: right.label,
                    sendValue: right.sendValue,
                    asset: right.asset,
                    diameter: btn,
                    showLabel: false,
                    onPressChanged: onPressChanged,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImagePressHoldButton extends StatefulWidget {
  final String label;
  final String sendValue;
  final String asset;
  final double diameter;
  final bool showLabel;

  // callback → ส่ง id + กด/ปล่อย
  final void Function(String id, bool isDown)? onPressChanged;

  const _ImagePressHoldButton({
    super.key,
    required this.label,
    required this.sendValue,
    required this.asset,
    this.diameter = 120,
    this.showLabel = true,
    this.onPressChanged,
  });

  @override
  State<_ImagePressHoldButton> createState() => _ImagePressHoldButtonState();
}

class _ImagePressHoldButtonState extends State<_ImagePressHoldButton> {
  bool _pressed = false;

  void _onDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    // แจ้ง parent ว่าปุ่มนี้ถูกกดลง
    widget.onPressChanged?.call(widget.sendValue, true);
  }

  void _onUpOrCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    // แจ้ง parent ว่าปุ่มนี้ถูกปล่อย
    widget.onPressChanged?.call(widget.sendValue, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnSize = widget.diameter;

    final baseColor = theme.colorScheme.surface;
    final accent = const Color(0xFF5C6BFF);

    final normalTop = lighten(baseColor, .08);
    final normalBottom = darken(baseColor, .12);
    final pressedTop = lighten(accent, .10);
    final pressedBottom = darken(accent, .18);

    final gradientColors = _pressed
        ? [pressedTop, pressedBottom]
        : [normalTop, normalBottom];

    final borderColor = _pressed
        ? Colors.cyanAccent.withOpacity(0.95)
        : Colors.black.withOpacity(0.45);

    final borderWidth = _pressed ? 3.0 : 1.4;

    final shadowBlur = _pressed ? 22.0 : 14.0;
    final shadowOffset = _pressed ? const Offset(0, 6) : const Offset(0, 4);
    final shadowColor = _pressed
        ? const Color(0xFF00FFFF).withOpacity(0.55)
        : Colors.black.withOpacity(0.30);

    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUpOrCancel(),
      onPointerCancel: (_) => _onUpOrCancel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: AnimatedScale(
              scale: _pressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: shadowBlur,
                      offset: shadowOffset,
                      color: shadowColor,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.asset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        color: _pressed
                            ? Colors.white.withOpacity(0.14)
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
