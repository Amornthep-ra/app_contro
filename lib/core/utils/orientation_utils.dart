// lib/core/utils/orientation_utils.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppOrientation { portrait, landscape }

class OrientationUtils {
  static AppOrientation? _requested;
  static Future<void> _pending = Future.value();

  /// The only orientation entry point for application screens.
  ///
  /// Requests are serialized and an obsolete queued request is skipped so a
  /// route being disposed cannot override its replacement route's orientation.
  static Future<void> request(AppOrientation orientation) {
    if (_requested == orientation) return _pending;
    _requested = orientation;

    _pending = _pending.then((_) async {
      if (_requested != orientation) return;
      await SystemChrome.setPreferredOrientations(switch (orientation) {
        AppOrientation.landscape => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        AppOrientation.portrait => const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      });
    });
    return _pending;
  }

  static Future<void> setLandscape() => request(AppOrientation.landscape);

  static Future<void> setPortrait() => request(AppOrientation.portrait);

  static Future<void> reset() {
    _requested = null;
    _pending = _pending.then(
      (_) => SystemChrome.setPreferredOrientations(DeviceOrientation.values),
    );
    return _pending;
  }

  @visibleForTesting
  static void resetForTesting() {
    _requested = null;
    _pending = SynchronousFuture<void>(null);
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
