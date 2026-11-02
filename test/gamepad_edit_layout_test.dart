// Layout editor: tool tap areas, grid/snap alignment and control spacing.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/gamepad_edit_metrics.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/gamepad/widgets/gamepad_controls_sheet.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRoboto() async {
  // Real glyph widths, so the toolbar fits like it does on a phone.
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

/// One control page and how to find its draggable controls.
class _Page {
  const _Page(this.build, this.controlType, {this.panelType});

  final Widget Function() build;

  /// Runtime type name of the page's editable control widget.
  final String controlType;

  /// Runtime type name of the box the controls are placed in, when the
  /// page has one (the Joystick pad fills the grid's own box).
  final String? panelType;
}

final _pages = <String, _Page>{
  'four-button': _Page(
    () => const Gamepad4ButtonPage(),
    '_EditableButton',
    panelType: '_EditablePadPanel',
  ),
  'eight-button': _Page(
    () => const GamepadModeEdit(),
    '_EditableButton',
    panelType: '_EditablePadPanel',
  ),
  'joystick': _Page(() => const JoystickPage(), '_EditableJoystick'),
};

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

double _gap(Rect a, Rect b) =>
    (a.center - b.center).distance - a.shortestSide / 2 - b.shortestSide / 2;

void main() {
  group('GamepadEditMetrics', () {
    test('snapToGrid rounds to the nearest 24 dp line', () {
      expect(GamepadEditMetrics.gridStep, 24);
      expect(GamepadEditMetrics.snapToGrid(0), 0);
      expect(GamepadEditMetrics.snapToGrid(11.9), 0);
      expect(GamepadEditMetrics.snapToGrid(12.1), 24);
      expect(GamepadEditMetrics.snapToGrid(100), 96);
    });

    bool crowds(Offset from, Offset to, {double radius = 20}) =>
        GamepadEditMetrics.crowdsNeighbour(
          fromCentre: from,
          fromRadius: radius,
          toCentre: to,
          toRadius: radius,
          otherCentre: Offset.zero,
          otherRadius: 20,
        );

    test('crowdsNeighbour refuses moving into the minimum gap', () {
      expect(GamepadEditMetrics.minControlGap, 6);
      // 60 apart = 20 dp gap; 44 apart = 4 dp gap.
      expect(crowds(const Offset(60, 0), const Offset(50, 0)), isFalse);
      expect(crowds(const Offset(60, 0), const Offset(44, 0)), isTrue);
      expect(crowds(const Offset(60, 0), const Offset(30, 0)), isTrue);
    });

    test('crowdsNeighbour lets controls that are already close move apart', () {
      // Starting 1 dp apart (closer than the minimum).
      expect(crowds(const Offset(41, 0), const Offset(43, 0)), isFalse);
      expect(crowds(const Offset(41, 0), const Offset(41, 0)), isFalse);
      expect(crowds(const Offset(41, 0), const Offset(40.5, 0)), isTrue);
    });

    test('crowdsNeighbour refuses growing into the minimum gap', () {
      bool grow(double toRadius) => GamepadEditMetrics.crowdsNeighbour(
        fromCentre: const Offset(50, 0),
        fromRadius: 20,
        toCentre: const Offset(50, 0),
        toRadius: toRadius,
        otherCentre: Offset.zero,
        otherRadius: 20,
      );
      expect(grow(22), isFalse); // 8 dp gap left
      expect(grow(26), isTrue); // 4 dp gap left
    });
  });

  group('layout editor', () {
    setUpAll(_loadRoboto);

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

    Future<void> openEditor(
      WidgetTester tester,
      Widget page, {
      Size size = const Size(914, 411),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit layout'));
      await tester.pumpAndSettle();
      // Controls size themselves from their images; decode them first.
      for (final element in find.byType(Image).evaluate().toList()) {
        final image = (element.widget as Image).image;
        await tester.runAsync(() => precacheImage(image, element));
      }
      await tester.pumpAndSettle();
    }

    Future<void> closePage(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    }

    Rect toolSlot(WidgetTester tester, String tool) {
      for (var i = 0; i < 12; i++) {
        final slot = find.byKey(ValueKey('gamepad-toolbar-slot-$i'));
        if (slot.evaluate().isEmpty) break;
        if (find
            .descendant(of: slot, matching: find.byTooltip(tool))
            .evaluate()
            .isNotEmpty) {
          return tester.getRect(slot);
        }
      }
      throw StateError('No toolbar slot for $tool');
    }

    final grid = find.byKey(const ValueKey('gamepad-edit-grid'));

    for (final page in _pages.entries) {
      testWidgets('${page.key}: a tap at the top or bottom of a tool slot '
          'works', (tester) async {
        await openEditor(tester, page.value.build());
        final slot = toolSlot(tester, 'Grid');
        expect(slot.height, greaterThanOrEqualTo(48));
        expect(grid, findsNothing);

        await tester.tapAt(Offset(slot.center.dx, slot.top + 3));
        await tester.pumpAndSettle();
        expect(grid, findsOneWidget);

        await tester.tapAt(Offset(slot.center.dx, slot.bottom - 3));
        await tester.pumpAndSettle();
        expect(grid, findsNothing);
        expect(tester.takeException(), isNull);

        await closePage(tester);
      });

      testWidgets('${page.key}: a dragged control lands on a drawn grid line', (
        tester,
      ) async {
        await openEditor(tester, page.value.build());
        final gridSlot = toolSlot(tester, 'Grid');
        await tester.tapAt(gridSlot.center);
        await tester.pumpAndSettle();

        final gridRect = tester.getRect(grid);
        if (page.value.panelType != null) {
          // Drawn over exactly the box the controls are placed in.
          expect(tester.getRect(_byTypeName(page.value.panelType!)), gridRect);
        }

        // Move a control into open space, away from the centre guides.
        final controls = _byTypeName(page.value.controlType);
        final (index, offset) = switch (page.key) {
          'four-button' => (2, const Offset(-170, -40)),
          'eight-button' => (4, const Offset(-200, 0)),
          _ => (0, const Offset(30, -60)),
        };
        final control = controls.at(index);
        final before = tester.getRect(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.drag(control, offset);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final after = tester.getRect(control);
        expect(after.center, isNot(before.center));
        final local = after.center - gridRect.topLeft;
        const step = GamepadEditMetrics.gridStep;
        expect(
          (local.dx / step - (local.dx / step).round()).abs() * step,
          lessThan(0.5),
          reason: 'x ${local.dx}',
        );
        expect(
          (local.dy / step - (local.dy / step).round()).abs() * step,
          lessThan(0.5),
          reason: 'y ${local.dy}',
        );

        await closePage(tester);
      });

      testWidgets('${page.key}: dragging into a neighbour keeps a 6 dp gap', (
        tester,
      ) async {
        await openEditor(tester, page.value.build());
        final controls = _byTypeName(page.value.controlType);
        // A control and the neighbour it is dragged straight towards.
        final (index, neighbour, offset) = switch (page.key) {
          'four-button' => (2, 3, const Offset(60, 0)),
          'eight-button' => (2, 3, const Offset(160, 0)),
          _ => (0, 1, const Offset(400, 0)),
        };
        final control = controls.at(index);
        final other = controls.at(neighbour);
        expect(
          _gap(tester.getRect(control), tester.getRect(other)),
          greaterThan(GamepadEditMetrics.minControlGap),
        );

        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.timedDrag(
          control,
          offset,
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (var i = 0; i < controls.evaluate().length; i++) {
          if (i == index) continue;
          expect(
            _gap(tester.getRect(control), tester.getRect(controls.at(i))),
            greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
            reason: 'gap to control $i',
          );
        }

        await closePage(tester);
      });
    }

    for (final size in [const Size(914, 411), const Size(640, 360)]) {
      testWidgets('joystick: the Buttons tool adds △ ✕ □ ○ to the pad at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await openEditor(tester, const JoystickPage(), size: size);
        final buttonItems = _byTypeName('_EditableButtonItem');
        expect(buttonItems, findsNothing); // Default: two joysticks only.

        // On the single tool row, inside the screen, full 48 px slot.
        final slot = toolSlot(tester, 'Buttons');
        final grid = toolSlot(tester, 'Grid');
        expect(slot.height, greaterThanOrEqualTo(48));
        expect(slot.top, grid.top);
        expect(slot.left, greaterThanOrEqualTo(0));
        expect(slot.right, lessThanOrEqualTo(size.width));

        await tester.tap(find.byTooltip('Buttons'));
        await tester.pumpAndSettle();
        expect(find.byType(GamepadControlsSheet), findsOneWidget);

        await tester.ensureVisible(find.text('Triangle'));
        await tester.tap(find.text('Triangle'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byType(GamepadControlsSheet), findsNothing);

        expect(buttonItems, findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('joy_dual_active'), contains('btn_triangle'));
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    for (final active in [
      '["joy_left","btn_triangle"]',
      // Saved layouts can have a button on top of the right joystick.
      '["joy_left","joy_right","btn_triangle"]',
    ]) {
      testWidgets('joystick: a face button can be selected, moved and '
          'deleted ($active)', (tester) async {
        SharedPreferences.setMockInitialValues({'joy_dual_active': active});
        await openEditor(tester, const JoystickPage());
        final triangle = _byTypeName('_EditableButtonItem');
        final joysticks = _byTypeName('_EditableJoystick');
        expect(triangle, findsOneWidget);
        final joystickCount = joysticks.evaluate().length;

        await tester.tapAt(tester.getRect(triangle).center);
        await tester.pumpAndSettle();
        final before = tester.getRect(triangle);
        await tester.drag(triangle, const Offset(-96, 0));
        await tester.pumpAndSettle();
        expect(tester.getRect(triangle).center.dx, lessThan(before.center.dx));

        // Delete removes the selected button, not a joystick under it.
        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();
        expect(triangle, findsNothing);
        expect(joysticks, findsNWidgets(joystickCount));
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }
  });
}
