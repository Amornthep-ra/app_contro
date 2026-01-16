// lib/features/gamepad/gamepad_4_button_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/gamepad_assets.dart';
import '../../core/ui/gamepad_components.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/ui/custom_appbars.dart';
import '../../core/ble/joystick_packet.dart';

const double PAGE_PAD_H = 0;
const double PAGE_PAD_V = 8;
const double COLUMN_GAP = 6;
const int FLEX_LEFT = 4;
const int FLEX_RIGHT = 6;

const double DESIGN_W = 1280;
const double DESIGN_H = 720;

const int kLoopHz = 60;
const int kLoopMs = 1000 ~/ kLoopHz;
const int kMinActiveMs = 150;
const int kMinIdleMs = 150;

const int kMaxSendHz = 40;
const int kMaxSendMs = 1000 ~/ kMaxSendHz;

const double _minBtnSize = 0.6;
const double _maxBtnSize = 1.6;

class _S {
  final double _sx;
  final double _sy;
  final double _sp;

  _S(this._sx, this._sy, this._sp);

  static _S from(BoxConstraints cons) {
    final sw = cons.maxWidth / DESIGN_W;
    final sh = cons.maxHeight / DESIGN_H;
    final sp = (sw + sh) / 2.0;
    return _S(sw, sh, sp.clamp(0.75, 1.35));
  }

  double w(double v) => v * _sx;
  double h(double v) => v * _sy;
  double r(double v) => v * ((_sx + _sy) / 2.0);
  double sp(double v) => v * _sp;

  EdgeInsets m(EdgeInsets e) =>
      EdgeInsets.fromLTRB(w(e.left), h(e.top), w(e.right), h(e.bottom));
  Offset o(Offset o) => Offset(w(o.dx), h(o.dy));
}

BtnCfg _baseHoldCfg(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final s = theme.colorScheme;

  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  const darkBase = Color(0xFF0D0F14);
  const darkBorder = Color(0xFF343A46);
  const darkNeon = Color(0xFF8B5CFF);

  final baseColor = isDark ? darkBase : Colors.white;

  final borderColor = isDark
      ? darkBorder.withOpacity(.85)
      : Colors.black.withOpacity(.20);

  final glowColor = isDark
      ? darkNeon.withOpacity(.92)
      : const Color(0xFF5C6BFF).withOpacity(.70);

  final pressOverlayColor = isDark ? Colors.white : Colors.black;

  final labelColor = isDark
      ? Colors.white.withOpacity(.92)
      : s.onPrimaryContainer;

  return BtnCfg(
    width: 220,
    height: 160,
    margin: const EdgeInsets.all(0),
    radius: 26,
    baseColor: baseColor,
    borderColor: borderColor,
    borderWidthOn: 2.4,
    borderWidthOff: 1.4,
    glowBlurOn: 30,
    glowSpreadOn: 1.2,
    glowBlurOff: 14,
    glowSpreadOff: 0.4,
    shadowOffsetOn: const Offset(0, 8),
    shadowOffsetOff: const Offset(0, 5),
    glowColor: glowColor,
    iconAsset: null,
    iconFit: BoxFit.cover,
    iconPadding: EdgeInsets.zero,
    label: 'Button',
    labelFontSize: 20,
    labelColor: labelColor,
    pressOverlayColor: pressOverlayColor,
    pressOverlayOpacity: .10,
  );
}

BtnCfg cfgForward(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Forward',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(100, 0, 0, 10),
  iconAsset: kGamepad4AssetUp,
);

BtnCfg cfgBackward(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Backward',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(100, 20, 0, 0),
  iconAsset: kGamepad4AssetDown,
);

BtnCfg cfgLeft(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Left',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(0, 80, 0, 0),
  iconAsset: kGamepad4AssetLeft,
);

BtnCfg cfgRight(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Right',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(0, 80, 0, 0),
  iconAsset: kGamepad4AssetRight,
);

const double SPEED_ROW_GAP = 6.0;

TapCfg cfgSpeedLow(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.green;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFF00FF9D), .10)
      : lighten(c, .24);

  final glow = isDark
      ? const Color(0xFF00FFB2).withOpacity(.55)
      : Colors.black.withOpacity(.22);

  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? Colors.white.withOpacity(.85)
      : const Color.fromARGB(255, 0, 0, 0).withOpacity(.85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Lo',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

TapCfg cfgSpeedMid(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.yellow;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFFFFD36A), .06)
      : lighten(c, .24);

  final glow = isDark
      ? const Color(0xFFFFD54F).withOpacity(.55)
      : Colors.black.withOpacity(.22);

  final textOn = Colors.black;
  final textOff = Colors.black.withOpacity(.85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Med',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

TapCfg cfgSpeedHigh(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.red;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFFFF6B6B), .06)
      : lighten(c, .24);

  final glow = isDark
      ? const Color(0xFFFF5A5A).withOpacity(.60)
      : Colors.black.withOpacity(.22);

  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? Colors.white.withOpacity(.85)
      : const Color.fromARGB(255, 0, 0, 0).withOpacity(.85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Hi',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

CommandCardCfg cfgCommandCard(BuildContext ctx) {
  final t = Theme.of(ctx);
  final base = t.colorScheme.surfaceVariant.withOpacity(.70);
  return CommandCardCfg(
    width: 480,
    margin: const EdgeInsets.only(top: 60),
    padding: const EdgeInsets.all(12),
    background: [lighten(base, .06), darken(base, .06)],
    radius: 16,
    borderColor: t.colorScheme.outlineVariant.withOpacity(.45),
    borderWidth: 1.2,
    shadowBlur: 12,
    shadowOffset: const Offset(0, 6),
    shadowColor: Colors.black.withOpacity(.14),
    titleFont: 18,
    valueFont: 24,
    textColor: t.textTheme.bodyMedium?.color ?? Colors.white,
    valueColor: t.textTheme.bodyLarge?.color ?? Colors.white,
    dividerColor: t.colorScheme.outlineVariant.withOpacity(.6),
  );
}

BtnCfg scaleBtn(BtnCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  height: s.h(c.height),
  margin: s.m(c.margin),
  radius: s.r(c.radius),
  borderWidthOn: s.r(c.borderWidthOn),
  borderWidthOff: s.r(c.borderWidthOff),
  glowBlurOn: s.r(c.glowBlurOn),
  glowSpreadOn: s.r(c.glowSpreadOn),
  glowBlurOff: s.r(c.glowBlurOff),
  glowSpreadOff: s.r(c.glowSpreadOff),
  shadowOffsetOn: s.o(c.shadowOffsetOn),
  shadowOffsetOff: s.o(c.shadowOffsetOff),
  iconPadding: s.m(c.iconPadding),
  labelFontSize: s.sp(c.labelFontSize),
);

TapCfg scaleTap(TapCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  height: s.h(c.height),
  margin: s.m(c.margin),
  radius: s.r(c.radius),
  borderWidthSelected: s.r(c.borderWidthSelected),
  borderWidthUnselected: s.r(c.borderWidthUnselected),
  glowBlurSelected: s.r(c.glowBlurSelected),
  glowBlurUnselected: s.r(c.glowBlurUnselected),
  shadowOffsetSelected: s.o(c.shadowOffsetSelected),
  shadowOffsetUnselected: s.o(c.shadowOffsetUnselected),
  fontSize: s.sp(c.fontSize),
);

CommandCardCfg scaleCard(CommandCardCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  margin: s.m(c.margin),
  padding: s.m(c.padding),
  radius: s.r(c.radius),
  borderWidth: s.r(c.borderWidth),
  shadowBlur: s.r(c.shadowBlur),
  shadowOffset: s.o(c.shadowOffset),
  titleFont: s.sp(c.titleFont),
  valueFont: s.sp(c.valueFont),
);

class Gamepad_4_Botton extends StatefulWidget {
  const Gamepad_4_Botton({super.key});

  @override
  State<Gamepad_4_Botton> createState() => _Gamepad_4_BottonState();
}

class _Gamepad_4_BottonState extends State<Gamepad_4_Botton> {
  static const _prefsLayoutAll = 'gp4_layout_all';
  static const _prefsActiveAll = 'gp4_active_all';

  bool _f = false, _b = false, _l = false, _r = false;
  String _command = '0';
  String _speedLabel = 'Lo';
  String _lastPacketKey = '';

  bool _editMode = false;
  Map<String, _ButtonLayout> _layoutAll = {};
  Set<String> _activeIds = {
    'F:forward',
    'F:backward',
    'F:left',
    'F:right',
  };
  String? _selectedId;
  Size? _panelSize;

  Timer? _tick;
  int _lastSendMs = 0;

  Set<int> _buildPressedButtons() {
    final btns = <int>{};

    if (_f && !_b) btns.add(kBleBtnUp);
    if (_b && !_f) btns.add(kBleBtnDown);
    if (_l && !_r) btns.add(kBleBtnLeft);
    if (_r && !_l) btns.add(kBleBtnRight);

    if (_speedLabel == 'Lo') btns.add(kBleBtnSpeedLow);
    if (_speedLabel == 'Med') btns.add(kBleBtnSpeedMid);
    if (_speedLabel == 'Hi') btns.add(kBleBtnSpeedHigh);

    return btns;
  }

  String _packetKey() => '$_command|$_speedLabel';

  int _buttonsByte() {
    final btns = _buildPressedButtons();
    int v = 0;
    for (final b in btns) {
      if (b < 1 || b > 8) continue;
      v |= (1 << (b - 1));
    }
    return v & 0xFF;
  }

  String _commandByteLabel() => _buttonsByte().toString();

  int _speedByte() {
    if (_speedLabel == 'Lo') return 1 << (kBleBtnSpeedLow - 9);
    if (_speedLabel == 'Med') return 1 << (kBleBtnSpeedMid - 9);
    if (_speedLabel == 'Hi') return 1 << (kBleBtnSpeedHigh - 9);
    return 0;
  }

  String _speedByteLabel() => _speedByte().toString();

  Future<void> _loadLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutRaw = prefs.getString(_prefsLayoutAll);
    final activeRaw = prefs.getString(_prefsActiveAll);

    if (layoutRaw != null && layoutRaw.isNotEmpty) {
      _layoutAll = _decodeLayout(layoutRaw);
    }
    if (activeRaw != null && activeRaw.isNotEmpty) {
      _activeIds = _decodeIdList(activeRaw);
    }

    if (_activeIds.isEmpty) {
      _activeIds = {
        'F:forward',
        'F:backward',
        'F:left',
        'F:right',
      };
    }

    _layoutAll.removeWhere((k, _) => !_activeIds.contains(k));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveLayout(
    String key,
    Map<String, _ButtonLayout> layout,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_encodeLayout(layout)));
  }

  Future<void> _saveActive(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  Map<String, _ButtonLayout> _decodeLayout(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return {};
      final out = <String, _ButtonLayout>{};
      obj.forEach((k, v) {
        if (v is Map) {
          final cx = (v['cx'] as num?)?.toDouble();
          final cy = (v['cy'] as num?)?.toDouble();
          final size = (v['size'] as num?)?.toDouble();
          if (cx != null && cy != null) {
            out[k.toString()] = _ButtonLayout(cx, cy, size ?? 1.0);
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, double>> _encodeLayout(
    Map<String, _ButtonLayout> layout,
  ) {
    final out = <String, Map<String, double>>{};
    layout.forEach((k, v) {
      out[k] = v.toJson();
    });
    return out;
  }

  Set<String> _decodeIdList(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! List) return {};
      return obj.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  void _toggleEdit() {
    setState(() => _editMode = !_editMode);
  }

  void _selectButton(String id) {
    setState(() => _selectedId = id);
  }

  void _toggleActive(String id) {
    setState(() {
      if (_activeIds.contains(id)) {
        _activeIds.remove(id);
        _layoutAll.remove(id);
        if (_selectedId == id) _selectedId = null;
        if (id == 'F:forward') _f = false;
        if (id == 'F:backward') _b = false;
        if (id == 'F:left') _l = false;
        if (id == 'F:right') _r = false;
      } else {
        _activeIds.add(id);
      }
      _saveActive(_prefsActiveAll, _activeIds);
    });
  }

  void _removeSelected() {
    final id = _selectedId;
    if (id == null) return;
    _toggleActive(id);
  }

  void _changeSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;
    final panelSize = _panelSize;
    if (panelSize == null) return;
    final current = _layoutAll[id];
    if (current == null) return;
    final base = _cfgForId(id);
    if (base == null) return;
    final unclamped = current.size + delta;
    final nextSize = unclamped.clamp(_minBtnSize, _maxBtnSize);
    if (nextSize == current.size) {
      _showSizeLimit(unclamped >= _maxBtnSize);
      return;
    }

    final w = panelSize.width;
    final h = panelSize.height;
    final baseScaled = _scaledBaseCfg(base, panelSize);
    final nextCfg = _scaleHoldCfg(baseScaled, nextSize);
    final halfW = nextCfg.width / 2;
    final halfH = nextCfg.height / 2;

    double cx = (current.cx * w).clamp(halfW, w - halfW);
    double cy = (current.cy * h).clamp(halfH, h - halfH);

    setState(() {
      final next = Map<String, _ButtonLayout>.from(_layoutAll);
      next[id] = _ButtonLayout(cx / w, cy / h, nextSize);
      _layoutAll = next;
    });
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  void _showSizeLimit(bool atMax) {
    final msg = atMax
        ? 'Max size reached / ถึงขนาดสูงสุดแล้ว'
        : 'Min size reached / ถึงขนาดต่ำสุดแล้ว';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  BtnCfg? _cfgForId(String id) {
    if (id == 'F:forward') return cfgForward(context);
    if (id == 'F:backward') return cfgBackward(context);
    if (id == 'F:left') return cfgLeft(context);
    if (id == 'F:right') return cfgRight(context);
    return null;
  }

  Widget _resizeButton(IconData icon, VoidCallback? onTap, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildResizeBar() {
    if (!_editMode) return const SizedBox.shrink();
    final hasSelection = _selectedId != null;
    final iconColor = hasSelection ? Colors.white : Colors.white54;

    return Positioned(
      top: 6,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Size',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              _resizeButton(
                Icons.remove,
                hasSelection ? () => _changeSelectedSize(-0.05) : null,
                iconColor,
              ),
              const SizedBox(width: 2),
              _resizeButton(
                Icons.add,
                hasSelection ? () => _changeSelectedSize(0.05) : null,
                iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayoutAll);
    await prefs.remove(_prefsActiveAll);
    setState(() {
      _layoutAll = {};
      _activeIds = {
        'F:forward',
        'F:backward',
        'F:left',
        'F:right',
      };
      _selectedId = null;
    });
  }

  PopupMenuButton<String> _buildEditMenu() {
    PopupMenuItem<String> item(String id, String label, bool active) {
      return PopupMenuItem<String>(
        value: id,
        child: Row(
          children: [
            Icon(
              active ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Add/Remove buttons',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Buttons',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      onSelected: _toggleActive,
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          item('F:forward', 'Forward', _activeIds.contains('F:forward')),
          item('F:backward', 'Backward', _activeIds.contains('F:backward')),
          item('F:left', 'Left', _activeIds.contains('F:left')),
          item('F:right', 'Right', _activeIds.contains('F:right')),
        ];
      },
    );
  }

  void _sendBinary({bool force = false}) {
    if (!BleManager.instance.isConnected) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final key = _packetKey();

    if (!force) {
      if ((now - _lastSendMs) < kMaxSendMs) return;

      final bool changed = key != _lastPacketKey;
      final bool active = _command != '0';
      final int minInterval = active ? kMinActiveMs : kMinIdleMs;

      if (!changed && (now - _lastSendMs) < minInterval) {
        return;
      }
    }

    _lastPacketKey = key;
    _lastSendMs = now;

    BleManager.instance.sendJoystickBinary(
      packet: JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      pressedButtons: _buildPressedButtons(),
    );
  }

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscapeOnly();
    _sendSpeed('Med');
    _loadLayouts();

    _tick = Timer.periodic(
      const Duration(milliseconds: kLoopMs),
      (_) => _sendLoop(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();

    if (BleManager.instance.isConnected && _command != '0') {
      _sendBinary(force: true);
    }
    OrientationUtils.reset();
    super.dispose();
  }

  String _computeCommand() {
    final bool forward = _f && !_b;
    final bool backward = _b && !_f;
    final bool left = _l && !_r;
    final bool right = _r && !_l;

    final v = forward ? 'F' : (backward ? 'B' : '');
    final h = left ? 'L' : (right ? 'R' : '');

    if (v.isEmpty && h.isEmpty) {
      return '0';
    } else if (v.isNotEmpty && h.isEmpty) {
      return v;
    } else if (v.isEmpty && h.isNotEmpty) {
      return h;
    } else {
      return '$v$h';
    }
  }

  void _updateCommandOnly() {
    final cmd = _computeCommand();
    setState(() {
      _command = cmd;
    });
    if (cmd == '0' && BleManager.instance.isConnected) {
      _sendBinary(force: true);
    }
  }

  void _sendLoop() {
    _sendBinary();
  }

  void _sendSpeed(String v) {
    if (_speedLabel == v) return;

    setState(() {
      _speedLabel = v;
    });

    _sendBinary(force: true);
  }

  void _onPressChanged(String id, bool isDown) {
    if (id == 'F') _f = isDown;
    if (id == 'B') _b = isDown;
    if (id == 'L') _l = isDown;
    if (id == 'R') _r = isDown;
    _updateCommandOnly();
  }

  Widget _appBarBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _speedChip(String label) {
    final selected = _speedLabel == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _sendSpeed(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.25)
                : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn(BuildContext context, _S s) {
    final cfgF = scaleBtn(cfgForward(context), s);
    final cfgB = scaleBtn(cfgBackward(context), s);

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GamepadHoldButton(
            cfg: cfgF,
            onChange: (down) {
              _f = down;
              if (down) _b = false;
              _updateCommandOnly();
            },
          ),
          GamepadHoldButton(
            cfg: cfgB,
            onChange: (down) {
              _b = down;
              if (down) _f = false;
              _updateCommandOnly();
            },
          ),
        ],
      ),
    );
  }

  Widget _rightColumn(BuildContext context, _S s) {
    final lrRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.shrink(),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: s.h(10)),
        lrRow,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GamepadAppBar(
        title: '',
        centerTitle: true,
        titleWidget: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _speedChip('Lo'),
                _speedChip('Med'),
                _speedChip('Hi'),
                const SizedBox(width: 6),
                _appBarBadge('Cmd', _commandByteLabel()),
                const SizedBox(width: 6),
                _appBarBadge('Spd', _speedByteLabel()),
                const SizedBox(width: 6),
                const ConnectionStatusBadge(),
              ],
            ),
          ),
        ),
        actions: [
          if (_editMode) _buildEditMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _toggleEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _editMode ? 'Done' : 'Customize',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (_editMode)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: _selectedId == null ? Colors.white54 : Colors.white,
              ),
              onPressed: _selectedId == null ? null : _removeSelected,
              tooltip: 'Remove selected',
            ),
          if (_editMode)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetLayouts,
              tooltip: 'Reset layout',
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, cons) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox.expand(
                      child: _editMode
                          ? _EditablePadPanel(
                              ids: _activeIds.toList(),
                              specs: {
                                'F:forward': _BtnSpec(
                                  'Forward',
                                  'F',
                                  cfgForward(context),
                                ),
                                'F:backward': _BtnSpec(
                                  'Backward',
                                  'B',
                                  cfgBackward(context),
                                ),
                                'F:left': _BtnSpec(
                                  'Left',
                                  'L',
                                  cfgLeft(context),
                                ),
                                'F:right': _BtnSpec(
                                  'Right',
                                  'R',
                                  cfgRight(context),
                                ),
                              },
                              layout: _layoutAll,
                              onLayoutChanged: (next) {
                                _layoutAll = next;
                                _saveLayout(
                                  _prefsLayoutAll,
                                  _layoutAll,
                                );
                              },
                              selectedId: _selectedId,
                              onSelect: _selectButton,
                              onPanelSize: (size) {
                                _panelSize = size;
                              },
                            )
                          : _LayoutPadPanel(
                              ids: _activeIds.toList(),
                              specs: {
                                'F:forward': _BtnSpec(
                                  'Forward',
                                  'F',
                                  cfgForward(context),
                                ),
                                'F:backward': _BtnSpec(
                                  'Backward',
                                  'B',
                                  cfgBackward(context),
                                ),
                                'F:left': _BtnSpec(
                                  'Left',
                                  'L',
                                  cfgLeft(context),
                                ),
                                'F:right': _BtnSpec(
                                  'Right',
                                  'R',
                                  cfgRight(context),
                                ),
                              },
                              layout: _layoutAll,
                              onPressChanged: _onPressChanged,
                            ),
                    ),
                  ),
                );
              },
            ),
            _buildResizeBar(),
            const LogoCorner(),
          ],
        ),
      ),
    );
  }
}

class _BtnSpec {
  final String label;
  final String sendValue;
  final BtnCfg cfg;
  const _BtnSpec(this.label, this.sendValue, this.cfg);
}

class _ScaledHoldCfg {
  final BtnCfg cfg;
  final Offset center;
  const _ScaledHoldCfg(this.cfg, this.center);
}

_S _scaleForPanel(Size panel) {
  final sw = panel.width / DESIGN_W;
  final sh = panel.height / DESIGN_H;
  final sp = ((sw + sh) / 2.0).clamp(0.75, 1.35);
  return _S(sw, sh, sp);
}

BtnCfg _scaledBaseCfg(BtnCfg base, Size panel) {
  final s = _scaleForPanel(panel);
  return scaleBtn(base, s).copyWith(margin: EdgeInsets.zero);
}

BtnCfg _scaleHoldCfg(BtnCfg c, double scale) {
  final ip = c.iconPadding;
  return c.copyWith(
    width: c.width * scale,
    height: c.height * scale,
    margin: EdgeInsets.zero,
    radius: c.radius * scale,
    borderWidthOn: c.borderWidthOn * scale,
    borderWidthOff: c.borderWidthOff * scale,
    glowBlurOn: c.glowBlurOn * scale,
    glowSpreadOn: c.glowSpreadOn * scale,
    glowBlurOff: c.glowBlurOff * scale,
    glowSpreadOff: c.glowSpreadOff * scale,
    shadowOffsetOn: Offset(
      c.shadowOffsetOn.dx * scale,
      c.shadowOffsetOn.dy * scale,
    ),
    shadowOffsetOff: Offset(
      c.shadowOffsetOff.dx * scale,
      c.shadowOffsetOff.dy * scale,
    ),
    iconPadding: EdgeInsets.fromLTRB(
      ip.left * scale,
      ip.top * scale,
      ip.right * scale,
      ip.bottom * scale,
    ),
    labelFontSize: c.labelFontSize * scale,
  );
}

_ScaledHoldCfg _scaledHoldCfg(BtnCfg base, _ButtonLayout layout, Size panel) {
  final w = panel.width;
  final h = panel.height;
  final cfg = _scaleHoldCfg(_scaledBaseCfg(base, panel), layout.size);
  final halfW = cfg.width / 2;
  final halfH = cfg.height / 2;

  final cx = (layout.cx * w).clamp(halfW, w - halfW);
  final cy = (layout.cy * h).clamp(halfH, h - halfH);

  return _ScaledHoldCfg(cfg, Offset(cx, cy));
}

Map<String, _ButtonLayout> _defaultLayoutForIds(
  Size size,
  Map<String, _BtnSpec> specs,
  List<String> ids,
) {
  final w = size.width;
  final h = size.height;
  final s = _scaleForPanel(size);

  _ButtonLayout make(double x, double y) {
    return _ButtonLayout(x / w, y / h, 1.0);
  }

  final hasForward = ids.contains('F:forward');
  final hasBackward = ids.contains('F:backward');
  final hasLeft = ids.contains('F:left');
  final hasRight = ids.contains('F:right');

  final out = <String, _ButtonLayout>{};

  if (hasForward || hasBackward) {
    final cfgF = hasForward ? scaleBtn(specs['F:forward']!.cfg, s) : null;
    final cfgB = hasBackward ? scaleBtn(specs['F:backward']!.cfg, s) : null;
    final colWidth = [
      if (cfgF != null) cfgF.width + cfgF.margin.horizontal,
      if (cfgB != null) cfgB.width + cfgB.margin.horizontal,
    ].fold(0.0, math.max);
    final totalHeight = [
      if (cfgF != null) cfgF.height + cfgF.margin.vertical,
      if (cfgB != null) cfgB.height + cfgB.margin.vertical,
    ].fold(0.0, (a, b) => a + b);
    final colLeft = 0.0;
    double y = (h - totalHeight) / 2.0;

    if (cfgF != null) {
      y += cfgF.margin.top;
      out['F:forward'] = make(
        colLeft + cfgF.margin.left + cfgF.width / 2,
        y + cfgF.height / 2,
      );
      y += cfgF.height + cfgF.margin.bottom;
    }
    if (cfgB != null) {
      y += cfgB.margin.top;
      out['F:backward'] = make(
        colLeft + cfgB.margin.left + cfgB.width / 2,
        y + cfgB.height / 2,
      );
      y += cfgB.height + cfgB.margin.bottom;
    }
  }

  if (hasLeft || hasRight) {
    final cfgL = hasLeft ? scaleBtn(specs['F:left']!.cfg, s) : null;
    final cfgR = hasRight ? scaleBtn(specs['F:right']!.cfg, s) : null;
    final gap = s.w(24);
    final rowWidth = [
      if (cfgL != null) cfgL.width + cfgL.margin.horizontal,
      if (cfgR != null) cfgR.width + cfgR.margin.horizontal,
    ].fold(0.0, (a, b) => a + b) +
        ((cfgL != null && cfgR != null) ? gap : 0);
    final maxHeight = [
      if (cfgL != null) cfgL.height + cfgL.margin.vertical,
      if (cfgR != null) cfgR.height + cfgR.margin.vertical,
    ].fold(0.0, math.max);

    double x = w - rowWidth;
    final y = (h - maxHeight) / 2.0;

    if (cfgL != null) {
      final cy = y + cfgL.margin.top + cfgL.height / 2;
      x += cfgL.margin.left;
      out['F:left'] = make(
        x + cfgL.width / 2,
        cy,
      );
      x += cfgL.width + cfgL.margin.right;
      if (cfgR != null) x += gap;
    }
    if (cfgR != null) {
      final cy = y + cfgR.margin.top + cfgR.height / 2;
      x += cfgR.margin.left;
      out['F:right'] = make(
        x + cfgR.width / 2,
        cy,
      );
      x += cfgR.width + cfgR.margin.right;
    }
  }

  return out;
}

class _ButtonLayout {
  final double cx;
  final double cy;
  final double size;

  const _ButtonLayout(this.cx, this.cy, this.size);

  _ButtonLayout copyWith({double? cx, double? cy, double? size}) {
    return _ButtonLayout(cx ?? this.cx, cy ?? this.cy, size ?? this.size);
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'size': size};
}

class _EditablePadPanel extends StatefulWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> layout;
  final ValueChanged<Map<String, _ButtonLayout>> onLayoutChanged;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<Size> onPanelSize;

  const _EditablePadPanel({
    required this.ids,
    required this.specs,
    required this.layout,
    required this.onLayoutChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onPanelSize,
  });

  @override
  State<_EditablePadPanel> createState() => _EditablePadPanelState();
}

class _EditablePadPanelState extends State<_EditablePadPanel> {
  late Map<String, _ButtonLayout> _layout;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _layout = Map<String, _ButtonLayout>.from(widget.layout);
  }

  @override
  void didUpdateWidget(covariant _EditablePadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layout, widget.layout)) {
      _layout = Map<String, _ButtonLayout>.from(widget.layout);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) {
      return Center(
        child: Text(
          'Tap + to add buttons',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        widget.onPanelSize(size);
        final defaults = _defaultLayoutForIds(size, widget.specs, widget.ids);

        bool changed = false;
        if (!_initialized) {
          _initialized = true;
        }
        for (final id in widget.ids) {
          final def = defaults[id];
          if (def != null && _layout[id] == null) {
            _layout[id] = def;
            changed = true;
          }
        }
        _layout.removeWhere((k, _) => !widget.ids.contains(k));
        if (changed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {});
            widget.onLayoutChanged(_layout);
          });
        }

        return Stack(
          children: widget.ids.map((id) {
            final spec = widget.specs[id];
            final layout = _layout[id];
            if (spec == null || layout == null) {
              return const SizedBox.shrink();
            }
            return _EditableButton(
              layout: layout,
              panelSize: size,
              cfg: spec.cfg,
              selected: widget.selectedId == id,
              dimmed: widget.selectedId != null && widget.selectedId != id,
              onChanged: (next) {
                setState(() => _layout[id] = next);
              },
              onEnd: () => widget.onLayoutChanged(_layout),
              onTap: () => widget.onSelect(id),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LayoutPadPanel extends StatelessWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> layout;
  final void Function(String id, bool down) onPressChanged;

  const _LayoutPadPanel({
    required this.ids,
    required this.specs,
    required this.layout,
    required this.onPressChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return Center(
        child: Text(
          'No buttons',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final defaults = _defaultLayoutForIds(size, specs, ids);
        final effective = <String, _ButtonLayout>{...defaults, ...layout};

        return Stack(
          children: ids.map((id) {
            final spec = specs[id];
            final l = effective[id];
            if (spec == null || l == null) {
              return const SizedBox.shrink();
            }
            final scaled = _scaledHoldCfg(spec.cfg, l, size);
            final cx = scaled.center.dx;
            final cy = scaled.center.dy;

            return Positioned(
              left: cx - scaled.cfg.width / 2,
              top: cy - scaled.cfg.height / 2,
              child: GamepadHoldButton(
                cfg: scaled.cfg,
                onChange: (down) => onPressChanged(spec.sendValue, down),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EditableButton extends StatefulWidget {
  final _ButtonLayout layout;
  final Size panelSize;
  final BtnCfg cfg;
  final bool selected;
  final bool dimmed;
  final ValueChanged<_ButtonLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback onTap;

  const _EditableButton({
    required this.layout,
    required this.panelSize,
    required this.cfg,
    required this.selected,
    required this.dimmed,
    required this.onChanged,
    required this.onEnd,
    required this.onTap,
  });

  @override
  State<_EditableButton> createState() => _EditableButtonState();
}

class _EditableButtonState extends State<_EditableButton> {
  late Offset _dragStart;
  late _ButtonLayout _startLayout;
  late _ScaledHoldCfg _startScaled;

  void _onPanStart(DragStartDetails d) {
    _dragStart = d.globalPosition;
    _startLayout = widget.layout;
    _startScaled = _scaledHoldCfg(widget.cfg, _startLayout, widget.panelSize);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final halfW = _startScaled.cfg.width / 2;
    final halfH = _startScaled.cfg.height / 2;

    final dx = d.globalPosition.dx - _dragStart.dx;
    final dy = d.globalPosition.dy - _dragStart.dy;

    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;

    cx = cx.clamp(halfW, w - halfW);
    cy = cy.clamp(halfH, h - halfH);

    widget.onChanged(_ButtonLayout(cx / w, cy / h, _startLayout.size));
  }

  @override
  Widget build(BuildContext context) {
    final scaled = _scaledHoldCfg(widget.cfg, widget.layout, widget.panelSize);
    final cx = scaled.center.dx;
    final cy = scaled.center.dy;
    final borderColor = widget.selected
        ? const Color(0xFF00F0FF)
        : Colors.white.withOpacity(0.7);
    final borderWidth = widget.selected ? 3.0 : 2.0;
    final glowColor = widget.selected
        ? const Color(0xFF00F0FF).withOpacity(0.45)
        : Colors.transparent;
    final dimOpacity = widget.dimmed ? 0.35 : 1.0;

    return Positioned(
      left: cx - scaled.cfg.width / 2,
      top: cy - scaled.cfg.height / 2,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => widget.onEnd(),
        onTap: widget.onTap,
        child: Opacity(
          opacity: dimOpacity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IgnorePointer(
              child: GamepadHoldButton(
                cfg: scaled.cfg,
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
