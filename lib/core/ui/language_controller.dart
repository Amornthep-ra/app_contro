// lib/core/ui/language_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController {
  static const _prefsKey = 'app_language_is_thai';
  static final ValueNotifier<bool> isThai = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isThai.value = prefs.getBool(_prefsKey) ?? false;
  }

  static Future<void> setIsThai(bool next) async {
    isThai.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, next);
  }
}


