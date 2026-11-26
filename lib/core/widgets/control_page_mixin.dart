import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_manager.dart';
import '../ui/control_mode.dart';
import 'control_start_stop.dart';
import 'gamepad_appbar_controls.dart';
import 'pairing_code_dialog.dart';

/// What the 4 BTN, 8 BTN and Joystick pages share: the control session
/// (BLE ownership, Start/Stop, leaving the page), the layout editor and
/// opening from Settings. Each page only says what it sends.
///
/// Call [initControlSession] from `initState` and [disposeControlSession]
/// from `dispose`.
mixin ControlPageMixin<T extends StatefulWidget> on State<T> {
  /// BLE traffic owner while this page holds control; null otherwise.
  int? controlOwner;
  bool controlStarted = false;
  bool startInProgress = false;

  /// Set once the page starts leaving (Back or dispose); nothing may start.
  bool leavingControlPage = false;

  /// Set while the page hands control over to another mode's page.
  bool modeSwitchInProgress = false;

  StreamSubscription<bool>? _controlConnectionSub;

  bool get editMode;

  /// Name given to the BLE owner, also the prefix of its log sources.
  String get controlOwnerName;

  /// Test seam: replaces [BleConnectionCoordinator.acquireControlForStart].
  Future<int?> Function()? get acquireControlOverride;

  /// Starts the page's periodic send loop, if it has one.
  void startControlLoop();

  /// Stops the page's periodic send loop, if it has one.
  void stopControlLoop();

  /// Stops all sending for good: the page is leaving.
  void stopSendingForExit() => stopControlLoop();

  /// Sends the first (neutral) packet right after Start.
  void sendStartPacket();

  /// Sends the stop packet when giving control back on a normal exit.
  Future<void> sendExitStop(int owner) async {
    final manager = BleManager.instance;
    if (manager.isConnected) await manager.sendControlStop(owner: owner);
  }

  /// Clears held buttons and sticks.
  void resetInputState();
  void toggleEdit();
  Future<void> showPresetSheet();

  bool get canStartControl =>
      !leavingControlPage && !startInProgress && !modeSwitchInProgress;

  /// Whether a control packet may go out now.
  bool get canSendControl =>
      controlStarted &&
      !startInProgress &&
      !modeSwitchInProgress &&
      controlOwner != null &&
      !BleManager.instance.controlSuspendedForLifecycle;

  void initControlSession() {
    BleManager.instance.controlSuspendedListenable.addListener(
      handleControlSuspended,
    );
    _controlConnectionSub = BleManager.instance.connectionStream.listen((
      connected,
    ) {
      if (!mounted) return;
      resetInputState();
      if (!connected) {
        stopControlLoop();
        setState(() => controlStarted = false);
        unawaited(releaseControl());
      }
    });
  }

  void disposeControlSession() {
    leavingControlPage = true;
    stopSendingForExit();
    _controlConnectionSub?.cancel();
    BleManager.instance.controlSuspendedListenable.removeListener(
      handleControlSuspended,
    );
    unawaited(releaseControl());
  }

  Future<void> startControl() async {
    if (controlStarted || !canStartControl) return;
    setState(() => startInProgress = true);
    final owner =
        await (acquireControlOverride?.call() ??
            BleConnectionCoordinator.instance.acquireControlForStart(
              ownerName: controlOwnerName,
            ));
    // Give control back if the page left, switched mode or opened the
    // editor while Start was pending.
    if (!mounted || leavingControlPage || modeSwitchInProgress || editMode) {
      if (owner != null) {
        await BleManager.instance.stopAndReleaseControl(owner: owner);
      }
      if (mounted) setState(() => startInProgress = false);
      return;
    }
    if (owner == null) {
      setState(() => startInProgress = false);
      if (requiresBlePairingCode(
        BleConnectionCoordinator.instance.state.securityState,
      )) {
        final paired = await promptForBlePairingCode(context: context);
        if (paired == true && mounted) {
          await startControl();
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
    controlOwner = owner;
    resetInputState();
    setState(() {
      startInProgress = false;
      controlStarted = true;
    });
    startControlLoop();
    sendStartPacket();
  }

  Future<void> stopControl() async {
    if (!controlStarted) return;
    stopControlLoop();
    resetInputState();
    if (mounted) setState(() => controlStarted = false);
    await releaseControl(emergency: true);
  }

  /// Gives BLE control back. [emergency] stops the robot like Emergency
  /// Stop; otherwise it sends the stop packet and releases the traffic mode.
  Future<void> releaseControl({bool emergency = false}) async {
    final owner = controlOwner;
    controlOwner = null;
    if (owner == null) return;
    final manager = BleManager.instance;
    if (emergency) {
      await manager.emergencyStopAndReleaseControl(
        owner: owner,
        source: '${controlOwnerName}_emergency_stop',
      );
      return;
    }
    manager.disableControlReconnect(owner);
    try {
      await sendExitStop(owner);
    } finally {
      manager.releaseTrafficMode(owner);
    }
  }

  /// Leaves the page (app bar Back and system back): once only, after
  /// control was given back.
  Future<void> exitControlPage() async {
    if (leavingControlPage) return;
    leavingControlPage = true;
    stopSendingForExit();
    await releaseControl();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        Navigator.defaultRouteName,
        (route) => false,
      );
    }
  }

  /// Entering the editor stops driving like Emergency Stop; driving again
  /// needs Start. Call from [toggleEdit] before flipping [editMode].
  void stopControlForEditor() {
    if (!editMode && controlStarted) unawaited(stopControl());
  }

  void showStartFirstNotice() {
    showGamepadTopNotice(
      context,
      message: 'Tap Start to drive',
      style: GamepadNoticeStyle.warning,
    );
  }

  Widget buildToolbarStartStop() {
    return ValueListenableBuilder<bool>(
      valueListenable: BleManager.instance.controlSuspendedListenable,
      builder: (context, suspended, _) => ControlStartStopButton(
        started: controlStarted && !suspended,
        busy: startInProgress,
        onPressed: controlStarted && !suspended
            ? stopControl
            : (canStartControl ? startControl : null),
      ),
    );
  }

  /// Listener of the BLE control suspension (app sent to the background):
  /// the robot was stopped, so the page shows Start again.
  void handleControlSuspended() {
    if (!BleManager.instance.controlSuspendedForLifecycle || !controlStarted) {
      return;
    }
    stopControlLoop();
    resetInputState();
    if (mounted) setState(() => controlStarted = false);
  }

  /// Reached by switching from Settings: open the editor or Saved layouts
  /// once the saved layout has loaded and the pad has been laid out.
  Future<void> openAfterLoad(Future<void> loaded, ControlModeOpen open) async {
    await loaded;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openFromSettings(open);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Opens what Settings asked for, on this page.
  void openFromSettings(ControlModeOpen? open) {
    switch (open) {
      case ControlModeOpen.layoutEditor:
        if (!editMode) toggleEdit();
      case ControlModeOpen.savedLayouts:
        unawaited(showPresetSheet());
      case null:
        break;
    }
  }
}
