import 'package:shared_preferences/shared_preferences.dart';

/// The last control surface the user opened. This deliberately does not keep
/// live control state such as pressed buttons or active BLE commands.
enum LastControlMode { fourButton, eightButton, joystick }

class ControlModePreference {
  ControlModePreference._();

  static const _key = 'last_control_mode';

  static Future<LastControlMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'eight_button' => LastControlMode.eightButton,
      'joystick' => LastControlMode.joystick,
      _ => LastControlMode.fourButton,
    };
  }

  static Future<void> save(LastControlMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (mode) {
      LastControlMode.fourButton => 'four_button',
      LastControlMode.eightButton => 'eight_button',
      LastControlMode.joystick => 'joystick',
    });
  }
}
