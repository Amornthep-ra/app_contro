// lib/pages/mode2_joystick_buttons.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/ble/ble_manager.dart';
import '../../../../core/ui/gamepad_assets.dart';
import '../../../../core/widgets/logo_corner.dart';
import '../../../../core/widgets/connection_status_badge.dart';
import '../../../../core/utils/orientation_utils.dart';
import '../widgets/joystick_widget.dart';
import '../joystick_controller.dart';
import '../../../../core/ble/joystick_packet.dart';
import '../joystick_theme.dart';
import 'mode1_dual_joystick.dart';
import '../../../home/home_page.dart';
import '../../../../core/ui/custom_appbars.dart';

class Mode2JoystickButtonsPage extends StatefulWidget {
  const Mode2JoystickButtonsPage({super.key});

  @override
  State<Mode2JoystickButtonsPage> createState() =>
      _Mode2JoystickButtonsPageState();
}

class _Mode2JoystickButtonsPageState extends State<Mode2JoystickButtonsPage>
    with SingleTickerProviderStateMixin {
  final JoystickController _joyController = JoystickController();

  final LayerLink _menuLink = LayerLink();
  bool _showModeMenu = false;
  bool _ignoreOutsideOnce = false;
  OverlayEntry? _menuEntry;

  late AnimationController _menuAnim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  Timer? _timer;

  double _smoothX = 0.0, _smoothY = 0.0;
  double _lastX = 0.0, _lastY = 0.0;

  static const double _deadZone = 0.05;
  static const double _smooth = 0.85;
  static const double _delta = 0.005;

  int _debugTick = 0;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _fmt(double v) => v.toStringAsFixed(2);
  String _joyDebug = "JL: (0.00, 0.00)";
  String _btnDebug = "BTN: 0";

  void _setJoyDebug(double x, double y) {
    _joyDebug = "JL: (${_fmt(x)}, ${_fmt(y)})";
  }

  void _setBtnDebug(String code) {
    _btnDebug = "BTN: $code";
  }

  String _currentButton = "0";

  String _lastBtnSent = "0";

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
    if (mounted) {
      setState(() => _showModeMenu = true);
    }

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

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _sendZeroAndClear({bool updateUi = true}) {
    _smoothX = 0;
    _smoothY = 0;
    _lastX = 0;
    _lastY = 0;

    _joyController.setLeftJoystick(0, 0);

    BleManager.instance.sendJoystick(
      JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      BleManager.instance.sendJoystick(
        JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      );
    });

    if (updateUi && mounted) {
      setState(() => _setJoyDebug(0, 0));
    }
  }

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscapeOnly();

    _menuAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fade = CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0.15, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuAnim, curve: Curves.easeOut));

    _timer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      const zeroEps = 0.015;

      final lx = _smoothX;
      final ly = _smoothY;

      final nearZero = lx.abs() < zeroEps && ly.abs() < zeroEps;

      if (nearZero && (_lastX != 0 || _lastY != 0)) {
        _lastX = 0;
        _lastY = 0;

        BleManager.instance.sendJoystick(
          JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
        );
        Future.delayed(const Duration(milliseconds: 20), () {
          BleManager.instance.sendJoystick(
            JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
          );
        });

        if (mounted) {
          setState(() => _setJoyDebug(0, 0));
        }
        return;
      }

      final changed =
          (lx - _lastX).abs() > _delta || (ly - _lastY).abs() > _delta;

      if (!changed) return;

      _lastX = lx;
      _lastY = ly;

      BleManager.instance.sendJoystick(
        JoystickPacket(lx: lx, ly: ly, rx: 0, ry: 0),
      );

      _debugTick++;
      if (!mounted) return;
      if (_debugTick % 3 == 0) {
        setState(() => _setJoyDebug(lx, ly));
      }
    });
  }

 

  @override
  void dispose() {
    _stopTimer();
    _menuAnim.dispose();
    _sendZeroAndClear(updateUi: false);
    _menuEntry?.remove();
    _menuEntry = null;
    super.dispose();
  }

  void _processJoystick(Offset off) {
    double x = (off.dx.abs() < _deadZone) ? 0 : off.dx;
    double y = (off.dy.abs() < _deadZone) ? 0 : off.dy;

    final sx = _lerp(_smoothX, x, _smooth);
    final sy = _lerp(_smoothY, y, _smooth);

    const eps = 0.01;
    final snapX = (sx.abs() < eps) ? 0.0 : sx;
    final snapY = (sy.abs() < eps) ? 0.0 : sy;

    _smoothX = snapX;
    _smoothY = snapY;

    _joyController.setLeftJoystick(snapX, snapY);
  }

  void _resetJoystick() {
    _smoothX = 0;
    _smoothY = 0;
    _lastX = 0;
    _lastY = 0;

    _joyController.setLeftJoystick(0, 0);

    BleManager.instance.sendJoystick(
      JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      BleManager.instance.sendJoystick(
        JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      );
    });

    if (mounted) {
      setState(() => _setJoyDebug(0, 0));
    }
  }

  void _onButtonPress(String code, bool down) {
    final newCode = down ? code : "0";

    if (newCode != _lastBtnSent) {
      BleManager.instance.send(newCode);
      _lastBtnSent = newCode;
    }

    if (!mounted) return;
    setState(() {
      _currentButton = newCode;
      _setBtnDebug(_currentButton);
    });
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
                      _sendZeroAndClear();
                      _stopTimer();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Mode1DualJoystickPage(),
                        ),
                      );
                    },
                  ),
                  Divider(color: Colors.white.withOpacity(0.25)),
                  _menuItem(
                    label: "Mode 2: Joystick + Buttons",
                    icon: Icons.tune,
                    onTap: () {
                      _hideMenuOverlay();
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
    OrientationUtils.reset();
    _sendZeroAndClear();
    _stopTimer();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;
    final joystickSize = shortestSide * 0.42;

    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        appBar: JoystickAppBar(
          title: "Joystick + Buttons Mode",
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
                      icon: Icons.tune,
                      label: "Mode: Joystick + Buttons",
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: joystickSize,
                        height: joystickSize,
                        child: JoystickWidget(
                          controller: _joyController,
                          isLeft: true,
                          knobImage: joystickTheme.leftKnobImage,
                          onChanged: (x, y) {
                            _processJoystick(Offset(x, y));
                            if (x == 0 && y == 0) {
                              _resetJoystick();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final s = c.maxWidth * 0.55;
                        final btn = s * 0.36;
                        final gap = s * 0.12;
                        final cx = c.maxWidth * 0.5;
                        final cy = c.maxHeight * 0.45;

                        return Stack(
                          children: [
                            Positioned(
                              left: cx - btn / 2,
                              top: cy - btn - gap,
                              child: _buildRoundBtn(
                                btn,
                                "T",
                                kGamepad8AssetTriangle,
                              ),
                            ),
                            Positioned(
                              left: cx - btn / 2,
                              top: cy + gap,
                              child: _buildRoundBtn(
                                btn,
                                "X",
                                kGamepad8AssetCross,
                              ),
                            ),
                            Positioned(
                              left: cx - btn - gap,
                              top: cy - btn / 2,
                              child: _buildRoundBtn(
                                btn,
                                "S",
                                kGamepad8AssetSquare,
                              ),
                            ),
                            Positioned(
                              left: cx + gap,
                              top: cy - btn / 2,
                              child: _buildRoundBtn(
                                btn,
                                "C",
                                kGamepad8AssetCircle,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundBtn(double size, String id, String asset) {
    final themeB = Theme.of(context).brightness;
    final platformB = MediaQuery.of(context).platformBrightness;
    final isDark = themeB == Brightness.dark || platformB == Brightness.dark;

    final borderW = size * 0.06;

    return Listener(
      onPointerDown: (_) => _onButtonPress(id, true),
      onPointerUp: (_) => _onButtonPress(id, false),
      onPointerCancel: (_) => _onButtonPress(id, false),
      child: Container(
        width: size,
        height: size,
        decoration: isDark
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF6B7CFF),
                    Color(0xFFB16BFF),
                    Color(0xFF6B7CFF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: size * 0.18,
                    spreadRadius: size * 0.02,
                    color: Colors.black.withOpacity(0.6),
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    blurRadius: size * 0.22,
                    spreadRadius: size * 0.03,
                    color: const Color(0xFF6B7CFF).withOpacity(0.25),
                    offset: const Offset(0, 0),
                  ),
                ],
              )
            : const BoxDecoration(shape: BoxShape.circle),
        child: Padding(
          padding: EdgeInsets.all(isDark ? borderW : 0),
          child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
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
            overflow: TextOverflow.visible,
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
