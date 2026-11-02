import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/editable_start_stop.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';

void main() {
  testWidgets('slow grid drag accumulates small deltas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 260,
            child: EditableStartStopSurface(
              placement: const StartStopPlacement(cx: .5, cy: .5),
              editing: true,
              selected: true,
              snapToGrid: true,
              started: false,
              busy: false,
              onPressed: () {},
              onSelect: () {},
              onBeginChange: () {},
              onChanged: (_) {},
              onBlocked: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final handle = find.byKey(const ValueKey('start-stop-edit-handle'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    final start = tester.getCenter(handle);
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump();
    }
    expect(tester.getCenter(handle).dx, greaterThan(start.dx + 12));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  test(
    'old and invalid placement defaults safely; roundtrip preserves values',
    () {
      expect(
        StartStopPlacement.fromJson(null).toJson(),
        const StartStopPlacement().toJson(),
      );
      expect(
        StartStopPlacement.fromJson({
          'cx': double.nan,
          'cy': -5,
          'scale': 20,
        }).toJson(),
        {'v': 2, 'cx': .5, 'cy': 0.0, 'scale': 2.0},
      );
      const value = StartStopPlacement(cx: .3, cy: .4, scale: .75);
      expect(
        StartStopPlacement.fromJson(
          jsonDecode(jsonEncode(value.toJson())),
        ).toJson(),
        value.toJson(),
      );
      expect(value.hitSize, 48);
      expect(value.diameter, 36);
    },
  );

  test('Start/Stop defaults to 72 px and migrates the old auto-saved size', () {
    expect(const StartStopPlacement().diameter, 72);
    // Older versions saved scale 1 (48 px) on every visit: treat as default.
    expect(
      StartStopPlacement.fromJson({'cx': .5, 'cy': 1, 'scale': 1}).scale,
      StartStopPlacement.defaultScale,
    );
    // A size the user chose in an older version is kept.
    expect(
      StartStopPlacement.fromJson({'cx': .5, 'cy': 1, 'scale': 1.25}).scale,
      1.25,
    );
    // Data saved by this version is kept as-is, even at 1.0.
    expect(
      StartStopPlacement.fromJson({
        'v': 2,
        'cx': .5,
        'cy': 1,
        'scale': 1,
      }).scale,
      1,
    );
  });

  for (final mode in <String, Widget Function()>{
    'gp4_layout_all': () => const Gamepad4ButtonPage(),
    'gp8_layout_all': () => const GamepadModeEdit(),
    'joy_dual_layout': () => const JoystickPage(),
  }.entries) {
    testWidgets('${mode.key}: system edit, history, protection and reload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> mount() async {
        await tester.pumpWidget(MaterialApp(home: mode.value()));
        await tester.pumpAndSettle();
      }

      Future<void> edit() async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Edit layout'));
        await tester.tap(find.text('Edit layout'));
        await tester.pumpAndSettle();
      }

      EditableStartStopSurface surface() =>
          tester.widget(find.byType(EditableStartStopSurface));
      Future<void> tool(String name) async {
        await tester.tap(find.byTooltip(name));
        await tester.pumpAndSettle();
      }

      await mount();
      expect(surface().placement.scale, StartStopPlacement.defaultScale);
      await edit();
      final handle = find.byKey(const ValueKey('start-stop-edit-handle'));
      expect(handle, findsOneWidget);
      await tester.tap(handle);
      await tester.pump();
      expect(surface().selected, isTrue);
      expect(surface().started, isFalse);
      for (final name in ['Delete', 'Lock']) {
        final ink = find.descendant(
          of: find.byTooltip(name),
          matching: find.byType(InkWell),
        );
        expect(tester.widget<InkWell>(ink.first).onTap, isNull);
      }
      final before = surface().placement.toJson();
      // Move into the central open corridor, away from the bottom edge.
      await tester.drag(handle, const Offset(0, -65));
      await tester.pumpAndSettle();
      expect(surface().placement.toJson(), isNot(before));
      final moved = surface().placement.toJson();
      await tool('Increase size');
      expect(
        surface().placement.scale,
        closeTo(StartStopPlacement.defaultScale + .05, .0001),
      );
      await tool('Undo');
      expect(surface().placement.toJson(), moved);
      await tool('Undo');
      expect(surface().placement.toJson(), before);
      await tool('Redo');
      expect(surface().placement.toJson(), moved);
      await tool('Redo');
      expect(
        surface().placement.scale,
        closeTo(StartStopPlacement.defaultScale + .05, .0001),
      );
      final saved = surface().placement.toJson();
      await tool('Done');
      expect(handle, findsNothing);
      expect(surface().started, isFalse);
      expect(surface().placement.toJson(), saved);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('${mode.key}_start_stop')!), saved);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount();
      expect(surface().placement.toJson(), saved);
      await edit();
      await tool('Reset');
      expect(surface().placement.toJson(), const StartStopPlacement().toJson());
      await tool('Undo');
      expect(surface().placement.toJson(), saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  for (final preset
      in <({String key, Widget Function() page, Map<String, Object> data})>[
        (
          key: 'gp4_preset_1',
          page: () => const Gamepad4ButtonPage(),
          data: {
            'layout': <String, Object>{},
            'active': ['F:forward', 'F:backward', 'F:left', 'F:right'],
            'speed': 'Lo',
          },
        ),
        (
          key: 'gp8_preset_1',
          page: () => const GamepadModeEdit(),
          data: {
            'layout': <String, Object>{},
            'leftActive': ['L:up', 'L:down', 'L:left', 'L:right'],
            'rightActive': ['R:triangle', 'R:cross', 'R:square', 'R:circle'],
            'drive': 100,
            'turn': 100,
          },
        ),
        (
          key: 'joy_preset_1',
          page: () => const JoystickPage(),
          data: {
            'layout': <String, Object>{},
            'active': ['joy_left', 'joy_right'],
          },
        ),
      ]) {
    testWidgets('${preset.key}: preset restores system placement', (
      tester,
    ) async {
      const expected = StartStopPlacement(cx: .42, cy: .64, scale: 1.25);
      SharedPreferences.setMockInitialValues({
        preset.key: jsonEncode({
          ...preset.data,
          'name': 'Test layout',
          'startStop': expected.toJson(),
        }),
      });
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: preset.page()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved layouts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Load'));
      await tester.pumpAndSettle();
      final surface = tester.widget<EditableStartStopSurface>(
        find.byType(EditableStartStopSurface, skipOffstage: false),
      );
      expect(surface.placement.toJson(), expected.toJson());
      expect(find.text('Presets'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('old preset without system placement remains compatible', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'gp4_preset_1': jsonEncode({
        'name': 'Old layout',
        'layout': <String, Object>{},
        'active': ['F:forward', 'F:backward', 'F:left', 'F:right'],
        'speed': 'Med',
      }),
    });
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Gamepad4ButtonPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved layouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Load'));
    await tester.pumpAndSettle();
    final surface = tester.widget<EditableStartStopSurface>(
      find.byType(EditableStartStopSurface, skipOffstage: false),
    );
    expect(surface.placement.toJson(), const StartStopPlacement().toJson());
  });

  testWidgets(
    'Edit never activates; size limits, collision and Start/Stop location',
    (tester) async {
      final key = GlobalKey<EditableStartStopSurfaceState>();
      var value = const StartStopPlacement(cx: .5, cy: .5);
      var editing = true, started = false;
      var actions = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: SizedBox(
                  width: 400,
                  height: 260,
                  child: EditableStartStopSurface(
                    key: key,
                    placement: value,
                    editing: editing,
                    selected: true,
                    snapToGrid: false,
                    started: started,
                    busy: false,
                    onPressed: () => actions++,
                    onSelect: () {},
                    onBeginChange: () {},
                    onChanged: (next) => update(() => value = next),
                    onBlocked: () {},
                    child: const Stack(
                      children: [
                        Positioned(
                          left: 280,
                          top: 80,
                          width: 80,
                          height: 80,
                          child: StartStopObstacle(
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('start-stop-edit-handle'));
      await tester.tap(handle);
      expect(actions, 0);
      final originalCenter = tester.getCenter(handle);
      final blockedDrag = await tester.startGesture(originalCenter);
      await blockedDrag.moveBy(const Offset(120, 0));
      await tester.pump();
      expect(value.cx, .5);
      await blockedDrag.moveBy(const Offset(-10, 0));
      await tester.pump();
      expect(tester.getCenter(handle).dx, lessThan(originalCenter.dx));
      await blockedDrag.up();
      await tester.pumpAndSettle();
      expect(value.cx, lessThan(.5));
      for (var i = 0; i < 30; i++) {
        key.currentState!.adjustSize(-.05);
        await tester.pump();
      }
      expect(value.scale, .75);
      expect(tester.getSize(handle), const Size(48, 48));
      for (var i = 0; i < 30; i++) {
        key.currentState!.adjustSize(.05);
        await tester.pump();
      }
      expect(value.scale, 2);
      update(() => editing = false);
      await tester.pumpAndSettle();
      final button = find.byType(GamepadStartStopControlButton);
      final startRect = tester.getRect(button);
      await tester.tap(button);
      expect(actions, 1);
      update(() => started = true);
      await tester.pumpAndSettle();
      expect(tester.getRect(button), startRect);
      await tester.tap(button);
      expect(actions, 2);
    },
  );

  group('Start hint', () {
    Widget surface({required bool started, required bool blocked}) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 300,
                child: EditableStartStopSurface(
                  placement: const StartStopPlacement(),
                  editing: false,
                  selected: false,
                  snapToGrid: false,
                  started: started,
                  busy: false,
                  onPressed: () {},
                  onSelect: () {},
                  onBeginChange: () {},
                  onChanged: (_) {},
                  onBlocked: () {},
                  child: Stack(
                    children: [
                      if (blocked)
                        // A control right where the label would go.
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 90,
                          height: 50,
                          child: StartStopObstacle(child: SizedBox.expand()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('shows "Tap Start to drive" until control starts', (
      tester,
    ) async {
      await tester.pumpWidget(surface(started: false, blocked: false));
      await tester.pump();
      expect(find.byKey(const ValueKey('start-hint')), findsOneWidget);
      expect(find.text('Tap Start to drive'), findsOneWidget);

      await tester.pumpWidget(surface(started: true, blocked: false));
      await tester.pump();
      expect(find.byKey(const ValueKey('start-hint')), findsNothing);
    });

    testWidgets('never covers a control', (tester) async {
      await tester.pumpWidget(surface(started: false, blocked: true));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('start-hint')), findsNothing);
    });
  });
}
