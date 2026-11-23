// lib/core/ui/control_mode.dart
import 'package:flutter/foundation.dart';

/// The three control pages: 4 BTN, 8 BTN and Joystick.
enum ControlMode { fourButton, eightButton, joystick }

/// What to open in the chosen control mode once Settings closes.
enum ControlModeOpen { layoutEditor, savedLayouts }

/// What Settings asks the control page to do when it closes: switch to
/// [mode] when it is not the page's own mode, then open [open] there.
///
/// So "pick Joystick, then Edit layout" lands in the Joystick editor in one
/// go, instead of editing the mode Settings was opened from.
@immutable
class ControlModeSettingsResult {
  const ControlModeSettingsResult(this.mode, {this.open});

  final ControlMode mode;
  final ControlModeOpen? open;
}

/// Route argument for a control page reached by switching from Settings.
@immutable
class ControlPageArguments {
  const ControlPageArguments({this.open});

  final ControlModeOpen? open;
}

String controlModeName(ControlMode mode) => switch (mode) {
  ControlMode.fourButton => '4 BTN',
  ControlMode.eightButton => '8 BTN',
  ControlMode.joystick => 'Joystick',
};
