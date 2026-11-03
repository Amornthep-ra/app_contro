// Home must be portrait again after leaving a control page, also when
// Settings switched the control mode (the control page replaced itself).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/routes/app_routes.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<List<Object?>> orientationCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.pbcontroller.app',
      version: '2.2.0',
      buildNumber: '22',
      buildSignature: '',
    );
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
    orientationCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientationCalls.add(List<Object?>.from(call.arguments as List));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('vibration'), (
      call,
    ) async {
      return call.method == 'hasVibrator' ? true : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const portrait = [
    'DeviceOrientation.portraitUp',
    'DeviceOrientation.portraitDown',
  ];

  testWidgets('Home is portrait after switching mode in Settings, then Back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        navigatorObservers: [appRouteObserver],
      ),
    );
    await tester.pumpAndSettle();

    // Home → Controller opens the last mode (4 BTN by default).
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    expect(find.byType(Gamepad4ButtonPage), findsOneWidget);

    // Settings → 8 BTN → Back: 4 BTN is replaced by 8 BTN.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8 BTN'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(GamepadModeEdit), findsOneWidget);
    expect(orientationCalls.last, isNot(portrait));

    // Back on the 8 BTN page returns to Home, which must be portrait.
    await tester.tap(find.byType(GamepadAppBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(GamepadModeEdit), findsNothing);
    expect(orientationCalls.last, portrait);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
