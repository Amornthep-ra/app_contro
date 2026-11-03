// lib/pages/joystick.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/widgets/control_input_gate.dart';
import '../../../../core/widgets/control_background.dart';
import '../../../../core/widgets/gamepad_edit_hint.dart';
import '../../../../core/ui/gamepad_edit_metrics.dart';
import '../../../../core/widgets/gamepad_edit_grid.dart';
import '../../../../core/widgets/control_start_stop.dart';
import '../../../../core/widgets/gamepad_control_toolbar.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ble/ble_manager.dart';
import '../../../../core/ble/ble_connection_coordinator.dart';
import '../joystick_controller.dart';
import '../widgets/joystick_widget.dart';
import '../joystick_view.dart';
import '../../../../core/widgets/connection_status_badge.dart';
import '../../../../core/utils/orientation_utils.dart';
import '../joystick_theme.dart';
import '../../../../core/ble/joystick_packet.dart';
import '../../../../core/ble/control_timing.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/ui/gamepad_assets.dart';
import '../../../gamepad/widgets/gamepad_controls_sheet.dart';
import '../../../../core/ui/control_mode_preference.dart';
import '../../../../core/ui/gamepad_components.dart';
import '../../../../core/ui/app_assets.dart';
import '../../../../core/widgets/gamepad_app_bar.dart';
import '../../../../core/widgets/gamepad_appbar_controls.dart';
import '../../../../core/widgets/control_preset_dialog.dart';
import '../../../../core/widgets/cat_glass_popup.dart';
import '../../../../core/ui/language_controller.dart';
import '../../../gamepad/widgets/gamepad_telemetry_chip.dart';
import '../../../gamepad/widgets/gamepad_edit_shared.dart';
import '../../../gamepad/control_mode_settings_page.dart';
import '../../../bluetooth/widgets/pairing_code_dialog.dart';

const double kJoyMinSize = 0.6;
const double kJoyMaxSize = 1.6;
const double kJoyBtnMinSize = 0.6;
const double kJoyBtnMaxSize = 1.6;
const String kJoyLeftId = 'joy_left';
const String kJoyRightId = 'joy_right';
const String kJoyYOnlyId = 'joy_y_only';
const String kJoyXOnlyId = 'joy_x_only';
const String kBtnTriangleId = 'btn_triangle';
const String kBtnCrossId = 'btn_cross';
const String kBtnSquareId = 'btn_square';
const String kBtnCircleId = 'btn_circle';
const Set<String> kJoyDefaultActiveIds = {kJoyLeftId, kJoyRightId};

class JoystickPage extends StatefulWidget {
  const JoystickPage({super.key, this.acquireControl, this.openOnArrival});

  // Optional transport seam for exercising delayed Start completion in tests.
  final Future<int?> Function()? acquireControl;

  /// Set when Settings switched to this mode to edit it or open its saved
  /// layouts (see [ControlPageArguments]).
  final ControlModeOpen? openOnArrival;
  @override
  State<JoystickPage> createState() => _JoystickPageState();
}

class _JoystickPageState extends State<JoystickPage> {
  static const Color _cmdAccent = Color(0xFFF59E0B);
  static const Color _jlAccent = Color(0xFF22C55E);
  static const Color _jrAccent = Color(0xFF38BDF8);
  final JoystickController _controller = JoystickController();
  Timer? _timer;
  static const _prefsLayout = 'joy_dual_layout';
  static const _prefsActive = 'joy_dual_active';
  static const double _baseJoyRatio = 0.45;
  static const _prefsPreset1 = 'joy_preset_1';
  static const _prefsPreset2 = 'joy_preset_2';
  static const _prefsPreset3 = 'joy_preset_3';
  static const _prefsPreset4 = 'joy_preset_4';
  static const _prefsPreset5 = 'joy_preset_5';
  bool _editMode = false;
  bool _menuOpen = false;
  String? _selectedId;
  Size? _panelSize;
  Map<String, _JoyLayout> _layout = {};
  Set<String> _activeIds = {kJoyLeftId, kJoyRightId};
  final Set<String> _lockedIds = {};
  final List<_EditSnapshot> _undoStack = [];
  final List<_EditSnapshot> _redoStack = [];
  static const int _maxHistory = 30;
  int _dragCount = 0;
  bool _showVGuide = false;
  bool _showHGuide = false;
  bool _guideSnap = false;
  double? _guideV;
  double? _guideH;
  String? _editWarningId;
  Timer? _editWarningTimer;
  int _lastBoundaryWarningMs = 0;
  int _lastOverlapWarningMs = 0;
  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;
  int _lastButtonsKey = 0;
  double _smoothLX = 0.0, _smoothLY = 0.0;
  double _smoothRX = 0.0, _smoothRY = 0.0;
  double _lastLX = 0.0, _lastLY = 0.0;
  double _lastRX = 0.0, _lastRY = 0.0;
  static const double _deadZone = 0.05;
  static const double _smooth = 0.85;
  static const double _delta = 0.005;
  int _lastControlSendMs = 0;
  double _lerp(double a, double b, double t) => a + (b - a) * t;
  String _fmt(double v) => v.toStringAsFixed(2);
  final _leftDebug = ValueNotifier<String>("X:0.00 Y:0.00");
  final _rightDebug = ValueNotifier<String>("X:0.00 Y:0.00");
  String _debugValue(double x, double y) => "X:${_fmt(x)} Y:${_fmt(y)}";
  bool _isThai = true;
  bool _showGrid = false;
  late final VoidCallback _langListener;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  StreamSubscription<bool>? _bleConnSub;
  int? _bleTrafficOwner;
  bool _startInProgress = false;
  bool _leavingControlPage = false;
  bool _controlStarted = false;
  bool _modeSwitchInProgress = false;
  void _resetInputState() {
    void apply() {
      _smoothLX = 0;
      _smoothLY = 0;
      _smoothRX = 0;
      _smoothRY = 0;
      _lastLX = 0;
      _lastLY = 0;
      _lastRX = 0;
      _lastRY = 0;
      _triangle = false;
      _cross = false;
      _square = false;
      _circle = false;
      _lastButtonsKey = 0;
      _controller.setLeftJoystick(0, 0);
      _controller.setRightJoystick(0, 0);
      _setLeftDebug(0, 0);
      _setRightDebug(0, 0);
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  bool _setLeftDebug(double x, double y) {
    final next = _debugValue(x, y);
    if (_leftDebug.value == next) return false;
    _leftDebug.value = next;
    return true;
  }

  bool _setRightDebug(double x, double y) {
    final next = _debugValue(x, y);
    if (_rightDebug.value == next) return false;
    _rightDebug.value = next;
    return true;
  }

  void _updateLeftDebug(double x, double y) {
    _setLeftDebug(x, y);
  }

  void _updateRightDebug(double x, double y) {
    _setRightDebug(x, y);
  }

  void _sendBinary(
    JoystickPacket packet, {
    Set<int>? buttons,
    bool force = false,
  }) {
    if (!_controlStarted ||
        _modeSwitchInProgress ||
        _startInProgress ||
        BleManager.instance.controlSuspendedForLifecycle) {
      return;
    }
    final owner = _bleTrafficOwner;
    if (owner == null) return;
    _lastControlSendMs = DateTime.now().millisecondsSinceEpoch;
    unawaited(
      BleManager.instance.sendJoystickBinary(
        packet: packet,
        pressedButtons: buttons ?? const <int>{},
        owner: owner,
        force: force,
      ),
    );
  }

  void _resetLeftJoystick() {
    _smoothLX = 0;
    _smoothLY = 0;
    _lastLX = 0;
    _lastLY = 0;
    _controller.setLeftJoystick(0, 0);
    // force: release must never be dropped by the BLE rate limiter.
    // If it is lost over the air, the idle keepalive resends it.
    _sendBinary(
      JoystickPacket(lx: 0, ly: 0, rx: _lastRX, ry: _lastRY),
      buttons: _pressedButtons(),
      force: true,
    );
    if (mounted) {
      setState(() => _setLeftDebug(0, 0));
    }
  }

  void _resetRightJoystick() {
    _smoothRX = 0;
    _smoothRY = 0;
    _lastRX = 0;
    _lastRY = 0;
    _controller.setRightJoystick(0, 0);
    // force: release must never be dropped by the BLE rate limiter.
    // If it is lost over the air, the idle keepalive resends it.
    _sendBinary(
      JoystickPacket(lx: _lastLX, ly: _lastLY, rx: 0, ry: 0),
      buttons: _pressedButtons(),
      force: true,
    );
    if (mounted) {
      setState(() => _setRightDebug(0, 0));
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleControlSuspended() {
    if (!BleManager.instance.controlSuspendedForLifecycle || !_controlStarted) {
      return;
    }
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
              ownerName: 'joystick',
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
        message: 'Connect to a BLE device, then tap Start again.',
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
    _sendBinary(
      JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      buttons: const <int>{},
      force: true,
    );
  }

  Future<void> _stopControl() async {
    if (!_controlStarted) return;
    _resetInputState();
    if (mounted) setState(() => _controlStarted = false);
    await _releaseTrafficOwnershipForExit(emergency: true);
  }

  Future<void> _sendZeroAndClear({bool updateUi = true, int? owner}) {
    _smoothLX = 0;
    _smoothLY = 0;
    _smoothRX = 0;
    _smoothRY = 0;
    _lastLX = 0;
    _lastLY = 0;
    _lastRX = 0;
    _lastRY = 0;
    _triangle = false;
    _cross = false;
    _square = false;
    _circle = false;
    _controller.setLeftJoystick(0, 0);
    _controller.setRightJoystick(0, 0);
    _lastButtonsKey = 0;
    final stopOwner = owner ?? _bleTrafficOwner;
    final stopFuture = stopOwner == null
        ? Future<void>.value()
        : BleManager.instance.sendControlStop(owner: stopOwner);
    if (updateUi && mounted) {
      setState(() {
        _setLeftDebug(0, 0);
        _setRightDebug(0, 0);
      });
    }
    return stopFuture;
  }

  @override
  void initState() {
    super.initState();
    unawaited(ControlModePreference.save(LastControlMode.joystick));
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
    final layoutLoaded = _loadLayout();
    final open = widget.openOnArrival;
    if (open != null) unawaited(_openAfterLoad(layoutLoaded, open));
    _bleConnSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;
      _resetInputState();
      if (!connected) {
        setState(() => _controlStarted = false);
        unawaited(_releaseTrafficOwnershipForExit());
      }
    });
    _timer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if (!_controlStarted || _editMode) return;
      var packet = _controller.buildPacket();
      final buttonsKey = _buttonsKey();
      final buttonsChanged = buttonsKey != _lastButtonsKey;
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
        _lastButtonsKey = buttonsKey;
        // force: release must never be dropped by the BLE rate limiter.
        // If it is lost over the air, the idle keepalive resends it.
        _sendBinary(
          JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
          buttons: _pressedButtons(),
          force: true,
        );
        if (mounted && !_menuOpen) {
          setState(() {
            _setLeftDebug(0, 0);
            _setRightDebug(0, 0);
          });
        }
        return;
      }
      final changed =
          (packet.lx - _lastLX).abs() > _delta ||
          (packet.ly - _lastLY).abs() > _delta ||
          (packet.rx - _lastRX).abs() > _delta ||
          (packet.ry - _lastRY).abs() > _delta;
      if (!changed && !buttonsChanged) {
        // Resend the current state periodically: fast while active, slower
        // while idle so a lost stop packet is recovered well before the
        // robot watchdog (kControlWatchdogMs).
        final active = !nearZero || buttonsKey != 0;
        final interval = active ? kMinActiveMs : kMinIdleMs;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastControlSendMs < interval) {
          return;
        }
      }
      // Inside the dead zone always send an exact stop, never residual noise.
      if (nearZero) {
        packet = JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0);
      }
      _lastLX = packet.lx;
      _lastLY = packet.ly;
      _lastRX = packet.rx;
      _lastRY = packet.ry;
      _lastButtonsKey = buttonsKey;
      _sendBinary(packet, buttons: _pressedButtons());
    });
  }

  Future<void> _switchToControlMode({
    required String route,
    required String source,
    ControlModeOpen? open,
  }) async {
    if (_modeSwitchInProgress || _editMode) return;
    final manager = BleManager.instance;
    final owner = _bleTrafficOwner;
    setState(() {
      _modeSwitchInProgress = true;
      _controlStarted = false;
    });
    _resetInputState();
    _stopTimer();
    unawaited(
      ControlModePreference.save(
        route == AppRoutes.gamepad4Button
            ? LastControlMode.fourButton
            : LastControlMode.eightButton,
      ),
    );
    _bleTrafficOwner = null;
    if (owner != null) {
      manager.handoffControlForModeSwitch(owner: owner, source: source);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed<void, bool>(
      route,
      result: true,
      arguments: ControlPageArguments(open: open),
    );
  }

  Future<void> _openSettings() async {
    if (_editMode || _modeSwitchInProgress) return;
    final result = await Navigator.of(context).push<ControlModeSettingsResult>(
      controlModeSettingsRoute(
        mode: ControlMode.joystick,
        onManageLayouts: _showPresetSheet,
      ),
    );
    if (!mounted || result == null) return;
    switch (result.mode) {
      case ControlMode.joystick:
        _openFromSettings(result.open);
      case ControlMode.fourButton:
        await _switchToControlMode(
          route: AppRoutes.gamepad4Button,
          source: 'joystick_to_gamepad_4',
          open: result.open,
        );
      case ControlMode.eightButton:
        await _switchToControlMode(
          route: AppRoutes.gamepad8Button,
          source: 'joystick_to_gamepad_8',
          open: result.open,
        );
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
                  !_startInProgress,
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
    _stopTimer();
    _editWarningTimer?.cancel();
    _bleConnSub?.cancel();
    BleManager.instance.controlSuspendedListenable.removeListener(
      _handleControlSuspended,
    );
    unawaited(_releaseTrafficOwnershipForExit());
    LanguageController.isThai.removeListener(_langListener);
    _leftDebug.dispose();
    _rightDebug.dispose();
    super.dispose();
  }

  (double, double) _process(double rawX, double rawY, double sx, double sy) {
    double x = (rawX.abs() < _deadZone) ? 0 : rawX;
    double y = (rawY.abs() < _deadZone) ? 0 : rawY;
    final fx = _lerp(sx, x, _smooth);
    final fy = _lerp(sy, y, _smooth);
    const eps = 0.01;
    final snapX = (fx.abs() < eps) ? 0.0 : fx;
    final snapY = (fy.abs() < eps) ? 0.0 : fy;
    return (snapX, snapY);
  }

  Set<int> _pressedButtons() {
    final btns = <int>{};
    if (_triangle) btns.add(kBleBtnTriangle);
    if (_cross) btns.add(kBleBtnCross);
    if (_square) btns.add(kBleBtnSquare);
    if (_circle) btns.add(kBleBtnCircle);
    return btns;
  }

  int _buttonsKey() {
    final btns = _pressedButtons();
    int v = 0;
    for (final b in btns) {
      if (b < 1 || b > 8) continue;
      v |= (1 << (b - 1));
    }
    return v & 0xFF;
  }

  String _cmdLabel() => _buttonsKey().toString();
  double _baseJoySize(Size panel) =>
      math.min(panel.width, panel.height) * _baseJoyRatio;
  double _baseBtnSize(Size panel) => _baseJoySize(panel) * 0.55;
  Map<String, _JoyLayout> _defaultLayout(Size panel, Set<String> active) {
    final out = <String, _JoyLayout>{};
    if (active.contains(kJoyLeftId)) {
      out[kJoyLeftId] = const _JoyLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyYOnlyId)) {
      out[kJoyYOnlyId] = const _JoyLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyRightId)) {
      out[kJoyRightId] = const _JoyLayout(0.75, 0.5, 1.0);
    }
    if (active.contains(kJoyXOnlyId)) {
      out[kJoyXOnlyId] = const _JoyLayout(0.75, 0.5, 1.0);
    }
    final buttonIds = <String>[
      if (active.contains(kBtnTriangleId)) 'R:triangle',
      if (active.contains(kBtnCrossId)) 'R:cross',
      if (active.contains(kBtnSquareId)) 'R:square',
      if (active.contains(kBtnCircleId)) 'R:circle',
    ];
    if (buttonIds.isNotEmpty) {
      final buttonDefaults = buildDualClusterDefaultLayout(panel, buttonIds);
      final idMap = <String, String>{
        'R:triangle': kBtnTriangleId,
        'R:cross': kBtnCrossId,
        'R:square': kBtnSquareId,
        'R:circle': kBtnCircleId,
      };
      final joyBaseButtonSize = _baseBtnSize(panel);
      final panelMinSide = math.min(panel.width, panel.height);
      const rightClusterCenterX = 0.72;
      const actionClusterCenterY = 0.5;
      const clusterTighten = 0.7;
      buttonDefaults.forEach((tempId, layout) {
        final joyId = idMap[tempId];
        if (joyId == null) return;
        final gamepadButtonPx = layout.size * panelMinSide;
        final mappedScale = gamepadButtonPx / joyBaseButtonSize;
        final joySizeScale = (mappedScale * 0.75).clamp(kJoyBtnMinSize, 1.2);
        final tightenedCx =
            rightClusterCenterX +
            ((layout.cx - rightClusterCenterX) * clusterTighten);
        final tightenedCy =
            actionClusterCenterY +
            ((layout.cy - actionClusterCenterY) * clusterTighten);
        out[joyId] = _JoyLayout(tightenedCx, tightenedCy, joySizeScale);
      });
    }
    return out;
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsLayout);
    final activeRaw = prefs.getString(_prefsActive);
    if (raw != null && raw.isNotEmpty) {
      _layout = _decodeLayout(raw);
    }
    if (activeRaw != null && activeRaw.isNotEmpty) {
      _activeIds = _decodeIdList(activeRaw);
    } else {
      _activeIds = {kJoyLeftId, kJoyRightId};
    }
    _layout.removeWhere((k, _) => !_activeIds.contains(k));
    _lockedIds.removeWhere((id) => !_layout.containsKey(id));
    if (mounted) setState(() {});
  }

  Future<void> _saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLayout, jsonEncode(_encodeLayout(_layout)));
  }

  Future<void> _saveActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActive, jsonEncode(_activeIds.toList()));
  }

  Map<String, _JoyLayout> _decodeLayout(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return {};
      final out = <String, _JoyLayout>{};
      obj.forEach((k, v) {
        if (v is Map) {
          final cx = (v['cx'] as num?)?.toDouble();
          final cy = (v['cy'] as num?)?.toDouble();
          final size = (v['size'] as num?)?.toDouble() ?? 1.0;
          if (cx != null && cy != null) {
            out[k.toString()] = _JoyLayout(cx, cy, size);
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, double>> _encodeLayout(
    Map<String, _JoyLayout> layout,
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
      if (_editMode && _panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        _layout = {...defaults, ..._layout};
      }
    });
  }

  bool _isLeftJoy(String id) => id == kJoyLeftId || id == kJoyYOnlyId;
  bool _isRightJoy(String id) => id == kJoyRightId || id == kJoyXOnlyId;
  void _selectJoystick(String id) {
    setState(() => _selectedId = id);
  }

  void _toggleSelectedLock() {
    final id = _selectedId;
    if (id == null) return;
    _pushHistory();
    setState(() {
      if (_lockedIds.contains(id)) {
        _lockedIds.remove(id);
      } else {
        _lockedIds.add(id);
      }
    });
  }

  Map<String, _JoyLayout> _cloneLayout(Map<String, _JoyLayout> src) {
    final out = <String, _JoyLayout>{};
    src.forEach((k, v) {
      out[k] = _JoyLayout(v.cx, v.cy, v.size);
    });
    return out;
  }

  _EditSnapshot _captureSnapshot() {
    return _EditSnapshot(
      layout: _cloneLayout(_layout),
      activeIds: Set<String>.from(_activeIds),
      lockedIds: Set<String>.from(_lockedIds),
      selectedId: _selectedId,
    );
  }

  void _applySnapshot(_EditSnapshot snap) {
    _layout = _cloneLayout(snap.layout);
    _activeIds = Set<String>.from(snap.activeIds);
    _lockedIds
      ..clear()
      ..addAll(snap.lockedIds);
    _selectedId = snap.selectedId;
    _layout.removeWhere((k, _) => !_activeIds.contains(k));
    _lockedIds.removeWhere((id) => !_layout.containsKey(id));
    if (_selectedId != null && !_layout.containsKey(_selectedId)) {
      _selectedId = null;
    }
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
    });
    _saveLayout();
    _saveActive();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_captureSnapshot());
      _applySnapshot(_redoStack.removeLast());
    });
    _saveLayout();
    _saveActive();
  }

  void _toggleActive(String id) {
    _pushHistory();
    setState(() {
      if (_activeIds.contains(id)) {
        _activeIds.remove(id);
        _layout.remove(id);
        _lockedIds.remove(id);
        if (_selectedId == id) _selectedId = null;
        _clearButtonState(id);
        if (_isLeftJoy(id)) _resetLeftJoystick();
        if (_isRightJoy(id)) _resetRightJoystick();
      } else {
        final panel = _panelSize;
        if (panel != null) {
          // Pin what is already on the pad: default spots depend on which
          // controls are active, and adding one must not move the others.
          final before = _defaultLayout(panel, _activeIds);
          for (final other in _activeIds) {
            final def = before[other];
            if (def != null) _layout.putIfAbsent(other, () => def);
          }
        }
        _activeIds.add(id);
        if (panel != null) {
          final def = _defaultLayout(panel, _activeIds)[id];
          if (def != null) _layout[id] = _placeOnFreeSpot(id, def, panel);
        }
      }
    });
    _saveLayout();
    _saveActive();
  }

  /// [def] moved to the nearest spot that does not crowd the controls
  /// already on the pad. New buttons used to land on the right joystick.
  _JoyLayout _placeOnFreeSpot(String id, _JoyLayout def, Size panel) {
    double radius(String key, _JoyLayout layout) =>
        (_isButtonId(key) ? _baseBtnSize(panel) : _baseJoySize(panel)) *
        layout.size /
        2;
    // Same edge rule as dragging a control on this page.
    const edge = 16.0;
    final w = panel.width;
    final h = panel.height;
    final r = radius(id, def);
    final spot = GamepadEditMetrics.freeSpotFor(
      preferred: Offset(def.cx * w, def.cy * h),
      radius: r,
      centreArea: Rect.fromLTRB(edge + r, edge + r, w - edge - r, h - edge - r),
      others: [
        for (final other in _activeIds)
          if (other != id && _layout[other] != null)
            (
              Offset(_layout[other]!.cx * w, _layout[other]!.cy * h),
              radius(other, _layout[other]!),
            ),
      ],
    );
    return _JoyLayout(spot.dx / w, spot.dy / h, def.size);
  }

  void _removeSelected() {
    final id = _selectedId;
    if (id == null) return;
    _toggleActive(id);
  }

  void _resetLayout() async {
    _pushHistory();
    final defaultActive = Set<String>.from(kJoyDefaultActiveIds);
    final defaultLayout = _panelSize != null
        ? _defaultLayout(_panelSize!, defaultActive)
        : <String, _JoyLayout>{};
    setState(() {
      _layout = defaultLayout;
      _activeIds = defaultActive;
      _lockedIds.clear();
      _selectedId = null;
      _dragCount = 0;
      _showVGuide = false;
      _showHGuide = false;
      _guideSnap = false;
      _guideV = null;
      _guideH = null;
      _clearButtonState(null);
    });
    _resetLeftJoystick();
    _resetRightJoystick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayout);
    await prefs.remove('${_prefsLayout}_start_stop');
    await prefs.remove(_prefsActive);
  }

  void _clearButtonState(String? id) {
    if (id == null || id == kBtnTriangleId) _triangle = false;
    if (id == null || id == kBtnCrossId) _cross = false;
    if (id == null || id == kBtnSquareId) _square = false;
    if (id == null || id == kBtnCircleId) _circle = false;
  }

  void _setGuideVisibility(
    bool showV,
    bool showH, {
    bool snap = false,
    double? guideV,
    double? guideH,
  }) {
    if (!mounted) return;
    setState(() {
      _showVGuide = showV;
      _showHGuide = showH;
      _guideV = showV ? guideV : null;
      _guideH = showH ? guideH : null;
      _guideSnap = snap && (showV || showH);
    });
  }

  void _beginDrag() {
    if (!mounted) return;
    setState(() {
      _dragCount += 1;
    });
  }

  void _endDrag() {
    if (!mounted) return;
    setState(() {
      _dragCount = math.max(0, _dragCount - 1);
      if (_dragCount == 0) {
        _showVGuide = false;
        _showHGuide = false;
        _guideSnap = false;
        _guideV = null;
        _guideH = null;
      }
    });
  }

  Widget _buildEditMenu({bool compact = false}) {
    final isThai = LanguageController.isThai.value;
    final accent = const Color(0xFF34D399);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        Color.lerp(
          accent,
          isDark ? Colors.white : theme.colorScheme.onSurface,
          0.4,
        ) ??
        Colors.white;
    final horizontalPadding = compact ? 10.0 : 12.0;
    final fontSize = compact ? 10.0 : 11.0;
    Widget content() {
      return GamepadGlassTopPill(
        pillKey: null,
        onTap: Platform.isIOS
            ? null
            : () {
                gamepadBuzz();
                _openButtonsMenu();
              },
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 0,
        ),
        child: Center(
          child: Text(
            isThai ? 'Buttons' : 'Buttons',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    if (Platform.isIOS) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          gamepadBuzz();
          _openButtonsMenu();
        },
        child: content(),
      );
    }
    return content();
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

  Widget _sizeToolPill({
    required bool isThai,
    required bool enabled,
    Key? key,
  }) {
    return GamepadSizeToolPill(
      pillKey: key,
      isThai: isThai,
      enabled: enabled,
      onDecrease: () {
        gamepadBuzz();
        _adjustSelectedSize(-0.05);
      },
      onIncrease: () {
        gamepadBuzz();
        _adjustSelectedSize(0.05);
      },
    );
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
      'layout': _encodeLayout(_layout),
      'active': _activeIds.toList(),
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
      if (layoutRaw is Map) {
        _layout = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (activeRaw is List) {
        _activeIds = activeRaw.map((e) => e.toString()).toSet();
      }
      if (_panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        _layout = {...defaults, ..._layout};
      }
      setState(() {});
      _saveLayout();
      _saveActive();
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

  Future<void> _openButtonsMenu() async {
    if (_menuOpen || !mounted) return;
    _menuOpen = true;
    try {
      await showGamepadControlsSheet(
        context: context,
        groups: const [
          GamepadControlGroup(
            title: 'Joysticks',
            choices: [
              GamepadControlChoice(
                id: kJoyLeftId,
                label: 'Left Joystick',
                icon: Icons.control_camera_rounded,
              ),
              GamepadControlChoice(
                id: kJoyRightId,
                label: 'Right Joystick',
                icon: Icons.control_camera_rounded,
              ),
              GamepadControlChoice(
                id: kJoyYOnlyId,
                label: 'Joystick (Y only)',
                icon: Icons.swap_vert_rounded,
              ),
              GamepadControlChoice(
                id: kJoyXOnlyId,
                label: 'Joystick (X only)',
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
          GamepadControlGroup(
            title: 'Buttons',
            choices: [
              GamepadControlChoice(
                id: kBtnTriangleId,
                label: 'Triangle',
                asset: kGamepad8AssetTriangle,
              ),
              GamepadControlChoice(
                id: kBtnCrossId,
                label: 'Cross',
                asset: kGamepad8AssetCross,
              ),
              GamepadControlChoice(
                id: kBtnSquareId,
                label: 'Square',
                asset: kGamepad8AssetSquare,
              ),
              GamepadControlChoice(
                id: kBtnCircleId,
                label: 'Circle',
                asset: kGamepad8AssetCircle,
              ),
            ],
          ),
        ],
        isActive: (id) => _activeIds.contains(id),
        onToggle: (id) {
          gamepadBuzz();
          _toggleActive(id);
        },
      );
    } finally {
      _menuOpen = false;
    }
  }

  void _showSizeLimit(bool atMax) {
    final isThai = LanguageController.isThai.value;
    final msg = atMax
        ? (isThai ? 'Max size reached' : 'Max size reached')
        : (isThai ? 'Min size reached' : 'Min size reached');
    showGamepadTopNotice(
      context,
      message: msg,
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _showSizeEdgeWarning() {
    final isThai = LanguageController.isThai.value;
    final msg = isThai
        ? 'Buttons must stay inside the safe zone.'
        : 'Buttons must stay inside the safe zone.';
    showGamepadTopNotice(
      context,
      message: msg,
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

  void _flashEditWarning(String id) {
    _editWarningTimer?.cancel();
    if (mounted) {
      setState(() => _editWarningId = id);
    }
    _editWarningTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        if (_editWarningId == id) {
          _editWarningId = null;
        }
      });
    });
  }

  void _adjustSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;
    if (_lockedIds.contains(id)) return;
    final panel = _panelSize;
    if (panel == null) return;
    final current = _layout[id];
    if (current == null) return;
    final w = panel.width;
    final h = panel.height;
    final isButton = _isButtonId(id);
    final base = isButton ? _baseBtnSize(panel) : _baseJoySize(panel);
    final unclamped = current.size + delta;
    final minSize = _isButtonId(id) ? kJoyBtnMinSize : kJoyMinSize;
    final maxSize = _isButtonId(id) ? kJoyBtnMaxSize : kJoyMaxSize;
    final nextSize = unclamped.clamp(minSize, maxSize);
    if (nextSize == current.size) {
      _showSizeLimit(unclamped >= maxSize);
      _flashEditWarning(id);
      return;
    }
    _pushHistory();
    final sizePx = base * nextSize;
    final half = sizePx / 2;
    final rawCx = current.cx * w;
    final rawCy = current.cy * h;
    const safeEdgePad = 16.0;
    final minX = safeEdgePad + half;
    final maxX = w - safeEdgePad - half;
    final minY = safeEdgePad + half;
    final maxY = h - safeEdgePad - half;
    if (rawCx < minX || rawCx > maxX || rawCy < minY || rawCy > maxY) {
      HapticFeedback.vibrate();
      _showBoundaryWarning();
      _flashEditWarning(id);
      return;
    }
    double cx = rawCx.clamp(minX, maxX);
    double cy = rawCy.clamp(minY, maxY);
    final edgeAdjusted = (cx - rawCx).abs() > 0.01 || (cy - rawCy).abs() > 0.01;
    var collides = false;
    for (final entry in _layout.entries) {
      if (entry.key == id) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherBase = _isButtonId(entry.key)
          ? _baseBtnSize(panel)
          : _baseJoySize(panel);
      final otherSizePx = otherBase * other.size;
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(current.cx * w, current.cy * h),
        fromRadius: base * current.size / 2,
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
      _showOverlapWarning();
      _flashEditWarning(id);
      return;
    }
    setState(() {
      final next = Map<String, _JoyLayout>.from(_layout);
      next[id] = _JoyLayout(cx / w, cy / h, nextSize);
      _layout = next;
      _editWarningId = null;
    });
    _saveLayout();
    if (edgeAdjusted) {
      _showSizeEdgeWarning();
    }
  }

  Widget _buildGridOverlay() {
    if (!_editMode || !_showGrid) return const SizedBox.shrink();
    // The joystick pad fills this Stack, so the grid lines up with snapping.
    return const Positioned.fill(child: GamepadEditGrid());
  }

  bool _isButtonId(String id) {
    return id == kBtnTriangleId ||
        id == kBtnCrossId ||
        id == kBtnSquareId ||
        id == kBtnCircleId;
  }

  void _onButtonChanged(String id, bool down) {
    if (_editMode) return;
    if (id == kBtnTriangleId) _triangle = down;
    if (id == kBtnCrossId) _cross = down;
    if (id == kBtnSquareId) _square = down;
    if (id == kBtnCircleId) _circle = down;
    _lastButtonsKey = _buttonsKey();
    _sendBinary(_controller.buildPacket(), buttons: _pressedButtons());
    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _onBack() async {
    if (_leavingControlPage) return false;
    _leavingControlPage = true;
    _stopTimer();
    await _releaseTrafficOwnershipForExit();
    if (!mounted) return false;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    }
    return false;
  }

  Future<void> _releaseTrafficOwnershipForExit({bool emergency = false}) async {
    final owner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (owner == null) return;
    final manager = BleManager.instance;
    if (emergency) {
      await manager.emergencyStopAndReleaseControl(
        owner: owner,
        source: 'joystick_emergency_stop',
      );
      return;
    }
    manager.disableControlReconnect(owner);
    try {
      await _sendZeroAndClear(updateUi: false, owner: owner);
    } finally {
      manager.releaseTrafficMode(owner);
    }
  }

  // ignore: unused_element
  GamepadAppBarMetrics _metricsWithOverrides(
    GamepadAppBarMetrics base, {
    double? labelButtonWidth,
    double? telemetryValueMaxWidth,
  }) {
    return GamepadAppBarMetrics(
      controlHeight: base.controlHeight,
      iconButtonExtent: base.iconButtonExtent,
      labelButtonWidth: labelButtonWidth ?? base.labelButtonWidth,
      controlGap: base.controlGap,
      sectionGap: base.sectionGap,
      contentPadding: base.contentPadding,
      iconSize: base.iconSize,
      borderRadius: base.borderRadius,
      labelIconGap: base.labelIconGap,
      telemetryLabelFontSize: base.telemetryLabelFontSize,
      telemetryValueFontSize: base.telemetryValueFontSize,
      telemetryValueMaxWidth:
          telemetryValueMaxWidth ?? base.telemetryValueMaxWidth,
    );
  }

  Widget _buildAlignmentGuides() {
    if (!_editMode || _dragCount == 0 || (!_showVGuide && !_showHGuide)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = _guideSnap
        ? _opacity(const Color(0xFFFACC15), isDark ? 0.92 : 0.85)
        : _opacity(cs.primary, isDark ? 0.35 : 0.25);
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: GamepadEditAlignmentGuidesPainter(
            color: color,
            showVertical: _showVGuide,
            showHorizontal: _showHGuide,
            verticalX: _guideV,
            horizontalY: _guideH,
            strokeWidth: 1.2,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions({
    required bool isThai,
    required GamepadAppBarMetrics appBarMetrics,
    required double actionGap,
  }) {
    return [
      ConnectionStatusBadge(
        autoPromptPairing: !_editMode,
        pairingPromptEnabled: !_editMode,
        appBarMetrics: appBarMetrics,
        iconAsset: AppAssets.controlBle,
        subdued: true,
        onManagementBlocked: () => showGamepadTopNotice(
          context,
          message: _isThai
              ? 'Use Emergency Stop before managing BLE.'
              : 'Use Emergency Stop before managing BLE.',
          style: GamepadNoticeStyle.ble,
        ),
      ),
      GamepadAppBarActionGroup(
        gap: actionGap,
        items: [
          GamepadAppBarActionItem(
            label: isThai ? 'Settings' : 'Settings',
            icon: Icons.settings_outlined,
            iconAsset: AppAssets.controlSettings,
            accent: const Color(0xFF94A3B8),
            iconOnly: true,
            compact: true,
            onTap: _openSettings,
          ),
        ],
      ),
    ];
  }

  Widget _buildAppBarToolbarRow({
    required bool isThai,
    required GamepadAppBarMetrics appBarMetrics,
    required GamepadAppBarMetrics cmdMetrics,
    required GamepadAppBarMetrics axisMetrics,
    required double uniformGap,
  }) {
    final telemetry = <Widget>[
      SizedBox(
        child: GamepadTelemetryChip(
          icon: Icons.flash_on,
          label: 'CMD',
          value: _cmdLabel(),
          metrics: cmdMetrics,
          accentColor: _cmdAccent,
          iconAsset: AppAssets.controlCommand,
          subdued: true,
        ),
      ),
      ValueListenableBuilder<String>(
        valueListenable: _leftDebug,
        builder: (context, value, child) => GamepadTelemetryChip(
          icon: Icons.west,
          label: 'JL',
          showLabel: false,
          value: value,
          metrics: axisMetrics,
          accentColor: _jlAccent,
        ),
      ),
      ValueListenableBuilder<String>(
        valueListenable: _rightDebug,
        builder: (context, value, child) => GamepadTelemetryChip(
          icon: Icons.east,
          label: 'JR',
          showLabel: false,
          value: value,
          metrics: axisMetrics,
          accentColor: _jrAccent,
        ),
      ),
    ];
    return GamepadCenteredToolbar(
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
      children: [
        _buildAppBarBackButton(appBarMetrics),
        _buildToolbarStartStop(),
        ...telemetry,
        ..._buildAppBarActions(
          isThai: isThai,
          appBarMetrics: appBarMetrics,
          actionGap: uniformGap,
        ),
      ],
    );
  }

  Widget _buildCenteredEditAppBar(bool isThai) {
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
        // Choose which joysticks and buttons (△ ✕ □ ○) are on the pad.
        // This entry point was lost when the editor moved to this toolbar.
        _toolIconPill(
          key: const ValueKey('joystick-edit-controls'),
          icon: Icons.videogame_asset_outlined,
          label: 'Buttons',
          accent: const Color(0xFF34D399),
          onTap: withBuzz(_openButtonsMenu),
        ),
        _toolIconPill(
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          label: gamepadEditLockLabel(isThai: isThai, locked: selectedLocked),
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? withBuzz(_toggleSelectedLock) : null,
        ),
        _toolIconPill(
          icon: Icons.remove,
          label: isThai ? 'ลดขนาด' : 'Decrease size',
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled
              ? withBuzz(() => _adjustSelectedSize(-0.05))
              : null,
        ),
        _toolIconPill(
          icon: Icons.add,
          label: isThai ? 'เพิ่มขนาด' : 'Increase size',
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
          onTap: _undoStack.isNotEmpty ? withBuzz(_undo) : null,
        ),
        _toolIconPill(
          icon: Icons.redo_rounded,
          label: 'Redo',
          accent: const Color(0xFFA78BFA),
          onTap: _redoStack.isNotEmpty ? withBuzz(_redo) : null,
        ),
        _toolIconPill(
          icon: Icons.restart_alt,
          label: 'Reset',
          accent: const Color(0xFFF59E0B),
          onTap: withBuzz(_resetLayout),
        ),
        _toolIconPill(
          icon: Icons.delete_outline,
          label: isThai ? 'ลบ' : 'Delete',
          accent: const Color(0xFFF87171),
          onTap: hasSelection ? withBuzz(_removeSelected) : null,
        ),
      ],
    );
  }

  // ignore: unused_element
  PreferredSizeWidget _buildEditModeAppBar(bool isThai) {
    final media = MediaQuery.of(context);
    if (media.size.width >= 1000 && media.textScaler.scale(1) <= 1.3) {
      return _buildExpandedEditModeAppBar(isThai);
    }
    final metrics = GamepadAppBarMetrics.forWidth(media.size.width);
    final hasSelection = _selectedId != null;
    final selectedLocked =
        _selectedId != null && _lockedIds.contains(_selectedId);
    final sizeEnabled = hasSelection && !selectedLocked;

    VoidCallback withBuzz(VoidCallback action) {
      return () {
        gamepadBuzz();
        action();
      };
    }

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
          onTap: hasSelection ? withBuzz(_removeSelected) : null,
        ),
        GamepadOverflowAction(
          label: 'Reset',
          icon: Icons.restart_alt,
          accent: const Color(0xFFF59E0B),
          onTap: withBuzz(_resetLayout),
        ),
        GamepadOverflowAction(
          label: 'Grid',
          icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          accent: const Color(0xFF38BDF8),
          active: _showGrid,
          onTap: withBuzz(() => setState(() => _showGrid = !_showGrid)),
        ),
        GamepadOverflowAction(
          label: isThai ? 'ลดขนาด' : 'Decrease size',
          icon: Icons.remove,
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled
              ? withBuzz(() => _adjustSelectedSize(-0.05))
              : null,
        ),
        GamepadOverflowAction(
          label: isThai ? 'เพิ่มขนาด' : 'Increase size',
          icon: Icons.add,
          accent: const Color(0xFF38BDF8),
          onTap: sizeEnabled ? withBuzz(() => _adjustSelectedSize(0.05)) : null,
        ),
        GamepadOverflowAction(
          label: gamepadEditLockLabel(isThai: isThai, locked: selectedLocked),
          icon: selectedLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
          accent: const Color(0xFFFBBF24),
          active: selectedLocked,
          onTap: hasSelection ? withBuzz(_toggleSelectedLock) : null,
        ),
      ],
    );
    final history = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        compactAction(
          label: 'Undo',
          icon: Icons.undo_rounded,
          onTap: _undoStack.isNotEmpty ? withBuzz(_undo) : null,
        ),
        SizedBox(width: metrics.controlGap),
        compactAction(
          label: 'Redo',
          icon: Icons.redo_rounded,
          onTap: _redoStack.isNotEmpty ? withBuzz(_redo) : null,
        ),
        SizedBox(width: metrics.controlGap),
        more,
      ],
    );
    final done = _actionPill(
      label: 'Done',
      icon: Icons.edit,
      accent: const Color(0xFF60A5FA),
      compact: true,
      onTap: withBuzz(_toggleEdit),
    );
    return GamepadUnifiedAppBar(
      textScaleFactor: media.textScaler.scale(1),
      useGlassBackground: false,
      glassOpacity: 0.18,
      toolbarContent: SizedBox(
        width: math.max(0, media.size.width - 24),
        height: metrics.tapTargetExtent,
        child: Row(
          children: [
            _buildEditMenu(compact: true),
            SizedBox(width: metrics.sectionGap),
            Expanded(child: Center(child: history)),
            SizedBox(width: metrics.sectionGap),
            done,
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildExpandedEditModeAppBar(bool isThai) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final metrics = GamepadAppBarMetrics.forWidth(
      MediaQuery.of(context).size.width,
    );
    final baseColor = isDark
        ? _opacity(const Color(0xFF111827), 0.30)
        : _opacity(
            Color.lerp(const Color(0xFFF8FAFC), cs.surface, 0.55) ?? cs.surface,
            0.18,
          );
    final border = _opacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      isDark ? 0.28 : 0.16,
    );
    final topLine = _opacity(Colors.white, isDark ? 0.1 : 0.45);
    final bottomLine = _opacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      isDark ? 0.32 : 0.18,
    );
    final middleChildren = <Widget>[
      _actionPill(
        label: isThai ? 'Delete' : 'Delete',
        icon: Icons.delete_outline,
        accent: const Color(0xFFF87171),
        compact: true,
        onTap: _selectedId == null
            ? null
            : () {
                gamepadBuzz();
                _removeSelected();
              },
      ),
      _actionPill(
        label: isThai ? 'Reset' : 'Reset',
        icon: Icons.restart_alt,
        accent: const Color(0xFFF59E0B),
        compact: true,
        onTap: () {
          gamepadBuzz();
          _resetLayout();
        },
      ),
      _toolIconPill(
        icon: Icons.undo_rounded,
        label: isThai ? 'Undo' : 'Undo',
        accent: const Color(0xFFA78BFA),
        onTap: _undoStack.isNotEmpty
            ? () {
                gamepadBuzz();
                _undo();
              }
            : null,
      ),
      _toolIconPill(
        icon: Icons.redo_rounded,
        label: isThai ? 'Redo' : 'Redo',
        accent: const Color(0xFFA78BFA),
        onTap: _redoStack.isNotEmpty
            ? () {
                gamepadBuzz();
                _redo();
              }
            : null,
      ),
      _toolIconPill(
        icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
        label: isThai ? 'Grid' : 'Grid',
        accent: const Color(0xFF38BDF8),
        active: _showGrid,
        onTap: () {
          gamepadBuzz();
          setState(() => _showGrid = !_showGrid);
        },
      ),
      _sizeToolPill(
        isThai: isThai,
        enabled: _selectedId != null && !_lockedIds.contains(_selectedId),
      ),
      _toolIconPill(
        icon: _selectedId != null && _lockedIds.contains(_selectedId)
            ? Icons.lock_rounded
            : Icons.lock_open_rounded,
        label: gamepadEditLockLabel(
          isThai: isThai,
          locked: _selectedId != null && _lockedIds.contains(_selectedId),
        ),
        accent: const Color(0xFFFBBF24),
        active: _selectedId != null && _lockedIds.contains(_selectedId),
        onTap: _selectedId != null
            ? () {
                gamepadBuzz();
                _toggleSelectedLock();
              }
            : null,
      ),
    ];
    final allChildren = <Widget>[
      _buildEditMenu(compact: true),
      ...middleChildren,
      _actionPill(
        label: isThai ? 'Done' : 'Done',
        icon: Icons.edit,
        accent: const Color(0xFF60A5FA),
        compact: true,
        onTap: () {
          gamepadBuzz();
          _toggleEdit();
        },
      ),
    ];
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: GamepadAppBarMetrics.toolbarHeight,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      titleSpacing: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              border: Border(
                top: BorderSide(color: topLine, width: 0.8),
                bottom: BorderSide(color: border, width: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: _opacity(Colors.black, isDark ? 0.24 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(height: 1, color: bottomLine),
            ),
          ),
        ),
      ),
      title: SizedBox(
        height: metrics.tapTargetExtent,
        child: Padding(
          padding: metrics.contentPadding,
          child: Row(
            children: [
              allChildren.first,
              SizedBox(width: metrics.sectionGap),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        int index = 1;
                        index < allChildren.length - 1;
                        index++
                      ) ...[
                        allChildren[index],
                        if (index < allChildren.length - 2)
                          SizedBox(width: metrics.controlGap),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: metrics.sectionGap),
              allChildren.last,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarBackButton(GamepadAppBarMetrics metrics) {
    return GamepadAppBarBackButton(
      metrics: metrics,
      onPressed: () {
        gamepadBuzz();
        _onBack();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlLayout = _editMode
        ? null
        : GamepadControlLayout.measure(context, [
            '',
            '',
            'CMD 255',
            'X:-1.00 Y:-1.00',
            'X:-1.00 Y:-1.00',
            '@ble',
            '',
          ], leadingCount: 2);
    final width = MediaQuery.of(context).size.width;
    final appBarMetrics = GamepadAppBarMetrics.forWidth(width);
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
    final cmdMetrics = appBarMetrics;
    final axisMetrics = appBarMetrics;
    final isThai = LanguageController.isThai.value;
    const uniformGap = GamepadAppBarMetrics.uniformGap;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Stack(
        children: [
          Scaffold(
            extendBodyBehindAppBar: true,
            appBar: GamepadUnifiedAppBar(
              controlLayout: controlLayout,
              textScaleFactor: textScaleFactor,
              viewportWidth: width - MediaQuery.paddingOf(context).horizontal,
              toolbarItemCount: _editMode ? 10 : 7,
              singleRowToolbar: _editMode,
              useGlassBackground: false,
              glassOpacity: 0.18,
              toolbarPadding: const EdgeInsets.symmetric(horizontal: 12),
              toolbarContent: _editMode
                  ? _buildCenteredEditAppBar(isThai)
                  : _buildAppBarToolbarRow(
                      isThai: isThai,
                      appBarMetrics: appBarMetrics,
                      cmdMetrics: cmdMetrics,
                      axisMetrics: axisMetrics,
                      uniformGap: uniformGap,
                    ),
            ),
            body: Stack(
              children: [
                Positioned.fill(child: const ControlBackground()),
                SafeArea(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildGridOverlay(),
                      if (_editMode)
                        GamepadEditHint(hasSelection: _selectedId != null),
                      _buildAlignmentGuides(),
                      LayoutBuilder(
                        builder: (context, c) {
                          final size = Size(c.maxWidth, c.maxHeight);
                          _panelSize = size;
                          final defaults = _defaultLayout(size, _activeIds);
                          final effective = {...defaults, ..._layout};
                          final base = _baseJoySize(size);
                          final btnBase = _baseBtnSize(size);
                          final widgets = <Widget>[];
                          if (_activeIds.contains(kJoyLeftId)) {
                            widgets.add(
                              _buildJoystick(
                                id: kJoyLeftId,
                                size: size,
                                baseSize: base,
                                layout: effective[kJoyLeftId]!,
                                allLayouts: effective,
                                isLeft: true,
                                axisLock: JoystickAxisLock.none,
                              ),
                            );
                          }
                          if (_activeIds.contains(kJoyYOnlyId)) {
                            widgets.add(
                              _buildJoystick(
                                id: kJoyYOnlyId,
                                size: size,
                                baseSize: base,
                                layout: effective[kJoyYOnlyId]!,
                                allLayouts: effective,
                                isLeft: true,
                                axisLock: JoystickAxisLock.yOnly,
                              ),
                            );
                          }
                          if (_activeIds.contains(kJoyRightId)) {
                            widgets.add(
                              _buildJoystick(
                                id: kJoyRightId,
                                size: size,
                                baseSize: base,
                                layout: effective[kJoyRightId]!,
                                allLayouts: effective,
                                isLeft: false,
                                axisLock: JoystickAxisLock.none,
                              ),
                            );
                          }
                          if (_activeIds.contains(kJoyXOnlyId)) {
                            widgets.add(
                              _buildJoystick(
                                id: kJoyXOnlyId,
                                size: size,
                                baseSize: base,
                                layout: effective[kJoyXOnlyId]!,
                                allLayouts: effective,
                                isLeft: false,
                                axisLock: JoystickAxisLock.xOnly,
                              ),
                            );
                          }
                          if (_activeIds.contains(kBtnTriangleId)) {
                            widgets.add(
                              _buildButton(
                                id: kBtnTriangleId,
                                label: 'Triangle',
                                asset: kGamepad8AssetTriangle,
                                size: size,
                                baseSize: btnBase,
                                layout: effective[kBtnTriangleId]!,
                                allLayouts: effective,
                              ),
                            );
                          }
                          if (_activeIds.contains(kBtnCrossId)) {
                            widgets.add(
                              _buildButton(
                                id: kBtnCrossId,
                                label: 'Cross',
                                asset: kGamepad8AssetCross,
                                size: size,
                                baseSize: btnBase,
                                layout: effective[kBtnCrossId]!,
                                allLayouts: effective,
                              ),
                            );
                          }
                          if (_activeIds.contains(kBtnSquareId)) {
                            widgets.add(
                              _buildButton(
                                id: kBtnSquareId,
                                label: 'Square',
                                asset: kGamepad8AssetSquare,
                                size: size,
                                baseSize: btnBase,
                                layout: effective[kBtnSquareId]!,
                                allLayouts: effective,
                              ),
                            );
                          }
                          if (_activeIds.contains(kBtnCircleId)) {
                            widgets.add(
                              _buildButton(
                                id: kBtnCircleId,
                                label: 'Circle',
                                asset: kGamepad8AssetCircle,
                                size: size,
                                baseSize: btnBase,
                                layout: effective[kBtnCircleId]!,
                                allLayouts: effective,
                              ),
                            );
                          }
                          return ControlInputGate(
                            started: _controlStarted,
                            editing: _editMode,
                            suspended:
                                BleManager.instance.controlSuspendedListenable,
                            onLockedTap: _showStartFirstNotice,
                            child: Stack(children: widgets),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (controlLayout != null) _buildStartHint(controlLayout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoystick({
    required String id,
    required Size size,
    required double baseSize,
    required _JoyLayout layout,
    required Map<String, _JoyLayout> allLayouts,
    required bool isLeft,
    required JoystickAxisLock axisLock,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final joySize = baseSize * layout.size;
    final half = joySize / 2;
    final cx = (layout.cx * size.width).clamp(half, size.width - half);
    final cy = (layout.cy * size.height).clamp(half, size.height - half);
    final joyWidget = SizedBox(
      width: joySize,
      height: joySize,
      child: JoystickWidget(
        controller: _controller,
        isLeft: isLeft,
        axisLock: axisLock,
        baseImage: isLeft
            ? joystickTheme.leftBaseImage
            : joystickTheme.rightBaseImage,
        knobImage: isLeft
            ? joystickTheme.leftKnobImage
            : joystickTheme.rightKnobImage,
        onChanged: (x, y) {
          if (_editMode) return;
          if (isLeft) {
            final (sx, sy) = _process(x, y, _smoothLX, _smoothLY);
            _smoothLX = sx;
            _smoothLY = sy;
            _controller.setLeftJoystick(sx, sy);
            if (x == 0 && y == 0) {
              _resetLeftJoystick();
              return;
            }
            _updateLeftDebug(sx, sy);
          } else {
            final (sx, sy) = _process(x, y, _smoothRX, _smoothRY);
            _smoothRX = sx;
            _smoothRY = sy;
            _controller.setRightJoystick(sx, sy);
            if (x == 0 && y == 0) {
              _resetRightJoystick();
              return;
            }
            _updateRightDebug(sx, sy);
          }
        },
      ),
    );
    if (!_editMode) {
      return Positioned(left: cx - half, top: cy - half, child: joyWidget);
    }
    return _EditableJoystick(
      id: id,
      panelSize: size,
      baseSize: baseSize,
      layout: layout,
      allLayouts: allLayouts,
      snapToGrid: _showGrid,
      selected: selected,
      dimmed: dimmed,
      locked: _lockedIds.contains(id),
      onSelect: () => _selectJoystick(id),
      onChanged: (next) {
        setState(() => _layout[id] = next);
      },
      onStart: () {
        _pushHistory();
        _beginDrag();
      },
      onEnd: () {
        _saveLayout();
        _endDrag();
      },
      onGuideChanged: (guide) {
        _setGuideVisibility(
          guide.showVertical,
          guide.showHorizontal,
          snap: guide.snap,
          guideV: guide.verticalX,
          guideH: guide.horizontalY,
        );
      },
      onCollision: _showOverlapWarning,
      onBoundaryWarning: _showBoundaryWarning,
      externalWarning: _editWarningId == id,
      child: joyWidget,
    );
  }

  Widget _buildButton({
    required String id,
    required String label,
    required String asset,
    required Size size,
    required double baseSize,
    required _JoyLayout layout,
    required Map<String, _JoyLayout> allLayouts,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final btnSize = baseSize * layout.size;
    final half = btnSize / 2;
    final cx = (layout.cx * size.width).clamp(half, size.width - half);
    final cy = (layout.cy * size.height).clamp(half, size.height - half);
    final btnWidget = SizedBox(
      width: btnSize,
      height: btnSize,
      child: _JoyImagePressHoldButton(
        label: label,
        asset: asset,
        diameter: btnSize,
        onPressChanged: (down) => _onButtonChanged(id, down),
      ),
    );
    if (!_editMode) {
      return Positioned(left: cx - half, top: cy - half, child: btnWidget);
    }
    return _EditableButtonItem(
      id: id,
      panelSize: size,
      baseSize: baseSize,
      layout: layout,
      allLayouts: allLayouts,
      snapToGrid: _showGrid,
      selected: selected,
      dimmed: dimmed,
      locked: _lockedIds.contains(id),
      asset: asset,
      onSelect: () => _selectJoystick(id),
      onChanged: (next) {
        setState(() => _layout[id] = next);
      },
      onStart: () {
        _pushHistory();
        _beginDrag();
      },
      onEnd: () {
        _saveLayout();
        _endDrag();
      },
      onGuideChanged: (guide) {
        _setGuideVisibility(
          guide.showVertical,
          guide.showHorizontal,
          snap: guide.snap,
          guideV: guide.verticalX,
          guideH: guide.horizontalY,
        );
      },
      onCollision: _showOverlapWarning,
      onBoundaryWarning: _showBoundaryWarning,
      externalWarning: _editWarningId == id,
      child: btnWidget,
    );
  }
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

class _JoyImagePressHoldButton extends StatefulWidget {
  final String label;
  final String asset;
  final double diameter;
  final ValueChanged<bool>? onPressChanged;
  const _JoyImagePressHoldButton({
    required this.label,
    required this.asset,
    this.diameter = 120,
    this.onPressChanged,
  });
  @override
  State<_JoyImagePressHoldButton> createState() =>
      _JoyImagePressHoldButtonState();
}

class _JoyImagePressHoldButtonState extends State<_JoyImagePressHoldButton> {
  bool _pressed = false;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  void _onDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    HapticFeedback.lightImpact();
    gamepadBuzz();
    widget.onPressChanged?.call(true);
  }

  void _onUpOrCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onPressChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _pressed ? 0.95 : 1.0;
    final glowColor = _opacity(
      theme.colorScheme.primary,
      theme.brightness == Brightness.dark ? 0.65 : 0.45,
    );
    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUpOrCancel(),
      onPointerCancel: (_) => _onUpOrCancel(),
      child: SizedBox(
        width: widget.diameter,
        height: widget.diameter,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ColorFiltered(
                colorFilter: _pressed
                    ? const ColorFilter.matrix([
                        1,
                        0,
                        0,
                        0,
                        51,
                        0,
                        1,
                        0,
                        0,
                        51,
                        0,
                        0,
                        1,
                        0,
                        51,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.matrix([
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, __) {
                    return SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _opacity(theme.colorScheme.onSurface, 0.35),
                            width: 1.4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.label,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSnapshot {
  final Map<String, _JoyLayout> layout;
  final Set<String> activeIds;
  final Set<String> lockedIds;
  final String? selectedId;
  const _EditSnapshot({
    required this.layout,
    required this.activeIds,
    required this.lockedIds,
    required this.selectedId,
  });
}

class _JoyLayout {
  final double cx;
  final double cy;
  final double size;
  const _JoyLayout(this.cx, this.cy, this.size);
  _JoyLayout copyWith({double? cx, double? cy, double? size}) {
    return _JoyLayout(cx ?? this.cx, cy ?? this.cy, size ?? this.size);
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'size': size};
}

class _EditableJoystick extends StatefulWidget {
  final String id;
  final Size panelSize;
  final double baseSize;
  final _JoyLayout layout;
  final Map<String, _JoyLayout> allLayouts;
  final bool snapToGrid;
  final bool selected;
  final bool dimmed;
  final bool locked;
  final VoidCallback onSelect;
  final ValueChanged<_JoyLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback? onStart;
  final ValueChanged<_GuideState>? onGuideChanged;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  final bool externalWarning;
  final Widget child;
  const _EditableJoystick({
    required this.id,
    required this.panelSize,
    required this.baseSize,
    required this.layout,
    required this.allLayouts,
    required this.snapToGrid,
    required this.selected,
    required this.dimmed,
    required this.locked,
    required this.onSelect,
    required this.onChanged,
    required this.onEnd,
    this.onStart,
    this.onGuideChanged,
    this.onCollision,
    this.onBoundaryWarning,
    this.externalWarning = false,
    required this.child,
  });
  @override
  State<_EditableJoystick> createState() => _EditableJoystickState();
}

class _EditableJoystickState extends State<_EditableJoystick> {
  late Offset _startFocal;
  late _JoyLayout _startLayout;
  static const double _safeEdgePad = 16.0;
  static const double _edgeWarnThresholdPx = 6.0;
  static const double _guideShowThreshold = 0.035;
  static const double _guideSnapThreshold = 0.018;
  bool _dragging = false;
  bool _colliding = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onSelect();
      return;
    }
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
    _dragging = false;
    _nearEdgeWarning = false;
    widget.onGuideChanged?.call(const _GuideState.hidden());
    widget.onStart?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (widget.locked || !widget.selected) return;
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    final moved = dx.abs() > 1 || dy.abs() > 1;
    if (moved && !_dragging) {
      setState(() => _dragging = true);
    }
    final nextSize = (_startLayout.size * d.scale).clamp(
      kJoyMinSize,
      kJoyMaxSize,
    );
    final sizePx = widget.baseSize * nextSize;
    final half = sizePx / 2;
    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;
    if (widget.snapToGrid) {
      cx = GamepadEditMetrics.snapToGrid(cx);
      cy = GamepadEditMetrics.snapToGrid(cy);
    }
    final normalizedCx = cx / w;
    final normalizedCy = cy / h;
    final dxCenter = (normalizedCx - 0.5).abs();
    final dyCenter = (normalizedCy - 0.5).abs();
    final showV = dxCenter <= _guideShowThreshold;
    final showH = dyCenter <= _guideShowThreshold;
    final snapV = dxCenter <= _guideSnapThreshold;
    final snapH = dyCenter <= _guideSnapThreshold;
    if (snapV) cx = w * 0.5;
    if (snapH) cy = h * 0.5;
    widget.onGuideChanged?.call(
      _GuideState(
        showVertical: showV,
        showHorizontal: showH,
        verticalX: 0.5,
        horizontalY: 0.5,
        snap: snapV || snapH,
      ),
    );
    final minX = _safeEdgePad + half;
    final maxX = w - _safeEdgePad - half;
    final minY = _safeEdgePad + half;
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
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherBase = _isButtonId(entry.key)
          ? (_baseBtnSize(w, h))
          : widget.baseSize;
      final otherSizePx = otherBase * other.size;
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(widget.layout.cx * w, widget.layout.cy * h),
        fromRadius: widget.baseSize * widget.layout.size / 2,
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
    widget.onChanged(_JoyLayout(cx / w, cy / h, nextSize));
  }

  double _baseBtnSize(double w, double h) => math.min(w, h) * 0.45 * 0.55;
  bool _isButtonId(String id) {
    return id == kBtnTriangleId ||
        id == kBtnCrossId ||
        id == kBtnSquareId ||
        id == kBtnCircleId;
  }

  @override
  Widget build(BuildContext context) {
    final joySize = widget.baseSize * widget.layout.size;
    final half = joySize / 2;
    final cx = (widget.layout.cx * widget.panelSize.width).clamp(
      _safeEdgePad + half,
      widget.panelSize.width - _safeEdgePad - half,
    );
    final cy = (widget.layout.cy * widget.panelSize.height).clamp(
      _safeEdgePad + half,
      widget.panelSize.height - _safeEdgePad - half,
    );
    final showWarning =
        _colliding || _nearEdgeWarning || widget.externalWarning;
    return Positioned(
      left: cx - half,
      top: cy - half,
      child: GestureDetector(
        onScaleStart: widget.locked ? null : _onScaleStart,
        onScaleUpdate: widget.locked ? null : _onScaleUpdate,
        onScaleEnd: widget.locked
            ? null
            : (_) {
                widget.onGuideChanged?.call(const _GuideState.hidden());
                if (_colliding || _dragging || _nearEdgeWarning) {
                  setState(() {
                    _colliding = false;
                    _dragging = false;
                    _nearEdgeWarning = false;
                  });
                }
                widget.onEnd();
              },
        onTap: widget.onSelect,
        child: SizedBox(
          width: joySize,
          height: joySize,
          child: GamepadEditSelectionVisual(
            selected: widget.selected,
            dimmed: widget.dimmed,
            warning: showWarning,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: widget.selected || showWarning
                    ? null
                    : Border.all(color: Colors.white70, width: 2),
              ),
              child: IgnorePointer(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableButtonItem extends StatefulWidget {
  final String id;
  final Size panelSize;
  final double baseSize;
  final _JoyLayout layout;
  final Map<String, _JoyLayout> allLayouts;
  final bool snapToGrid;
  final bool selected;
  final bool dimmed;
  final bool locked;
  final String asset;
  final VoidCallback onSelect;
  final ValueChanged<_JoyLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback? onStart;
  final ValueChanged<_GuideState>? onGuideChanged;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  final bool externalWarning;
  final Widget child;
  const _EditableButtonItem({
    required this.id,
    required this.panelSize,
    required this.baseSize,
    required this.layout,
    required this.allLayouts,
    required this.snapToGrid,
    required this.selected,
    required this.dimmed,
    required this.locked,
    required this.asset,
    required this.onSelect,
    required this.onChanged,
    required this.onEnd,
    this.onStart,
    this.onGuideChanged,
    this.onCollision,
    this.onBoundaryWarning,
    this.externalWarning = false,
    required this.child,
  });
  @override
  State<_EditableButtonItem> createState() => _EditableButtonItemState();
}

class _EditableButtonItemState extends State<_EditableButtonItem> {
  late Offset _startFocal;
  late _JoyLayout _startLayout;
  static const double _safeEdgePad = 16.0;
  static const double _snapThresholdPx = 5.0;
  static const double _edgeWarnThresholdPx = 6.0;
  bool _dragging = false;
  bool _colliding = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onSelect();
      return;
    }
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
    _dragging = false;
    _nearEdgeWarning = false;
    widget.onGuideChanged?.call(const _GuideState.hidden());
    widget.onStart?.call();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (widget.locked || !widget.selected) return;
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    final moved = dx.abs() > 1 || dy.abs() > 1;
    if (moved && !_dragging) {
      setState(() => _dragging = true);
    }
    final nextSize = (_startLayout.size * d.scale).clamp(
      kJoyBtnMinSize,
      kJoyBtnMaxSize,
    );
    final sizePx = widget.baseSize * nextSize;
    final half = sizePx / 2;
    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;
    if (widget.snapToGrid) {
      cx = GamepadEditMetrics.snapToGrid(cx);
      cy = GamepadEditMetrics.snapToGrid(cy);
    }
    double? snapX;
    double? snapY;
    var bestDx = _snapThresholdPx + 1;
    var bestDy = _snapThresholdPx + 1;
    final centerX = w / 2;
    final centerY = h / 2;
    final dxCenter = (cx - centerX).abs();
    if (dxCenter <= _snapThresholdPx) {
      snapX = centerX;
      bestDx = dxCenter;
    }
    final dyCenter = (cy - centerY).abs();
    if (dyCenter <= _snapThresholdPx) {
      snapY = centerY;
      bestDy = dyCenter;
    }
    for (final entry in widget.allLayouts.entries) {
      if (entry.key == widget.id) continue;
      if (!_isButtonEditId(entry.key)) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final dxOther = (cx - ox).abs();
      final dyOther = (cy - oy).abs();
      if (dxOther <= _snapThresholdPx && dxOther < bestDx) {
        snapX = ox;
        bestDx = dxOther;
      }
      if (dyOther <= _snapThresholdPx && dyOther < bestDy) {
        snapY = oy;
        bestDy = dyOther;
      }
    }
    if (snapX != null) cx = snapX;
    if (snapY != null) cy = snapY;
    widget.onGuideChanged?.call(
      _GuideState(
        showVertical: snapX != null,
        showHorizontal: snapY != null,
        verticalX: snapX != null ? snapX / w : null,
        horizontalY: snapY != null ? snapY / h : null,
        snap: snapX != null || snapY != null,
      ),
    );
    final minX = _safeEdgePad + half;
    final maxX = w - _safeEdgePad - half;
    final minY = _safeEdgePad + half;
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
      final otherSizePx = widget.baseSize * other.size;
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(widget.layout.cx * w, widget.layout.cy * h),
        fromRadius: widget.baseSize * widget.layout.size / 2,
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
    widget.onChanged(_JoyLayout(cx / w, cy / h, nextSize));
  }

  @override
  Widget build(BuildContext context) {
    final btnSize = widget.baseSize * widget.layout.size;
    final half = btnSize / 2;
    final cx = (widget.layout.cx * widget.panelSize.width).clamp(
      _safeEdgePad + half,
      widget.panelSize.width - _safeEdgePad - half,
    );
    final cy = (widget.layout.cy * widget.panelSize.height).clamp(
      _safeEdgePad + half,
      widget.panelSize.height - _safeEdgePad - half,
    );
    final buttonContent = SizedBox(
      width: btnSize,
      height: btnSize,
      child: IgnorePointer(child: widget.child),
    );
    return GamepadEditableButtonFrame(
      left: cx - half,
      top: cy - half,
      width: btnSize,
      height: btnSize,
      locked: widget.locked,
      selected: widget.selected,
      dimmed: widget.dimmed,
      warning:
          (_colliding && _dragging) ||
          _nearEdgeWarning ||
          widget.externalWarning,
      selectionMask: Padding(
        padding: const EdgeInsets.all(2),
        child: Image.asset(
          widget.asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: (_) {
        widget.onGuideChanged?.call(const _GuideState.hidden());
        if (_colliding || _dragging || _nearEdgeWarning) {
          setState(() {
            _colliding = false;
            _dragging = false;
            _nearEdgeWarning = false;
          });
        }
        widget.onEnd();
      },
      onTap: widget.onSelect,
      child: buttonContent,
    );
  }

  bool _isButtonEditId(String id) {
    return id == kBtnTriangleId ||
        id == kBtnCrossId ||
        id == kBtnSquareId ||
        id == kBtnCircleId;
  }
}
