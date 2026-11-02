import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/widgets/gamepad_edit_hint.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  for (final mode in <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  }.entries) {
    testWidgets('${mode.key}: layout editor explains what to do', (
      tester,
    ) async {
      await mount(tester, mode.value());
      expect(find.byKey(const ValueKey('gamepad-edit-hint')), findsNothing);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit layout'));
      await tester.tap(find.text('Edit layout'));
      await tester.pumpAndSettle();

      expect(find.text(GamepadEditHint.idleMessage), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('start-stop-edit-handle')));
      await tester.pumpAndSettle();
      expect(find.text(GamepadEditHint.selectedMessage), findsOneWidget);

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gamepad-edit-hint')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('8-button speed panel spells out Drive and Turn', (tester) async {
    await mount(tester, const GamepadModeEdit());
    expect(find.text('Drive'), findsNothing);

    await tester.tap(find.text('Speed').first);
    await tester.pumpAndSettle();

    // Short labels the Arduino examples use stay; full words are added.
    expect(find.text('DRV'), findsOneWidget);
    expect(find.text('TRN'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.text('Turn'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
