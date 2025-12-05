// lib/core/utils/orientation_utils.dart
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

  static Future<void> setLandscapeOnly() async {
    return setLandscape();
  }

  static Future<void> setPortraitOnly() async {
    return setPortrait();
  }

  static Future<void> setAuto() async {
    return reset();
  }
}
