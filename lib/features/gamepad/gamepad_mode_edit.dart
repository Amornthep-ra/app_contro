// lib/features/gamepad/gamepad_mode_edit.dart
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
import '../../core/ble/joystick_packet.dart';
import '../../core/ble/control_timing.dart';
import '../../core/ui/gamepad_assets.dart';
import '../../core/ui/control_mode.dart';
import '../../core/ui/control_mode_preference.dart';
import '../../core/ui/gamepad_components.dart';
import '../../core/ui/gamepad_edit_metrics.dart';
import '../../core/widgets/gamepad_edit_grid.dart';
import '../../core/ui/app_assets.dart';
import '../../core/ui/lavender_glass.dart';
import '../../core/widgets/gamepad_appbar_controls.dart';
import '../../core/widgets/control_preset_dialog.dart';
import '../../core/widgets/cat_glass_popup.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/widgets/gamepad_app_bar.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/gamepad_controls_sheet.dart';
import '../../core/widgets/gamepad_edit_shared.dart';
import '../../core/widgets/gamepad_telemetry_chip.dart';
import '../../core/widgets/pairing_code_dialog.dart';
import 'control_mode_settings_page.dart';

const String kIdle = '0';
const String kCmdUp = 'F';
const String kCmdDown = 'B';
const String kCmdLeft = 'L';
const String kCmdRight = 'R';
const String kCmdTriangle = 'T';
const String kCmdCross = 'X';
const String kCmdSquare = 'S';
const String kCmdCircle = 'C';
const double _minBtnSize = 0.18;
const double _maxBtnSize = 0.8;
const double _defaultBtnSize = 0.30;
const double speedRowGap = 6.0;
const Set<String> _defaultLeftActiveIds = {
  'L:up',
  'L:down',
  'L:left',
  'L:right',
};
const Set<String> _defaultRightActiveIds = {
  'R:triangle',
  'R:cross',
  'R:square',
  'R:circle',
};
const Set<String> _supportedEightButtonIds = {
  ..._defaultLeftActiveIds,
  ..._defaultRightActiveIds,
};
Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());
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

class GamepadModeEdit extends StatefulWidget {
  const GamepadModeEdit({super.key, this.acquireControl, this.openOnArrival});

  // Optional transport seam for exercising Start without a robot in tests.
  final Future<int?> Function()? acquireControl;

  /// Set when Settings switched to this mode to edit it or open its saved
  /// layouts (see [ControlPageArguments]).
  final ControlModeOpen? openOnArrival;
  @override
  State<GamepadModeEdit> createState() => _GamepadModeEditState();
}

class _GamepadModeEditState extends State<GamepadModeEdit> {
  static const _prefsLayoutLeft = 'gp8_layout_left';
  static const _prefsLayoutRight = 'gp8_layout_right';
  static const _prefsLayoutAll = 'gp8_layout_all';
  static const _prefsActiveLeft = 'gp8_active_left';
  static const _prefsActiveRight = 'gp8_active_right';
  static const _prefsDriveSpeed = 'gp8_drive_speed';
  static const _prefsTurnSpeed = 'gp8_turn_speed';
  static const _prefsPreset1 = 'gp8_preset_1';
  static const _prefsPreset2 = 'gp8_preset_2';
  static const _prefsPreset3 = 'gp8_preset_3';
  static const _prefsPreset4 = 'gp8_preset_4';
  static const _prefsPreset5 = 'gp8_preset_5';
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
  int _driveSpeed = 50;
  int _turnSpeed = 50;
  bool _speedPanelEditingDrive = true;
  bool _speedPanelOpen = false;

  /// Position of the Speed button in the control toolbar items.
  static const int _speedSlotIndex = 2;
  bool _editMode = false;
  bool _showGrid = false;
  final Set<String> _lockedIds = {};
  bool _menuOpen = false;
  Map<String, GamepadButtonLayout> _layoutAll = {};
  Set<String> _leftActive = Set<String>.from(_defaultLeftActiveIds);
  Set<String> _rightActive = Set<String>.from(_defaultRightActiveIds);
  final Set<String> _pressedIds = {};
  DateTime _lastRejectHapticAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _selectedId;
  String? _editWarningId;
  int _lastBoundaryWarningMs = 0;
  int _lastOverlapWarningMs = 0;
  Size? _panelSize;
  Timer? _editWarningTimer;
  final _history = GamepadEditHistory<_EditSnapshot>();
  Timer? _tick;
  String _lastPacketKey = '';
  int _lastSendMs = 0;
  StreamSubscription<bool>? _bleConnSub;
  int? _bleTrafficOwner;
  bool _startInProgress = false;
  bool _controlStarted = false;
  bool _modeSwitchInProgress = false;
  void _resetInputState() {
    void apply() {
      _up = false;
      _down = false;
      _left = false;
      _right = false;
      _triangle = false;
      _cross = false;
      _square = false;
      _circle = false;
      _command = kIdle;
      _moveCmd = kIdle;
      _actionCmd = '';
      _pressedIds.clear();
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
    if (_up && !_down) btns.add(kBleBtnUp);
    if (_down && !_up) btns.add(kBleBtnDown);
    if (_left && !_right) btns.add(kBleBtnLeft);
    if (_right && !_left) btns.add(kBleBtnRight);
    if (_triangle) btns.add(kBleBtnTriangle);
    if (_cross) btns.add(kBleBtnCross);
    if (_square) btns.add(kBleBtnSquare);
    if (_circle) btns.add(kBleBtnCircle);
    return btns;
  }

  String _packetKey() => '$_command|$_driveSpeed|$_turnSpeed';
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
      final changed = key != _lastPacketKey;
      final active = _command != kIdle;
      final minInterval = active ? kMinActiveMs : kMinIdleMs;
      if (!changed && (now - _lastSendMs) < minInterval) {
        return;
      }
    }
    _lastPacketKey = key;
    _lastSendMs = now;
    unawaited(
      BleManager.instance.sendJoystickBinary(
        packet: JoystickPacket(
          lx: (_driveSpeed / 100.0).clamp(0.0, 1.0),
          ly: 0,
          rx: (_turnSpeed / 100.0).clamp(0.0, 1.0),
          ry: 0,
        ),
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

  bool get _canStartControl => !_startInProgress && !_modeSwitchInProgress;
  Future<void> _startControl() async {
    if (_controlStarted || !_canStartControl) return;
    setState(() => _startInProgress = true);
    final owner =
        await (widget.acquireControl?.call() ??
            BleConnectionCoordinator.instance.acquireControlForStart(
              ownerName: 'gamepad_8',
            ));
    if (!mounted) return;
    if (owner == null) {
      setState(() => _startInProgress = false);
      if (requiresBlePairingCode(
        BleConnectionCoordinator.instance.state.securityState,
      )) {
        final paired = await promptForBlePairingCode(context: context);
        if (paired == true && mounted) {
          await _startControl();
        }
        return;
      }
      showGamepadTopNotice(
        context,
        message: controlStartFailureMessage(
          BleConnectionCoordinator.instance.state,
        ),
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
    unawaited(ControlModePreference.save(LastControlMode.eightButton));
    BleManager.instance.controlSuspendedListenable.addListener(
      _handleControlSuspended,
    );
    unawaited(OrientationUtils.request(AppOrientation.landscape));
    unawaited(_loadSpeedPrefs());
    final layoutsLoaded = _loadLayouts();
    final open = widget.openOnArrival;
    if (open != null) unawaited(_openAfterLoad(layoutsLoaded, open));
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

  Future<void> _switchToPreset({ControlModeOpen? open}) async {
    if (_modeSwitchInProgress || _editMode) return;
    final manager = BleManager.instance;
    final owner = _bleTrafficOwner;
    setState(() {
      _modeSwitchInProgress = true;
      _controlStarted = false;
      _speedPanelOpen = false;
    });
    _resetInputState();
    _stopControlLoop();
    unawaited(ControlModePreference.save(LastControlMode.fourButton));
    _bleTrafficOwner = null;
    if (owner != null) {
      manager.handoffControlForModeSwitch(
        owner: owner,
        source: 'gamepad_precision_to_preset',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed<void, bool>(
      AppRoutes.gamepad4Button,
      result: true,
      arguments: ControlPageArguments(open: open),
    );
  }

  Future<void> _switchToJoystick({ControlModeOpen? open}) async {
    if (_modeSwitchInProgress || _editMode) return;
    final manager = BleManager.instance;
    final owner = _bleTrafficOwner;
    setState(() {
      _modeSwitchInProgress = true;
      _controlStarted = false;
      _speedPanelOpen = false;
    });
    _resetInputState();
    _stopControlLoop();
    unawaited(ControlModePreference.save(LastControlMode.joystick));
    _bleTrafficOwner = null;
    if (owner != null) {
      manager.handoffControlForModeSwitch(
        owner: owner,
        source: 'gamepad_8_to_joystick',
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed<void, bool>(
      AppRoutes.dualJoystickMode1,
      result: true,
      arguments: ControlPageArguments(open: open),
    );
  }

  Future<void> _openSettings() async {
    if (_editMode) return;
    final result = await Navigator.of(context).push<ControlModeSettingsResult>(
      controlModeSettingsRoute(
        mode: ControlMode.eightButton,
        onManageLayouts: _showPresetSheet,
      ),
    );
    if (!mounted || result == null) return;
    switch (result.mode) {
      case ControlMode.eightButton:
        _openFromSettings(result.open);
      case ControlMode.fourButton:
        await _switchToPreset(open: result.open);
      case ControlMode.joystick:
        await _switchToJoystick(open: result.open);
    }
  }

  /// Opens what Settings asked for, on this page.
  void _openFromSettings(ControlModeOpen? open) {
    switch (open) {
      case ControlModeOpen.layoutEditor:
        if (!_editMode) _toggleEdit();
      case ControlModeOpen.savedLayouts:
        unawaited(_showPresetSheet());
      case null:
        break;
    }
  }

  /// Reached by switching from Settings: open the editor or Saved layouts
  /// once the saved layout has loaded and the pad has been laid out.
  Future<void> _openAfterLoad(Future<void> loaded, ControlModeOpen open) async {
    await loaded;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openFromSettings(open);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
                  !_speedPanelOpen,
              anchorX: ControlStartHint.anchorXFor(layout),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _editWarningTimer?.cancel();
    _stopControlLoop();
    _bleConnSub?.cancel();
    BleManager.instance.controlSuspendedListenable.removeListener(
      _handleControlSuspended,
    );
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
        source: 'gamepad_8_emergency_stop',
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
    await _releaseTrafficOwnershipForExit();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadSpeedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final int? drive = prefs.getInt(_prefsDriveSpeed);
    final int? turn = prefs.getInt(_prefsTurnSpeed);
    if (!mounted) return;
    setState(() {
      if (drive != null) _driveSpeed = drive.clamp(0, 100);
      if (turn != null) _turnSpeed = turn.clamp(0, 100);
    });
  }

  Future<void> _saveSpeedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsDriveSpeed, _driveSpeed);
    await prefs.setInt(_prefsTurnSpeed, _turnSpeed);
  }

  void _setDriveSpeed(int value) {
    if (_driveSpeed == value) return;
    setState(() => _driveSpeed = value);
    unawaited(_saveSpeedPrefs());
    _sendBinary(force: true);
  }

  void _setTurnSpeed(int value) {
    if (_turnSpeed == value) return;
    setState(() => _turnSpeed = value);
    unawaited(_saveSpeedPrefs());
    _sendBinary(force: true);
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

  String _defaultPresetName(int slot) => 'Preset $slot';
  static final RegExp _presetAllowedPattern = RegExp(r'^[A-Za-z0-9 _-]+$');
  static final RegExp _presetRequiredChars = RegExp(r'[A-Za-z0-9]');
  String? _validatePresetName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return 'Enter a preset name using letters or numbers.';
    }
    if (!_presetAllowedPattern.hasMatch(value)) {
      return 'Only letters, numbers, spaces, - and _ are allowed.';
    }
    if (!_presetRequiredChars.hasMatch(value)) {
      return 'Use at least one letter or number. Symbols alone are not allowed.';
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
    return showCatPresetNameDialog(
      context: context,
      currentName: currentName,
      validator: _validatePresetName,
    );
  }

  Future<void> _savePreset(int slot, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object>{
      'layout': _encodeLayout(_layoutAll),
      'leftActive': _leftActive.toList(),
      'rightActive': _rightActive.toList(),
      'drive': _driveSpeed,
      'turn': _turnSpeed,
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
      final leftRaw = obj['leftActive'];
      final rightRaw = obj['rightActive'];
      final drive = obj['drive'];
      final turn = obj['turn'];
      // Undo in the editor brings back what was on the pad before.
      _pushHistory();
      _resetInputState();
      if (layoutRaw is Map) {
        _layoutAll = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (leftRaw is List) {
        _leftActive = leftRaw.map((e) => e.toString()).toSet();
      }
      if (rightRaw is List) {
        _rightActive = rightRaw.map((e) => e.toString()).toSet();
      }
      _sanitizeActive();
      _lockedIds.clear();
      _selectedId = null;
      _editWarningId = null;
      if (drive is num) _driveSpeed = drive.round().clamp(0, 100);
      if (turn is num) _turnSpeed = turn.round().clamp(0, 100);
      setState(() {});
      _saveLayout(_prefsLayoutAll, _layoutAll);
      _saveActive(_prefsActiveLeft, _leftActive);
      _saveActive(_prefsActiveRight, _rightActive);
      _saveSpeedPrefs();
      _sendBinary(force: true);
    } catch (_) {}
  }

  Future<void> _showPresetSheet() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    ControlPresetSlot makeSlot(int slot) {
      final raw = prefs.getString(_presetKey(slot)) ?? '';
      return ControlPresetSlot(
        slot: slot,
        name: _readPresetName(raw) ?? _defaultPresetName(slot),
        hasData: raw.isNotEmpty,
      );
    }

    await showControlPresetDialog(
      context: context,
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
          name: trimmed.isEmpty ? _defaultPresetName(slot.slot) : trimmed,
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
          name: _defaultPresetName(slot.slot),
          hasData: false,
        );
      },
    );
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
    final buf = StringBuffer();
    if (_triangle) buf.write(kCmdTriangle);
    if (_cross) buf.write(kCmdCross);
    if (_square) buf.write(kCmdSquare);
    if (_circle) buf.write(kCmdCircle);
    return buf.toString();
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
    if (combined == kIdle && BleManager.instance.isConnected) {
      _sendBinary(force: true);
    }
  }

  Future<void> _loadLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final leftRaw = prefs.getString(_prefsLayoutLeft);
    final rightRaw = prefs.getString(_prefsLayoutRight);
    final allRaw = prefs.getString(_prefsLayoutAll);
    final leftActiveRaw = prefs.getString(_prefsActiveLeft);
    final rightActiveRaw = prefs.getString(_prefsActiveRight);
    if (allRaw != null && allRaw.isNotEmpty) {
      _layoutAll = _decodeLayout(allRaw);
    } else {
      if (leftRaw != null && leftRaw.isNotEmpty) {
        final leftLayout = _decodeLayout(leftRaw);
        _layoutAll.addAll(_remapLayout(leftLayout, 0.0, 0.5));
      }
      if (rightRaw != null && rightRaw.isNotEmpty) {
        final rightLayout = _decodeLayout(rightRaw);
        _layoutAll.addAll(_remapLayout(rightLayout, 0.5, 0.5));
      }
    }
    if (leftActiveRaw != null && leftActiveRaw.isNotEmpty) {
      _leftActive = _decodeIdList(leftActiveRaw);
    } else {
      _leftActive = Set<String>.from(_defaultLeftActiveIds);
    }
    if (rightActiveRaw != null && rightActiveRaw.isNotEmpty) {
      _rightActive = _decodeIdList(rightActiveRaw);
    } else {
      _rightActive = Set<String>.from(_defaultRightActiveIds);
    }
    _sanitizeActive();
    _lockedIds.removeWhere((id) => !_layoutAll.containsKey(id));
    await _saveActive(_prefsActiveLeft, _leftActive);
    await _saveActive(_prefsActiveRight, _rightActive);
    await _saveLayout(_prefsLayoutAll, _layoutAll);
    if (mounted) {
      setState(() {});
    }
  }

  /// Keeps only arrows on the left and face buttons on the right, falls
  /// back to the default pad when nothing is left, and drops layouts of
  /// buttons that are not on the pad.
  void _sanitizeActive() {
    _leftActive = _leftActive
        .where((id) => id.startsWith('L:'))
        .toSet()
        .intersection(_supportedEightButtonIds);
    _rightActive = _rightActive
        .where((id) => id.startsWith('R:'))
        .toSet()
        .intersection(_supportedEightButtonIds);
    if (_leftActive.isEmpty && _rightActive.isEmpty) {
      _leftActive = Set<String>.from(_defaultLeftActiveIds);
      _rightActive = Set<String>.from(_defaultRightActiveIds);
    }
    _layoutAll.removeWhere(
      (k, _) => !_leftActive.contains(k) && !_rightActive.contains(k),
    );
  }

  Future<void> _saveLayout(
    String key,
    Map<String, GamepadButtonLayout> layout,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_encodeLayout(layout)));
  }

  Future<void> _saveActive(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  Map<String, GamepadButtonLayout> _remapLayout(
    Map<String, GamepadButtonLayout> layout,
    double offsetX,
    double scaleX,
  ) {
    final out = <String, GamepadButtonLayout>{};
    layout.forEach((k, v) {
      out[k] = GamepadButtonLayout(offsetX + v.cx * scaleX, v.cy, v.size);
    });
    return out;
  }

  Map<String, GamepadButtonLayout> _decodeLayout(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return {};
      final out = <String, GamepadButtonLayout>{};
      obj.forEach((k, v) {
        final saved = GamepadEditMetrics.readSavedLayout(
          v,
          minSize: _minBtnSize,
          maxSize: _maxBtnSize,
          defaultSize: _defaultBtnSize,
        );
        if (saved != null) {
          out[k.toString()] = GamepadButtonLayout(
            saved.cx,
            saved.cy,
            saved.size,
          );
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, double>> _encodeLayout(
    Map<String, GamepadButtonLayout> layout,
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

  _EditSnapshot _captureSnapshot() {
    return _EditSnapshot(
      layoutAll: cloneGamepadLayout(_layoutAll),
      leftActive: Set<String>.from(_leftActive),
      rightActive: Set<String>.from(_rightActive),
      lockedIds: Set<String>.from(_lockedIds),
      selectedId: _selectedId,
    );
  }

  void _applySnapshot(_EditSnapshot snap) {
    _layoutAll = cloneGamepadLayout(snap.layoutAll);
    _leftActive = Set<String>.from(snap.leftActive);
    _rightActive = Set<String>.from(snap.rightActive);
    _lockedIds
      ..clear()
      ..addAll(snap.lockedIds);
    _selectedId = snap.selectedId;
    _layoutAll.removeWhere(
      (k, _) => !_leftActive.contains(k) && !_rightActive.contains(k),
    );
    _lockedIds.removeWhere((id) => !_layoutAll.containsKey(id));
    _pressedIds.removeWhere((id) => !_layoutAll.containsKey(id));
    _up = false;
    _down = false;
    _left = false;
    _right = false;
    _triangle = false;
    _cross = false;
    _square = false;
    _circle = false;
    _command = kIdle;
  }

  void _persistEditState() {
    _saveLayout(_prefsLayoutAll, _layoutAll);
    _saveActive(_prefsActiveLeft, _leftActive);
    _saveActive(_prefsActiveRight, _rightActive);
  }

  void _pushHistory() => _history.push(_captureSnapshot());

  void _startEditTransform() {
    _pushHistory();
    if (_editWarningId != null) {
      setState(() => _editWarningId = null);
    }
  }

  void _undo() {
    if (!_history.canUndo) return;
    setState(() {
      _applySnapshot(_history.undo(_captureSnapshot()));
    });
    _persistEditState();
  }

  void _redo() {
    if (!_history.canRedo) return;
    setState(() {
      _applySnapshot(_history.redo(_captureSnapshot()));
    });
    _persistEditState();
  }

  void _adjustSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;
    if (_lockedIds.contains(id)) return;
    final panelSize = _panelSize;
    final current = _layoutAll[id];
    if (panelSize == null || current == null) return;
    final w = panelSize.width;
    final h = panelSize.height;
    final s = GamepadEditMetrics.panelUnit(panelSize);
    final minSize = GamepadEditMetrics.minSizeFactor(_minBtnSize, s);
    final nextSize = (current.size + delta).clamp(minSize, _maxBtnSize);
    if (delta < 0 ? nextSize >= current.size : nextSize <= current.size) {
      _showSizeLimit(delta > 0);
      _flashEditWarning(id);
      return;
    }
    double px(double size) => GamepadEditMetrics.sizePx(panelSize, size);
    final sizePx = px(nextSize);
    final half = sizePx / 2;
    const safeEdgePad = GamepadEditMetrics.safeEdgePad;
    const safeTopPad = GamepadEditMetrics.safeTopEdgePad;
    final minX = safeEdgePad + half;
    final maxX = w - safeEdgePad - half;
    final minY = safeTopPad + half;
    final maxY = h - safeEdgePad - half;
    final cx = current.cx * w;
    final cy = current.cy * h;
    // Shrinking is always allowed: it is how a control that an older layout
    // or another screen size left past the edge gets fixed.
    final growing = nextSize > current.size;
    if (growing && (cx < minX || cx > maxX || cy < minY || cy > maxY)) {
      HapticFeedback.vibrate();
      setState(() => _editWarningId = id);
      _showBoundaryWarning();
      return;
    }
    var collides = false;
    for (final entry in _layoutAll.entries) {
      if (entry.key == id) continue;
      if (!entry.key.startsWith('L:') && !entry.key.startsWith('R:')) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherSizePx = px(other.size);
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(cx, cy),
        fromRadius: px(current.size) / 2,
        toCentre: Offset(cx, cy),
        toRadius: sizePx / 2,
        otherCentre: Offset(ox, oy),
        otherRadius: otherSizePx / 2,
      )) {
        collides = true;
        break;
      }
    }
    if (collides) {
      HapticFeedback.vibrate();
      setState(() => _editWarningId = id);
      _showOverlapWarning();
      return;
    }
    _pushHistory();
    setState(() {
      final nextLayout = Map<String, GamepadButtonLayout>.from(_layoutAll);
      nextLayout[id] = GamepadButtonLayout(cx / w, cy / h, nextSize);
      _layoutAll = nextLayout;
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
    final msg = atMax ? 'Max size reached' : 'Min size reached';
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

  void _resetLayouts() async {
    _pushHistory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayoutAll);
    await prefs.remove('${_prefsLayoutAll}_start_stop');
    await prefs.remove(_prefsLayoutLeft);
    await prefs.remove(_prefsLayoutRight);
    await prefs.remove(_prefsActiveLeft);
    await prefs.remove(_prefsActiveRight);
    setState(() {
      _layoutAll = {};
      _leftActive = Set<String>.from(_defaultLeftActiveIds);
      _rightActive = Set<String>.from(_defaultRightActiveIds);
      _lockedIds.clear();
      _pressedIds.clear();
      _selectedId = null;
      _editWarningId = null;
      _up = false;
      _down = false;
      _left = false;
      _right = false;
      _triangle = false;
      _cross = false;
      _square = false;
      _circle = false;
    });
    _updateCommand();
  }

  void _toggleActive(String id, bool isLeft) {
    _pushHistory();
    setState(() {
      if (isLeft) {
        if (_leftActive.contains(id)) {
          _leftActive.remove(id);
          _layoutAll.remove(id);
          _pressedIds.remove(id);
          _lockedIds.remove(id);
          if (_selectedId == id) _selectedId = null;
          if (id == 'L:up') _up = false;
          if (id == 'L:down') _down = false;
          if (id == 'L:left') _left = false;
          if (id == 'L:right') _right = false;
        } else {
          _pinActiveLayouts();
          _leftActive.add(id);
          _placeOnFreeSpot(id);
        }
        _saveActive(_prefsActiveLeft, _leftActive);
      } else {
        if (_rightActive.contains(id)) {
          _rightActive.remove(id);
          _layoutAll.remove(id);
          _pressedIds.remove(id);
          _lockedIds.remove(id);
          if (_selectedId == id) _selectedId = null;
          if (id == 'R:triangle') _triangle = false;
          if (id == 'R:cross') _cross = false;
          if (id == 'R:square') _square = false;
          if (id == 'R:circle') _circle = false;
        } else {
          _pinActiveLayouts();
          _rightActive.add(id);
          _placeOnFreeSpot(id);
        }
        _saveActive(_prefsActiveRight, _rightActive);
      }
    });
  }

  void _removeSelected() {
    final id = _selectedId;
    if (id == null) return;
    _toggleActive(id, id.startsWith('L:'));
  }

  /// Saves where the buttons already on the pad are: their default spots
  /// depend on which buttons are active, and adding one must not move them.
  void _pinActiveLayouts() {
    final panel = _panelSize;
    if (panel == null) return;
    final ids = _allActiveIds();
    final defaults = _defaultLayoutForIds(panel, ids);
    final next = Map<String, GamepadButtonLayout>.from(_layoutAll);
    for (final id in ids) {
      final def = defaults[id];
      if (def != null) next.putIfAbsent(id, () => def);
    }
    _layoutAll = next;
  }

  /// Gives a button that was just added the free spot nearest to its
  /// default one, so it never lands on a button that was moved there.
  void _placeOnFreeSpot(String id) {
    final panel = _panelSize;
    if (panel == null) return;
    final ids = _allActiveIds();
    final def = _defaultLayoutForIds(panel, ids)[id];
    if (def == null) return;
    final w = panel.width;
    final h = panel.height;
    double radius(double size) => GamepadEditMetrics.sizePx(panel, size) / 2;
    final r = radius(def.size);
    final spot = GamepadEditMetrics.freeSpotFor(
      preferred: Offset(def.cx * w, def.cy * h),
      radius: r,
      centreArea: Rect.fromLTRB(
        GamepadEditMetrics.safeEdgePad + r,
        GamepadEditMetrics.safeTopEdgePad + r,
        w - GamepadEditMetrics.safeEdgePad - r,
        h - GamepadEditMetrics.safeEdgePad - r,
      ),
      others: [
        for (final other in ids)
          if (other != id && _layoutAll[other] != null)
            (
              Offset(_layoutAll[other]!.cx * w, _layoutAll[other]!.cy * h),
              radius(_layoutAll[other]!.size),
            ),
      ],
    );
    _layoutAll = {
      ..._layoutAll,
      id: GamepadButtonLayout(spot.dx / w, spot.dy / h, def.size),
    };
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  Future<void> _showEditMenuAndroid() async {
    if (_menuOpen || !mounted) return;
    _menuOpen = true;
    try {
      await showGamepadControlsSheet(
        context: context,
        groups: const [
          GamepadControlGroup(
            title: 'Left pad',
            choices: [
              GamepadControlChoice(
                id: 'L:up',
                label: 'Up',
                asset: kGamepad8AssetUp,
              ),
              GamepadControlChoice(
                id: 'L:down',
                label: 'Down',
                asset: kGamepad8AssetDown,
              ),
              GamepadControlChoice(
                id: 'L:left',
                label: 'Left',
                asset: kGamepad8AssetLeft,
              ),
              GamepadControlChoice(
                id: 'L:right',
                label: 'Right',
                asset: kGamepad8AssetRight,
              ),
            ],
          ),
          GamepadControlGroup(
            title: 'Right pad',
            choices: [
              GamepadControlChoice(
                id: 'R:triangle',
                label: 'Triangle',
                asset: kGamepad8AssetTriangle,
              ),
              GamepadControlChoice(
                id: 'R:cross',
                label: 'Cross',
                asset: kGamepad8AssetCross,
              ),
              GamepadControlChoice(
                id: 'R:square',
                label: 'Square',
                asset: kGamepad8AssetSquare,
              ),
              GamepadControlChoice(
                id: 'R:circle',
                label: 'Circle',
                asset: kGamepad8AssetCircle,
              ),
            ],
          ),
        ],
        isActive: (id) => _leftActive.contains(id) || _rightActive.contains(id),
        onToggle: (id) {
          gamepadBuzz();
          _toggleActive(id, id.startsWith('L:'));
        },
      );
    } finally {
      _menuOpen = false;
    }
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

  void _showBoundaryWarning() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBoundaryWarningMs < 900) return;
    _lastBoundaryWarningMs = now;
    showGamepadTopNotice(
      context,
      message: 'Buttons must stay inside the safe zone.',
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _showOverlapWarning() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastOverlapWarningMs < 900) return;
    _lastOverlapWarningMs = now;
    showGamepadTopNotice(
      context,
      message: 'Buttons cannot overlap.',
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  Widget _appBarBadge(String label, String value) {
    IconData icon;
    Color accent;
    switch (label) {
      case 'SPD':
        icon = Icons.speed_rounded;
        accent = const Color(0xFF38BDF8);
        break;
      case 'CMD':
        icon = Icons.tune_rounded;
        accent = const Color(0xFFF59E0B);
        break;
      case 'DRV':
        icon = Icons.sports_motorsports_rounded;
        accent = const Color(0xFF22C55E);
        break;
      case 'TRN':
        icon = Icons.rotate_right_rounded;
        accent = const Color(0xFF38BDF8);
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

  Widget _speedToggle() {
    return GamepadSpeedTogglePill(
      expanded: _speedPanelOpen,
      accent: _barAccent('SPD'),
      label: 'Speed',
      iconAsset: AppAssets.controlSpeed,
      onTap: () {
        setState(() => _speedPanelOpen = !_speedPanelOpen);
      },
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

  Widget _buildCenteredEditAppBar() {
    final selectedId = _selectedId;
    final hasSelection = selectedId != null;
    final selectedLocked =
        selectedId != null && _lockedIds.contains(selectedId);
    final sizeEnabled = hasSelection && !selectedLocked;
    VoidCallback withBuzz(VoidCallback action) {
      return () {
        gamepadBuzz();
        action();
      };
    }

    return GamepadCenteredToolbar(
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      singleRow: true,
      children: [
        _toolIconPill(
          icon: Icons.done_rounded,
          label: 'Done',
          accent: const Color(0xFF60A5FA),
          onTap: withBuzz(_toggleEdit),
        ),
        // Show or hide controls, e.g. bring back one that was deleted
        // without resetting the whole layout.
        _toolIconPill(
          key: const ValueKey('gamepad-edit-controls'),
          icon: Icons.videogame_asset_outlined,
          label: 'Buttons',
          accent: const Color(0xFF34D399),
          onTap: withBuzz(_showEditMenuAndroid),
        ),
        _toolIconPill(
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          label: gamepadEditLockLabel(locked: selectedLocked),
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? withBuzz(_toggleSelectedLock) : null,
        ),
        _toolIconPill(
          icon: Icons.remove,
          label: 'Decrease size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled
              ? withBuzz(() => _adjustSelectedSize(-0.05))
              : null,
        ),
        _toolIconPill(
          icon: Icons.add,
          label: 'Increase size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? withBuzz(() => _adjustSelectedSize(0.05)) : null,
        ),
        _toolIconPill(
          icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          label: 'Grid',
          accent: const Color(0xFF38BDF8),
          active: _showGrid,
          onTap: withBuzz(() => setState(() => _showGrid = !_showGrid)),
        ),
        _toolIconPill(
          icon: Icons.undo_rounded,
          label: 'Undo',
          accent: const Color(0xFFA78BFA),
          onTap: _history.canUndo ? withBuzz(_undo) : null,
        ),
        _toolIconPill(
          icon: Icons.redo_rounded,
          label: 'Redo',
          accent: const Color(0xFFA78BFA),
          onTap: _history.canRedo ? withBuzz(_redo) : null,
        ),
        _toolIconPill(
          icon: Icons.restart_alt,
          label: 'Reset',
          accent: const Color(0xFFF59E0B),
          onTap: withBuzz(_resetLayouts),
        ),
        _toolIconPill(
          icon: Icons.delete_outline,
          label: 'Delete',
          accent: const Color(0xFFF87171),
          onTap: hasSelection ? withBuzz(_removeSelected) : null,
        ),
      ],
    );
  }

  void _adjustSpeed({required bool drive, required int delta}) {
    final current = drive ? _driveSpeed : _turnSpeed;
    final next = (current + delta).clamp(0, 100).round();
    if (drive) {
      _setDriveSpeed(next);
    } else {
      _setTurnSpeed(next);
    }
  }

  /// DRV / TRN panel. It floats under the Speed button over the pad, so
  /// opening it never moves or resizes the drive buttons.
  Widget _buildSpeedPanelOverlay(GamepadControlLayout layout) {
    final availableWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        24;
    final panelWidth = math.min(availableWidth, 560.0);
    final compact = panelWidth < 360;
    final editingDrive = _speedPanelEditingDrive;
    final activeValue = editingDrive ? _driveSpeed : _turnSpeed;
    return GamepadToolbarDropdown(
      layout: layout,
      slotIndex: _speedSlotIndex,
      panelWidth: panelWidth,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !_speedPanelOpen || _editMode
            ? const SizedBox.shrink()
            : Container(
                width: panelWidth,
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Lavender Glass panel (light), matching Home and Settings.
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.90),
                      const Color(0xFFF1EBFF).withValues(alpha: 0.88),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: LavenderPalette.violetDeep.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildSpeedTarget(
                      label: 'DRV',
                      caption: 'Drive',
                      value: _driveSpeed,
                      asset: AppAssets.speedValueCat,
                      accent: const Color(0xFF22C55E),
                      selected: editingDrive,
                      compact: compact,
                      onTap: () =>
                          setState(() => _speedPanelEditingDrive = true),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildSpeedStepCat(
                            asset: AppAssets.speedPanelDash,
                            tooltip: 'Decrease by 5',
                            onTap: () =>
                                _adjustSpeed(drive: editingDrive, delta: -5),
                          ),
                          Expanded(
                            child: _buildGradientSpeedSlider(
                              value: activeValue,
                              onChanged: (value) {
                                if (editingDrive) {
                                  _setDriveSpeed(value);
                                } else {
                                  _setTurnSpeed(value);
                                }
                              },
                            ),
                          ),
                          _buildSpeedStepCat(
                            asset: AppAssets.speedPanelPlus,
                            tooltip: 'Increase by 5',
                            onTap: () =>
                                _adjustSpeed(drive: editingDrive, delta: 5),
                          ),
                        ],
                      ),
                    ),
                    _buildSpeedTarget(
                      label: 'TRN',
                      caption: 'Turn',
                      value: _turnSpeed,
                      asset: AppAssets.speedValueCat,
                      accent: const Color(0xFF38BDF8),
                      selected: !editingDrive,
                      compact: compact,
                      onTap: () =>
                          setState(() => _speedPanelEditingDrive = false),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGradientSpeedSlider({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalInset = 12.0;
        const thumbSize = 26.0;
        final trackWidth = math.max(
          0.0,
          constraints.maxWidth - (horizontalInset * 2),
        );
        final thumbLeft =
            horizontalInset + (trackWidth * value / 100) - (thumbSize / 2);
        return Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE878FF), Color(0xFF61E3FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8FE9FF).withAlpha(105),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    21,
                    (_) => Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: LavenderPalette.violet.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.transparent,
                overlayColor: Colors.transparent,
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (next) => onChanged(next.round()),
              ),
            ),
            Positioned(
              left: thumbLeft,
              child: IgnorePointer(
                child: SizedBox(
                  width: thumbSize,
                  height: thumbSize,
                  child: OverflowBox(
                    maxWidth: 64,
                    maxHeight: 64,
                    child: Image.asset(
                      AppAssets.speedSliderThumb,
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeedTarget({
    required String label,
    required String caption,
    required int value,
    required String asset,
    required Color accent,
    required bool selected,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $value%',
      child: Tooltip(
        message: '$label $value%',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: SizedBox(
              width: compact ? 48 : 66,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: compact ? 32 : 40,
                    height: compact ? 32 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? accent.withAlpha(24)
                          : Colors.transparent,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: accent.withAlpha(190),
                                blurRadius: 14,
                              ),
                            ]
                          : const [],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: selected ? 1 : 0.52,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: compact ? 76 : 98,
                        height: compact ? 76 : 98,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.tune_rounded, size: 32, color: accent),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: compact ? 21 : 20,
                    child: Text(
                      '$value%',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withAlpha(135),
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF12082F).withAlpha(220),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? Color.lerp(accent, LavenderPalette.ink, 0.35)
                            : LavenderPalette.inkMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -8,
                    child: Text(
                      caption,
                      style: TextStyle(
                        color: selected
                            ? LavenderPalette.inkSoft
                            : LavenderPalette.inkMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildSpeedStepCat({
    required String asset,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDimOverlay() {
    return const SizedBox.shrink();
  }

  void _sendLoop() {
    _sendBinary();
  }

  bool _applyPressLimit(String id, bool isDown) {
    if (isDown) {
      if (_pressedIds.length >= 2 && !_pressedIds.contains(id)) {
        final now = DateTime.now();
        if (now.difference(_lastRejectHapticAt) >
            const Duration(milliseconds: 200)) {
          HapticFeedback.selectionClick();
          _lastRejectHapticAt = now;
        }
        return false;
      }
      _pressedIds.add(id);
    } else {
      _pressedIds.remove(id);
    }
    return true;
  }

  void _onLeftPress(String id, bool isDown) {
    if (!_applyPressLimit(id, isDown)) {
      return;
    }
    if (id == kCmdUp) _up = isDown;
    if (id == kCmdDown) _down = isDown;
    if (id == kCmdLeft) _left = isDown;
    if (id == kCmdRight) _right = isDown;
    _updateCommand();
  }

  void _onRightPress(String id, bool isDown) {
    if (!_applyPressLimit(id, isDown)) {
      return;
    }
    if (id == kCmdTriangle) _triangle = isDown;
    if (id == kCmdCross) _cross = isDown;
    if (id == kCmdSquare) _square = isDown;
    if (id == kCmdCircle) _circle = isDown;
    _updateCommand();
  }

  void _onAnyPress(String id, bool isDown) {
    if (id == kCmdUp || id == kCmdDown || id == kCmdLeft || id == kCmdRight) {
      _onLeftPress(id, isDown);
      return;
    }
    _onRightPress(id, isDown);
  }

  List<String> _allActiveIds() {
    return [..._leftActive, ..._rightActive];
  }

  @override
  Widget build(BuildContext context) {
    final playLayout = GamepadControlLayout.measure(context, [
      '',
      '',
      '@speed:Speed',
      'CMD = 255 | DRV = 100% | TRN = 100%',
      '@ble',
      '',
    ], leadingCount: 2);
    final controlLayout = _editMode ? null : playLayout;
    final media = MediaQuery.of(context);
    final appBarMetrics = GamepadAppBarMetrics.forWidth(media.size.width);
    final textScaleFactor = media.textScaler.scale(1);
    // The editor's pad matches the driving pad's size exactly.
    final editorTopInset = _editMode
        ? gamepadEditorTopInset(
            playLayout: playLayout,
            viewportWidth: media.size.width - media.padding.horizontal,
            textScaleFactor: textScaleFactor,
          )
        : 0.0;
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
              toolbarItemCount: _editMode ? 10 : null,
              singleRowToolbar: _editMode,
              useGlassBackground: false,
              glassOpacity: 0.18,
              toolbarContent: _editMode ? _buildCenteredEditAppBar() : null,
              leading: _editMode ? null : _buildAppBarBackButton(),
              startStop: _editMode ? null : _buildToolbarStartStop(),
              speedToggle: _editMode ? null : _speedToggle(),
              cmdChip: _editMode
                  ? null
                  : SizedBox(
                      child: _appBarBadge(
                        'CMD',
                        '= ${_commandByteLabel()} | DRV = $_driveSpeed% | TRN = $_turnSpeed%',
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
                        message: 'Use Emergency Stop before managing BLE.',
                        style: GamepadNoticeStyle.ble,
                      ),
                    ),
              actionsBuilder: _editMode
                  ? null
                  : (gap) {
                      return GamepadAppBarActionGroup(
                        gap: gap,
                        items: [
                          GamepadAppBarActionItem(
                            label: 'Settings',
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
                  child: Stack(
                    children: [
                      if (_editMode)
                        GamepadEditHint(hasSelection: _selectedId != null),
                      LayoutBuilder(
                        builder: (context, cons) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              8,
                              4 + editorTopInset,
                              8,
                              8,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ControlInputGate(
                                    started: _controlStarted,
                                    editing: _editMode,
                                    suspended: BleManager
                                        .instance
                                        .controlSuspendedListenable,
                                    onLockedTap: _showStartFirstNotice,
                                    child: _editMode
                                        ? _EditablePadPanel(
                                            ids: _allActiveIds(),
                                            specs: const {
                                              'L:up': _BtnSpec(
                                                'Up',
                                                kCmdUp,
                                                kGamepad8AssetUp,
                                              ),
                                              'L:down': _BtnSpec(
                                                'Down',
                                                kCmdDown,
                                                kGamepad8AssetDown,
                                              ),
                                              'L:left': _BtnSpec(
                                                'Left',
                                                kCmdLeft,
                                                kGamepad8AssetLeft,
                                              ),
                                              'L:right': _BtnSpec(
                                                'Right',
                                                kCmdRight,
                                                kGamepad8AssetRight,
                                              ),
                                              'R:triangle': _BtnSpec(
                                                'Triangle',
                                                kCmdTriangle,
                                                kGamepad8AssetTriangle,
                                              ),
                                              'R:cross': _BtnSpec(
                                                'Cross',
                                                kCmdCross,
                                                kGamepad8AssetCross,
                                              ),
                                              'R:square': _BtnSpec(
                                                'Square',
                                                kCmdSquare,
                                                kGamepad8AssetSquare,
                                              ),
                                              'R:circle': _BtnSpec(
                                                'Circle',
                                                kCmdCircle,
                                                kGamepad8AssetCircle,
                                              ),
                                            },
                                            layout: _layoutAll,
                                            onLayoutChanged: (next) {
                                              setState(() {
                                                _layoutAll = next;
                                                _editWarningId = null;
                                              });
                                              _saveLayout(
                                                _prefsLayoutAll,
                                                _layoutAll,
                                              );
                                            },
                                            selectedId: _selectedId,
                                            lockedIds: _lockedIds,
                                            snapToGrid: _showGrid,
                                            onSelect: _selectButton,
                                            onPanelSize: (size) {
                                              _panelSize = size;
                                            },
                                            onStart: _startEditTransform,
                                            onCollision: _showOverlapWarning,
                                            onBoundaryWarning:
                                                _showBoundaryWarning,
                                            warningId: _editWarningId,
                                          )
                                        : _LayoutPadPanel(
                                            ids: _allActiveIds(),
                                            specs: const {
                                              'L:up': _BtnSpec(
                                                'Up',
                                                kCmdUp,
                                                kGamepad8AssetUp,
                                              ),
                                              'L:down': _BtnSpec(
                                                'Down',
                                                kCmdDown,
                                                kGamepad8AssetDown,
                                              ),
                                              'L:left': _BtnSpec(
                                                'Left',
                                                kCmdLeft,
                                                kGamepad8AssetLeft,
                                              ),
                                              'L:right': _BtnSpec(
                                                'Right',
                                                kCmdRight,
                                                kGamepad8AssetRight,
                                              ),
                                              'R:triangle': _BtnSpec(
                                                'Triangle',
                                                kCmdTriangle,
                                                kGamepad8AssetTriangle,
                                              ),
                                              'R:cross': _BtnSpec(
                                                'Cross',
                                                kCmdCross,
                                                kGamepad8AssetCross,
                                              ),
                                              'R:square': _BtnSpec(
                                                'Square',
                                                kCmdSquare,
                                                kGamepad8AssetSquare,
                                              ),
                                              'R:circle': _BtnSpec(
                                                'Circle',
                                                kCmdCircle,
                                                kGamepad8AssetCircle,
                                              ),
                                            },
                                            layout: _layoutAll,
                                            onPressChanged: _onAnyPress,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildDimOverlay(),

                if (controlLayout != null) _buildStartHint(controlLayout),
              ],
            ),
          ),
          if (controlLayout != null) _buildSpeedPanelOverlay(controlLayout),
        ],
      ),
    );
  }
}

class _BtnSpec {
  final String label, sendValue, asset;
  const _BtnSpec(this.label, this.sendValue, this.asset);
}

Map<String, GamepadButtonLayout> _defaultLayoutForIds(
  Size size,
  List<String> ids,
) {
  final w = size.width;
  final h = size.height;
  final s = GamepadEditMetrics.panelUnit(size);
  final btn = s * 0.30;
  final gap = s * 0.08;
  final frame = GamepadEditMetrics.defaultLayoutFrame(size);
  final cy = frame.center.dy;
  GamepadButtonLayout make(double x, double y) {
    return GamepadButtonLayout(x / w, y / h, btn / s);
  }

  final suffixMap = <String, String>{};
  for (final id in ids) {
    final parts = id.split(':');
    final key = parts.length > 1 ? parts[1] : id;
    suffixMap[key] = id;
  }
  final out = <String, GamepadButtonLayout>{};
  final hasMove =
      suffixMap.containsKey('up') ||
      suffixMap.containsKey('down') ||
      suffixMap.containsKey('left') ||
      suffixMap.containsKey('right');
  final hasAction =
      suffixMap.containsKey('triangle') ||
      suffixMap.containsKey('cross') ||
      suffixMap.containsKey('square') ||
      suffixMap.containsKey('circle');
  if (hasMove) {
    final cxLeft = frame.left + frame.width * 0.20;
    if (suffixMap.containsKey('up')) {
      out[suffixMap['up']!] = make(cxLeft, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('down')) {
      out[suffixMap['down']!] = make(cxLeft, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('left')) {
      out[suffixMap['left']!] = make(cxLeft - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('right')) {
      out[suffixMap['right']!] = make(cxLeft + gap + btn / 2, cy);
    }
  }
  if (hasAction) {
    final cxRight = frame.left + frame.width * 0.80;
    if (suffixMap.containsKey('triangle')) {
      out[suffixMap['triangle']!] = make(cxRight, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('cross')) {
      out[suffixMap['cross']!] = make(cxRight, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('square')) {
      out[suffixMap['square']!] = make(cxRight - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('circle')) {
      out[suffixMap['circle']!] = make(cxRight + gap + btn / 2, cy);
    }
  }
  return out;
}

/// [layout] with the buttons in [ids] moved, where needed, to fit inside
/// the pad's safe margins without overlapping (see
/// [GamepadEditMetrics.fitLayout]). Returns [layout] itself when nothing
/// had to move.
Map<String, GamepadButtonLayout> _fitLayoutToPanel(
  Size panel,
  List<String> ids,
  Map<String, GamepadButtonLayout> layout,
) {
  final w = panel.width;
  final h = panel.height;
  final placed = [
    for (final id in ids)
      if (layout[id] != null) (id, layout[id]!),
  ];
  final fitted = GamepadEditMetrics.fitLayout(
    panel: panel,
    pad: const EdgeInsets.fromLTRB(
      GamepadEditMetrics.safeEdgePad,
      GamepadEditMetrics.safeTopEdgePad,
      GamepadEditMetrics.safeEdgePad,
      GamepadEditMetrics.safeEdgePad,
    ),
    controls: [
      for (final (_, l) in placed)
        (
          Offset(l.cx * w, l.cy * h),
          GamepadEditMetrics.sizePx(panel, l.size) / 2,
        ),
    ],
  );
  Map<String, GamepadButtonLayout>? out;
  for (var i = 0; i < placed.length; i++) {
    final (id, l) = placed[i];
    final spot = fitted[i];
    if ((spot - Offset(l.cx * w, l.cy * h)).distance <= 0.5) continue;
    out ??= Map<String, GamepadButtonLayout>.from(layout);
    out[id] = l.copyWith(cx: spot.dx / w, cy: spot.dy / h);
  }
  return out ?? layout;
}

class _EditSnapshot {
  final Map<String, GamepadButtonLayout> layoutAll;
  final Set<String> leftActive;
  final Set<String> rightActive;
  final Set<String> lockedIds;
  final String? selectedId;
  const _EditSnapshot({
    required this.layoutAll,
    required this.leftActive,
    required this.rightActive,
    required this.lockedIds,
    required this.selectedId,
  });
}

class _EditablePadPanel extends StatefulWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, GamepadButtonLayout> layout;
  final ValueChanged<Map<String, GamepadButtonLayout>> onLayoutChanged;
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
    this.warningId,
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
  late Map<String, GamepadButtonLayout> _layout;
  bool _initialized = false;
  bool _showGuideX = false;
  bool _showGuideY = false;
  bool _guideSnapActive = false;
  double? _guideX;
  double? _guideY;
  @override
  void initState() {
    super.initState();
    _layout = Map<String, GamepadButtonLayout>.from(widget.layout);
  }

  @override
  void didUpdateWidget(covariant _EditablePadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layout, widget.layout)) {
      _layout = Map<String, GamepadButtonLayout>.from(widget.layout);
    }
    if (oldWidget.selectedId != widget.selectedId) {
      _resetGuide(notify: false);
    }
  }

  void _resetGuide({bool notify = true}) {
    if (!_showGuideX &&
        !_showGuideY &&
        !_guideSnapActive &&
        _guideX == null &&
        _guideY == null) {
      return;
    }
    void clearState() {
      _showGuideX = false;
      _showGuideY = false;
      _guideSnapActive = false;
      _guideX = null;
      _guideY = null;
    }

    if (notify) {
      setState(clearState);
    } else {
      clearState();
    }
  }

  void _handleGuideChanged(GamepadEditGuideState guide) {
    final nextShowX = guide.showVertical;
    final nextShowY = guide.showHorizontal;
    final nextSnap = guide.snap && (nextShowX || nextShowY);
    final nextX = nextShowX ? guide.verticalX : null;
    final nextY = nextShowY ? guide.horizontalY : null;
    if (_showGuideX == nextShowX &&
        _showGuideY == nextShowY &&
        _guideSnapActive == nextSnap &&
        _guideX == nextX &&
        _guideY == nextY) {
      return;
    }
    setState(() {
      _showGuideX = nextShowX;
      _showGuideY = nextShowY;
      _guideSnapActive = nextSnap;
      _guideX = nextX;
      _guideY = nextY;
    });
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
        final defaults = _defaultLayoutForIds(size, widget.ids);
        // Buttons the user placed keep their spots when fitting below.
        final fitOrder = GamepadEditMetrics.savedFirst(
          widget.ids,
          _layout.containsKey,
        );
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
        // A layout from another screen size can sit past the edge or on
        // top of another button: show and save it moved into place.
        final fitted = _fitLayoutToPanel(size, fitOrder, _layout);
        if (!identical(fitted, _layout)) {
          fitted.forEach((id, layout) => _layout[id] = layout);
          changed = true;
        }
        if (changed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {});
            widget.onLayoutChanged(_layout);
          });
        }
        return Stack(
          children: [
            // Same box the buttons are placed and snapped in.
            if (widget.snapToGrid)
              const Positioned.fill(child: GamepadEditGrid()),
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
                asset: spec.asset,
                allLayouts: _layout,
                selected: widget.selectedId == id,
                externalWarning: widget.warningId == id,
                dimmed: widget.selectedId != null && widget.selectedId != id,
                locked: widget.lockedIds.contains(id),
                snapToGrid: widget.snapToGrid,
                onChanged: (next) {
                  setState(() => _layout[id] = next);
                },
                onGuideChanged: _handleGuideChanged,
                onEnd: () {
                  _resetGuide();
                  widget.onLayoutChanged(_layout);
                },
                onTap: () => widget.onSelect(id),
                onStart: widget.onStart,
                onCollision: widget.onCollision,
                onBoundaryWarning: widget.onBoundaryWarning,
              );
            }),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: GamepadEditAlignmentGuidesPainter(
                    showVertical: _showGuideX,
                    showHorizontal: _showGuideY,
                    verticalX: _guideX,
                    horizontalY: _guideY,
                    color: _guideSnapActive
                        ? _opacity(const Color(0xFFFACC15), 0.95)
                        : _opacity(const Color(0xFFFACC15), 0.60),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LayoutPadPanel extends StatelessWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, GamepadButtonLayout> layout;
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
        final defaults = _defaultLayoutForIds(size, ids);
        final effective = _fitLayoutToPanel(
          size,
          GamepadEditMetrics.savedFirst(ids, layout.containsKey),
          {...defaults, ...layout},
        );
        final w = size.width;
        final h = size.height;
        return Stack(
          children: ids.map((id) {
            final spec = specs[id];
            final l = effective[id];
            if (spec == null || l == null) {
              return const SizedBox.shrink();
            }
            final d = GamepadEditMetrics.sizePx(size, l.size);
            final cx = l.cx * w;
            final cy = l.cy * h;
            return Positioned(
              left: cx - d / 2,
              top: cy - d / 2,
              child: GamepadImageHoldButton(
                label: spec.label,
                sendValue: spec.sendValue,
                asset: spec.asset,
                diameter: d,
                showLabel: false,
                lightImpactBeforeBuzz: true,
                onPressChanged: onPressChanged,
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
  final GamepadButtonLayout layout;
  final Size panelSize;
  final String asset;
  final Map<String, GamepadButtonLayout> allLayouts;
  final bool selected;
  final bool externalWarning;
  final bool dimmed;
  final bool locked;
  final bool snapToGrid;
  final ValueChanged<GamepadButtonLayout> onChanged;
  final ValueChanged<GamepadEditGuideState>? onGuideChanged;
  final VoidCallback onEnd;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  const _EditableButton({
    required this.id,
    required this.layout,
    required this.panelSize,
    required this.asset,
    required this.allLayouts,
    required this.selected,
    this.externalWarning = false,
    required this.dimmed,
    required this.locked,
    required this.snapToGrid,
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
  Offset _startFocal = Offset.zero;
  GamepadButtonLayout _startLayout = const GamepadButtonLayout(0, 0, 0);

  /// True only while a drag that began on the already-selected button is
  /// running. A touch on an unselected button just selects it; the rest of
  /// that gesture must not move it, even though it is selected by then.
  bool _gestureActive = false;
  static const double _safeEdgePad = GamepadEditMetrics.safeEdgePad;
  static const double _safeTopEdgePad = GamepadEditMetrics.safeTopEdgePad;
  static const double _snapThresholdPx = 5.0;
  static const double _edgeWarnThresholdPx =
      GamepadEditMetrics.edgeWarnThresholdPx;
  bool _dragging = false;
  bool _colliding = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    _gestureActive = false;
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onTap();
      return;
    }
    _gestureActive = true;
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
    _dragging = false;
    _nearEdgeWarning = false;
    widget.onGuideChanged?.call(const GamepadEditGuideState.hidden());
    widget.onStart?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_gestureActive || widget.locked || !widget.selected) return;
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final s = GamepadEditMetrics.panelUnit(widget.panelSize);
    double px(double size) => GamepadEditMetrics.sizePx(widget.panelSize, size);
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    final moved = dx.abs() > 1 || dy.abs() > 1;
    if (moved && !_dragging) {
      setState(() => _dragging = true);
    }
    // A plain drag (scale 1) keeps the size; pinching stays within the
    // editor's range, never below a pressable button.
    double size = d.scale == 1.0
        ? _startLayout.size
        : (_startLayout.size * d.scale).clamp(
            GamepadEditMetrics.minSizeFactor(_minBtnSize, s),
            _maxBtnSize,
          );
    final sizePx = px(size);
    final half = sizePx / 2;
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
      GamepadEditGuideState(
        showVertical: snapX,
        showHorizontal: snapY,
        verticalX: snapX ? 0.5 : null,
        horizontalY: snapY ? 0.5 : null,
        snap: snapX || snapY,
      ),
    );
    final minX = _safeEdgePad + half;
    final maxX = w - _safeEdgePad - half;
    final minY = _safeTopEdgePad + half;
    final maxY = h - _safeEdgePad - half;
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
    var collides = false;
    for (final entry in widget.allLayouts.entries) {
      if (entry.key == widget.id) continue;
      if (!_isButtonEditId(entry.key)) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherSizePx = px(other.size);
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(widget.layout.cx * w, widget.layout.cy * h),
        fromRadius: px(widget.layout.size) / 2,
        toCentre: Offset(cx, cy),
        toRadius: sizePx / 2,
        otherCentre: Offset(ox, oy),
        otherRadius: otherSizePx / 2,
      )) {
        collides = true;
        break;
      }
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
    widget.onChanged(GamepadButtonLayout(cx / w, cy / h, size));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final size = GamepadEditMetrics.sizePx(
      widget.panelSize,
      widget.layout.size,
    );
    final cx = widget.layout.cx * w;
    final cy = widget.layout.cy * h;
    final showWarning =
        _colliding || _nearEdgeWarning || widget.externalWarning;
    // Drawn exactly as in play (same inset and fit, ears and tail
    // included), so spacing in the editor is what the driver gets.
    Widget buildButtonVisual() => Padding(
      padding: const EdgeInsets.all(2),
      child: Image.asset(
        widget.asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: _opacity(Colors.red, 0.18),
          alignment: Alignment.center,
          child: Text(
            widget.asset.split('/').last.split('.').first,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    final buttonContent = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GamepadEditSelectionVisual(
            selected: widget.selected,
            dimmed: widget.dimmed,
            warning: showWarning,
            selectionMask: buildButtonVisual(),
            child: buildButtonVisual(),
          ),
          if (widget.selected) const GamepadTouchAreaOutline(),
        ],
      ),
    );
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      child: GestureDetector(
        onScaleStart: widget.locked ? null : _onScaleStart,
        onScaleUpdate: widget.locked ? null : _onScaleUpdate,
        onScaleEnd: widget.locked
            ? null
            : (_) {
                final began = _gestureActive;
                _gestureActive = false;
                if (!began) return;
                widget.onGuideChanged?.call(
                  const GamepadEditGuideState.hidden(),
                );
                if (_colliding || _dragging || _nearEdgeWarning) {
                  setState(() {
                    _colliding = false;
                    _dragging = false;
                    _nearEdgeWarning = false;
                  });
                }
                widget.onEnd();
              },
        onTap: widget.onTap,
        child: SizedBox(width: size, height: size, child: buttonContent),
      ),
    );
  }

  bool _isButtonEditId(String id) {
    return id.startsWith('L:') || id.startsWith('R:');
  }
}
