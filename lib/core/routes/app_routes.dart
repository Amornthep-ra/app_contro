// lib/core/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../../features/home/home_page.dart';
import '../../features/bluetooth/bluetooth_ble_page.dart';
import '../../features/gamepad/gamepad_4_button_page.dart';
import '../../features/gamepad/gamepad_8_button_page.dart';
import '../../features/joystick/joystick/presentation/mode1_dual_joystick.dart';
import '../../features/joystick/joystick/presentation/mode2_joystick_buttons.dart';
import '../../features/joystick/joystick_test_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String bluetoothBle = '/bluetooth-ble';
  static const String gamepad4Button = '/gamepad-4-button';
  static const String gamepad8Button = '/gamepad-8-button';
  static const String dualJoystickMode1 = '/dual-joystick-mode1';
  static const String joystickMode2Buttons = '/joystick-mode2-buttons';
  static const String joystickTest = '/joystick-test';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());

      case bluetoothBle:
        return MaterialPageRoute(builder: (_) => const BluetoothBlePage());

      case gamepad4Button:
        return MaterialPageRoute(builder: (_) => const Gamepad_4_Botton());

      case gamepad8Button:
        return MaterialPageRoute(builder: (_) => const Gamepad_8_Botton());

      case dualJoystickMode1:
        return MaterialPageRoute(builder: (_) => const Mode1DualJoystickPage());

      case joystickMode2Buttons:
        return MaterialPageRoute(builder: (_) => const Mode2JoystickButtonsPage());

      case joystickTest:
        return MaterialPageRoute(builder: (_) => const JoystickTestPage());

      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}
