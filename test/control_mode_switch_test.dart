// Settings → pick another mode → Edit layout / Saved layouts lands in that
// mode's editor or saved layouts, without a second trip through Settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/routes/app_routes.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          call,
        ) async {
          return call.method == 'hasVibrator' ? true : null;
        });
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<void> start(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        onGenerateInitialRoutes: (_) => [
          AppRoutes.onGenerateRoute(RouteSettings(name: route)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> inSettings(WidgetTester tester, List<String> taps) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    for (final label in taps) {
      // Settings' Back is an icon with a "Back" label for screen readers.
      final target = label == 'Back'
          ? find.bySemanticsLabel('Back')
          : find.text(label);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
  }

  Future<void> finish(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('4 BTN: pick Joystick, Edit layout → the Joystick editor', (
    tester,
  ) async {
    await start(tester, AppRoutes.gamepad4Button);
    await inSettings(tester, ['Joystick', 'Edit layout']);

    expect(find.byType(JoystickPage), findsOneWidget);
    expect(find.byType(Gamepad4ButtonPage), findsNothing);
    // The layout editor's tools are showing.
    expect(find.byTooltip('Done'), findsOneWidget);
    expect(find.byTooltip('Buttons'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Joystick: pick 8 BTN, Saved layouts → 8 BTN saved layouts', (
    tester,
  ) async {
    await start(tester, AppRoutes.dualJoystickMode1);
    await inSettings(tester, ['8 BTN', 'Saved layouts']);

    expect(find.byType(GamepadModeEdit), findsOneWidget);
    expect(find.byType(JoystickPage), findsNothing);
    expect(_byTypeName('_ControlPresetDialog'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('8 BTN: pick 4 BTN, Back → 4 BTN, ready to drive', (
    tester,
  ) async {
    await start(tester, AppRoutes.gamepad8Button);
    await inSettings(tester, ['4 BTN', 'Back']);

    expect(find.byType(Gamepad4ButtonPage), findsOneWidget);
    expect(find.byType(GamepadModeEdit), findsNothing);
    expect(find.byTooltip('Buttons'), findsNothing);
    await finish(tester);
  });

  testWidgets('8 BTN: Edit layout without changing mode stays on 8 BTN', (
    tester,
  ) async {
    await start(tester, AppRoutes.gamepad8Button);
    await inSettings(tester, ['Edit layout']);

    expect(find.byType(GamepadModeEdit), findsOneWidget);
    expect(find.byTooltip('Buttons'), findsOneWidget);
    await finish(tester);
  });
}
