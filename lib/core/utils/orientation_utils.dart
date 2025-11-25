// lib/utils/orientation_utils.dart
import 'package:flutter/services.dart';

class OrientationUtils {
  static Future<void> setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  static Future<void> setPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static Future<void> reset() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}
