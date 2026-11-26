import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The control session shared by the three control pages
/// (ControlPageMixin): Start, Stop, the editor and leaving the page.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<int?> acquire() async =>
      BleManager.instance.claimTrafficMode(BleTrafficMode.controlBinary);

  final modes = <String, Widget Function()>{
    'four-button': () => Gamepad4ButtonPage(acquireControl: acquire),
    'eight-button': () => GamepadModeEdit(acquireControl: acquire),
    'joystick': () => JoystickPage(acquireControl: acquire),
  };

  void useLandscapePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Gives control back the way a test would find it: a text-mode owner
  /// can claim the link only once no control owner holds it.
  void expectControlReleased() {
    final textOwner = BleManager.instance.claimTrafficMode(
      BleTrafficMode.textCommand,
    );
    expect(textOwner, isNotNull, reason: 'control owner still held');
    BleManager.instance.releaseTrafficMode(textOwner!);
  }

  for (final mode in modes.entries) {
    testWidgets(
      '${mode.key}: Back while driving releases control and leaves once',
      (tester) async {
        useLandscapePhone(tester);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Root')),
          ),
        );
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Home')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(builder: (_) => mode.value()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ControlStartStopButton));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);

        final back = find.byType(GamepadAppBarBackButton);
        await tester.tap(back);
        await tester.tap(back, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Root'), findsNothing);
        expectControlReleased();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${mode.key}: opening the editor stops driving', (
      tester,
    ) async {
      useLandscapePhone(tester);
      await tester.pumpWidget(MaterialApp(home: mode.value()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit layout'));
      await tester.pumpAndSettle();
      expectControlReleased();

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Start control'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
