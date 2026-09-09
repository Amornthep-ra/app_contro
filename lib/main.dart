// lib/main.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/routes/app_routes.dart';
import 'core/ui/gamepad_skin.dart';
import 'core/ui/language_controller.dart';
import 'core/ble/ble_manager.dart';
import 'core/ble/ble_connection_coordinator.dart';
import 'core/utils/orientation_utils.dart';

TextStyle? _withFonts(TextStyle? style, String family, List<String> fallback) {
  if (style == null) return null;
  return style.copyWith(fontFamily: family, fontFamilyFallback: fallback);
}

TextTheme _applyFonts(TextTheme base, String family, List<String> fallback) {
  return base.copyWith(
    displayLarge: _withFonts(base.displayLarge, family, fallback),
    displayMedium: _withFonts(base.displayMedium, family, fallback),
    displaySmall: _withFonts(base.displaySmall, family, fallback),
    headlineLarge: _withFonts(base.headlineLarge, family, fallback),
    headlineMedium: _withFonts(base.headlineMedium, family, fallback),
    headlineSmall: _withFonts(base.headlineSmall, family, fallback),
    titleLarge: _withFonts(base.titleLarge, family, fallback),
    titleMedium: _withFonts(base.titleMedium, family, fallback),
    titleSmall: _withFonts(base.titleSmall, family, fallback),
    bodyLarge: _withFonts(base.bodyLarge, family, fallback),
    bodyMedium: _withFonts(base.bodyMedium, family, fallback),
    bodySmall: _withFonts(base.bodySmall, family, fallback),
    labelLarge: _withFonts(base.labelLarge, family, fallback),
    labelMedium: _withFonts(base.labelMedium, family, fallback),
    labelSmall: _withFonts(base.labelSmall, family, fallback),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrientationUtils.request(AppOrientation.portrait);
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove('app_theme_mode');
  await LanguageController.init();
  await BleConnectionCoordinator.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(BleManager.instance.handleAppLifecycleState(state));
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    const fontFamily = 'Roboto';
    const fontFallback = <String>[];
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, _, __) {
        final lightTextTheme = _applyFonts(
          ThemeData.light().textTheme.apply(
            bodyColor: lightScheme.onSurface,
            displayColor: lightScheme.onSurface,
          ),
          fontFamily,
          fontFallback,
        );

        return MaterialApp(
          title: 'PrinceBot Controller',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            extensions: const <ThemeExtension<dynamic>>[GamepadSkin.light()],
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            textTheme: lightTextTheme,
            iconTheme: IconThemeData(color: lightScheme.onSurface),
            appBarTheme: AppBarTheme(
              foregroundColor: lightScheme.onSurface,
              iconTheme: IconThemeData(color: lightScheme.onSurface),
              titleTextStyle: lightTextTheme.titleLarge?.copyWith(
                color: lightScheme.onSurface,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
              ),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
