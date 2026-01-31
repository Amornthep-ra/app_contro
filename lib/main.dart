// lib/main.dart
import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/ui/theme_controller.dart';
import 'core/ui/language_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.init();
  await LanguageController.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'PrinceBot Controller',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [LoggingNavigatorObserver()],
          themeMode: mode,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: lightScheme.onSurface,
                  displayColor: lightScheme.onSurface,
                ),
            iconTheme: IconThemeData(color: lightScheme.onSurface),
            appBarTheme: AppBarTheme(
              foregroundColor: lightScheme.onSurface,
              iconTheme: IconThemeData(color: lightScheme.onSurface),
              titleTextStyle: ThemeData.light()
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: lightScheme.onSurface),
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
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            textTheme: ThemeData.dark().textTheme.apply(
                  bodyColor: darkScheme.onSurface,
                  displayColor: darkScheme.onSurface,
                ),
            iconTheme: IconThemeData(color: darkScheme.onSurface),
            appBarTheme: AppBarTheme(
              foregroundColor: darkScheme.onSurface,
              iconTheme: IconThemeData(color: darkScheme.onSurface),
              titleTextStyle: ThemeData.dark()
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: darkScheme.onSurface),
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

// TEMP: log route changes to find unexpected pops on iOS.
class LoggingNavigatorObserver extends NavigatorObserver {
  LoggingNavigatorObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[nav] push ${route.settings.name ?? route.runtimeType}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[nav] pop ${route.settings.name ?? route.runtimeType}');
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[nav] remove ${route.settings.name ?? route.runtimeType}');
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint(
      '[nav] replace ${oldRoute?.settings.name ?? oldRoute?.runtimeType}'
      ' -> ${newRoute?.settings.name ?? newRoute?.runtimeType}',
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
