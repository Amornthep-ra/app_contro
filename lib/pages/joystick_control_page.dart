// lib/pages/joystick_control_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../ble/ble_manager.dart';
import '../joystick/joystick_controller.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/connection_status_badge.dart';
import '../UI/joystick_theme.dart';
import '../utils/orientation_utils.dart';

import 'joystick_plus_buttons_page.dart';
import 'home_page.dart';

class JoystickControlPage extends StatefulWidget {
  const JoystickControlPage({super.key});

  @override
  State<JoystickControlPage> createState() => _JoystickControlPageState();
}

class _JoystickControlPageState extends State<JoystickControlPage>
    with SingleTickerProviderStateMixin {
  final JoystickController _controller = JoystickController();
  Timer? _timer;

  bool _showModeMenu = false;

  late AnimationController _menuAnim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  double _smoothLX = 0.0, _smoothLY = 0.0;
  double _smoothRX = 0.0, _smoothRY = 0.0;

  double _lastLX = 0.0, _lastLY = 0.0;
  double _lastRX = 0.0, _lastRY = 0.0;

  static const double _deadZone = 0.08;
  static const double _smooth = 0.15;
  static const double _delta = 0.02;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _leftDebug = "JL: (0,0)";
  String _rightDebug = "JR: (0,0)";

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    // Animation popup menu
    _menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fade = CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0.15, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut));

    // joystick loop
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final packet = _controller.buildPacket();

      final changed =
          (packet.lx - _lastLX).abs() > _delta ||
          (packet.ly - _lastLY).abs() > _delta ||
          (packet.rx - _lastRX).abs() > _delta ||
          (packet.ry - _lastRY).abs() > _delta;

      if (!changed) return;

      _lastLX = packet.lx;
      _lastLY = packet.ly;
      _lastRX = packet.rx;
      _lastRY = packet.ry;

      BleManager.instance.sendJoystick(packet);

      setState(() {
        _leftDebug =
            "JL: (${packet.lx.toStringAsFixed(2)}, ${packet.ly.toStringAsFixed(2)})";
        _rightDebug =
            "JR: (${packet.rx.toStringAsFixed(2)}, ${packet.ry.toStringAsFixed(2)})";
      });
    });
  }

  @override
  void dispose() {
    _menuAnim.dispose();
    _timer?.cancel();
    OrientationUtils.setPortrait();
    super.dispose();
  }

  (double, double) _process(double rawX, double rawY, double sx, double sy) {
    double x = (rawX.abs() < _deadZone) ? 0 : rawX;
    double y = (rawY.abs() < _deadZone) ? 0 : rawY;

    final fx = _lerp(sx, x, _smooth);
    final fy = _lerp(sy, y, _smooth);

    return (fx, fy);
  }

  // ================================
  //  MODE MENU (Glass + Animation)
  // ================================
  Widget _buildModeMenu() {
    return Positioned(
      top: 56,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      color: Colors.black.withOpacity(0.25),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _menuItem(
                      label: "Mode 1: Dual Joystick",
                      icon: Icons.sports_esports,
                      onTap: () {
                        _menuAnim.reverse();
                        Future.delayed(
                            const Duration(milliseconds: 180),
                            () => setState(() => _showModeMenu = false));
                      },
                    ),
                    Divider(color: Colors.white.withOpacity(0.25)),
                    _menuItem(
                      label: "Mode 2: Joystick + Buttons",
                      icon: Icons.tune,
                      onTap: () {
                        _menuAnim.reverse();
                        Future.delayed(const Duration(milliseconds: 180), () {
                          setState(() => _showModeMenu = false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const JoystickPlusButtonsPage(),
                            ),
                          );
                        });
                      },
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

  Widget _menuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15, shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black54,
                  )
                ]),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Back → กลับหน้า Home
  Future<bool> _onBack() async {
    OrientationUtils.setPortrait();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = joystickTheme;

    return WillPopScope(
      onWillPop: _onBack,
      child: GestureDetector(
        onTap: () {
          if (_showModeMenu) {
            _menuAnim.reverse();
            Future.delayed(
                const Duration(milliseconds: 180),
                () => setState(() => _showModeMenu = false));
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _onBack,
            ),
            title: const Text("Joystick Control (Dual)"),

            // ⭐ Glass AppBar
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.12)),
                ),
              ),
            ),

            actions: [
              const ConnectionStatusBadge(),
              const SizedBox(width: 8),
              const _ModeBadge(
                icon: Icons.sports_esports,
                label: "Mode: Dual Joystick",
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  if (!_showModeMenu) {
                    setState(() => _showModeMenu = true);
                    _menuAnim.forward();
                  } else {
                    _menuAnim.reverse();
                    Future.delayed(
                        const Duration(milliseconds: 180),
                        () => setState(() => _showModeMenu = false));
                  }
                },
              ),
            ],
          ),

          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          VirtualJoystick(
                            isLeft: true,
                            theme: t,
                            onChanged: (offset) {
                              final (sx, sy) = _process(
                                  offset.dx, offset.dy, _smoothLX, _smoothLY);
                              _smoothLX = sx;
                              _smoothLY = sy;
                              _controller.setLeftJoystick(sx, sy);
                            },
                            onReset: () {
                              _smoothLX = 0;
                              _smoothLY = 0;
                              _controller.setLeftJoystick(0, 0);
                              setState(() => _leftDebug = "JL: (0,0)");
                            },
                          ),
                          VirtualJoystick(
                            isLeft: false,
                            theme: t,
                            onChanged: (offset) {
                              final (sx, sy) = _process(
                                  offset.dx, offset.dy, _smoothRX, _smoothRY);
                              _smoothRX = sx;
                              _smoothRY = sy;
                              _controller.setRightJoystick(sx, sy);
                            },
                            onReset: () {
                              _smoothRX = 0;
                              _smoothRY = 0;
                              _controller.setRightJoystick(0, 0);
                              setState(() => _rightDebug = "JR: (0,0)");
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _debugBox(_leftDebug),
                        const SizedBox(width: 20),
                        _debugBox(_rightDebug),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

                if (_showModeMenu) _buildModeMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _debugBox(String txt) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        txt,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontFamily: "monospace",
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ModeBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceVariant.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
