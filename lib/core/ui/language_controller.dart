import 'package:flutter/foundation.dart';

/// The application supports English only.
class LanguageController {
  LanguageController._();

  static final ValueNotifier<bool> isThai = ValueNotifier<bool>(false);

  static Future<void> init() async {
    isThai.value = false;
  }

  static Future<void> setIsThai(bool _) async {
    isThai.value = false;
  }
}
