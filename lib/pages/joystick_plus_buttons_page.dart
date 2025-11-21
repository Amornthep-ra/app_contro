// lib/pages/joystick_plus_buttons_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../ble/ble_manager.dart';
import '../UI/gamepad_assets.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/logo_corner.dart';
import '../widgets/connection_status_badge.dart';
import '../UI/joystick_theme.dart';
import '../utils/orientation_utils.dart';

import '../joystick/joystick_packet.dart';
import 'joystick_control_page.dart';
import 'home_page.dart';

class JoystickPlusButtonsPage extends StatefulWidget {
  const JoystickPlusButtonsPage({super.key});

  @override
  State<JoystickPlusButtonsPage> createState() =>
      _JoystickPlusButtonsPageState();
}

class _JoystickPlusButtonsPageState extends State<JoystickPlusButtonsPage> {
  bool _showModeMenu = false;

  // --- Joystick values ---
  double _smoothX = 0.0, _smoothY = 0.0;
  double _lastX = 0.0, _lastY = 0.0;

  static const double _deadZone = 0.08;
  static const double _smooth = 0.15;
  static const double _delta = 0.02;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  // --- Debug ---
  String _joyDebug = "JL: (0,0)";
  String _btnDebug = "BTN: 0";

  // --- Buttons ---
  String _currentButton = "0";
  Timer? _btnTimer;

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    // ส่งปุ่มซ้ำทุก 16ms
    _btnTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => BleManager.instance.send(_currentButton),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    OrientationUtils.setLandscape();
  }

  @override
  void dispose() {
    _btnTimer?.cancel();
    // ไม่ setPortrait ที่นี่ เพราะออกด้วย back เราคุมเองใน _onBack()
    super.dispose();
  }

  // ======================================================
  // JOYSTICK PROCESS
  // ======================================================
  void _processJoystick(Offset off) {
    double x = (off.dx.abs() < _deadZone) ? 0 : off.dx;
    double y = (off.dy.abs() < _deadZone) ? 0 : off.dy;

    final sx = _lerp(_smoothX, x, _smooth);
    final sy = _lerp(_smoothY, y, _smooth);

    _smoothX = sx;
    _smoothY = sy;

    if ((sx - _lastX).abs() > _delta || (sy - _lastY).abs() > _delta) {
      _lastX = sx;
      _lastY = sy;

      BleManager.instance.sendJoystick(
        JoystickPacket(lx: sx, ly: sy, rx: 0, ry: 0),
      );

      setState(() {
        _joyDebug = "JL: (${sx.toStringAsFixed(2)}, ${sy.toStringAsFixed(2)})";
      });
    }
  }

  // ======================================================
  // RESET JOYSTICK (กันค่าค้าง)
  // ======================================================
  void _resetJoystick() {
    _smoothX = 0;
    _smoothY = 0;
    _lastX = 0;
    _lastY = 0;

    // ส่ง 0 ซ้ำ 2 ครั้ง กัน smoothing / ESP ค้าง
    BleManager.instance.sendJoystick(
      JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      BleManager.instance.sendJoystick(
        JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      );
    });

    setState(() => _joyDebug = "JL: (0,0)");
  }

  // ======================================================
  // BUTTON
  // ======================================================
  void _onButtonPress(String code, bool down) {
    setState(() {
      _currentButton = down ? code : "0";
      _btnDebug = "BTN: $_currentButton";
    });
  }

  // ======================================================
  // MODE MENU (เหมือนของ Mode 1)
  // ======================================================
  Widget _buildModePopover() {
    return Positioned(
      top: 56,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          width: 220,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              _modeItem(
                "Mode 1: Dual Joystick",
                Icons.sports_esports,
                () {
                  setState(() => _showModeMenu = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JoystickControlPage(),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white24),
              _modeItem(
                "Mode 2: Joystick + Buttons",
                Icons.tune,
                () {
                  // อยู่โหมดนี้แล้ว แค่ปิดเมนู
                  setState(() => _showModeMenu = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeItem(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.lightBlueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // BACK → กลับ Home เสมอ (เหมือน Mode 1)
  // ======================================================
  Future<bool> _onBack() async {
    OrientationUtils.setPortrait();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    return false;
  }

  // ======================================================
  // BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final joyT = joystickTheme;

    return WillPopScope(
      onWillPop: _onBack,
      child: GestureDetector(
        onTap: () {
          if (_showModeMenu) setState(() => _showModeMenu = false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Joystick + Buttons Mode"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _onBack,
            ),
            actions: [
              const ConnectionStatusBadge(),
              const SizedBox(width: 8),
              const _ModeBadge(
                icon: Icons.tune,
                label: "Mode: Joystick + Buttons",
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  setState(() => _showModeMenu = !_showModeMenu);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Row(
                  children: [
                    // =========================================
                    // LEFT: JOYSTICK
                    // =========================================
                    Expanded(
                      child: Center(
                        child: VirtualJoystick(
                          theme: joyT,
                          isLeft: true,
                          onChanged: _processJoystick,
                          onReset: _resetJoystick,
                        ),
                      ),
                    ),

                    // =========================================
                    // RIGHT: 4 BUTTONS (รูปจอย)
                    // =========================================
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final s = c.maxWidth * 0.55;
                          final btn = s * 0.36;
                          final gap = s * 0.18;
                          final cx = c.maxWidth * 0.5;
                          final cy = c.maxHeight * 0.45;

                          return Stack(
                            children: [
                              Positioned(
                                left: cx - btn / 2,
                                top: cy - btn - gap,
                                child: _buildRoundBtn(
                                    btn, "T", kGamepad8AssetTriangle),
                              ),
                              Positioned(
                                left: cx - btn / 2,
                                top: cy + gap,
                                child: _buildRoundBtn(
                                    btn, "X", kGamepad8AssetCross),
                              ),
                              Positioned(
                                left: cx - btn - gap,
                                top: cy - btn / 2,
                                child: _buildRoundBtn(
                                    btn, "SQ", kGamepad8AssetSquare),
                              ),
                              Positioned(
                                left: cx + gap,
                                top: cy - btn / 2,
                                child: _buildRoundBtn(
                                    btn, "C", kGamepad8AssetCircle),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // DEBUG BAR (เหมือน Mode 1 style)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _debugBox(_joyDebug),
                        const SizedBox(width: 20),
                        _debugBox(_btnDebug),
                      ],
                    ),
                  ),
                ),

                const LogoCorner(),

                if (_showModeMenu) _buildModePopover(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // UI HELPERS
  // ======================================================
  Widget _buildRoundBtn(double size, String id, String asset) {
    return Listener(
      onPointerDown: (_) => _onButtonPress(id, true),
      onPointerUp: (_) => _onButtonPress(id, false),
      onPointerCancel: (_) => _onButtonPress(id, false),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _debugBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontFamily: "monospace",
        ),
      ),
    );
  }
}

// ======================================================
// MODE BADGE (ให้หน้าตาเหมือน Mode 1)
// ======================================================
class _ModeBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ModeBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
