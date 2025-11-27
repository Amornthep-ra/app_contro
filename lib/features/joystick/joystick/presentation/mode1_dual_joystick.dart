// lib/pages/mode1_dual_joystick.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/ble/ble_manager.dart';
import '../joystick_controller.dart';
import '../widgets/joystick_widget.dart';
import '../../../../core/widgets/connection_status_badge.dart';
import '../../../../core/utils/orientation_utils.dart';
import '../joystick_theme.dart';
import 'mode2_joystick_buttons.dart';
import '../../../home/home_page.dart';
import '../../../../core/ble/joystick_packet.dart';
import '../../../../core/ui/custom_appbars.dart';
import '../../../../core/widgets/logo_corner.dart';


class Mode1DualJoystickPage extends StatefulWidget {
  const Mode1DualJoystickPage({super.key});

  @override
  State<Mode1DualJoystickPage> createState() => _Mode1DualJoystickPageState();
}

class _Mode1DualJoystickPageState extends State<Mode1DualJoystickPage>
    with SingleTickerProviderStateMixin {
  final JoystickController _controller = JoystickController();
  final LayerLink _menuLink = LayerLink();
  Timer? _timer;

  bool _ignoreOutsideOnce = false;
  bool _showModeMenu = false;
  OverlayEntry? _menuEntry;

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

  String _fmt(double v) => v.toStringAsFixed(2);
  String _leftDebug = "JL: (0.00, 0.00)";
  String _rightDebug = "JR: (0.00, 0.00)";

  void _setLeftDebug(double x, double y) {
    _leftDebug = "JL: (${_fmt(x)}, ${_fmt(y)})";
  }

  void _setRightDebug(double x, double y) {
    _rightDebug = "JR: (${_fmt(x)}, ${_fmt(y)})";
  }

  void _resetLeftJoystick() {
    _smoothLX = 0;
    _smoothLY = 0;
    _lastLX = 0;
    _lastLY = 0;

    _controller.setLeftJoystick(0, 0);

    BleManager.instance.sendJoystick(
      JoystickPacket(lx: 0, ly: 0, rx: _lastRX, ry: _lastRY),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      BleManager.instance.sendJoystick(
        JoystickPacket(lx: 0, ly: 0, rx: _lastRX, ry: _lastRY),
      );
    });

    setState(() => _setLeftDebug(0, 0));
  }

  void _resetRightJoystick() {
    _smoothRX = 0;
    _smoothRY = 0;
    _lastRX = 0;
    _lastRY = 0;

    _controller.setRightJoystick(0, 0);

    BleManager.instance.sendJoystick(
      JoystickPacket(lx: _lastLX, ly: _lastLY, rx: 0, ry: 0),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      BleManager.instance.sendJoystick(
        JoystickPacket(lx: _lastLX, ly: _lastLY, rx: 0, ry: 0),
      );
    });

    setState(() => _setRightDebug(0, 0));
  }

  void _showMenuOverlay() {
    if (_menuEntry != null) return;

    _ignoreOutsideOnce = true;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_ignoreOutsideOnce) return;
                  _hideMenuOverlay();
                },
                child: Container(color: Colors.transparent),
              ),
              CompositedTransformFollower(
                link: _menuLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.transparent,
                  child: _buildMenuContent(),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    _menuAnim.forward();
    setState(() => _showModeMenu = true);

    Future.delayed(const Duration(milliseconds: 120), () {
      _ignoreOutsideOnce = false;
    });
  }

  void _hideMenuOverlay() {
    _menuAnim.reverse();
    Future.delayed(const Duration(milliseconds: 180), () {
      _menuEntry?.remove();
      _menuEntry = null;
      if (mounted) setState(() => _showModeMenu = false);
    });
  }

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    _menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fade = CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0.15, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut));

    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final packet = _controller.buildPacket();

      const zeroEps = 0.015;

      final nearZero =
          packet.lx.abs() < zeroEps &&
          packet.ly.abs() < zeroEps &&
          packet.rx.abs() < zeroEps &&
          packet.ry.abs() < zeroEps;

      if (nearZero &&
          (_lastLX != 0 || _lastLY != 0 || _lastRX != 0 || _lastRY != 0)) {
        _lastLX = 0;
        _lastLY = 0;
        _lastRX = 0;
        _lastRY = 0;

        _smoothLX = 0;
        _smoothLY = 0;
        _smoothRX = 0;
        _smoothRY = 0;

        _controller.setLeftJoystick(0, 0);
        _controller.setRightJoystick(0, 0);

        BleManager.instance.sendJoystick(
          JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
        );
        Future.delayed(const Duration(milliseconds: 20), () {
          BleManager.instance.sendJoystick(
            JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
          );
        });

        setState(() {
          _setLeftDebug(0, 0);
          _setRightDebug(0, 0);
        });
        return;
      }

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
        _setLeftDebug(packet.lx, packet.ly);
        _setRightDebug(packet.rx, packet.ry);
      });
    });
  }

  @override
  void dispose() {
    _menuAnim.dispose();
    _timer?.cancel();
    OrientationUtils.setPortrait();
    _menuEntry?.remove();
    _menuEntry = null;
    super.dispose();
  }

  (double, double) _process(double rawX, double rawY, double sx, double sy) {
    double x = (rawX.abs() < _deadZone) ? 0 : rawX;
    double y = (rawY.abs() < _deadZone) ? 0 : rawY;

    final fx = _lerp(sx, x, _smooth);
    final fy = _lerp(sy, y, _smooth);

    const eps = 0.015;
    final snapX = (fx.abs() < eps) ? 0.0 : fx;
    final snapY = (fy.abs() < eps) ? 0.0 : fy;

    return (snapX, snapY);
  }

  Widget _buildMenuContent() {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.28),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _menuItem(
                    label: "Mode 1: Dual Joystick",
                    icon: Icons.sports_esports,
                    onTap: () {
                      _hideMenuOverlay();
                    },
                  ),
                  Divider(color: Colors.white.withOpacity(0.25)),
                  _menuItem(
                    label: "Mode 2: Joystick + Buttons",
                    icon: Icons.tune,
                    onTap: () {
                      _hideMenuOverlay();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Mode2JoystickButtonsPage(),
                        ),
                      );
                    },
                  ),
                ],
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    // ใช้ด้านสั้นของหน้าจอเป็นฐานคำนวณขนาดจอย → รองรับอัตราส่วนหลายแบบ
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    final joystickSize = shortestSide * 0.42; // ปรับได้ถ้าอยากให้จอยใหญ่/เล็กลง

    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        appBar: JoystickAppBar(
          title: "Joystick Control (Dual)",
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBack,
          ),
          actions: [
            const ConnectionStatusBadge(),
            const SizedBox(width: 8),
            UnconstrainedBox(
              child: CompositedTransformTarget(
                link: _menuLink,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      if (!_showModeMenu) {
                        _showMenuOverlay();
                      } else {
                        _hideMenuOverlay();
                      }
                    },
                    child: const IosPill(
                      icon: Icons.sports_esports,
                      label: "Mode: Dual Joystick",
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: joystickSize,
                              height: joystickSize,
                              child: JoystickWidget(
                                controller: _controller,
                                isLeft: true,
                                knobImage: joystickTheme.leftKnobImage,
                                onChanged: (x, y) {
                                  final (sx, sy) = _process(
                                    x,
                                    y,
                                    _smoothLX,
                                    _smoothLY,
                                  );

                                  _smoothLX = sx;
                                  _smoothLY = sy;
                                  _controller.setLeftJoystick(sx, sy);

                                  if (x == 0 && y == 0) {
                                    _resetLeftJoystick();
                                    return;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: joystickSize,
                              height: joystickSize,
                              child: JoystickWidget(
                                controller: _controller,
                                isLeft: false,
                                knobImage: joystickTheme.rightKnobImage,
                                onChanged: (x, y) {
                                  final (sx, sy) = _process(
                                    x,
                                    y,
                                    _smoothRX,
                                    _smoothRY,
                                  );

                                  _smoothRX = sx;
                                  _smoothRY = sy;
                                  _controller.setRightJoystick(sx, sy);

                                  if (x == 0 && y == 0) {
                                    _resetRightJoystick();
                                    return;
                                  }
                                },
                              ),
                            ),
                          ),
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
              const LogoCorner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugBox(String txt) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          constraints: BoxConstraints(minWidth: joystickTheme.debugMinWidth),
          padding: joystickTheme.debugPadding,
          decoration: BoxDecoration(
            color: joystickTheme.debugBgColor,
            borderRadius: BorderRadius.circular(joystickTheme.debugRadius),
            border: Border.all(color: Colors.white38),
          ),
          child: Text(
            txt,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis, // กันล้นแถว debug
            style: TextStyle(
              color: joystickTheme.debugTextColor,
              fontFamily: "monospace",
              fontSize: joystickTheme.debugFontSize,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class IosPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const IosPill({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  State<IosPill> createState() => _IosPillState();
}

class _IosPillState extends State<IosPill> {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final maxPillW = screenW * 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(maxWidth: maxPillW),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: widget.iconColor ?? Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.1,
                    ),
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
