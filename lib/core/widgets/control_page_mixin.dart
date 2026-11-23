import 'dart:async';

import 'package:flutter/widgets.dart';

import '../ble/ble_manager.dart';
import '../ui/control_mode.dart';
import 'control_start_stop.dart';
import 'gamepad_appbar_controls.dart';

/// What the 4 BTN, 8 BTN and Joystick pages share around Start/Stop, the
/// layout editor and opening from Settings. Starting and stopping control
/// (BLE ownership and sending) stays in each page.
mixin ControlPageMixin<T extends StatefulWidget> on State<T> {
  bool get controlStarted;
  set controlStarted(bool value);
  bool get startInProgress;
  bool get canStartControl;
  bool get editMode;

  Future<void> startControl();
  Future<void> stopControl();

  /// Stops the page's periodic send loop, if it has one.
  void stopControlLoop();

  /// Clears held buttons and sticks.
  void resetInputState();
  void toggleEdit();
  Future<void> showPresetSheet();

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
