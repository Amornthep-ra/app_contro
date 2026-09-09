import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:pb_controller/features/linesonic/linesonic_pid_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  for (final joystick in [false, true]) {
    for (final newerOwner in [false, true]) {
      testWidgets(
        'abandoned Start cleans only its owner: joystick=$joystick newer=$newerOwner',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final completion = Completer<int?>();
          int? pendingOwner;
          Future<int?> acquire() {
            pendingOwner = BleManager.instance.claimTrafficMode(
              BleTrafficMode.controlBinary,
            );
            return completion.future;
          }

          final navigator = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              home: const Scaffold(body: Text('Home')),
            ),
          );
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => joystick
                    ? JoystickPage(acquireControl: acquire)
                    : Gamepad4ButtonPage(acquireControl: acquire),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(GamepadStartStopControlButton));
          await tester.pump();
          expect(pendingOwner, isNotNull);
          await navigator.currentState!.maybePop();
          // Complete one case during the exit animation, while still mounted.
          if (newerOwner) {
            await tester.pumpAndSettle();
          } else {
            await tester.pump();
          }
          int? replacement;
          if (newerOwner) {
            BleManager.instance.releaseTrafficMode(pendingOwner!);
            replacement = BleManager.instance.claimTrafficMode(
              BleTrafficMode.controlBinary,
            );
          }
          completion.complete(pendingOwner);
          await tester.pumpAndSettle();
          expect(find.text('Home'), findsOneWidget);
          final textOwner = BleManager.instance.claimTrafficMode(
            BleTrafficMode.textCommand,
          );
          if (newerOwner) {
            expect(textOwner, isNull);
            BleManager.instance.releaseTrafficMode(replacement!);
          } else {
            expect(textOwner, isNotNull);
            BleManager.instance.releaseTrafficMode(textOwner!);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final directRemoval in [false, true]) {
    testWidgets('PID saves pending edits on exit: removal=$directRemoval', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => const LineSonicPidPage()),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      await tester.enterText(field, '17');
      // Exit before the 400 ms debounce can run.
      if (directRemoval) {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        await navigator.currentState!.maybePop();
      }
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('linesonic_steps_v2')!) as List;
      expect((saved.first as Map).values, contains('17'));
      await tester.pumpWidget(const MaterialApp(home: LineSonicPidPage()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '17',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
