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
      final applied = await _apply(switch (orientation) {
        AppOrientation.landscape => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        AppOrientation.portrait => const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      });
      // Not applied: let the same request try again next time.
      if (!applied && _requested == orientation) _requested = null;
    });
    return _pending;
  }

  static Future<void> setLandscape() => request(AppOrientation.landscape);

  static Future<void> setPortrait() => request(AppOrientation.portrait);

  static Future<void> reset() {
    _requested = null;
    _pending = _pending.then((_) => _apply(DeviceOrientation.values));
    return _pending;
  }

  /// Sets [orientations]; a platform failure is reported, not thrown, so
  /// one failed request cannot break every later one queued behind it.
  static Future<bool> _apply(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
      return true;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'orientation',
          context: ErrorDescription('while setting preferred orientations'),
        ),
      );
      return false;
    }
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
