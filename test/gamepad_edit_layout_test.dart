// Layout editor: tool tap areas, grid/snap alignment and control spacing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/gamepad_edit_metrics.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/core/widgets/gamepad_controls_sheet.dart';
import 'package:pb_controller/core/widgets/gamepad_edit_shared.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';
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

  group('GamepadEditMetrics.freeSpotFor', () {
    const area = Rect.fromLTRB(20, 20, 300, 200);

    test('keeps the preferred spot when it is free', () {
      expect(
        GamepadEditMetrics.freeSpotFor(
          preferred: const Offset(100, 100),
          radius: 20,
          centreArea: area,
          others: const [(Offset(200, 100), 20)],
        ),
        const Offset(100, 100),
      );
    });

    test('moves to the nearest free grid point when taken', () {
      final spot = GamepadEditMetrics.freeSpotFor(
        preferred: const Offset(100, 100),
        radius: 20,
        centreArea: area,
        others: const [(Offset(100, 100), 20)],
      );
      expect(spot.dx % GamepadEditMetrics.gridStep, 0);
      expect(spot.dy % GamepadEditMetrics.gridStep, 0);
      expect(
        (spot - const Offset(100, 100)).distance - 40,
        greaterThanOrEqualTo(GamepadEditMetrics.minControlGap),
      );
      // Nearest: no free grid point is closer to the preferred spot.
      expect((spot - const Offset(100, 100)).distance, lessThan(72));
      expect(area.contains(spot), isTrue);
    });

    test('falls back to the preferred spot when the pad is full', () {
      expect(
        GamepadEditMetrics.freeSpotFor(
          preferred: const Offset(100, 100),
          radius: 20,
          centreArea: area,
          others: const [(Offset(160, 110), 400)],
        ),
        const Offset(100, 100),
      );
    });
  });

  group('GamepadEditMetrics.readSavedLayout', () {
    ({double cx, double cy, double size})? read(Object? raw) =>
        GamepadEditMetrics.readSavedLayout(
          raw,
          minSize: 0.2,
          maxSize: 0.8,
          defaultSize: 0.3,
        );

    test('keeps a good entry', () {
      expect(read({'cx': 0.25, 'cy': 0.5, 'size': 0.4}), (
        cx: 0.25,
        cy: 0.5,
        size: 0.4,
      ));
    });

    test('pulls the centre onto the pad and the size into range', () {
      expect(read({'cx': 5, 'cy': -3, 'size': -1}), (
        cx: 1.0,
        cy: 0.0,
        size: 0.2,
      ));
      expect(read({'cx': 0.5, 'cy': 0.5, 'size': 9})?.size, 0.8);
    });

    test('uses the default size when it is missing', () {
      expect(read({'cx': 0.5, 'cy': 0.5})?.size, 0.3);
    });

    test('drops entries without a usable centre', () {
      expect(read(null), isNull);
      expect(read('x'), isNull);
      expect(read({'cx': 'a', 'cy': 0.5}), isNull);
      expect(read({'cy': 0.5}), isNull);
    });
  });

  group('GamepadEditMetrics.fitLayout', () {
    const panel = Size(400, 200);
    const pad = EdgeInsets.fromLTRB(12, 4, 12, 12);

    test('leaves a layout that fits alone', () {
      const controls = [(Offset(80, 100), 30.0), (Offset(300, 100), 30.0)];
      expect(
        GamepadEditMetrics.fitLayout(
          panel: panel,
          pad: pad,
          controls: controls,
        ),
        [for (final c in controls) c.$1],
      );
    });

    test('pulls a control past the edge back inside the margins', () {
      final fitted = GamepadEditMetrics.fitLayout(
        panel: panel,
        pad: pad,
        controls: const [(Offset(395, -10), 30)],
      );
      expect(fitted.single, const Offset(400 - 12 - 30, 4 + 30.0));
    });

    test('moves the later of two overlapping controls clear of the first', () {
      final fitted = GamepadEditMetrics.fitLayout(
        panel: panel,
        pad: pad,
        controls: const [(Offset(150, 100), 30), (Offset(170, 100), 30)],
      );
      expect(fitted.first, const Offset(150, 100));
      expect(
        (fitted.last - fitted.first).distance - 60,
        greaterThanOrEqualTo(GamepadEditMetrics.minControlGap),
      );
    });

    test('keeps controls that are close but not overlapping', () {
      const controls = [(Offset(150, 100), 30.0), (Offset(212, 100), 30.0)];
      expect(
        GamepadEditMetrics.fitLayout(
          panel: panel,
          pad: pad,
          controls: controls,
        ),
        [for (final c in controls) c.$1],
      );
    });

    test('savedFirst puts placed controls before default ones', () {
      expect(
        GamepadEditMetrics.savedFirst([
          'a',
          'b',
          'c',
          'd',
        ], {'c', 'a'}.contains),
        ['a', 'c', 'b', 'd'],
      );
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

    for (final page in _pages.entries.where((e) => e.key != 'joystick')) {
      testWidgets('${page.key}: a deleted button comes back from the Buttons '
          'sheet without Reset', (tester) async {
        await openEditor(tester, page.value.build());
        final controls = _byTypeName(page.value.controlType);
        final count = controls.evaluate().length;
        expect(count, greaterThan(1));

        await tester.tap(controls.first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();
        expect(controls, findsNWidgets(count - 1));

        await tester.tap(find.byTooltip('Buttons'));
        await tester.pumpAndSettle();
        expect(find.byType(GamepadControlsSheet), findsOneWidget);
        // Exactly the deleted one is offered for adding back.
        final hidden = find.ancestor(
          of: find.byIcon(Icons.add_circle_outline_rounded),
          matching: find.byType(InkWell),
        );
        expect(hidden, findsOneWidget);
        await tester.tap(hidden);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(controls, findsNWidgets(count));
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    void expectNoCrowding(WidgetTester tester, Finder controls) {
      final rects = [
        for (final element in controls.evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            _gap(rects[i], rects[j]),
            greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
            reason: '${rects[i]} vs ${rects[j]}',
          );
        }
      }
    }

    testWidgets('joystick: added buttons land on free spots, not on the '
        'right joystick', (tester) async {
      await openEditor(tester, const JoystickPage());
      for (final label in ['Triangle', 'Cross', 'Square', 'Circle']) {
        await tester.tap(find.byTooltip('Buttons'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      }
      expect(_byTypeName('_EditableButtonItem'), findsNWidgets(4));
      expectNoCrowding(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w.runtimeType.toString() == '_EditableButtonItem' ||
              w.runtimeType.toString() == '_EditableJoystick',
        ),
      );
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    // Saved layout: ↑ (Forward) is hidden and ← sits in ↑'s default spot.
    final reAdd = <String, (String, String, String, String, List<String>)>{
      'eight-button': (
        'gp8_active_left',
        'gp8_layout_all',
        'L:up',
        'L:left',
        ['L:down', 'L:left', 'L:right'],
      ),
      'four-button': (
        'gp4_active_all',
        'gp4_layout_all',
        'F:forward',
        'F:left',
        ['F:backward', 'F:left', 'F:right'],
      ),
    };
    for (final entry in reAdd.entries) {
      final page = _pages[entry.key]!;
      final (activeKey, layoutKey, hiddenId, moverId, active) = entry.value;
      testWidgets('${entry.key}: a re-added button does not land on one '
          'that was moved to its spot', (tester) async {
        // Where ↑ sits by default, as a fraction of the pad.
        await openEditor(tester, page.build());
        final panel = tester.getRect(_byTypeName(page.panelType!));
        final controls = _byTypeName(page.controlType);
        final rects = [
          for (final e in controls.evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ];
        // ↑ is the top-most control on the left half of the pad.
        final up = rects
            .where((r) => r.center.dx < panel.center.dx)
            .reduce((a, b) => a.top < b.top ? a : b);
        final upFraction = Offset(
          (up.center.dx - panel.left) / panel.width,
          (up.center.dy - panel.top) / panel.height,
        );
        await closePage(tester);

        SharedPreferences.setMockInitialValues({
          activeKey: jsonEncode(active),
          layoutKey: jsonEncode({
            moverId: {'cx': upFraction.dx, 'cy': upFraction.dy, 'size': 0.30},
          }),
        });
        await openEditor(tester, page.build());
        final before = [
          for (final e in controls.evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ];
        expect(
          before.any((r) => (r.center - up.center).distance < 2),
          isTrue,
          reason: 'the mover should start in the hidden button\'s spot',
        );

        await tester.tap(find.byTooltip('Buttons'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.ancestor(
            of: find.byIcon(Icons.add_circle_outline_rounded),
            matching: find.byType(InkWell),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(
          jsonDecode(
            (await SharedPreferences.getInstance()).getString(activeKey)!,
          ),
          contains(hiddenId),
        );

        expect(controls, findsNWidgets(before.length + 1));
        // The buttons already on the pad stay where they were.
        final after = [
          for (final e in controls.evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ];
        for (final rect in before) {
          expect(
            after.any((r) => (r.center - rect.center).distance < 0.5),
            isTrue,
            reason: 'moved: $rect',
          );
        }
        // The re-added one keeps the minimum gap to every other control.
        // (Hiding ↑ can let a 4 BTN default overlap another; that saved
        // state is not what this test checks.)
        final added = after.singleWhere(
          (r) => !before.any((b) => (b.center - r.center).distance < 0.5),
        );
        for (final other in before) {
          expect(
            _gap(added, other),
            greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
            reason: '$added vs $other',
          );
        }
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    for (final page in _pages.entries) {
      testWidgets('${page.key}: dragging an unselected control selects it '
          'without moving it', (tester) async {
        await openEditor(tester, page.value.build());
        final controls = _byTypeName(page.value.controlType);
        final (index, offset) = switch (page.key) {
          'four-button' => (2, const Offset(-170, -40)),
          'eight-button' => (4, const Offset(-200, 0)),
          _ => (0, const Offset(30, -60)),
        };
        final control = controls.at(index);
        final before = tester.getRect(control);

        // No tap first: the touch both selects it and tries to move it.
        // Frames run between moves, as on a device, so the control is
        // already rebuilt as selected while the same finger keeps moving.
        final gesture = await tester.startGesture(before.center);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(offset / 6);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(control), before);

        // Selected now, so the next drag moves it.
        await tester.drag(control, offset);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(control).center, isNot(before.center));

        await closePage(tester);
      });
    }

    List<Rect> rectsOf(WidgetTester tester, Finder controls) => [
      for (final e in controls.evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];

    void expectInsideWithoutOverlap(List<Rect> rects, Rect bounds) {
      for (final r in rects) {
        expect(bounds.inflate(0.5).contains(r.topLeft), isTrue, reason: '$r');
        expect(
          bounds.inflate(0.5).contains(r.bottomRight),
          isTrue,
          reason: '$r in $bounds',
        );
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            _gap(rects[i], rects[j]),
            greaterThanOrEqualTo(-0.5),
            reason: '${rects[i]} overlaps ${rects[j]}',
          );
        }
      }
    }

    // Each saved layout, as one made on another screen size can, has a
    // control past the pad's edge and/or two controls on top of each other.
    final cramped = <String, Map<String, Object>>{
      'four-button': {
        'gp4_active_all': jsonEncode(['F:left', 'F:right']),
        'gp4_layout_all': jsonEncode({
          'F:left': {'cx': 0.50, 'cy': 0.5, 'size': 0.30},
          'F:right': {'cx': 0.58, 'cy': 0.5, 'size': 0.30},
        }),
      },
      'eight-button': {
        'gp8_active_left': jsonEncode(['L:up', 'L:down']),
        'gp8_active_right': jsonEncode(<String>[]),
        'gp8_layout_all': jsonEncode({
          'L:up': {'cx': 0.3, 'cy': 0.05, 'size': 0.30},
          'L:down': {'cx': 0.3, 'cy': 0.2, 'size': 0.30},
        }),
      },
      'joystick': {
        'joy_dual_active': jsonEncode(['joy_left', 'joy_right']),
        'joy_dual_layout': jsonEncode({
          'joy_left': {'cx': 0.02, 'cy': 0.5, 'size': 1.0},
          'joy_right': {'cx': 0.2, 'cy': 0.5, 'size': 1.0},
        }),
      },
    };
    for (final entry in cramped.entries) {
      final page = _pages[entry.key]!;
      testWidgets('${entry.key}: a layout past the edge or overlapping is '
          'fitted into the pad and can still be resized', (tester) async {
        SharedPreferences.setMockInitialValues(entry.value);
        await openEditor(tester, page.build());
        final controls = _byTypeName(page.controlType);
        final bounds = page.panelType == null
            ? Offset.zero & tester.view.physicalSize
            : tester.getRect(_byTypeName(page.panelType!));
        expectInsideWithoutOverlap(rectsOf(tester, controls), bounds);

        Rect leftMost() => rectsOf(
          tester,
          controls,
        ).reduce((a, b) => a.center.dx < b.center.dx ? a : b);
        await tester.tapAt(leftMost().center);
        await tester.pumpAndSettle();
        final start = leftMost().shortestSide;
        await tester.tap(find.byTooltip('Decrease size'));
        await tester.pumpAndSettle();
        expect(leftMost().shortestSide, lessThan(start - 1));

        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    testWidgets('eight-button: play mode fits a saved layout without '
        'rewriting it', (tester) async {
      final layout = jsonEncode({
        'L:up': {'cx': 0.3, 'cy': 0.0, 'size': 0.5},
        'L:down': {'cx': 0.32, 'cy': 0.1, 'size': 0.5},
        'R:circle': {'cx': 1.0, 'cy': 1.0, 'size': 0.5},
      });
      SharedPreferences.setMockInitialValues({
        'gp8_active_left': jsonEncode(['L:up', 'L:down']),
        'gp8_active_right': jsonEncode(['R:circle']),
        'gp8_layout_all': layout,
      });
      tester.view.physicalSize = const Size(914, 411);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: GamepadModeEdit()));
      await tester.pumpAndSettle();

      final buttons = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'GamepadImageHoldButton',
      );
      expect(buttons, findsNWidgets(3));
      expectInsideWithoutOverlap(
        rectsOf(tester, buttons),
        Offset.zero & tester.view.physicalSize,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gp8_layout_all'), layout);
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    // Saved data no version of the app writes, but storage can hold.
    final corrupt = <String, (Map<String, Object>, int)>{
      'four-button': (
        {
          'gp4_active_all': jsonEncode(['F:forward', 'bogus']),
          'gp4_layout_all': jsonEncode({
            'F:forward': {'cx': 5, 'cy': -3, 'size': -1},
          }),
        },
        1,
      ),
      'eight-button': (
        {
          // A face button in the arrows' list, and an unreadable spot.
          'gp8_active_left': jsonEncode(['L:up', 'R:cross']),
          'gp8_active_right': jsonEncode(<String>[]),
          'gp8_layout_all': jsonEncode({
            'L:up': {'cx': 'x', 'cy': 0.5},
          }),
        },
        1,
      ),
      'joystick': (
        // Nothing usable: the default two joysticks come back.
        {
          'joy_dual_active': jsonEncode(['bogus']),
        },
        2,
      ),
    };
    for (final entry in corrupt.entries) {
      final page = _pages[entry.key]!;
      final (prefs, count) = entry.value;
      testWidgets('${entry.key}: corrupt saved data still gives a usable '
          'pad', (tester) async {
        SharedPreferences.setMockInitialValues(prefs);
        await openEditor(tester, page.build());
        expect(tester.takeException(), isNull);
        final controls = _byTypeName(page.controlType);
        expect(controls, findsNWidgets(count));
        final bounds = page.panelType == null
            ? Offset.zero & tester.view.physicalSize
            : tester.getRect(_byTypeName(page.panelType!));
        expectInsideWithoutOverlap(rectsOf(tester, controls), bounds);
        for (final r in rectsOf(tester, controls)) {
          expect(r.shortestSide, greaterThan(20));
        }
        await closePage(tester);
      });
    }

    testWidgets('joystick: a pad saved with every control removed opens '
        'with the default joysticks', (tester) async {
      SharedPreferences.setMockInitialValues({
        'joy_dual_active': jsonEncode(<String>[]),
      });
      await openEditor(tester, const JoystickPage());
      expect(_byTypeName('_EditableJoystick'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    testWidgets('joystick: a one-axis joystick takes the place of the full '
        'one on its side', (tester) async {
      await openEditor(tester, const JoystickPage());
      final joysticks = _byTypeName('_EditableJoystick');
      Rect leftJoystick() => [
        for (final e in joysticks.evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ].reduce((a, b) => a.center.dx < b.center.dx ? a : b);
      expect(joysticks, findsNWidgets(2));
      final before = leftJoystick();

      await tester.tap(find.byTooltip('Buttons'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Joystick (Y only)'));
      await tester.tap(find.text('Joystick (Y only)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(joysticks, findsNWidgets(2));
      expect(leftJoystick(), before);
      final active = jsonDecode(
        (await SharedPreferences.getInstance()).getString('joy_dual_active')!,
      );
      expect(active, contains('joy_y_only'));
      expect(active, isNot(contains('joy_left')));
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    testWidgets('four-button: on a tablet the touched box is the drawn '
        'circle and can reach the top edge', (tester) async {
      // The arrows' design box is taller than wide on 4:3-ish pads.
      await openEditor(
        tester,
        const Gamepad4ButtonPage(),
        size: const Size(1180, 820),
      );
      final panel = tester.getRect(_byTypeName('_EditablePadPanel'));
      final controls = _byTypeName('_EditableButton');
      for (final e in controls.evaluate()) {
        final rect = tester.getRect(find.byWidget(e.widget));
        expect(rect.width, closeTo(rect.height, 0.5), reason: '$rect');
      }

      // Drag the top-most arrow far up: it stops at the pad's top margin.
      Rect topMost() => [
        for (final e in controls.evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ].reduce((a, b) => a.top < b.top ? a : b);
      final start = topMost();
      await tester.tapAt(start.center);
      await tester.pumpAndSettle();
      await tester.dragFrom(start.center, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        topMost().top - panel.top,
        closeTo(GamepadEditMetrics.safeTopEdgePad, 0.5),
      );
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    testWidgets('joystick: a saved layout with both left joysticks keeps '
        'only the full one', (tester) async {
      SharedPreferences.setMockInitialValues({
        'joy_dual_active': jsonEncode(['joy_left', 'joy_y_only', 'joy_right']),
      });
      await openEditor(tester, const JoystickPage());
      expect(_byTypeName('_EditableJoystick'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    Future<void> openPlay(WidgetTester tester, Widget page, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    Finder playButtons() => find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() == 'GamepadImageHoldButton' ||
          w.runtimeType.toString() == '_JoyImagePressHoldButton',
    );

    // Where the driving toolbar wraps to two rows (8 BTN on a small phone).
    for (final entry in {
      'four-button': ('_LayoutPadPanel', '_EditablePadPanel'),
      'eight-button': ('_LayoutPadPanel', '_EditablePadPanel'),
      // The editor draws the stick inside a 2 dp frame: compare the frame.
      'joystick': ('JoystickView', '_EditableJoystick'),
    }.entries) {
      final page = _pages[entry.key]!;
      testWidgets('${entry.key}: the editor\'s pad is the driving pad on a '
          'small phone', (tester) async {
        const size = Size(640, 360);
        await openPlay(tester, page.build(), size);
        final play = tester.getRect(_byTypeName(entry.value.$1).first);
        await closePage(tester);

        await openEditor(tester, page.build(), size: size);
        final edit = tester.getRect(_byTypeName(entry.value.$2).first);
        expect(edit.top, closeTo(play.top, 0.5));
        expect(edit.size.width, closeTo(play.size.width, 0.5));
        expect(edit.size.height, closeTo(play.size.height, 0.5));
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    for (final entry in {
      'eight-button': {
        'gp8_active_left': jsonEncode(['L:up']),
        'gp8_active_right': jsonEncode(<String>[]),
        'gp8_layout_all': jsonEncode({
          'L:up': {'cx': 0.3, 'cy': 0.5, 'size': 0.18},
        }),
      },
      'joystick': {
        'joy_dual_active': jsonEncode(['joy_left', 'btn_triangle']),
        'joy_dual_layout': jsonEncode({
          'joy_left': {'cx': 0.25, 'cy': 0.5, 'size': 0.6},
          'btn_triangle': {'cx': 0.75, 'cy': 0.5, 'size': 0.6},
        }),
      },
    }.entries) {
      testWidgets('${entry.key}: the smallest saved size is still a 48 dp '
          'button on a small phone', (tester) async {
        SharedPreferences.setMockInitialValues(entry.value);
        await openPlay(
          tester,
          _pages[entry.key]!.build(),
          const Size(640, 360),
        );
        final buttons = playButtons();
        expect(buttons, findsOneWidget);
        expect(
          tester.getRect(buttons).shortestSide,
          greaterThanOrEqualTo(GamepadEditMetrics.minTouchDiameter - 0.5),
        );
        if (entry.key == 'joystick') {
          expect(
            tester.getRect(find.byType(JoystickView)).shortestSide,
            greaterThanOrEqualTo(kJoyStickMinDiameter - 0.5),
          );
        }
        expect(tester.takeException(), isNull);
        await closePage(tester);
      });
    }

    testWidgets('joystick: sticks stop growing on a large tablet, like the '
        'gamepad buttons', (tester) async {
      await openPlay(tester, const JoystickPage(), const Size(1366, 1024));
      for (final e in find.byType(JoystickView).evaluate()) {
        expect(
          tester.getRect(find.byWidget(e.widget)).width,
          lessThanOrEqualTo(GamepadEditMetrics.maxPanelUnit * 0.45 + 0.5),
        );
      }
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });

    for (final page in _pages.entries.where((e) => e.key != 'joystick')) {
      testWidgets('${page.key}: the editor draws buttons as in play and '
          'outlines the selected one\'s touch area', (tester) async {
        await openEditor(tester, page.value.build());
        final controls = _byTypeName(page.value.controlType);
        expect(
          find.descendant(of: controls.first, matching: find.byType(ClipOval)),
          findsNothing,
        );
        expect(find.byKey(GamepadTouchAreaOutline.outlineKey), findsNothing);
        await tester.tap(controls.first);
        await tester.pumpAndSettle();
        final outline = find.byKey(GamepadTouchAreaOutline.outlineKey);
        expect(outline, findsOneWidget);
        expect(tester.getRect(outline), tester.getRect(controls.first));
        await closePage(tester);
      });
    }

    testWidgets('joystick: a face button cannot be dragged onto a joystick', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'joy_dual_active': jsonEncode(['joy_left', 'btn_triangle']),
        'joy_dual_layout': jsonEncode({
          'joy_left': {'cx': 0.25, 'cy': 0.5, 'size': 1.0},
          'btn_triangle': {'cx': 0.65, 'cy': 0.5, 'size': 1.0},
        }),
      });
      await openEditor(tester, const JoystickPage());
      final triangle = _byTypeName('_EditableButtonItem');
      final stick = _byTypeName('_EditableJoystick');
      await tester.tapAt(tester.getRect(triangle).center);
      await tester.pumpAndSettle();
      await tester.timedDrag(
        triangle,
        const Offset(-500, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(
        _gap(tester.getRect(triangle), tester.getRect(stick)),
        greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
      );
      // What is saved keeps the gap too (drawing alone could hide an
      // overlap by fitting it). Both sit on the pad's middle row and the
      // pad spans the 914 dp screen width.
      final saved =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  'joy_dual_layout',
                )!,
              )
              as Map<String, dynamic>;
      final cxGap =
          ((saved['btn_triangle']['cx'] as num) -
                  (saved['joy_left']['cx'] as num))
              .abs() *
          914;
      expect(
        cxGap -
            tester.getRect(triangle).shortestSide / 2 -
            tester.getRect(stick).shortestSide / 2,
        greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
      );
      expect(tester.takeException(), isNull);
      await closePage(tester);
    });
  });
}
