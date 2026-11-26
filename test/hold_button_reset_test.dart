import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/gamepad_components.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the page clears input (Stop, a connection change, suspend), a
/// button still held stops looking pressed and ignores that finger until
/// it lifts, like Joystick's buttons.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<int?> acquire() async =>
      BleManager.instance.claimTrafficMode(BleTrafficMode.controlBinary);

  final pages = <String, Widget Function()>{
    'four-button': () => Gamepad4ButtonPage(acquireControl: acquire),
    'eight-button': () => GamepadModeEdit(acquireControl: acquire),
  };

  double scaleOf(WidgetTester tester, Finder button) => tester
      .widget<AnimatedScale>(
        find.descendant(of: button, matching: find.byType(AnimatedScale)),
      )
      .scale;

  for (final page in pages.entries) {
    testWidgets('${page.key}: a held button lets go when input is reset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(914, 411);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('vibration'),
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('vibration'),
          null,
        ),
      );
      await tester.pumpWidget(MaterialApp(home: page.value()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();

      final button = find.byType(GamepadImageHoldButton).first;
      final finger = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester, button), 0.95);

      BleManager.instance.debugEmitConnectionChangeForTesting(true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester, button), 1.0);

      // The same finger moving on the button does not press it again.
      await finger.moveBy(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester, button), 1.0);

      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      final again = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scaleOf(tester, button), 0.95);
      await again.up();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
