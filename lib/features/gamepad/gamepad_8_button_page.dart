// lib/features/gamepad/gamepad_8_button_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/gamepad_assets.dart';
import '../../core/ui/gamepad_components.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/ui/custom_appbars.dart';

const String kIdle = '0';

const String kCmdUp = 'F';
const String kCmdDown = 'B';
const String kCmdLeft = 'L';
const String kCmdRight = 'R';

const String kCmdTriangle = 'T';
const String kCmdCross = 'X';
const String kCmdSquare = 'S';
const String kCmdCircle = 'C';

const int kLoopHz = 60;
const int kLoopMs = 1000 ~/ kLoopHz;
const int kMinActiveMs = 150;
const int kMinIdleMs = 600;

class Gamepad_8_Botton extends StatefulWidget {
  const Gamepad_8_Botton({super.key});

  @override
  State<Gamepad_8_Botton> createState() => _Gamepad_8_BottonState();
}

class _Gamepad_8_BottonState extends State<Gamepad_8_Botton> {
  bool _up = false;
  bool _down = false;
  bool _left = false;
  bool _right = false;

  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;

  String _command = kIdle;

  String _moveCmd = kIdle;
  String _actionCmd = '';

  Timer? _tick;
  String _lastCmdSent = kIdle;
  int _lastSendMs = 0;

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    _tick = Timer.periodic(
      const Duration(milliseconds: kLoopMs),
      (_) => _sendLoop(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();

    if (BleManager.instance.isConnected && _lastCmdSent != kIdle) {
      BleManager.instance.send(kIdle);
    }

    OrientationUtils.setPortrait();
    super.dispose();
  }

  String _computeMoveCmd() {
    final bool up = _up && !_down;
    final bool down = _down && !_up;
    final bool left = _left && !_right;
    final bool right = _right && !_left;

    final v = up ? kCmdUp : (down ? kCmdDown : '');
    final h = left ? kCmdLeft : (right ? kCmdRight : '');

    if (v.isEmpty && h.isEmpty) {
      return kIdle;
    } else if (v.isNotEmpty && h.isEmpty) {
      return v;
    } else if (v.isEmpty && h.isNotEmpty) {
      return h;
    } else {
      return '$v$h';
    }
  }

  String _computeActionCmd() {
    if (_triangle) return kCmdTriangle;
    if (_cross) return kCmdCross;
    if (_square) return kCmdSquare;
    if (_circle) return kCmdCircle;
    return '';
  }

  void _updateCommand() {
    _moveCmd = _computeMoveCmd();
    _actionCmd = _computeActionCmd();

    String combined;
    if (_moveCmd == kIdle && _actionCmd.isEmpty) {
      combined = kIdle;
    } else if (_moveCmd != kIdle && _actionCmd.isEmpty) {
      combined = _moveCmd;
    } else if (_moveCmd == kIdle && _actionCmd.isNotEmpty) {
      combined = _actionCmd;
    } else {
      combined = '$_moveCmd$_actionCmd';
    }

    setState(() {
      _command = combined;
    });
  }

  void _sendLoop() {
    if (!BleManager.instance.isConnected) return;

    final cmd = _command;
    final now = DateTime.now().millisecondsSinceEpoch;

    final changed = cmd != _lastCmdSent;
    final active = cmd != kIdle;
    final minInterval = active ? kMinActiveMs : kMinIdleMs;

    if (!changed && (now - _lastSendMs) < minInterval) {
      return;
    }

    _lastCmdSent = cmd;
    _lastSendMs = now;
    BleManager.instance.send(cmd);
  }

  void _onLeftPress(String id, bool isDown) {
    if (isDown) {
      _up = id == kCmdUp;
      _down = id == kCmdDown;
      _left = id == kCmdLeft;
      _right = id == kCmdRight;
    } else {
      if (id == kCmdUp) _up = false;
      if (id == kCmdDown) _down = false;
      if (id == kCmdLeft) _left = false;
      if (id == kCmdRight) _right = false;
    }

    _updateCommand();
  }

  void _onRightPress(String id, bool isDown) {
    if (isDown) {
      _triangle = id == kCmdTriangle;
      _cross = id == kCmdCross;
      _square = id == kCmdSquare;
      _circle = id == kCmdCircle;
    } else {
      if (id == kCmdTriangle) _triangle = false;
      if (id == kCmdCross) _cross = false;
      if (id == kCmdSquare) _square = false;
      if (id == kCmdCircle) _circle = false;
    }

    _updateCommand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GamepadAppBar(
        title: 'Gamepad(8 Button)',
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
                  borderColor: theme.colorScheme.outlineVariant.withOpacity(
                    .45,
                  ),
                  borderWidth: 1.2,
                  shadowBlur: 10,
                  shadowOffset: const Offset(0, 4),
                  shadowColor: Colors.black.withOpacity(.12),
                  titleFont: 14,
                  valueFont: 18,
                  textColor: theme.textTheme.bodyMedium?.color ?? Colors.white,
                  valueColor: theme.textTheme.bodyLarge?.color ?? Colors.white,
                  dividerColor: theme.colorScheme.outlineVariant.withOpacity(
                    .6,
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DpadPanel(
                          up: const _BtnSpec('Up', kCmdUp, kGamepad8AssetUp),
                          down: const _BtnSpec(
                            'Down',
                            kCmdDown,
                            kGamepad8AssetDown,
                          ),
                          left: const _BtnSpec(
                            'Left',
                            kCmdLeft,
                            kGamepad8AssetLeft,
                          ),
                          right: const _BtnSpec(
                            'Right',
                            kCmdRight,
                            kGamepad8AssetRight,
                          ),
                          onPressChanged: _onLeftPress,
                        ),
                      ),
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
                      Expanded(
                        child: _DpadPanel(
                          up: const _BtnSpec(
                            'Triangle',
                            kCmdTriangle,
                            kGamepad8AssetTriangle,
                          ),
                          down: const _BtnSpec(
                            'Cross',
                            kCmdCross,
                            kGamepad8AssetCross,
                          ),
                          left: const _BtnSpec(
                            'Square',
                            kCmdSquare,
                            kGamepad8AssetSquare,
                          ),
                          right: const _BtnSpec(
                            'Circle',
                            kCmdCircle,
                            kGamepad8AssetCircle,
                          ),
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

class _BtnSpec {
  final String label, sendValue, asset;
  const _BtnSpec(this.label, this.sendValue, this.asset);
}

class _DpadPanel extends StatelessWidget {
  final _BtnSpec up, down, left, right;
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
        final btn = s * 0.30;
        final gap = s * 0.08;
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
    final btnSize = widget.diameter;

    final themeB = theme.brightness;
    final platformB = MediaQuery.of(context).platformBrightness;
    final isDark = themeB == Brightness.dark || platformB == Brightness.dark;

    final baseColor = theme.colorScheme.surface;
    final accent = const Color(0xFF5C6BFF);

    final normalTop = isDark
        ? const Color(0xFF2B2F3A)
        : lighten(baseColor, .08);
    final normalBottom = isDark
        ? const Color(0xFF0E1015)
        : darken(baseColor, .12);

    final pressedTop = isDark ? lighten(accent, .18) : lighten(accent, .10);
    final pressedBottom = isDark ? darken(accent, .28) : darken(accent, .18);

    final gradientColors = _pressed
        ? [pressedTop, pressedBottom]
        : [normalTop, normalBottom];

    final borderColor = _pressed
        ? (isDark
              ? const Color(0xFF00F0FF).withOpacity(0.95)
              : Colors.cyanAccent.withOpacity(0.95))
        : (isDark
              ? const Color(0xFF6B7CFF).withOpacity(0.85)
              : Colors.black.withOpacity(0.45));

    final borderWidth = _pressed ? 3.0 : (isDark ? 2.2 : 1.4);

    final shadowBlur = _pressed ? 22.0 : (isDark ? 18.0 : 14.0);
    final shadowOffset = _pressed ? const Offset(0, 6) : const Offset(0, 4);

    final shadowColor = _pressed
        ? (isDark
              ? const Color(0xFF00F0FF).withOpacity(0.55)
              : const Color(0xFF00FFFF).withOpacity(0.55))
        : (isDark
              ? Colors.black.withOpacity(0.65)
              : Colors.black.withOpacity(0.30));

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
                    if (isDark && !_pressed)
                      BoxShadow(
                        blurRadius: btnSize * 0.22,
                        spreadRadius: btnSize * 0.02,
                        color: const Color(0xFF6B7CFF).withOpacity(0.25),
                        offset: const Offset(0, 0),
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
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                child: Text(widget.label, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
