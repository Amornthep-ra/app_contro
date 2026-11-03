import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/ui/ambient_motion.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/core/widgets/gamepad_control_toolbar.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRoboto() async {
  // Real glyph widths, so toolbar fitting matches a phone (the default test
  // font is much wider than any real font).
  final loader = FontLoader('Roboto');
  for (final path in [
    'assets/fonts/Roboto/static/Roboto-Regular.ttf',
    'assets/fonts/Roboto/static/Roboto-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(844, 390),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  final modes = <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  };

  for (final mode in modes.entries) {
    testWidgets('${mode.key}: Start/Stop sits in the toolbar after Back', (
      tester,
    ) async {
      await mount(tester, mode.value());

      final startStop = find.byType(ControlStartStopButton);
      expect(startStop, findsOneWidget);
      final start = tester.getRect(startStop);
      expect(start.size, const Size(48, 48));

      final back = tester.getRect(find.byType(GamepadAppBarBackButton));
      final settings = tester.getRect(find.byTooltip('Settings'));
      // Same size as Back, right next to it with the 16 px safety gap,
      // and on the same toolbar row.
      expect(back.size, start.size);
      expect(start.left - back.right, 16);
      expect(start.center.dy, back.center.dy);
      expect(settings.left, greaterThan(start.right));
      expect(tester.takeException(), isNull);

      // No Hero: a Hero shared by the three control pages made Start/Stop
      // fly over the page transition when switching modes.
      expect(
        find.descendant(of: startStop, matching: find.byType(Hero)),
        findsNothing,
      );
      expect(
        find.ancestor(of: startStop, matching: find.byType(Hero)),
        findsNothing,
      );

      // Not part of the layout editor any more.
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit layout'));
      await tester.tap(find.text('Edit layout'));
      await tester.pumpAndSettle();
      expect(startStop, findsNothing);
      expect(find.byKey(const ValueKey('start-hint')), findsNothing);

      await unmount(tester);
    });
  }

  for (final mode in <String, Widget Function(Future<int?> Function())>{
    'four-button': (acquire) => Gamepad4ButtonPage(acquireControl: acquire),
    'joystick': (acquire) => JoystickPage(acquireControl: acquire),
  }.entries) {
    testWidgets('${mode.key}: Start turns into Emergency Stop', (tester) async {
      await mount(tester, mode.value(() async => 1));

      expect(find.byKey(const ValueKey('start-hint')), findsOneWidget);
      expect(find.bySemanticsLabel('Start control'), findsOneWidget);

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);
      expect(find.byKey(const ValueKey('start-hint')), findsNothing);

      await unmount(tester);
    });
  }

  testWidgets('Start/Stop shows only its artwork, even with motion on', (
    tester,
  ) async {
    // No glow, halo or breathing ring: they were cut off by the cat ears,
    // paw and tail on the phone.
    AmbientMotion.enabledByDefault = true;
    addTearDown(() => AmbientMotion.enabledByDefault = false);
    for (final started in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ControlStartStopButton(
                started: started,
                busy: false,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final button = find.byType(ControlStartStopButton);
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        find.descendant(of: button, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: button, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the busy spinner centres on the round face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GamepadStartStopControlButton(
              isStarted: false,
              isBusy: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    // The face sits below the image centre (cat ears on top).
    final face = GamepadStartStopControlButton.faceOffset(48, started: false);
    expect(face.dy, closeTo(1.97, 0.01));
    expect(
      tester.getCenter(find.byType(CircularProgressIndicator)) -
          tester.getCenter(find.byType(GamepadStartStopControlButton)),
      offsetMoreOrLessEquals(face),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('old saved Start/Stop placement is ignored safely', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'gp4_layout_all_start_stop': jsonEncode({
        'v': 2,
        'cx': .2,
        'cy': .3,
        'scale': 2,
      }),
      'gp4_preset_1': jsonEncode({
        'name': 'Old layout',
        'startStop': {'cx': .1, 'cy': .1, 'scale': 2},
        'layout': <String, Object>{},
        'active': ['F:forward', 'F:backward', 'F:left', 'F:right'],
        'speed': 'Med',
      }),
    });
    await mount(tester, const Gamepad4ButtonPage());
    expect(
      tester.getSize(find.byType(ControlStartStopButton)),
      const Size(48, 48),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved layouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Load'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('joystick toolbar stays on one row on a 640 px screen', (
    tester,
  ) async {
    await mount(tester, const JoystickPage(), size: const Size(640, 360));

    final rows = tester.widget<GamepadControlRows>(
      find.byType(GamepadControlRows),
    );
    expect(rows.layout.rows, hasLength(1));
    // It fits by using the short Bluetooth wording.
    expect(rows.layout.compactBle, isTrue);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('wide screens keep the full Bluetooth wording', (tester) async {
    await mount(tester, const JoystickPage(), size: const Size(914, 411));

    final rows = tester.widget<GamepadControlRows>(
      find.byType(GamepadControlRows),
    );
    expect(rows.layout.rows, hasLength(1));
    expect(rows.layout.compactBle, isFalse);

    await unmount(tester);
  });

  test('short Bluetooth labels only shorten long wording', () {
    for (final kind in BlePresentationKind.values) {
      final state = BlePresentationState(kind);
      expect(state.shortLabel.length, lessThanOrEqualTo(state.label.length));
      expect(state.shortLabel.length, lessThanOrEqualTo(16));
    }
    expect(
      const BlePresentationState(BlePresentationKind.notConnected).shortLabel,
      'Not connected',
    );
  });
}
