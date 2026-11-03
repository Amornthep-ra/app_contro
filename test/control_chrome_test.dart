import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/app_assets.dart';
import 'package:pb_controller/core/widgets/control_background.dart';
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

      // Selecting by tap works in the test layout for 4 BTN and Joystick.
      // (8 BTN edit items are not hit-testable at this test size, also before
      // this change, so only the idle hint is checked there.)
      if (mode.key != 'eight-button') {
        final controls = find.byWidgetPredicate(
          (w) => const {
            '_EditableButton',
            '_EditableButtonItem',
            '_EditableJoystick',
          }.contains(w.runtimeType.toString()),
        );
        for (var i = 0; i < controls.evaluate().length; i++) {
          await tester.tap(controls.at(i), warnIfMissed: false);
          await tester.pumpAndSettle();
          if (find
              .text(GamepadEditHint.selectedMessage)
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        expect(find.text(GamepadEditHint.selectedMessage), findsOneWidget);
      }

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

  test('background veil only on short screens', () {
    expect(ControlBackground.veilStrengthFor(411), 0);
    expect(ControlBackground.veilStrengthFor(400), 0);
    expect(ControlBackground.veilStrengthFor(370), closeTo(0.5, 1e-9));
    expect(ControlBackground.veilStrengthFor(340), 1);
    expect(ControlBackground.veilStrengthFor(300), 1);
  });

  for (final entry in <String, (Size, bool)>{
    'phone 914x411': (const Size(914, 411), false),
    'small 640x360': (const Size(640, 360), true),
  }.entries) {
    testWidgets('control background on ${entry.key}', (tester) async {
      final (size, veiled) = entry.value;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Gamepad4ButtonPage()));
      await tester.pumpAndSettle();

      // The original artwork is still the background.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == AppAssets.controlBackground,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('control-background-veil')),
        veiled ? findsOneWidget : findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
