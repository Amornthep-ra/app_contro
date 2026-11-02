// lib/core/ui/ambient_motion.dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Decorative, looping motion (ambient background, attention pulses).
///
/// Off under `flutter test` so `pumpAndSettle` can settle, and off whenever
/// the system "remove animations" accessibility setting is on.
class AmbientMotion {
  AmbientMotion._();

  static bool enabledByDefault = !_runningUnderFlutterTest();

  static bool _runningUnderFlutterTest() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Whether looping decorative motion should run in [context].
  static bool enabledFor(BuildContext context) =>
      enabledByDefault &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}
