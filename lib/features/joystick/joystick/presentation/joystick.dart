// lib/pages/joystick.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../../../../core/widgets/gamepad_controls_sheet.dart';
import '../../../../core/ui/control_mode.dart';
import '../../../../core/ui/control_mode_preference.dart';
import '../../../../core/ui/gamepad_components.dart';
import '../../../../core/ui/app_assets.dart';
import '../../../../core/widgets/gamepad_app_bar.dart';
import '../../../../core/widgets/gamepad_appbar_controls.dart';
import '../../../../core/widgets/control_preset_slots.dart';
import '../../../../core/widgets/gamepad_telemetry_chip.dart';
import '../../../../core/widgets/gamepad_edit_notices.dart';
import '../../../../core/widgets/gamepad_edit_shared.dart';
import '../../../../core/widgets/gamepad_edit_toolbar.dart';
import '../../../../core/widgets/pairing_code_dialog.dart';
import '../../../gamepad/control_mode_settings_page.dart';

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

/// Each joystick and the one-axis variant that drives the same axes. Only
/// one of a pair can be on the pad: releasing one would zero the axes the
/// other is still holding.
const Map<String, String> kJoyAxisPartner = {
  kJoyLeftId: kJoyYOnlyId,
  kJoyYOnlyId: kJoyLeftId,
  kJoyRightId: kJoyXOnlyId,
  kJoyXOnlyId: kJoyRightId,
};

/// Face buttons on the Joystick pad (everything else is a joystick).
const Set<String> kJoyButtonIds = {
  kBtnTriangleId,
  kBtnCrossId,
  kBtnSquareId,
  kBtnCircleId,
};

/// Smallest joystick drawn: its knob still travels ~34 dp from the centre,
/// enough to set a speed between stop and full.
const double kJoyStickMinDiameter = 96.0;

/// Diameter of a size-1 joystick (or face button) on [panel]. Uses the
/// same capped pad unit as the gamepad buttons, so a tablet does not get
/// a stick so large the thumb must travel across half the screen.
double joyBasePx(Size panel, {required bool button}) =>
    GamepadEditMetrics.panelUnit(panel) * 0.45 * (button ? 0.55 : 1.0);

/// Drawn and touched diameter of control [id] at [size] on [panel], never
/// below a pressable button or a usable stick.
double joyControlDiameter(String id, double size, Size panel) {
  final button = kJoyButtonIds.contains(id);
  return GamepadEditMetrics.fitDiameter(
    GamepadEditMetrics.diameterFor(
      size,
      joyBasePx(panel, button: button),
      minDiameter: button
          ? GamepadEditMetrics.minTouchDiameter
          : kJoyStickMinDiameter,
    ),
    panel,
    16.0, // the editor's edge margin on this pad
  );
}

/// Smallest size factor the editor offers for control [id] on [panel].
double joyMinSizeFactor(String id, Size panel) {
  final button = kJoyButtonIds.contains(id);
  return GamepadEditMetrics.minSizeFactor(
    button ? kJoyBtnMinSize : kJoyMinSize,
    joyBasePx(panel, button: button),
    minDiameter: button
        ? GamepadEditMetrics.minTouchDiameter
        : kJoyStickMinDiameter,
  );
}

/// Every control the Joystick pad can show.
const Set<String> kJoyKnownIds = {
  kJoyLeftId,
  kJoyRightId,
  kJoyYOnlyId,
  kJoyXOnlyId,
  kBtnTriangleId,
  kBtnCrossId,
  kBtnSquareId,
  kBtnCircleId,
};

/// [ids] with a one-axis joystick dropped when its full joystick is also
/// there (older layouts and presets allowed both).
Set<String> dropDuplicateAxisJoysticks(Iterable<String> ids) {
  final out = ids.toSet();
  if (out.contains(kJoyLeftId)) out.remove(kJoyYOnlyId);
  if (out.contains(kJoyRightId)) out.remove(kJoyXOnlyId);
  return out;
}

/// Saved control ids made safe to show: unknown ids and duplicate axis
/// joysticks dropped, and the default pad when nothing is left.
Set<String> sanitizeJoyActiveIds(Iterable<String> ids) {
  final out = dropDuplicateAxisJoysticks(ids.where(kJoyKnownIds.contains));
  return out.isEmpty ? Set<String>.from(kJoyDefaultActiveIds) : out;
}

class JoystickPage extends StatefulWidget {
  const JoystickPage({
    super.key,
    this.acquireControl,
    this.openOnArrival,
    this.sendControlPacket,
  });

  // Optional transport seam for exercising delayed Start completion in tests.
  final Future<int?> Function()? acquireControl;

  /// Test seam: receives each control packet the page sends (with its
  /// pressed buttons and whether it bypasses BLE rate limiting) instead of
  /// BleManager.
  @visibleForTesting
  final void Function(JoystickPacket packet, Set<int> buttons, bool force)?
  sendControlPacket;

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

  /// Space the editor leaves above the pad so it is as tall as when
  /// driving (see [gamepadEditorTopInset]); 0 while driving.
  double _editorTopInset = 0.0;

  /// Margin the editor keeps between a control and the pad's edge.
  static const double _editEdgePad = 16.0;
  static const _prefsPreset1 = 'joy_preset_1';
  static const _prefsPreset2 = 'joy_preset_2';
  static const _prefsPreset3 = 'joy_preset_3';
  static const _prefsPreset4 = 'joy_preset_4';
  static const _prefsPreset5 = 'joy_preset_5';
  bool _editMode = false;
  bool _menuOpen = false;
  String? _selectedId;
  Size? _panelSize;
  Map<String, GamepadButtonLayout> _layout = {};
  Set<String> _activeIds = {kJoyLeftId, kJoyRightId};
  final Set<String> _lockedIds = {};
  final _history = GamepadEditHistory<_EditSnapshot>();
  int _dragCount = 0;
  bool _showVGuide = false;
  bool _showHGuide = false;
  bool _guideSnap = false;
  double? _guideV;
  double? _guideH;
  String? _editWarningId;
  Timer? _editWarningTimer;
  final _editNotices = GamepadEditNotices();
  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;
  int _lastButtonsKey = 0;
  double _smoothLX = 0.0, _smoothLY = 0.0;
  double _smoothRX = 0.0, _smoothRY = 0.0;

  /// Where each stick is held (after the dead zone); the sent values above
  /// move toward these.
  double _targetLX = 0.0, _targetLY = 0.0;
  double _targetRX = 0.0, _targetRY = 0.0;
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
  bool _showGrid = false;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  StreamSubscription<bool>? _bleConnSub;
  int? _bleTrafficOwner;
  bool _startInProgress = false;
  bool _leavingControlPage = false;
  bool _controlStarted = false;
  bool _modeSwitchInProgress = false;

  /// Tells the sticks and face buttons that input was cleared, so they
  /// stop showing a held position and ignore fingers still down (J-4).
  final _inputResetSignal = ValueNotifier<int>(0);

  void _signalInputReset() {
    if (mounted) _inputResetSignal.value++;
  }

  void _resetInputState() {
    _signalInputReset();
    void apply() {
      _clearStickTargets();
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
    final testSink = widget.sendControlPacket;
    if (testSink != null) {
      testSink(packet, buttons ?? const <int>{}, force);
      return;
    }
    unawaited(
      BleManager.instance.sendJoystickBinary(
        packet: packet,
        pressedButtons: buttons ?? const <int>{},
        owner: owner,
        force: force,
      ),
    );
  }

  void _clearStickTargets() {
    _targetLX = 0;
    _targetLY = 0;
    _targetRX = 0;
    _targetRY = 0;
  }

  void _resetLeftJoystick() {
    _targetLX = 0;
    _targetLY = 0;
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
    _targetRX = 0;
    _targetRY = 0;
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
    // Also give control back if the editor opened while Start was pending.
    if (!mounted || _leavingControlPage || _modeSwitchInProgress || _editMode) {
      if (owner != null) {
        await BleManager.instance.stopAndReleaseControl(owner: owner);
      }
      if (mounted) setState(() => _startInProgress = false);
      return;
    }
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
    _signalInputReset();
    _clearStickTargets();
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
      _stepSticks();
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
      // A send right after a forced one (e.g. one stick released) would be
      // dropped by BleManager yet recorded here as sent. Skip the tick so the
      // next one, 25 ms later, sends the latest value.
      if (isWithinBinaryMinGap(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        lastSendMs: _lastControlSendMs,
      )) {
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
    _leftDebug.dispose();
    _rightDebug.dispose();
    _inputResetSignal.dispose();
    super.dispose();
  }

  double _deadZoned(double raw) => raw.abs() < _deadZone ? 0.0 : raw;

  /// One smoothing step from [from] toward [to], landing exactly on [to]
  /// once within 0.005 so a held stick sends its full value.
  double _approach(double from, double to) {
    final next = _lerp(from, to, _smooth);
    return (next - to).abs() < 0.005 ? to : next;
  }

  void _stepLeft() {
    _smoothLX = _approach(_smoothLX, _targetLX);
    _smoothLY = _approach(_smoothLY, _targetLY);
    _controller.setLeftJoystick(_smoothLX, _smoothLY);
    _updateLeftDebug(_smoothLX, _smoothLY);
  }

  void _stepRight() {
    _smoothRX = _approach(_smoothRX, _targetRX);
    _smoothRY = _approach(_smoothRY, _targetRY);
    _controller.setRightJoystick(_smoothRX, _smoothRY);
    _updateRightDebug(_smoothRX, _smoothRY);
  }

  /// Moves each stick's sent value toward where the finger holds it. Touch
  /// events stop while a finger is still, so without this a stick pushed
  /// to the rim and held sent only ~85 %.
  void _stepSticks() {
    if (_smoothLX != _targetLX || _smoothLY != _targetLY) _stepLeft();
    if (_smoothRX != _targetRX || _smoothRY != _targetRY) _stepRight();
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
  double _baseBtnSize(Size panel) => joyBasePx(panel, button: true);
  Map<String, GamepadButtonLayout> _defaultLayout(
    Size panel,
    Set<String> active,
  ) {
    final out = <String, GamepadButtonLayout>{};
    if (active.contains(kJoyLeftId)) {
      out[kJoyLeftId] = const GamepadButtonLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyYOnlyId)) {
      out[kJoyYOnlyId] = const GamepadButtonLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyRightId)) {
      out[kJoyRightId] = const GamepadButtonLayout(0.75, 0.5, 1.0);
    }
    if (active.contains(kJoyXOnlyId)) {
      out[kJoyXOnlyId] = const GamepadButtonLayout(0.75, 0.5, 1.0);
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
        out[joyId] = GamepadButtonLayout(
          tightenedCx,
          tightenedCy,
          joySizeScale,
        );
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
      _activeIds = sanitizeJoyActiveIds(decodeGamepadIdList(activeRaw));
    } else {
      _activeIds = {kJoyLeftId, kJoyRightId};
    }
    _layout.removeWhere((k, _) => !_activeIds.contains(k));
    _lockedIds.removeWhere((id) => !_layout.containsKey(id));
    if (mounted) setState(() {});
  }

  Future<void> _saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsLayout,
      jsonEncode(encodeGamepadLayout(_layout)),
    );
  }

  Future<void> _saveActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActive, jsonEncode(_activeIds.toList()));
  }

  Map<String, GamepadButtonLayout> _decodeLayout(String raw) =>
      decodeGamepadLayout(
        raw,
        minSize: (id) => _isButtonId(id) ? kJoyBtnMinSize : kJoyMinSize,
        maxSize: (id) => _isButtonId(id) ? kJoyBtnMaxSize : kJoyMaxSize,
        defaultSize: 1.0,
      );

  void _toggleEdit() {
    // The editor is not for driving: entering it stops the robot like
    // Emergency Stop, and driving again needs Start. (While editing the
    // page sends nothing, not even keepalives.)
    if (!_editMode && _controlStarted) unawaited(_stopControl());
    setState(() {
      _editMode = !_editMode;
      if (_editMode && _panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        // Edit what the pad shows, already fitted to this screen.
        _layout = Map<String, GamepadButtonLayout>.from(
          _fitToPanel(_panelSize!, {...defaults, ..._layout}, _layout),
        );
      }
    });
  }

  /// Active controls in fitting order: joysticks keep their spots and
  /// buttons move out of their way, after controls the user placed
  /// ([saved]) have kept theirs.
  static const List<String> _fitOrder = [
    kJoyLeftId,
    kJoyYOnlyId,
    kJoyRightId,
    kJoyXOnlyId,
    kBtnTriangleId,
    kBtnCrossId,
    kBtnSquareId,
    kBtnCircleId,
  ];

  /// [layout] with the active controls moved, where needed, to fit inside
  /// the pad's edge margin without overlapping (see
  /// [GamepadEditMetrics.fitLayout]). Returns [layout] itself when nothing
  /// had to move.
  Map<String, GamepadButtonLayout> _fitToPanel(
    Size panel,
    Map<String, GamepadButtonLayout> layout,
    Map<String, GamepadButtonLayout> saved,
  ) {
    final w = panel.width;
    final h = panel.height;
    final placed = [
      for (final id in GamepadEditMetrics.savedFirst(
        _fitOrder,
        saved.containsKey,
      ))
        if (_activeIds.contains(id) && layout[id] != null) (id, layout[id]!),
    ];
    double radius(String id, GamepadButtonLayout l) =>
        joyControlDiameter(id, l.size, panel) / 2;
    final fitted = GamepadEditMetrics.fitLayout(
      panel: panel,
      pad: const EdgeInsets.all(_editEdgePad),
      controls: [
        for (final (id, l) in placed)
          (Offset(l.cx * w, l.cy * h), radius(id, l)),
      ],
    );
    Map<String, GamepadButtonLayout>? out;
    for (var i = 0; i < placed.length; i++) {
      final (id, l) = placed[i];
      final spot = fitted[i];
      if ((spot - Offset(l.cx * w, l.cy * h)).distance <= 0.5) continue;
      out ??= Map<String, GamepadButtonLayout>.from(layout);
      out[id] = GamepadButtonLayout(spot.dx / w, spot.dy / h, l.size);
    }
    return out ?? layout;
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

  _EditSnapshot _captureSnapshot() {
    return _EditSnapshot(
      layout: cloneGamepadLayout(_layout),
      activeIds: Set<String>.from(_activeIds),
      lockedIds: Set<String>.from(_lockedIds),
      selectedId: _selectedId,
    );
  }

  void _applySnapshot(_EditSnapshot snap) {
    _layout = cloneGamepadLayout(snap.layout);
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

  void _pushHistory() => _history.push(_captureSnapshot());

  void _undo() {
    if (!_history.canUndo) return;
    setState(() {
      _applySnapshot(_history.undo(_captureSnapshot()));
    });
    _saveLayout();
    _saveActive();
  }

  void _redo() {
    if (!_history.canRedo) return;
    setState(() {
      _applySnapshot(_history.redo(_captureSnapshot()));
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
      } else if (_activeIds.contains(kJoyAxisPartner[id])) {
        // A full joystick and its one-axis variant drive the same axes, so
        // only one of them can be on the pad: the new one takes its place.
        final partner = kJoyAxisPartner[id]!;
        final panel = _panelSize;
        final spot =
            _layout[partner] ??
            (panel == null ? null : _defaultLayout(panel, _activeIds)[partner]);
        _activeIds.remove(partner);
        _layout.remove(partner);
        _lockedIds.remove(partner);
        if (_selectedId == partner) _selectedId = id;
        if (_isLeftJoy(partner)) _resetLeftJoystick();
        if (_isRightJoy(partner)) _resetRightJoystick();
        _activeIds.add(id);
        if (spot != null) _layout[id] = spot;
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
  GamepadButtonLayout _placeOnFreeSpot(
    String id,
    GamepadButtonLayout def,
    Size panel,
  ) {
    double radius(String key, GamepadButtonLayout layout) =>
        joyControlDiameter(key, layout.size, panel) / 2;
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
    return GamepadButtonLayout(spot.dx / w, spot.dy / h, def.size);
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
        : <String, GamepadButtonLayout>{};
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

  Future<void> _savePreset(int slot, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, Object>{
      'layout': encodeGamepadLayout(_layout),
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
      // Undo in the editor brings back what was on the pad before.
      _pushHistory();
      _clearButtonState(null);
      if (layoutRaw is Map) {
        _layout = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (activeRaw is List) {
        _activeIds = sanitizeJoyActiveIds(activeRaw.map((e) => e.toString()));
      }
      _layout.removeWhere((k, _) => !_activeIds.contains(k));
      _lockedIds.clear();
      _selectedId = null;
      _editWarningId = null;
      if (_panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        _layout = {...defaults, ..._layout};
      }
      setState(() {});
      _saveLayout();
      _saveActive();
    } catch (_) {}
  }

  Future<void> _showPresetSheet() => showControlPresetSheet(
    context: context,
    presetKey: _presetKey,
    onSave: (slot, name) => _savePreset(slot, name: name),
    onLoad: _loadPreset,
  );

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

  void _showSizeLimit(bool atMax) =>
      _editNotices.showSizeLimit(context, atMax: atMax);

  void _showSizeEdgeWarning() {
    const msg = 'Buttons must stay inside the safe zone.';
    showGamepadTopNotice(
      context,
      message: msg,
      duration: const Duration(milliseconds: 900),
      style: GamepadNoticeStyle.warning,
    );
  }

  void _showBoundaryWarning() => _editNotices.showBoundaryWarning(context);

  void _showOverlapWarning() => _editNotices.showOverlapWarning(context);

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
    double px(String key, double size) => joyControlDiameter(key, size, panel);
    // Never below a pressable button or a usable stick on this screen.
    final minSize = joyMinSizeFactor(id, panel);
    final maxSize = _isButtonId(id) ? kJoyBtnMaxSize : kJoyMaxSize;
    final nextSize = (current.size + delta).clamp(minSize, maxSize);
    if (delta < 0 ? nextSize >= current.size : nextSize <= current.size) {
      _showSizeLimit(delta > 0);
      _flashEditWarning(id);
      return;
    }
    final sizePx = px(id, nextSize);
    final half = sizePx / 2;
    final rawCx = current.cx * w;
    final rawCy = current.cy * h;
    const safeEdgePad = 16.0;
    final minX = safeEdgePad + half;
    final maxX = w - safeEdgePad - half;
    final minY = safeEdgePad + half;
    final maxY = h - safeEdgePad - half;
    // Shrinking is always allowed, in place: it is how a control that an
    // older layout or another screen size left past the edge gets fixed.
    final growing = nextSize > current.size;
    if (growing &&
        (rawCx < minX || rawCx > maxX || rawCy < minY || rawCy > maxY)) {
      HapticFeedback.vibrate();
      _showBoundaryWarning();
      _flashEditWarning(id);
      return;
    }
    final double cx = growing ? rawCx.clamp(minX, maxX) : rawCx;
    final double cy = growing ? rawCy.clamp(minY, maxY) : rawCy;
    final edgeAdjusted = (cx - rawCx).abs() > 0.01 || (cy - rawCy).abs() > 0.01;
    var collides = false;
    for (final entry in _layout.entries) {
      if (entry.key == id) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherSizePx = px(entry.key, other.size);
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(current.cx * w, current.cy * h),
        fromRadius: px(id, current.size) / 2,
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
    _pushHistory();
    setState(() {
      final next = Map<String, GamepadButtonLayout>.from(_layout);
      next[id] = GamepadButtonLayout(cx / w, cy / h, nextSize);
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
    // Over exactly the joystick pad, so the grid lines up with snapping.
    return Positioned.fill(
      top: _editorTopInset,
      child: const GamepadEditGrid(),
    );
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
    // force: a press or release must not be dropped by the BLE rate
    // limiter (a send within 20 ms of the last one), or a short tap could
    // never reach the robot and a release could arrive 150 ms late.
    _sendBinary(
      _controller.buildPacket(),
      buttons: _pressedButtons(),
      force: true,
    );
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
      top: _editorTopInset,
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
          message: 'Use Emergency Stop before managing BLE.',
          style: GamepadNoticeStyle.ble,
        ),
      ),
      GamepadAppBarActionGroup(
        gap: actionGap,
        items: [
          GamepadAppBarActionItem(
            label: 'Settings',
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
          appBarMetrics: appBarMetrics,
          actionGap: uniformGap,
        ),
      ],
    );
  }

  Widget _buildCenteredEditAppBar() {
    final selectedId = _selectedId;
    // Buttons chooses which joysticks and buttons (△ ✕ □ ○) are on the pad.
    return GamepadEditToolbar(
      buttonsKey: const ValueKey('joystick-edit-controls'),
      hasSelection: selectedId != null,
      selectedLocked: selectedId != null && _lockedIds.contains(selectedId),
      showGrid: _showGrid,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
      buzzOnTap: true,
      onDone: _toggleEdit,
      onButtons: _openButtonsMenu,
      onToggleLock: _toggleSelectedLock,
      onChangeSize: _adjustSelectedSize,
      onToggleGrid: () => setState(() => _showGrid = !_showGrid),
      onUndo: _undo,
      onRedo: _redo,
      onReset: _resetLayout,
      onDelete: _removeSelected,
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
    final playLayout = GamepadControlLayout.measure(context, [
      '',
      '',
      'CMD 255',
      'X:-1.00 Y:-1.00',
      'X:-1.00 Y:-1.00',
      '@ble',
      '',
    ], leadingCount: 2);
    final controlLayout = _editMode ? null : playLayout;
    final width = MediaQuery.of(context).size.width;
    final appBarMetrics = GamepadAppBarMetrics.forWidth(width);
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
    // The editor's pad matches the driving pad's size exactly.
    _editorTopInset = _editMode
        ? gamepadEditorTopInset(
            playLayout: playLayout,
            viewportWidth: width - MediaQuery.paddingOf(context).horizontal,
            textScaleFactor: textScaleFactor,
          )
        : 0.0;
    final cmdMetrics = appBarMetrics;
    final axisMetrics = appBarMetrics;
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
                  ? _buildCenteredEditAppBar()
                  : _buildAppBarToolbarRow(
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
                      Padding(
                        padding: EdgeInsets.only(top: _editorTopInset),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final size = Size(c.maxWidth, c.maxHeight);
                            _panelSize = size;
                            final defaults = _defaultLayout(size, _activeIds);
                            final effective = _fitToPanel(size, {
                              ...defaults,
                              ..._layout,
                            }, _layout);
                            final widgets = <Widget>[];
                            if (_activeIds.contains(kJoyLeftId)) {
                              widgets.add(
                                _buildJoystick(
                                  id: kJoyLeftId,
                                  size: size,
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
                                  layout: effective[kBtnCircleId]!,
                                  allLayouts: effective,
                                ),
                              );
                            }
                            return ControlInputGate(
                              started: _controlStarted,
                              editing: _editMode,
                              suspended: BleManager
                                  .instance
                                  .controlSuspendedListenable,
                              onLockedTap: _showStartFirstNotice,
                              child: Stack(children: widgets),
                            );
                          },
                        ),
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
    required GamepadButtonLayout layout,
    required Map<String, GamepadButtonLayout> allLayouts,
    required bool isLeft,
    required JoystickAxisLock axisLock,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final joySize = joyControlDiameter(id, layout.size, size);
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
        resetSignal: _inputResetSignal,
        onChanged: (x, y) {
          if (_editMode) return;
          // Each touch event sets where the stick should go and takes one
          // smoothing step; the 25 ms tick keeps stepping (see _stepSticks)
          // so a finger held still still reaches its value.
          if (isLeft) {
            if (x == 0 && y == 0) {
              _resetLeftJoystick();
              return;
            }
            _targetLX = _deadZoned(x);
            _targetLY = _deadZoned(y);
            _stepLeft();
          } else {
            if (x == 0 && y == 0) {
              _resetRightJoystick();
              return;
            }
            _targetRX = _deadZoned(x);
            _targetRY = _deadZoned(y);
            _stepRight();
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
    required GamepadButtonLayout layout,
    required Map<String, GamepadButtonLayout> allLayouts,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final btnSize = joyControlDiameter(id, layout.size, size);
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
        resetSignal: _inputResetSignal,
        onPressChanged: (down) => _onButtonChanged(id, down),
      ),
    );
    if (!_editMode) {
      return Positioned(left: cx - half, top: cy - half, child: btnWidget);
    }
    return _EditableButtonItem(
      id: id,
      panelSize: size,
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

class _JoyImagePressHoldButton extends StatefulWidget {
  final String label;
  final String asset;
  final double diameter;
  final ValueChanged<bool>? onPressChanged;

  /// Input was cleared by the page: drop the pressed look without
  /// reporting a release. A finger still down stays ignored until every
  /// finger on the button lifts (CircularHoldDetector reports no new
  /// press while one is held).
  final Listenable? resetSignal;
  const _JoyImagePressHoldButton({
    required this.label,
    required this.asset,
    this.diameter = 120,
    this.onPressChanged,
    this.resetSignal,
  });
  @override
  State<_JoyImagePressHoldButton> createState() =>
      _JoyImagePressHoldButtonState();
}

class _JoyImagePressHoldButtonState extends State<_JoyImagePressHoldButton> {
  bool _pressed = false;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  @override
  void initState() {
    super.initState();
    widget.resetSignal?.addListener(_onInputReset);
  }

  @override
  void didUpdateWidget(_JoyImagePressHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetSignal != widget.resetSignal) {
      oldWidget.resetSignal?.removeListener(_onInputReset);
      widget.resetSignal?.addListener(_onInputReset);
    }
  }

  @override
  void dispose() {
    widget.resetSignal?.removeListener(_onInputReset);
    super.dispose();
  }

  void _onInputReset() {
    if (_pressed) setState(() => _pressed = false);
  }

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
    return CircularHoldDetector(
      onHoldChanged: (held) => held ? _onDown() : _onUpOrCancel(),
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
  final Map<String, GamepadButtonLayout> layout;
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

class _EditableJoystick extends StatefulWidget {
  final String id;
  final Size panelSize;
  final GamepadButtonLayout layout;
  final Map<String, GamepadButtonLayout> allLayouts;
  final bool snapToGrid;
  final bool selected;
  final bool dimmed;
  final bool locked;
  final VoidCallback onSelect;
  final ValueChanged<GamepadButtonLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback? onStart;
  final ValueChanged<GamepadEditGuideState>? onGuideChanged;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  final bool externalWarning;
  final Widget child;
  const _EditableJoystick({
    required this.id,
    required this.panelSize,
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
  Offset _startFocal = Offset.zero;
  GamepadButtonLayout _startLayout = const GamepadButtonLayout(0, 0, 0);

  /// True only while a drag that began on the already-selected control is
  /// running. A touch on an unselected control just selects it; the rest of
  /// that gesture must not move it, even though it is selected by then.
  bool _gestureActive = false;
  static const double _safeEdgePad = 16.0;
  static const double _edgeWarnThresholdPx = 6.0;
  static const double _guideShowThreshold = 0.035;
  static const double _guideSnapThreshold = 0.018;
  bool _dragging = false;
  bool _colliding = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    _gestureActive = false;
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onSelect();
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
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    final moved = dx.abs() > 1 || dy.abs() > 1;
    if (moved && !_dragging) {
      setState(() => _dragging = true);
    }
    // A plain drag (scale 1) keeps the size; pinching stays within the
    // editor's range, never below a usable stick.
    final nextSize = d.scale == 1.0
        ? _startLayout.size
        : (_startLayout.size * d.scale).clamp(
            joyMinSizeFactor(widget.id, widget.panelSize),
            kJoyMaxSize,
          );
    final sizePx = _px(widget.id, nextSize);
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
      GamepadEditGuideState(
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
      final otherSizePx = _px(entry.key, other.size);
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(widget.layout.cx * w, widget.layout.cy * h),
        fromRadius: _px(widget.id, widget.layout.size) / 2,
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
    widget.onChanged(GamepadButtonLayout(cx / w, cy / h, nextSize));
  }

  double _px(String id, double size) =>
      joyControlDiameter(id, size, widget.panelSize);

  @override
  Widget build(BuildContext context) {
    final joySize = _px(widget.id, widget.layout.size);
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
  final GamepadButtonLayout layout;
  final Map<String, GamepadButtonLayout> allLayouts;
  final bool snapToGrid;
  final bool selected;
  final bool dimmed;
  final bool locked;
  final String asset;
  final VoidCallback onSelect;
  final ValueChanged<GamepadButtonLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback? onStart;
  final ValueChanged<GamepadEditGuideState>? onGuideChanged;
  final VoidCallback? onCollision;
  final VoidCallback? onBoundaryWarning;
  final bool externalWarning;
  final Widget child;
  const _EditableButtonItem({
    required this.id,
    required this.panelSize,
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
  Offset _startFocal = Offset.zero;
  GamepadButtonLayout _startLayout = const GamepadButtonLayout(0, 0, 0);

  /// True only while a drag that began on the already-selected control is
  /// running. A touch on an unselected control just selects it; the rest of
  /// that gesture must not move it, even though it is selected by then.
  bool _gestureActive = false;
  static const double _safeEdgePad = 16.0;
  static const double _snapThresholdPx = 5.0;
  static const double _edgeWarnThresholdPx = 6.0;
  bool _dragging = false;
  bool _colliding = false;
  bool _nearEdgeWarning = false;
  void _onScaleStart(ScaleStartDetails d) {
    _gestureActive = false;
    if (widget.locked) return;
    if (!widget.selected) {
      widget.onSelect();
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
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;
    final moved = dx.abs() > 1 || dy.abs() > 1;
    if (moved && !_dragging) {
      setState(() => _dragging = true);
    }
    // A plain drag (scale 1) keeps the size; pinching stays within the
    // editor's range, never below a pressable button.
    final nextSize = d.scale == 1.0
        ? _startLayout.size
        : (_startLayout.size * d.scale).clamp(
            joyMinSizeFactor(widget.id, widget.panelSize),
            kJoyBtnMaxSize,
          );
    final sizePx = _px(widget.id, nextSize);
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
      GamepadEditGuideState(
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
    // Keep clear of every control on the pad, joysticks included.
    var collides = false;
    for (final entry in widget.allLayouts.entries) {
      if (entry.key == widget.id) continue;
      final other = entry.value;
      final ox = other.cx * w;
      final oy = other.cy * h;
      final otherSizePx = _px(entry.key, other.size);
      if (GamepadEditMetrics.crowdsNeighbour(
        fromCentre: Offset(widget.layout.cx * w, widget.layout.cy * h),
        fromRadius: _px(widget.id, widget.layout.size) / 2,
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
    widget.onChanged(GamepadButtonLayout(cx / w, cy / h, nextSize));
  }

  double _px(String id, double size) =>
      joyControlDiameter(id, size, widget.panelSize);

  @override
  Widget build(BuildContext context) {
    final btnSize = _px(widget.id, widget.layout.size);
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
        final began = _gestureActive;
        _gestureActive = false;
        if (!began) return;
        widget.onGuideChanged?.call(const GamepadEditGuideState.hidden());
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
