import 'package:shared_preferences/shared_preferences.dart';

import 'control_mode.dart';

/// The last control mode the user opened. This deliberately does not keep
/// live control state such as pressed buttons or active BLE commands.
class ControlModePreference {
  ControlModePreference._();

  static const _key = 'last_control_mode';

  static Future<ControlMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'eight_button' => ControlMode.eightButton,
      'joystick' => ControlMode.joystick,
      _ => ControlMode.fourButton,
    };
  }

  static Future<void> save(ControlMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (mode) {
      ControlMode.fourButton => 'four_button',
      ControlMode.eightButton => 'eight_button',
      ControlMode.joystick => 'joystick',
    });
  }
}
