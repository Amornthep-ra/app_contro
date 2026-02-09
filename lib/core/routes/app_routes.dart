// lib/core/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../../features/home/home_page.dart';
import '../../features/controller/controller_home_page.dart';
import '../../features/linesonic/linesonic_page.dart';
import '../../features/bluetooth/bluetooth_ble_page.dart';
import '../../features/gamepad/gamepad_4_button_page.dart';
import '../../features/gamepad/gamepad_mode_edit.dart';
import '../../features/joystick/joystick/presentation/joystick.dart';
import '../../features/joystick/joystick_test_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String controller = '/controller';
  static const String lineSonic = '/linesonic';
  static const String bluetoothBle = '/bluetooth-ble';
  static const String gamepad4Button = '/gamepad-4-button';
  static const String gamepad8Button = '/gamepad-8-button';
  static const String dualJoystickMode1 = '/dual-joystick-mode1';
  static const String joystickTest = '/joystick-test';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());

      case controller:
        return MaterialPageRoute(builder: (_) => const ControllerHomePage());

      case lineSonic:
        return MaterialPageRoute(builder: (_) => const LineSonicPage());

      case bluetoothBle:
        return MaterialPageRoute(builder: (_) => const BluetoothBlePage());

      case gamepad4Button:
        return MaterialPageRoute(builder: (_) => const Gamepad4ButtonPage());

      case gamepad8Button:
        return MaterialPageRoute(builder: (_) => const GamepadModeEdit());

      case dualJoystickMode1:
        return MaterialPageRoute(builder: (_) => const JoystickPage());


      case joystickTest:
        return MaterialPageRoute(builder: (_) => const JoystickTestPage());

      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}
