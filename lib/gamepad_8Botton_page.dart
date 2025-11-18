// lib/gamepad_8Botton_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ble_manager.dart'; // ⬅ เปลี่ยนจาก classic_manager.dart
import 'UI/gamepad_assets.dart';
import 'UI/gamepad_components.dart';
import 'widgets/logo_corner.dart';
import 'widgets/connection_status_badge.dart';
import 'utils/orientation_utils.dart';


const kIdle = '48';
const kRepeatMs = 120;

const kCmdUp = '1';
const kCmdDown = '2';
const kCmdLeft = '3';
const kCmdRight = '4';
const kCmdTriangle = '5';
const kCmdCross = '6';
const kCmdSquare = '7';
const kCmdCircle = '8';

class Gamepad_8Botton extends StatefulWidget {
  const Gamepad_8Botton({super.key});
  @override
  State<Gamepad_8Botton> createState() => _Gamepad_8BottonState();
}

class _Gamepad_8BottonState extends State<Gamepad_8Botton> {
  List<DeviceOrientation>? _prev;
  String _command = '0';

@override
void initState() {
  super.initState();
  OrientationUtils.setLandscape(); // ← บังคับแนวนอน
}

@override
void dispose() {
  OrientationUtils.setPortrait(); // ← คืนแนวตั้งตอนออก
  super.dispose();
}


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

  void _updateCommand(String cmd) {
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
                  width: math.min(cons.maxWidth * 0.25, 200),
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
                      Expanded(
                        child: _DpadPanel(
                          up: const _BtnSpec('Up', kCmdUp, kGamepad8AssetUp),
                          down: const _BtnSpec(
                              'Down', kCmdDown, kGamepad8AssetDown),
                          left: const _BtnSpec(
                              'Left', kCmdLeft, kGamepad8AssetLeft),
                          right: const _BtnSpec(
                              'Right', kCmdRight, kGamepad8AssetRight),
                          onCommandChanged: _updateCommand,
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
                              'Triangle', kCmdTriangle, kGamepad8AssetTriangle),
                          down: const _BtnSpec(
                              'Cross', kCmdCross, kGamepad8AssetCross),
                          left: const _BtnSpec(
                              'Square', kCmdSquare, kGamepad8AssetSquare),
                          right: const _BtnSpec(
                              'Circle', kCmdCircle, kGamepad8AssetCircle),
                          onCommandChanged: _updateCommand,
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
  final ValueChanged<String> onCommandChanged;

  const _DpadPanel({
    super.key,
    required this.up,
    required this.down,
    required this.left,
    required this.right,
    required this.onCommandChanged,
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
                    onCommandChanged: onCommandChanged,
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
                    onCommandChanged: onCommandChanged,
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
                    onCommandChanged: onCommandChanged,
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
                    onCommandChanged: onCommandChanged,
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
  final ValueChanged<String>? onCommandChanged;

  const _ImagePressHoldButton({
    super.key,
    required this.label,
    required this.sendValue,
    required this.asset,
    this.diameter = 120,
    this.showLabel = true,
    this.onCommandChanged,
  });

  @override
  State<_ImagePressHoldButton> createState() => _ImagePressHoldButtonState();
}

class _ImagePressHoldButtonState extends State<_ImagePressHoldButton> {
  Timer? _repeat;
  bool _pressed = false;

  @override
  void dispose() {
    _stopRepeat(sendIdle: true);
    super.dispose();
  }

  void _startRepeat() {
    if (_repeat?.isActive == true) return;

    widget.onCommandChanged?.call(widget.sendValue);
    BleManager.instance.send(widget.sendValue); // ⬅ เปลี่ยน

    _repeat = Timer.periodic(const Duration(milliseconds: kRepeatMs), (_) {
      BleManager.instance.send(widget.sendValue); // ⬅ เปลี่ยน
    });
  }

  void _stopRepeat({bool sendIdle = false}) {
    _repeat?.cancel();
    _repeat = null;
    if (sendIdle) {
      widget.onCommandChanged?.call(kIdle);
      BleManager.instance.send(kIdle); // ⬅ เปลี่ยน
    }
  }

  void _onDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    _startRepeat();
  }

  void _onUpOrCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _stopRepeat(sendIdle: true);
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
                child: Text(widget.label,
                    style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
