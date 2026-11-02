// lib/features/gamepad/gamepad_4_button_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/control_input_gate.dart';
import '../../core/widgets/control_background.dart';
import '../../core/widgets/gamepad_edit_hint.dart';
import '../../core/widgets/control_start_stop.dart';
import '../../core/widgets/gamepad_control_toolbar.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ble/ble_connection_coordinator.dart';
import '../../core/ui/gamepad_assets.dart';
import '../../core/ui/gamepad_components.dart';
import '../../core/ui/gamepad_edit_metrics.dart';
import '../../core/widgets/gamepad_edit_grid.dart';
import '../../core/ui/app_assets.dart';
import '../../core/ui/control_mode_preference.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/widgets/control_preset_dialog.dart';
import '../../core/widgets/cat_glass_popup.dart';
import '../../core/widgets/gamepad_app_bar.dart';
import '../../core/widgets/gamepad_appbar_controls.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/ble/joystick_packet.dart';
import '../../core/ui/language_controller.dart';
import '../../core/routes/app_routes.dart';
import 'control_mode_settings_page.dart';
import 'widgets/gamepad_edit_shared.dart';
import 'widgets/gamepad_telemetry_chip.dart';
import '../bluetooth/widgets/pairing_code_dialog.dart';

const double designW = 1280;
const double designH = 720;
const double _panelEdgeInset = 28.0;
const double _panelRowGap = 28.0;
const double _panelColGap = 32.0;
const int kLoopHz = 60;
const int kLoopMs = 1000 ~/ kLoopHz;
const int kMinActiveMs = 50;
const int kMinIdleMs = 150;
const int kMaxSendHz = 40;
const int kMaxSendMs = 1000 ~/ kMaxSendHz;
const double _minBtnSize = 0.18;
const double _maxBtnSize = 0.8;
const Set<String> _supportedFourButtonIds = {
  'F:forward',
  'F:backward',
  'F:left',
  'F:right',
};
Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

class _S {
  final double _sx;
  final double _sy;
  final double _sp;
  _S(this._sx, this._sy, this._sp);
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
  final isDark = theme.brightness == Brightness.dark;
  const darkBase = Color(0xFF0D0F14);
  const darkBorder = Color(0xFF343A46);
  const darkNeon = Color(0xFF8B5CFF);
  final baseColor = isDark ? darkBase : Colors.white;
  final borderColor = isDark
      ? _opacity(darkBorder, .85)
      : _opacity(Colors.black, .20);
  final glowColor = isDark
      ? _opacity(darkNeon, .92)
      : _opacity(const Color(0xFF5C6BFF), .70);
  final pressOverlayColor = isDark ? Colors.white : Colors.black;
  final labelColor = isDark
      ? _opacity(Colors.white, .92)
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
  width: 210,
  height: 280,
  margin: const EdgeInsets.fromLTRB(80, 0, 0, 8),
  iconAsset: kGamepad8AssetUp,
);
BtnCfg cfgBackward(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Backward',
  width: 210,
  height: 280,
  margin: const EdgeInsets.fromLTRB(80, 16, 0, 0),
  iconAsset: kGamepad8AssetDown,
);
BtnCfg cfgLeft(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Left',
  width: 210,
  height: 280,
  margin: const EdgeInsets.fromLTRB(0, 64, 0, 0),
  iconAsset: kGamepad8AssetLeft,
);
BtnCfg cfgRight(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Right',
  width: 210,
  height: 280,
  margin: const EdgeInsets.fromLTRB(0, 64, 0, 0),
  iconAsset: kGamepad8AssetRight,
);
const double speedRowGap = 6.0;
TapCfg cfgSpeedLow(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final isDark = theme.brightness == Brightness.dark;
  final c = Colors.green;
  final grad = [lighten(c, .18), darken(c, .06)];
  final border = isDark
      ? lighten(const Color(0xFF00FF9D), .10)
      : lighten(c, .24);
  final glow = isDark
      ? _opacity(const Color(0xFF00FFB2), .55)
      : _opacity(Colors.black, .22);
  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? _opacity(Colors.white, .85)
      : _opacity(const Color.fromARGB(255, 0, 0, 0), .85);
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
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
  final isDark = theme.brightness == Brightness.dark;
  final c = Colors.yellow;
  final grad = [lighten(c, .18), darken(c, .06)];
  final border = isDark
      ? lighten(const Color(0xFFFFD36A), .06)
      : lighten(c, .24);
  final glow = isDark
      ? _opacity(const Color(0xFFFFD54F), .55)
      : _opacity(Colors.black, .22);
  final textOn = Colors.black;
  final textOff = _opacity(Colors.black, .85);
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
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
  final isDark = theme.brightness == Brightness.dark;
  final c = Colors.red;
  final grad = [lighten(c, .18), darken(c, .06)];
  final border = isDark
      ? lighten(const Color(0xFFFF6B6B), .06)
      : lighten(c, .24);
  final glow = isDark
      ? _opacity(const Color(0xFFFF5A5A), .60)
      : _opacity(Colors.black, .22);
  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? _opacity(Colors.white, .85)
      : _opacity(const Color.fromARGB(255, 0, 0, 0), .85);
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
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
  final base = _opacity(t.colorScheme.surfaceContainerHighest, .70);
  return CommandCardCfg(
    width: 480,
    margin: const EdgeInsets.only(top: 60),
    padding: const EdgeInsets.all(12),
    background: [lighten(base, .06), darken(base, .06)],
    radius: 16,
    borderColor: _opacity(t.colorScheme.outlineVariant, .45),
    borderWidth: 1.2,
    shadowBlur: 12,
    shadowOffset: const Offset(0, 6),
    shadowColor: _opacity(Colors.black, .14),
    titleFont: 18,
    valueFont: 24,
    textColor: t.textTheme.bodyMedium?.color ?? Colors.white,
    valueColor: t.textTheme.bodyLarge?.color ?? Colors.white,
    dividerColor: _opacity(t.colorScheme.outlineVariant, .6),
  );
}

BtnCfg _scaleBtn(BtnCfg c, _S s) => c.copyWith(
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

class Gamepad4ButtonPage extends StatefulWidget {
  const Gamepad4ButtonPage({super.key, this.acquireControl});

  // Optional transport seam for exercising delayed Start completion in tests.
  final Future<int?> Function()? acquireControl;
  @override
  State<Gamepad4ButtonPage> createState() => _Gamepad4ButtonPageState();
}

class _Gamepad4ButtonPageState extends State<Gamepad4ButtonPage> {
  static const _prefsLayoutAll = 'gp4_layout_all';
  static const _prefsActiveAll = 'gp4_active_all';
  static const _prefsPreset1 = 'gp4_preset_1';
  static const _prefsPreset2 = 'gp4_preset_2';
  static const _prefsPreset3 = 'gp4_preset_3';
  static const _prefsPreset4 = 'gp4_preset_4';
  static const _prefsPreset5 = 'gp4_preset_5';
  bool _f = false, _b = false, _l = false, _r = false;
  String _command = '0';
  String _speedLabel = 'Lo';
  String _lastPacketKey = '';
  bool _isThai = true;
  late final VoidCallback _langListener;
  bool _editMode = false;
  bool _showGrid = false;
  bool _speedMenuOpen = false;

  /// Position of the Speed button in the control toolbar items.
  static const int _speedSlotIndex = 2;
  Map<String, _ButtonLayout> _layoutAll = {};
  Set<String> _activeIds = {'F:forward', 'F:backward', 'F:left', 'F:right'};
  final Set<String> _lockedIds = {};
  String? _selectedId;
  String? _editWarningId;
  Size? _panelSize;
  Timer? _editWarningTimer;
  int _lastOverlapWarningMs = 0;
  int _lastBoundaryWarningMs = 0;
  final List<_EditSnapshot> _undoStack = [];
  final List<_EditSnapshot> _redoStack = [];
  static const int _maxHistory = 30;
  Timer? _tick;
  int _lastSendMs = 0;
  StreamSubscription<bool>? _bleConnSub;
  int? _bleTrafficOwner;
  bool _startInProgress = false;
  bool _leavingControlPage = false;
  bool _controlStarted = false;
  bool _modeSwitchInProgress = false;
  void _resetInputState() {
    void apply() {
      _f = false;
      _b = false;
      _l = false;
      _r = false;
      _command = '0';
      _lastPacketKey = '';
      _lastSendMs = 0;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

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
  int _speedLevelByte() {
    var value = 0;
    for (final button in _buildPressedButtons()) {
      if (button >= 9 && button <= 16) {
        value |= 1 << (button - 9);
      }
    }
    return value;
  }

  Future<void> _loadLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutRaw = prefs.getString(_prefsLayoutAll);
    final activeRaw = prefs.getString(_prefsActiveAll);
    if (layoutRaw != null && layoutRaw.isNotEmpty) {
      _layoutAll = _decodeLayout(layoutRaw);
    }
    if (activeRaw != null && activeRaw.isNotEmpty) {
      _activeIds = _decodeIdList(
        activeRaw,
      ).intersection(_supportedFourButtonIds);
    }
    if (_activeIds.isEmpty) {
      _activeIds = {'F:forward', 'F:backward', 'F:left', 'F:right'};
    }
    _layoutAll.removeWhere((k, _) => !_activeIds.contains(k));
    _lockedIds.removeWhere((id) => !_layoutAll.containsKey(id));
    await _saveActive(_prefsActiveAll, _activeIds);
    await _saveLayout(_prefsLayoutAll, _layoutAll);
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
    setState(() {
      _editMode = !_editMode;
      _editWarningId = null;
    });
  }

  void _selectButton(String id) {
    setState(() {
      _selectedId = id;
      _editWarningId = null;
    });
  }

  void _toggleActive(String id) {
    _pushHistory();
    setState(() {
      if (_activeIds.contains(id)) {
        _activeIds.remove(id);
        _layoutAll.remove(id);
        _lockedIds.remove(id);
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

  Map<String, _ButtonLayout> _cloneLayout(Map<String, _ButtonLayout> src) {
    final out = <String, _ButtonLayout>{};
    src.forEach((k, v) {
      out[k] = _ButtonLayout(v.cx, v.cy, v.size);
    });
    return out;
  }

  _EditSnapshot _captureSnapshot() {
    return _EditSnapshot(
      layoutAll: _cloneLayout(_layoutAll),
      activeIds: Set<String>.from(_activeIds),
      lockedIds: Set<String>.from(_lockedIds),
      selectedId: _selectedId,
    );
  }

  void _applySnapshot(_EditSnapshot snap) {
    _layoutAll = _cloneLayout(snap.layoutAll);
    _activeIds
      ..clear()
      ..addAll(snap.activeIds);
    _lockedIds
      ..clear()
      ..addAll(snap.lockedIds);
    _selectedId = snap.selectedId;
    _lockedIds.removeWhere((id) => !_layoutAll.containsKey(id));
  }

  void _pushHistory() {
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_captureSnapshot());
      _applySnapshot(_undoStack.removeLast());
      _editWarningId = null;
    });
    _saveActive(_prefsActiveAll, _activeIds);
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_captureSnapshot());
      _applySnapshot(_redoStack.removeLast());
      _editWarningId = null;
    });
    _saveActive(_prefsActiveAll, _activeIds);
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  void _changeSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;
    if (_lockedIds.contains(id)) return;
    final panelSize = _panelSize;
    if (panelSize == null) return;
    final current = _layoutAll[id];
    if (current == null) return;
    final base = _cfgForId(id);
    if (base == null) return;
    final unclamped = current.size + delta;
    final nextSize = unclamped.clamp(_minBtnSize, _maxBtnSize);
    if (nextSize == current.size) {
      final atMax = unclamped >= _maxBtnSize;
      _showSizeLimit(atMax);
      _flashEditWarning(id);
      return;
    }
    final w = panelSize.width;
    final h = panelSize.height;
    final baseScaled = _scaledBaseCfg(base, panelSize);
    final baseDiameter = math.min(baseScaled.width, baseScaled.height);
    if (baseDiameter <= 0) return;
    final targetDiameter = GamepadEditMetrics.sizePx(panelSize, nextSize);
    final visualScale = targetDiameter / baseDiameter;
    final nextCfg = _scaleHoldCfg(baseScaled, visualScale);
    final halfW = nextCfg.width / 2;
    final halfH = nextCfg.height / 2;
    const safeEdgePad = GamepadEditMetrics.safeEdgePad;
    const safeTopPad = GamepadEditMetrics.safeTopEdgePad;
    final minX = safeEdgePad + halfW;
    final maxX = w - safeEdgePad - halfW;
    final minY = safeTopPad + halfH;
    final maxY = h - safeEdgePad - halfH;
    final cx = current.cx * w;
    final cy = current.cy * h;
    if (cx < minX || cx > maxX || cy < minY || cy > maxY) {
      HapticFeedback.vibrate();
      setState(() => _editWarningId = id);
      _showBoundaryWarning();
      return;
    }
    final candidate = _ButtonLayout(cx / w, cy / h, nextSize);
    if (_wouldOverlapAny(id, candidate, panelSize)) {
      HapticFeedback.vibrate();
      setState(() => _editWarningId = id);
      _showOverlapWarning();
      return;
    }
    _pushHistory();
    setState(() {
      final next = Map<String, _ButtonLayout>.from(_layoutAll);
      next[id] = candidate;
      _layoutAll = next;
      _editWarningId = null;
    });
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  void _toggleSelectedLock() {
    final id = _selectedId;
    if (id == null) return;
    setState(() {
      if (_lockedIds.contains(id)) {
        _lockedIds.remove(id);
      } else {
        _lockedIds.add(id);
      }
    });
  }

  void _showSizeLimit(bool atMax) {
    final isThai = LanguageController.isThai.value;
    final msg = atMax
        ? (isThai ? 'Maximum size is 80%.' : 'Maximum size is 80%.')
        : (isThai ? 'Minimum size reached.' : 'Minimum size reached.');
    showGamepadTopNotice(
      context,
      message: msg,
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _flashEditWarning(String id) {
    _editWarningTimer?.cancel();
    setState(() => _editWarningId = id);
    _editWarningTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        if (_editWarningId == id) _editWarningId = null;
      });
    });
  }

  BtnCfg? _cfgForId(String id) {
    if (id == 'F:forward') return cfgForward(context);
    if (id == 'F:backward') return cfgBackward(context);
    if (id == 'F:left') return cfgLeft(context);
    if (id == 'F:right') return cfgRight(context);
    return null;
  }

  bool _wouldOverlapAny(String movingId, _ButtonLayout moving, Size panelSize) {
    final movingBase = _cfgForId(movingId);
    if (movingBase == null) return false;
    final movingScaled = _scaledHoldCfg(movingBase, moving, panelSize);
    final movingRadius =
        math.min(movingScaled.cfg.width, movingScaled.cfg.height) / 2;
    final movingCenter = movingScaled.center;
    for (final entry in _layoutAll.entries) {
      final id = entry.key;
      if (id == movingId) continue;
      if (!_activeIds.contains(id)) continue;
      final base = _cfgForId(id);
      if (base == null) continue;
      final otherScaled = _scaledHoldCfg(base, entry.value, panelSize);
      final otherRadius =
          math.min(otherScaled.cfg.width, otherScaled.cfg.height) / 2;
      final dx = movingCenter.dx - otherScaled.center.dx;
      final dy = movingCenter.dy - otherScaled.center.dy;
      final dist = math.sqrt((dx * dx) + (dy * dy));
      if (dist < (movingRadius + otherRadius)) {
        return true;
      }
    }
    return false;
  }

  void _resetLayouts() async {
    _pushHistory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayoutAll);
    await prefs.remove('${_prefsLayoutAll}_start_stop');
    await prefs.remove(_prefsActiveAll);
    setState(() {
      _layoutAll = {};
      _activeIds = {'F:forward', 'F:backward', 'F:left', 'F:right'};
      _lockedIds.clear();
      _selectedId = null;
      _editWarningId = null;
    });
  }

  String _presetKey(int slot) {
    switch (slot) {
      case 1:
        return _prefsPreset1;
      case 2:
        return _prefsPreset2;
      case 3:
        return _prefsPreset3;
      case 4:
        return _prefsPreset4;
      case 5:
        return _prefsPreset5;
      default:
        throw ArgumentError.value(slot, 'slot', 'Unsupported preset slot');
    }
  }

  String _defaultPresetName(int slot, bool isThai) =>
      isThai ? 'Preset $slot' : 'Preset $slot';
  static final RegExp _presetAllowedPattern = RegExp(r'^[A-Za-z0-9 _-]+$');
  static final RegExp _presetRequiredChars = RegExp(r'[A-Za-z0-9]');
  String? _validatePresetName(String raw, bool isThai) {
    final value = raw.trim();
    if (value.isEmpty) {
      return isThai
          ? 'Enter a preset name using letters or numbers.'
          : 'Enter a preset name using letters or numbers.';
    }
    if (!_presetAllowedPattern.hasMatch(value)) {
      return isThai
          ? 'Only letters, numbers, spaces, - and _ are allowed.'
          : 'Only letters, numbers, spaces, - and _ are allowed.';
    }
    if (!_presetRequiredChars.hasMatch(value)) {
      return isThai
          ? 'Use at least one letter or number. Symbols alone are not allowed.'
          : 'Use at least one letter or number. Symbols alone are not allowed.';
    }
    return null;
  }

  String? _readPresetName(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return null;
      final name = obj['name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return null;
  }

  Future<String?> _promptPresetName({
    required BuildContext context,
    String? currentName,
  }) {
    final isThai = LanguageController.isThai.value;
    return showCatPresetNameDialog(
      context: context,
      isThai: isThai,
      currentName: currentName,
      validator: (value) => _validatePresetName(value, isThai),
    );
  }

  Future<void> _savePreset(int slot, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object>{
      'layout': _encodeLayout(_layoutAll),
      'active': _activeIds.toList(),
      'speed': _speedLabel,
    };
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) {
      data['name'] = trimmed;
    }
    await prefs.setString(_presetKey(slot), jsonEncode(data));
  }

  Future<void> _loadPreset(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetKey(slot));
    if (raw == null || raw.isEmpty) return;
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return;
      final layoutRaw = obj['layout'];
      final activeRaw = obj['active'];
      final speed = obj['speed'];
      if (layoutRaw is Map) {
        _layoutAll = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (activeRaw is List) {
        _activeIds = activeRaw
            .map((e) => e.toString())
            .toSet()
            .intersection(_supportedFourButtonIds);
      }
      if (speed is String) _speedLabel = speed;
      setState(() {});
      _saveLayout(_prefsLayoutAll, _layoutAll);
      _saveActive(_prefsActiveAll, _activeIds);
      _sendBinary(force: true);
    } catch (_) {}
  }

  Future<void> _showPresetSheet() async {
    final isThai = LanguageController.isThai.value;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    ControlPresetSlot makeSlot(int slot) {
      final raw = prefs.getString(_presetKey(slot)) ?? '';
      return ControlPresetSlot(
        slot: slot,
        name: _readPresetName(raw) ?? _defaultPresetName(slot, isThai),
        hasData: raw.isNotEmpty,
      );
    }

    await showControlPresetDialog(
      context: context,
      isThai: isThai,
      slots: List<ControlPresetSlot>.generate(
        controlPresetSlotCount,
        (index) => makeSlot(index + 1),
      ),
      onSave: (slot) async {
        gamepadBuzz();
        final name = await _promptPresetName(
          context: context,
          currentName: slot.hasData ? slot.name : null,
        );
        if (name == null) return null;
        await _savePreset(slot.slot, name: name);
        final trimmed = name.trim();
        return ControlPresetSlot(
          slot: slot.slot,
          name: trimmed.isEmpty
              ? _defaultPresetName(slot.slot, isThai)
              : trimmed,
          hasData: true,
        );
      },
      onLoad: (slot) async {
        gamepadBuzz();
        await _loadPreset(slot.slot);
      },
      onClear: (slot) async {
        gamepadBuzz();
        await prefs.remove(_presetKey(slot.slot));
        return ControlPresetSlot(
          slot: slot.slot,
          name: _defaultPresetName(slot.slot, isThai),
          hasData: false,
        );
      },
    );
  }

  void _showOverlapWarning() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastOverlapWarningMs < 900) return;
    _lastOverlapWarningMs = now;
    final isThai = LanguageController.isThai.value;
    showGamepadTopNotice(
      context,
      message: isThai ? 'Buttons cannot overlap.' : 'Buttons cannot overlap.',
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _showBoundaryWarning() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBoundaryWarningMs < 900) return;
    _lastBoundaryWarningMs = now;
    final isThai = LanguageController.isThai.value;
    showGamepadTopNotice(
      context,
      message: isThai
          ? 'Buttons must stay inside the safe zone.'
          : 'Buttons must stay inside the safe zone.',
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _sendBinary({bool force = false}) {
    if (!_controlStarted ||
        _startInProgress ||
        _modeSwitchInProgress ||
        BleManager.instance.controlSuspendedForLifecycle) {
      return;
    }
    if (!BleManager.instance.isConnected) return;
    final owner = _bleTrafficOwner;
    if (owner == null) return;
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
    unawaited(
      BleManager.instance.sendJoystickBinary(
        packet: JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
        pressedButtons: _buildPressedButtons(),
        owner: owner,
        force: force,
      ),
    );
  }

  void _startControlLoop() {
    if (_tick != null) return;
    _tick = Timer.periodic(
      const Duration(milliseconds: kLoopMs),
      (_) => _sendLoop(),
    );
  }

  void _stopControlLoop() {
    _tick?.cancel();
    _tick = null;
  }

  void _handleControlSuspended() {
    if (!BleManager.instance.controlSuspendedForLifecycle || !_controlStarted) {
      return;
    }
    _stopControlLoop();
    _resetInputState();
    if (mounted) setState(() => _controlStarted = false);
  }

  bool get _canStartControl =>
      !_leavingControlPage && !_startInProgress && !_modeSwitchInProgress;
  Future<void> _startControl() async {
    if (_controlStarted || !_canStartControl) return;
    setState(() => _startInProgress = true);
    final owner =
        await (widget.acquireControl?.call() ??
            BleConnectionCoordinator.instance.acquireControlForStart(
              ownerName: 'gamepad_4',
            ));
    if (!mounted || _leavingControlPage || _modeSwitchInProgress) {
      if (owner != null) {
        await BleManager.instance.stopAndReleaseControl(owner: owner);
      }
      return;
    }
    if (owner == null) {
      setState(() => _startInProgress = false);
      if (requiresBlePairingCode(
        BleConnectionCoordinator.instance.state.securityState,
      )) {
        final paired = await promptForBlePairingCode(
          context: context,
          isThai: LanguageController.isThai.value,
        );
        if (paired == true && mounted) {
          await _startControl();
        }
        return;
      }
      showGamepadTopNotice(
        context,
        message:
            switch (BleConnectionCoordinator.instance.state.recoveryOutcome) {
              BleRecoveryOutcome.credentialMismatchSuspected ||
              BleRecoveryOutcome.credentialRejected => true,
              _ => false,
            }
            ? 'Saved pairing does not match this board. Use Forget device to pair again.'
            : 'Connect to a BLE device, then tap Start again.',
        style: GamepadNoticeStyle.error,
      );
      return;
    }
    _bleTrafficOwner = owner;
    _resetInputState();
    if (!mounted) return;
    setState(() {
      _startInProgress = false;
      _controlStarted = true;
    });
    _startControlLoop();
    _sendBinary(force: true);
  }

  Future<void> _stopControl() async {
    if (!_controlStarted) return;
    _stopControlLoop();
    _resetInputState();
    if (mounted) setState(() => _controlStarted = false);
    await _releaseTrafficOwnershipForExit(emergency: true);
  }

  @override
  void initState() {
    super.initState();
    unawaited(ControlModePreference.save(LastControlMode.fourButton));
    BleManager.instance.controlSuspendedListenable.addListener(
      _handleControlSuspended,
    );
    unawaited(OrientationUtils.request(AppOrientation.landscape));
    _isThai = LanguageController.isThai.value;
    _langListener = () {
      final next = LanguageController.isThai.value;
      if (next != _isThai) {
        setState(() => _isThai = next);
      }
    };
    LanguageController.isThai.addListener(_langListener);
    _sendSpeed('Med');
    _loadLayouts();
    _bleConnSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;
      _resetInputState();
      if (!connected) {
        _stopControlLoop();
        setState(() => _controlStarted = false);
        unawaited(_releaseTrafficOwnershipForExit());
      }
    });
  }

  Future<void> _switchToPrecision() async {
    if (_modeSwitchInProgress || _editMode) return;
    final manager = BleManager.instance;
    final owner = _bleTrafficOwner;
    setState(() {
      _modeSwitchInProgress = true;
      _controlStarted = false;
      _speedMenuOpen = false;
    });
    _resetInputState();
    _stopControlLoop();
    unawaited(ControlModePreference.save(LastControlMode.eightButton));
    _bleTrafficOwner = null;
    if (owner != null) {
      manager.handoffControlForModeSwitch(
        owner: owner,
        source: 'gamepad_preset_to_precision',
      );
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed<void, bool>(AppRoutes.gamepad8Button, result: true);
  }

  Future<void> _switchToJoystick() async {
    if (_modeSwitchInProgress || _editMode) return;
    final manager = BleManager.instance;
    final owner = _bleTrafficOwner;
    setState(() {
      _modeSwitchInProgress = true;
      _controlStarted = false;
      _speedMenuOpen = false;
    });
    _resetInputState();
    _stopControlLoop();
    unawaited(ControlModePreference.save(LastControlMode.joystick));
    _bleTrafficOwner = null;
    if (owner != null) {
      manager.handoffControlForModeSwitch(
        owner: owner,
        source: 'gamepad_4_to_joystick',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed<void, bool>(
      AppRoutes.dualJoystickMode1,
      result: true,
    );
  }

  Future<void> _openSettings() async {
    if (_editMode) return;
    final action = await Navigator.of(context).push<ControlModeSettingsAction>(
      controlModeSettingsRoute(
        mode: ControlMode.fourButton,
        onManageLayouts: _showPresetSheet,
      ),
    );
    if (!mounted) return;
    switch (action) {
      case ControlModeSettingsAction.editLayout:
        _toggleEdit();
      case ControlModeSettingsAction.selectEightButton:
        await _switchToPrecision();
      case ControlModeSettingsAction.selectJoystick:
        await _switchToJoystick();
      case ControlModeSettingsAction.selectFourButton:
      case null:
        break;
    }
  }

  void _showStartFirstNotice() {
    showGamepadTopNotice(
      context,
      message: 'Tap Start to drive',
      style: GamepadNoticeStyle.warning,
    );
  }

  Widget _buildToolbarStartStop() {
    return ValueListenableBuilder<bool>(
      valueListenable: BleManager.instance.controlSuspendedListenable,
      builder: (context, suspended, _) => ControlStartStopButton(
        started: _controlStarted && !suspended,
        busy: _startInProgress,
        onPressed: _controlStarted && !suspended
            ? _stopControl
            : (_canStartControl ? _startControl : null),
      ),
    );
  }

  Widget _buildStartHint(GamepadControlLayout layout) {
    final padding = MediaQuery.paddingOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: BleManager.instance.controlSuspendedListenable,
      builder: (context, suspended, _) => Positioned(
        left: padding.left,
        right: padding.right,
        top: padding.top + layout.height,
        bottom: 0,
        child: Stack(
          children: [
            ControlStartHint(
              // Only under a one-row toolbar, where it sits right below Start.
              visible:
                  layout.rows.length == 1 &&
                  !(_controlStarted && !suspended) &&
                  !_startInProgress &&
                  !_speedMenuOpen,
              anchorX: ControlStartHint.anchorXFor(layout),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leavingControlPage = true;
    _editWarningTimer?.cancel();
    _stopControlLoop();
    _bleConnSub?.cancel();
    BleManager.instance.controlSuspendedListenable.removeListener(
      _handleControlSuspended,
    );
    LanguageController.isThai.removeListener(_langListener);
    unawaited(_releaseTrafficOwnershipForExit());
    super.dispose();
  }

  Future<void> _releaseTrafficOwnershipForExit({bool emergency = false}) async {
    final owner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (owner == null) return;
    final manager = BleManager.instance;
    if (emergency) {
      await manager.emergencyStopAndReleaseControl(
        owner: owner,
        source: 'gamepad_4_emergency_stop',
      );
      return;
    }
    manager.disableControlReconnect(owner);
    try {
      if (manager.isConnected) {
        await manager.sendControlStop(owner: owner);
      }
    } finally {
      manager.releaseTrafficMode(owner);
    }
  }

  Future<void> _exitControlPage() async {
    if (_leavingControlPage) return;
    _leavingControlPage = true;
    await _releaseTrafficOwnershipForExit();
    if (mounted) Navigator.of(context).pop();
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

  Color _barAccent(String label) {
    switch (label) {
      case 'SPD':
        return const Color(0xFF38BDF8);
      case 'CMD':
        return const Color(0xFFF59E0B);
      case 'DRV':
        return const Color(0xFF22C55E);
      case 'TRN':
        return const Color(0xFFA855F7);
      case 'BLE':
        return const Color(0xFF3B82F6);
      case 'PRESET':
        return const Color(0xFFF59E0B);
      case 'EDIT':
        return const Color(0xFF60A5FA);
      case 'SETTINGS':
        return const Color(0xFF94A3B8);
      default:
        return Colors.white;
    }
  }

  Widget _buildAppBarBackButton() {
    return GamepadAppBarBackButton(
      onPressed: () async {
        gamepadBuzz();
        await _releaseTrafficOwnershipForExit();
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  Widget _appBarBadge(String label, String value) {
    IconData icon;
    Color accent;
    switch (label) {
      case 'SPD':
        icon = Icons.speed_rounded;
        accent = _barAccent('SPD');
        break;
      case 'CMD':
        icon = Icons.tune_rounded;
        accent = _barAccent('CMD');
        break;
      default:
        icon = Icons.circle;
        accent = _barAccent(label);
    }
    return GamepadTelemetryChip(
      icon: icon,
      label: label,
      value: value,
      accentColor: accent,
      iconAsset: label == 'CMD' ? AppAssets.controlCommand : null,
      subdued: label == 'CMD',
    );
  }

  Color _speedColor(String label) {
    return switch (label) {
      'Lo' => const Color(0xFF76CBEA),
      'Med' => const Color(0xFFF2B84B),
      'Hi' => const Color(0xFFF06B58),
      _ => Colors.white,
    };
  }

  String _speedAsset(String label) {
    return switch (label) {
      'Lo' => AppAssets.controlSpeedLow,
      'Med' => AppAssets.controlSpeedMedium,
      'Hi' => AppAssets.controlSpeedHigh,
      _ => AppAssets.controlSpeed,
    };
  }

  void _openSpeedMenu() {
    setState(() => _speedMenuOpen = !_speedMenuOpen);
  }

  void _selectSpeedMenuValue(String value) {
    setState(() => _speedMenuOpen = false);
    _sendSpeed(value);
  }

  /// Lo / Med / Hi menu. It floats under the Speed button over the pad, so
  /// opening it never moves or resizes the drive buttons.
  Widget _buildSpeedMenuOverlay(GamepadControlLayout layout) {
    final availableWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        24;
    final painter = TextPainter(
      text: TextSpan(text: 'Med', style: gamepadControlTextStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final tileWidth = painter.width.ceilToDouble() + 48;
    painter.dispose();
    final columns = ((availableWidth - 8) / (tileWidth + 2)).floor().clamp(
      1,
      3,
    );
    final panelWidth = columns * (tileWidth + 2) + 6;
    return GamepadToolbarDropdown(
      layout: layout,
      slotIndex: _speedSlotIndex,
      panelWidth: panelWidth,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !_speedMenuOpen || _editMode
            ? const SizedBox.shrink()
            : Container(
                width: panelWidth,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFDF9FF), Color(0xFFEDE5FF)],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: const Color(0xFFD5A0F5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD66DFF).withAlpha(56),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    48.0,
                    math.min(
                      150.0,
                      MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          layout.height -
                          100,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 2,
                    children: [
                      for (final label in const ['Lo', 'Med', 'Hi']) ...[
                        SizedBox(
                          width: tileWidth,
                          child: _buildInlineSpeedOption(label),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInlineSpeedOption(String label) {
    final selected = _speedLabel == label;
    final optionLabel = label;
    final color = _speedColor(label);
    final (
      selectedBorder,
      selectedTop,
      selectedBottom,
      selectedTextColor,
    ) = switch (label) {
      'Lo' => (
        const Color(0xFF65C95B),
        const Color(0xFFF0FFE8),
        const Color(0xFFCBF2B8),
        const Color(0xFF214A20),
      ),
      'Hi' => (
        const Color(0xFFFF694A),
        const Color(0xFFFFEEE5),
        const Color(0xFFFFBEAB),
        const Color(0xFF6A2418),
      ),
      _ => (
        const Color(0xFFFFC83D),
        const Color(0xFFFFF8D9),
        const Color(0xFFFFDF9C),
        const Color(0xFF542B0B),
      ),
    };
    final radius = selected
        ? BorderRadius.circular(24)
        : BorderRadius.horizontal(
            left: Radius.circular(label == 'Lo' ? 30 : 4),
            right: Radius.circular(label == 'Hi' ? 30 : 4),
          );
    return Semantics(
      button: true,
      selected: selected,
      label: optionLabel,
      child: Tooltip(
        message: optionLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectSpeedMenuValue(label),
            borderRadius: radius,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: SizedBox(
              height: 48,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [selectedTop, selectedBottom],
                        )
                      : null,
                  border: Border.all(
                    color: selected
                        ? selectedBorder
                        : Colors.white.withAlpha(210),
                    width: selected ? 1.8 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: selectedBorder.withAlpha(102),
                            blurRadius: 10,
                          ),
                        ]
                      : const [],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        _speedAsset(label),
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.speed_rounded, color: color, size: 32),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            optionLabel,
                            maxLines: 1,
                            style: gamepadControlTextStyle(context).copyWith(
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? selectedTextColor
                                  : const Color(0xFF8071AA),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _speedPopupButton() {
    return GamepadSpeedTogglePill(
      expanded: _speedMenuOpen,
      onTap: _openSpeedMenu,
      accent: _speedColor(_speedLabel),
      label: 'Speed',
      iconAsset: _speedAsset(_speedLabel),
    );
  }

  Widget _actionPill({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback? onTap,
    Key? key,
    bool iconOnly = false,
    bool compact = false,
  }) {
    return GamepadActionPill(
      pillKey: key,
      label: label,
      icon: icon,
      accent: accent,
      onTap: onTap,
      iconOnly: iconOnly,
      compact: compact,
    );
  }

  Widget _toolIconPill({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback? onTap,
    Key? key,
    bool active = false,
  }) {
    return GamepadToolIconPill(
      pillKey: key,
      icon: icon,
      label: label,
      accent: accent,
      onTap: onTap,
      active: active,
    );
  }

  Widget _sizeToolPill({required bool enabled, Key? key}) {
    return GamepadSizeToolPill(
      pillKey: key,
      isThai: LanguageController.isThai.value,
      enabled: enabled,
      onDecrease: enabled ? () => _changeSelectedSize(-0.05) : null,
      onIncrease: enabled ? () => _changeSelectedSize(0.05) : null,
    );
  }

  // Kept temporarily for compatibility with the previous toolbar composition.
  // ignore: unused_element
  double _editAppBarGap({
    required bool isThai,
    required GamepadAppBarMetrics metrics,
  }) {
    final width = MediaQuery.of(context).size.width;
    final estimatedButtonsWidth = isThai ? 126.0 : 82.0;
    final estimatedDoneWidth = isThai ? 78.0 : 70.0;
    final estimatedDeleteWidth = isThai ? 58.0 : 76.0;
    final estimatedResetWidth = isThai ? 72.0 : 70.0;
    const estimatedToolWidth = 62.0;
    final estimatedSizeWidth = isThai ? 78.0 : 70.0;
    final estimatedContentWidth =
        estimatedButtonsWidth +
        estimatedDoneWidth +
        estimatedDeleteWidth +
        estimatedResetWidth +
        (estimatedToolWidth * 4) +
        estimatedSizeWidth;
    final availableWidth = math.max(
      0.0,
      width - metrics.contentPadding.horizontal - 28.0,
    );
    final remaining = math.max(0.0, availableWidth - estimatedContentWidth);
    return (remaining / 8).clamp(4.0, 10.0);
  }

  // ignore: unused_element
  Widget _buildEditAppBarRow(bool isThai, double gap) {
    final media = MediaQuery.of(context);
    if (media.size.width >= 1000 && media.textScaler.scale(1) <= 1.3) {
      return _buildExpandedEditAppBarRow(isThai, gap);
    }
    final selectedId = _selectedId;
    final hasSelection = selectedId != null;
    final selectedLocked =
        selectedId != null && _lockedIds.contains(selectedId);
    final sizeEnabled = hasSelection && !selectedLocked;
    final metrics = GamepadAppBarMetrics.forWidth(media.size.width);

    Widget compactAction({
      required String label,
      required IconData icon,
      required VoidCallback? onTap,
    }) {
      return Tooltip(
        message: label,
        child: _actionPill(
          label: label,
          icon: icon,
          accent: const Color(0xFFA78BFA),
          iconOnly: true,
          compact: true,
          onTap: onTap,
        ),
      );
    }

    final more = GamepadEditMoreButton(
      actions: [
        GamepadOverflowAction(
          label: isThai ? 'ลบ' : 'Delete',
          icon: Icons.delete_outline,
          accent: const Color(0xFFF87171),
          onTap: hasSelection ? _removeSelected : null,
        ),
        GamepadOverflowAction(
          label: 'Reset',
          icon: Icons.restart_alt,
          accent: const Color(0xFFF59E0B),
          onTap: _resetLayouts,
        ),
        GamepadOverflowAction(
          label: 'Grid',
          icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          accent: const Color(0xFF38BDF8),
          active: _showGrid,
          onTap: () => setState(() => _showGrid = !_showGrid),
        ),
        GamepadOverflowAction(
          label: isThai ? 'ลดขนาด' : 'Decrease size',
          icon: Icons.remove,
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? () => _changeSelectedSize(-0.05) : null,
        ),
        GamepadOverflowAction(
          label: isThai ? 'เพิ่มขนาด' : 'Increase size',
          icon: Icons.add,
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? () => _changeSelectedSize(0.05) : null,
        ),
        GamepadOverflowAction(
          label: gamepadEditLockLabel(isThai: isThai, locked: selectedLocked),
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? _toggleSelectedLock : null,
        ),
      ],
    );
    final history = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        compactAction(
          label: 'Undo',
          icon: Icons.undo_rounded,
          onTap: _undoStack.isNotEmpty ? _undo : null,
        ),
        SizedBox(width: gap),
        compactAction(
          label: 'Redo',
          icon: Icons.redo_rounded,
          onTap: _redoStack.isNotEmpty ? _redo : null,
        ),
      ],
    );
    final done = _actionPill(
      label: 'Done',
      icon: Icons.edit,
      accent: const Color(0xFF60A5FA),
      compact: true,
      onTap: _toggleEdit,
    );
    return SizedBox(
      width: math.max(0, media.size.width - 48),
      height: metrics.tapTargetExtent,
      child: Row(
        children: [
          more,
          SizedBox(width: metrics.sectionGap),
          Expanded(child: Center(child: history)),
          SizedBox(width: metrics.sectionGap),
          done,
        ],
      ),
    );
  }

  Widget _buildExpandedEditAppBarRow(bool isThai, double gap) {
    final selectedId = _selectedId;
    final hasSelection = selectedId != null;
    final selectedLocked =
        selectedId != null && _lockedIds.contains(selectedId);
    final sizeEnabled = hasSelection && !selectedLocked;
    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;
    final children = <Widget>[
      _actionPill(
        label: isThai ? 'ź' : 'Delete',
        icon: Icons.delete_outline,
        accent: const Color(0xFFF87171),
        compact: true,
        onTap: hasSelection ? _removeSelected : null,
      ),
      _actionPill(
        label: isThai ? 'Reset' : 'Reset',
        icon: Icons.restart_alt,
        accent: const Color(0xFFF59E0B),
        compact: true,
        onTap: _resetLayouts,
      ),
      _toolIconPill(
        icon: Icons.undo_rounded,
        label: isThai ? 'Undo' : 'Undo',
        accent: const Color(0xFFA78BFA),
        onTap: canUndo ? _undo : null,
      ),
      _toolIconPill(
        icon: Icons.redo_rounded,
        label: isThai ? 'Redo' : 'Redo',
        accent: const Color(0xFFA78BFA),
        onTap: canRedo ? _redo : null,
      ),
      _toolIconPill(
        icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
        label: isThai ? 'Grid' : 'Grid',
        accent: const Color(0xFF38BDF8),
        active: _showGrid,
        onTap: () => setState(() => _showGrid = !_showGrid),
      ),
      _sizeToolPill(enabled: sizeEnabled),
      _toolIconPill(
        icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
        label: gamepadEditLockLabel(isThai: isThai, locked: selectedLocked),
        accent: const Color(0xFFFBBF24),
        active: selectedLocked,
        onTap: hasSelection ? _toggleSelectedLock : null,
      ),
      _actionPill(
        label: isThai ? 'Done' : 'Done',
        icon: Icons.edit,
        accent: const Color(0xFF60A5FA),
        compact: true,
        onTap: _toggleEdit,
      ),
    ];
    Widget actionRow(Iterable<Widget> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items) ...[
          item,
          if (!identical(item, items.last)) SizedBox(width: gap),
        ],
      ],
    );
    final media = MediaQuery.of(context);
    final metrics = GamepadAppBarMetrics.forWidth(media.size.width);
    return SizedBox(
      width: math.max(0, media.size.width - 48),
      height: metrics.tapTargetExtent,
      child: Row(
        children: [
          actionRow(children.take(2)),
          SizedBox(width: metrics.sectionGap),
          Expanded(child: Center(child: actionRow(children.sublist(2, 7)))),
          SizedBox(width: metrics.sectionGap),
          children.last,
        ],
      ),
    );
  }

  Widget _buildCenteredEditAppBar(bool isThai) {
    final selectedId = _selectedId;
    final hasSelection = selectedId != null;
    final selectedLocked =
        selectedId != null && _lockedIds.contains(selectedId);
    final sizeEnabled = hasSelection && !selectedLocked;
    return GamepadCenteredToolbar(
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      singleRow: true,
      children: [
        _toolIconPill(
          icon: Icons.done_rounded,
          label: 'Done',
          accent: const Color(0xFF60A5FA),
          onTap: _toggleEdit,
        ),
        _toolIconPill(
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          label: gamepadEditLockLabel(isThai: isThai, locked: selectedLocked),
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? _toggleSelectedLock : null,
        ),
        _toolIconPill(
          icon: Icons.remove,
          label: isThai ? 'ลดขนาด' : 'Decrease size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? () => _changeSelectedSize(-0.05) : null,
        ),
        _toolIconPill(
          icon: Icons.add,
          label: isThai ? 'เพิ่มขนาด' : 'Increase size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? () => _changeSelectedSize(0.05) : null,
        ),
        _toolIconPill(
          icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          label: 'Grid',
          accent: const Color(0xFF38BDF8),
          active: _showGrid,
          onTap: () => setState(() => _showGrid = !_showGrid),
        ),
        _toolIconPill(
          icon: Icons.undo_rounded,
          label: 'Undo',
          accent: const Color(0xFFA78BFA),
          onTap: _undoStack.isNotEmpty ? _undo : null,
        ),
        _toolIconPill(
          icon: Icons.redo_rounded,
          label: 'Redo',
          accent: const Color(0xFFA78BFA),
          onTap: _redoStack.isNotEmpty ? _redo : null,
        ),
        _toolIconPill(
          icon: Icons.restart_alt,
          label: 'Reset',
          accent: const Color(0xFFF59E0B),
          onTap: _resetLayouts,
        ),
        _toolIconPill(
          icon: Icons.delete_outline,
          label: isThai ? 'ลบ' : 'Delete',
          accent: const Color(0xFFF87171),
          onTap: hasSelection ? _removeSelected : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlLayout = _editMode
        ? null
        : GamepadControlLayout.measure(context, [
            '',
            '',
            '@speed:Speed',
            'CMD = 255 | Med = 2',
            '@ble',
            '',
          ], leadingCount: 2);
    final isThai = LanguageController.isThai.value;
    final media = MediaQuery.of(context);
    final appBarMetrics = GamepadAppBarMetrics.forWidth(media.size.width);
    final textScaleFactor = media.textScaler.scale(1);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_exitControlPage());
      },
      child: Stack(
        children: [
          Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GamepadUnifiedAppBar(
              controlLayout: controlLayout,
              textScaleFactor: textScaleFactor,
              viewportWidth: media.size.width - media.padding.horizontal,
              toolbarItemCount: _editMode ? 9 : null,
              singleRowToolbar: _editMode,
              useGlassBackground: false,
              glassOpacity: 0.18,
              leading: _editMode ? null : _buildAppBarBackButton(),
              startStop: _editMode ? null : _buildToolbarStartStop(),
              toolbarContent: _editMode
                  ? _buildCenteredEditAppBar(isThai)
                  : null,
              speedToggle: _editMode ? null : _speedPopupButton(),
              cmdChip: _editMode
                  ? null
                  : SizedBox(
                      child: _appBarBadge(
                        'CMD',
                        '= ${_commandByteLabel()} | $_speedLabel = ${_speedLevelByte()}',
                      ),
                    ),
              bleBadge: _editMode
                  ? null
                  : ConnectionStatusBadge(
                      autoPromptPairing: true,
                      appBarMetrics: appBarMetrics,
                      iconAsset: AppAssets.controlBle,
                      subdued: true,
                      onManagementBlocked: () => showGamepadTopNotice(
                        context,
                        message: isThai
                            ? 'Use Emergency Stop before managing BLE.'
                            : 'Use Emergency Stop before managing BLE.',
                        style: GamepadNoticeStyle.ble,
                      ),
                    ),
              actionsBuilder: (gap) {
                if (_editMode) {
                  return const SizedBox.shrink();
                }
                return GamepadAppBarActionGroup(
                  gap: gap,
                  items: [
                    GamepadAppBarActionItem(
                      label: isThai ? 'Settings' : 'Settings',
                      icon: Icons.settings_outlined,
                      iconAsset: AppAssets.controlSettings,
                      accent: _barAccent('SETTINGS'),
                      iconOnly: true,
                      compact: true,
                      onTap: _openSettings,
                    ),
                  ],
                );
              },
            ),
            body: Stack(
              children: [
                Positioned.fill(child: const ControlBackground()),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            if (_editMode)
                              GamepadEditHint(
                                hasSelection: _selectedId != null,
                              ),
                            LayoutBuilder(
                              builder: (context, cons) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    4,
                                    8,
                                    8,
                                  ),
                                  child: Center(
                                    child: SizedBox.expand(
                                      child: ControlInputGate(
                                        started: _controlStarted,
                                        editing: _editMode,
                                        suspended: BleManager
                                            .instance
                                            .controlSuspendedListenable,
                                        onLockedTap: _showStartFirstNotice,
                                        child: _editMode
                                            ? _EditablePadPanel(
                                                ids: _activeIds
                                                    .intersection(
                                                      _supportedFourButtonIds,
                                                    )
                                                    .toList(),
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
                                                snapToGrid: _showGrid,
                                                onLayoutChanged: (next) {
                                                  _layoutAll = next;
                                                  _saveLayout(
                                                    _prefsLayoutAll,
                                                    _layoutAll,
                                                  );
                                                },
                                                selectedId: _selectedId,
                                                warningId: _editWarningId,
                                                lockedIds: _lockedIds,
                                                onSelect: _selectButton,
                                                onPanelSize: (size) {
                                                  _panelSize = size;
                                                },
                                                onStart: () {
                                                  if (_editWarningId != null) {
                                                    setState(
                                                      () =>
                                                          _editWarningId = null,
                                                    );
                                                  }
                                                  _pushHistory();
                                                },
                                                onCollision:
                                                    _showOverlapWarning,
                                                onBoundaryWarning:
                                                    _showBoundaryWarning,
                                              )
                                            : _LayoutPadPanel(
                                                ids: _activeIds
                                                    .intersection(
                                                      _supportedFourButtonIds,
                                                    )
                                                    .toList(),
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
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (controlLayout != null) _buildStartHint(controlLayout),
              ],
            ),
          ),
          if (controlLayout != null) _buildSpeedMenuOverlay(controlLayout),
        ],
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
  final sw = panel.width / designW;
  final sh = panel.height / designH;
  final sp = ((sw + sh) / 2.0).clamp(0.75, 1.35);
  return _S(sw, sh, sp);
}

BtnCfg _scaledBaseCfg(BtnCfg base, Size panel) {
  final s = _scaleForPanel(panel);
  return _scaleBtn(base, s).copyWith(margin: EdgeInsets.zero);
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
  final baseScaled = _scaledBaseCfg(base, panel);
  final baseDiameter = math.min(baseScaled.width, baseScaled.height);
  final targetDiameter = GamepadEditMetrics.sizePx(panel, layout.size);
  final visualScale = baseDiameter > 0 ? (targetDiameter / baseDiameter) : 1.0;
  final cfg = _scaleHoldCfg(baseScaled, visualScale);
  final halfW = cfg.width / 2;
  final halfH = cfg.height / 2;
  final cx = (layout.cx * w).clamp(halfW, w - halfW);
  final cy = (layout.cy * h).clamp(halfH, h - halfH);
  return _ScaledHoldCfg(cfg, Offset(cx, cy));
}

BtnCfg _defaultRenderedCfg(BtnCfg base, Size panel) {
  return _scaledHoldCfg(base, const _ButtonLayout(0.5, 0.5, 0.30), panel).cfg;
}

Map<String, _ButtonLayout> _defaultLayoutForIds(
  Size size,
  Map<String, _BtnSpec> specs,
  List<String> ids,
) {
  final w = size.width;
  final h = size.height;
  final s = _scaleForPanel(size);
  final frame = GamepadEditMetrics.defaultLayoutFrame(size);
  _ButtonLayout make(double x, double y) {
    return _ButtonLayout(x / w, y / h, 0.30);
  }

  final hasForward = ids.contains('F:forward');
  final hasBackward = ids.contains('F:backward');
  final hasLeft = ids.contains('F:left');
  final hasRight = ids.contains('F:right');
  final out = <String, _ButtonLayout>{};
  if (hasForward || hasBackward) {
    final cfgF = hasForward
        ? _defaultRenderedCfg(specs['F:forward']!.cfg, size)
        : null;
    final cfgB = hasBackward
        ? _defaultRenderedCfg(specs['F:backward']!.cfg, size)
        : null;
    final totalHeight = [
      if (cfgF != null) cfgF.height + cfgF.margin.vertical,
      if (cfgB != null) cfgB.height + cfgB.margin.vertical,
    ].fold(0.0, (a, b) => a + b);
    final gapY = (cfgF != null && cfgB != null) ? s.h(_panelColGap) : 0.0;
    final colLeft = frame.left + _panelEdgeInset;
    double y = frame.top + (frame.height - (totalHeight + gapY)) / 2.0;
    if (cfgF != null) {
      y += cfgF.margin.top;
      out['F:forward'] = make(
        colLeft + cfgF.margin.left + cfgF.width / 2,
        y + cfgF.height / 2,
      );
      y += cfgF.height + cfgF.margin.bottom;
      y += gapY;
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
    final cfgL = hasLeft
        ? _defaultRenderedCfg(specs['F:left']!.cfg, size)
        : null;
    final cfgR = hasRight
        ? _defaultRenderedCfg(specs['F:right']!.cfg, size)
        : null;
    final gap = s.w(_panelRowGap);
    final rowWidth =
        [
          if (cfgL != null) cfgL.width + cfgL.margin.horizontal,
          if (cfgR != null) cfgR.width + cfgR.margin.horizontal,
        ].fold(0.0, (a, b) => a + b) +
        ((cfgL != null && cfgR != null) ? gap : 0);
    final maxHeight = [
      if (cfgL != null) cfgL.height + cfgL.margin.vertical,
      if (cfgR != null) cfgR.height + cfgR.margin.vertical,
    ].fold(0.0, math.max);
    double x = frame.right - rowWidth - _panelEdgeInset;
    final y = frame.top + (frame.height - maxHeight) / 2.0;
    if (cfgL != null) {
      final cy = y + cfgL.margin.top + cfgL.height / 2;
      x += cfgL.margin.left;
      out['F:left'] = make(x + cfgL.width / 2, cy);
      x += cfgL.width + cfgL.margin.right;
      if (cfgR != null) x += gap;
    }
    if (cfgR != null) {
      final cy = y + cfgR.margin.top + cfgR.height / 2;
      x += cfgR.margin.left;
      out['F:right'] = make(x + cfgR.width / 2, cy);
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

class _EditSnapshot {
  final Map<String, _ButtonLayout> layoutAll;
  final Set<String> activeIds;
  final Set<String> lockedIds;
  final String? selectedId;
  const _EditSnapshot({
    required this.layoutAll,
    required this.activeIds,
    required this.lockedIds,
    required this.selectedId,
  });
}

class _GuideState {
  final bool showVertical;
  final bool showHorizontal;
  final double? verticalX;
  final double? horizontalY;
  final bool snap;
  const _GuideState({
    required this.showVertical,
    required this.showHorizontal,
    required this.verticalX,
    required this.horizontalY,
    required this.snap,
  });
  const _GuideState.hidden()
    : showVertical = false,
      showHorizontal = false,
      verticalX = null,
      horizontalY = null,
      snap = false;
}

class _EditGuidePainter extends CustomPainter {
  final bool showVertical;
  final bool showHorizontal;
  final double? verticalXFactor;
  final double? horizontalYFactor;
  final Color color;
  const _EditGuidePainter({
    required this.showVertical,
    required this.showHorizontal,
    required this.verticalXFactor,
    required this.horizontalYFactor,
    required this.color,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (!showVertical && !showHorizontal) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    if (showVertical && verticalXFactor != null) {
      final x = (verticalXFactor!.clamp(0.0, 1.0)) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    if (showHorizontal && horizontalYFactor != null) {
      final y = (horizontalYFactor!.clamp(0.0, 1.0)) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _EditGuidePainter oldDelegate) {
    return oldDelegate.showVertical != showVertical ||
        oldDelegate.showHorizontal != showHorizontal ||
        oldDelegate.verticalXFactor != verticalXFactor ||
        oldDelegate.horizontalYFactor != horizontalYFactor ||
        oldDelegate.color != color;
  }
}

class _EditablePadPanel extends StatefulWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> layout;
  final ValueChanged<Map<String, _ButtonLayout>> onLayoutChanged;
  final String? selectedId;
  final String? warningId;
  final Set<String> lockedIds;
  final bool snapToGrid;
  final ValueChanged<String> onSelect;
  final ValueChanged<Size> onPanelSize;
  final VoidCallback? onStart;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  const _EditablePadPanel({
    required this.ids,
    required this.specs,
    required this.layout,
    required this.onLayoutChanged,
    required this.selectedId,
    required this.warningId,
    required this.lockedIds,
    required this.snapToGrid,
    required this.onSelect,
    required this.onPanelSize,
    this.onStart,
    this.onCollision,
    this.onBoundaryWarning,
  });
  @override
  State<_EditablePadPanel> createState() => _EditablePadPanelState();
}

class _EditablePadPanelState extends State<_EditablePadPanel> {
  late Map<String, _ButtonLayout> _layout;
  bool _initialized = false;
  _GuideState _guide = const _GuideState.hidden();
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
        final guideColor = _guide.snap
            ? _opacity(const Color(0xFFFACC15), 0.95)
            : _opacity(const Color(0xFFFACC15), 0.60);
        return Stack(
          children: [
            // Same box the buttons are placed and snapped in.
            if (widget.snapToGrid)
              const Positioned.fill(child: GamepadEditGrid()),
            IgnorePointer(
              child: CustomPaint(
                painter: _EditGuidePainter(
                  showVertical: _guide.showVertical,
                  showHorizontal: _guide.showHorizontal,
                  verticalXFactor: _guide.verticalX,
                  horizontalYFactor: _guide.horizontalY,
                  color: guideColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            ...widget.ids.map((id) {
              final spec = widget.specs[id];
              final layout = _layout[id];
              if (spec == null || layout == null) {
                return const SizedBox.shrink();
              }
              return _EditableButton(
                id: id,
                layout: layout,
                panelSize: size,
                cfg: spec.cfg,
                specs: widget.specs,
                allLayouts: _layout,
                snapToGrid: widget.snapToGrid,
                selected: widget.selectedId == id,
                externalWarning: widget.warningId == id,
                dimmed: widget.selectedId != null && widget.selectedId != id,
                locked: widget.lockedIds.contains(id),
                onChanged: (next) {
                  setState(() => _layout[id] = next);
                },
                onGuideChanged: (g) {
                  if (g.showVertical != _guide.showVertical ||
                      g.showHorizontal != _guide.showHorizontal ||
                      g.verticalX != _guide.verticalX ||
                      g.horizontalY != _guide.horizontalY ||
                      g.snap != _guide.snap) {
                    setState(() => _guide = g);
                  }
                },
                onEnd: () {
                  setState(() => _guide = const _GuideState.hidden());
                  widget.onLayoutChanged(_layout);
                },
                onTap: () => widget.onSelect(id),
                onStart: widget.onStart,
                onCollision: widget.onCollision,
                onBoundaryWarning: widget.onBoundaryWarning,
              );
            }),
          ],
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
              child: SizedBox(
                width: scaled.cfg.width,
                height: scaled.cfg.height,
                child: Center(
                  child: GamepadImageHoldButton(
                    label: spec.label,
                    sendValue: spec.sendValue,
                    asset: scaled.cfg.iconAsset ?? '',
                    diameter: math.min(scaled.cfg.width, scaled.cfg.height),
                    showLabel: false,
                    onPressChanged: (id, down) => onPressChanged(id, down),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EditableButton extends StatefulWidget {
  final String id;
  final _ButtonLayout layout;
  final Size panelSize;
  final BtnCfg cfg;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> allLayouts;
  final bool snapToGrid;
  final bool selected;
  final bool externalWarning;
  final bool dimmed;
  final bool locked;
  final ValueChanged<_ButtonLayout> onChanged;
  final ValueChanged<_GuideState>? onGuideChanged;
  final VoidCallback onEnd;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  const _EditableButton({
    required this.id,
    required this.layout,
    required this.panelSize,
    required this.cfg,
    required this.specs,
    required this.allLayouts,
    required this.snapToGrid,
    required this.selected,
    this.externalWarning = false,
    required this.dimmed,
    required this.locked,
    required this.onChanged,
    this.onGuideChanged,
    required this.onEnd,
    required this.onTap,
    this.onStart,
    this.onCollision,
    this.onBoundaryWarning,
  });
  @override
  State<_EditableButton> createState() => _EditableButtonState();
}

class _EditableButtonState extends State<_EditableButton> {
  late Offset _startFocal;
  late _ButtonLayout _startLayout;
  late _ScaledHoldCfg _startScaled;
  static const double _snapThresholdPx = 5.0;
  static const double _nearCollisionPx = 10.0;
  static const double _safeEdgePad = GamepadEditMetrics.safeEdgePad;
  static const double _safeTopEdgePad = GamepadEditMetrics.safeTopEdgePad;
  static const double _edgeWarnThresholdPx =
      GamepadEditMetrics.edgeWarnThresholdPx;
  bool _colliding = false;
  bool _nearCollision = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onTap();
      return;
    }
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
    _startScaled = _scaledHoldCfg(widget.cfg, _startLayout, widget.panelSize);
    _nearEdgeWarning = false;
    widget.onGuideChanged?.call(const _GuideState.hidden());
    widget.onStart?.call();
  }

  (bool, bool) _collisionState(_ButtonLayout movingLayout) {
    final movingScaled = _scaledHoldCfg(
      widget.cfg,
      movingLayout,
      widget.panelSize,
    );
    final movingRadius =
        math.min(movingScaled.cfg.width, movingScaled.cfg.height) / 2;
    final movingCenter = movingScaled.center;
    final currentScaled = _scaledHoldCfg(
      widget.cfg,
      widget.layout,
      widget.panelSize,
    );
    final currentRadius =
        math.min(currentScaled.cfg.width, currentScaled.cfg.height) / 2;
    var near = false;
    for (final entry in widget.allLayouts.entries) {
      final id = entry.key;
      if (id == widget.id) continue;
      final spec = widget.specs[id];
      if (spec == null) continue;
      final otherScaled = _scaledHoldCfg(
        spec.cfg,
        entry.value,
        widget.panelSize,
      );
      final otherRadius =
          math.min(otherScaled.cfg.width, otherScaled.cfg.height) / 2;
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: currentScaled.center,
        fromRadius: currentRadius,
        toCentre: movingCenter,
        toRadius: movingRadius,
        otherCentre: otherScaled.center,
        otherRadius: otherRadius,
      )) {
        return (true, true);
      }
      final gap =
          (movingCenter - otherScaled.center).distance -
          movingRadius -
          otherRadius;
      if (gap < GamepadEditMetrics.minControlGap + _nearCollisionPx) {
        near = true;
      }
    }
    return (false, near);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (widget.locked) return;
    if (!widget.selected) return;
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final halfW = _startScaled.cfg.width / 2;
    final halfH = _startScaled.cfg.height / 2;
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;
    if (widget.snapToGrid) {
      cx = GamepadEditMetrics.snapToGrid(cx);
      cy = GamepadEditMetrics.snapToGrid(cy);
    }
    final centerX = w / 2;
    final centerY = h / 2;
    final snapX = (cx - centerX).abs() <= _snapThresholdPx;
    final snapY = (cy - centerY).abs() <= _snapThresholdPx;
    if (snapX) cx = centerX;
    if (snapY) cy = centerY;
    widget.onGuideChanged?.call(
      _GuideState(
        showVertical: snapX,
        showHorizontal: snapY,
        verticalX: snapX ? 0.5 : null,
        horizontalY: snapY ? 0.5 : null,
        snap: snapX || snapY,
      ),
    );
    final minX = _safeEdgePad + halfW;
    final maxX = w - _safeEdgePad - halfW;
    final minY = _safeTopEdgePad + halfH;
    final maxY = h - _safeEdgePad - halfH;
    final attemptedOutOfBounds =
        cx < minX || cx > maxX || cy < minY || cy > maxY;
    cx = cx.clamp(minX, maxX);
    cy = cy.clamp(minY, maxY);
    final nearEdge =
        attemptedOutOfBounds ||
        ((cx - minX).abs() <= _edgeWarnThresholdPx) ||
        ((maxX - cx).abs() <= _edgeWarnThresholdPx) ||
        ((cy - minY).abs() <= _edgeWarnThresholdPx) ||
        ((maxY - cy).abs() <= _edgeWarnThresholdPx);
    if (nearEdge != _nearEdgeWarning) {
      setState(() => _nearEdgeWarning = nearEdge);
      if (nearEdge) {
        widget.onBoundaryWarning?.call();
      }
    }
    final candidate = _ButtonLayout(cx / w, cy / h, _startLayout.size);
    final collisionState = _collisionState(candidate);
    final collides = collisionState.$1;
    final near = collisionState.$2;
    if (near != _nearCollision) {
      setState(() => _nearCollision = near);
    }
    if (collides) {
      if (!_colliding) {
        HapticFeedback.vibrate();
        setState(() => _colliding = true);
        widget.onCollision?.call();
      }
      return;
    }
    if (_colliding) {
      setState(() => _colliding = false);
    }
    widget.onChanged(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final scaled = _scaledHoldCfg(widget.cfg, widget.layout, widget.panelSize);
    final cx = scaled.center.dx;
    final cy = scaled.center.dy;
    final diameter = math.min(scaled.cfg.width, scaled.cfg.height);
    final showWarning =
        _colliding ||
        _nearCollision ||
        _nearEdgeWarning ||
        widget.externalWarning;
    Widget buildButtonVisual() => Padding(
      padding: EdgeInsets.all(diameter * 0.08),
      child: ClipOval(
        child: Image.asset(
          scaled.cfg.iconAsset ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: _opacity(Colors.red, 0.18),
            alignment: Alignment.center,
            child: Text(
              widget.id.split(':').last,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    final buttonContent = SizedBox(
      width: diameter,
      height: diameter,
      child: GamepadEditSelectionVisual(
        selected: widget.selected,
        dimmed: widget.dimmed,
        warning: showWarning,
        selectionMask: buildButtonVisual(),
        child: buildButtonVisual(),
      ),
    );
    return Positioned(
      left: cx - scaled.cfg.width / 2,
      top: cy - scaled.cfg.height / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: widget.locked ? null : _onScaleStart,
        onScaleUpdate: widget.locked ? null : _onScaleUpdate,
        onScaleEnd: widget.locked
            ? null
            : (_) {
                widget.onGuideChanged?.call(const _GuideState.hidden());
                if (_colliding || _nearCollision || _nearEdgeWarning) {
                  setState(() {
                    _colliding = false;
                    _nearCollision = false;
                    _nearEdgeWarning = false;
                  });
                }
                widget.onEnd();
              },
        onTap: widget.onTap,
        child: SizedBox(
          width: scaled.cfg.width,
          height: scaled.cfg.height,
          child: Center(child: IgnorePointer(child: buttonContent)),
        ),
      ),
    );
  }
}
