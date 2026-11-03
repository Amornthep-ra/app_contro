// Layout editor: tool tap areas, grid/snap alignment and control spacing.
import 'dart:convert';
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

/// Radius of a control's visible edge: the round face of a button's
/// artwork, or a joystick's whole circle.
double _faceRadius(Rect box, {bool joystick = false}) => joystick
    ? box.shortestSide / 2
    : GamepadEditMetrics.buttonVisibleRadius(box.shortestSide);

/// Clear space between two controls' visible edges.
double _gap(Rect a, Rect b, {bool aJoystick = false, bool bJoystick = false}) =>
    (a.center - b.center).distance -
    _faceRadius(a, joystick: aJoystick) -
    _faceRadius(b, joystick: bJoystick);

void main() {
  group('GamepadEditMetrics', () {
    test('snapToGrid rounds to the nearest 12 dp line', () {
      expect(GamepadEditMetrics.gridStep, 12);
      expect(GamepadEditMetrics.snapToGrid(0), 0);
      expect(GamepadEditMetrics.snapToGrid(5.9), 0);
      expect(GamepadEditMetrics.snapToGrid(6.1), 12);
      expect(GamepadEditMetrics.snapToGrid(100), 96);
      expect(GamepadEditMetrics.snapToGrid(103), 108);
    });

    test('a button face is ~77 % of its image, 2 px inside the box', () {
      // 88 px box -> 84 px image -> ~64 px face.
      expect(
        GamepadEditMetrics.buttonVisibleRadius(88),
        closeTo(84 * 0.766 / 2, 0.01),
      );
      expect(GamepadEditMetrics.buttonVisibleRadius(2), 0);
    });

    test('touchRadius splits the space to the nearest neighbour', () {
      double touch(List<(Offset, double)> others) =>
          GamepadEditMetrics.touchRadius(
            centre: Offset.zero,
            visibleRadius: 30,
            maxRadius: 44,
            others: others,
          );
      // Alone or far away: the whole box.
      expect(touch(const []), 44);
      expect(touch(const [(Offset(200, 0), 30)]), 44);
      // 64 apart -> 4 px clear between faces -> 2 px each.
      expect(touch(const [(Offset(64, 0), 30)]), 32);
      // The nearest neighbour wins.
      expect(touch(const [(Offset(80, 0), 30), (Offset(0, 70), 30)]), 35);
      // Never less than the face.
      expect(touch(const [(Offset(50, 0), 30)]), 30);
    });

    test('slideToward stops right at the first blocked point', () {
      // Blocked from x = 40 on.
      final stop = GamepadEditMetrics.slideToward(
        from: Offset.zero,
        to: const Offset(100, 0),
        blocked: (c) => c.dx >= 40,
      );
      expect(stop.dx, closeTo(40, 0.05));
      expect(stop.dx, lessThan(40));
      expect(
        GamepadEditMetrics.slideToward(
          from: Offset.zero,
          to: const Offset(30, 0),
          blocked: (c) => c.dx >= 40,
        ),
        const Offset(30, 0),
      );
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
      expect(GamepadEditMetrics.minControlGap, 4);
      // 60 apart = 20 dp gap; 44 apart = 4 dp; 43 apart = 3 dp.
      expect(crowds(const Offset(60, 0), const Offset(50, 0)), isFalse);
      expect(crowds(const Offset(60, 0), const Offset(44, 0)), isFalse);
      expect(crowds(const Offset(60, 0), const Offset(43, 0)), isTrue);
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
      expect(grow(26), isFalse); // 4 dp gap left
      expect(grow(27), isTrue); // 3 dp gap left
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

      if (page.key != 'joystick') {
        testWidgets('${page.key}: the editor draws buttons like drive mode '
            '(2 px inset)', (tester) async {
          await openEditor(tester, page.value.build());
          final control = _byTypeName(page.value.controlType).first;
          final box = tester.getRect(control);
          final image = tester.getRect(
            find.descendant(of: control, matching: find.byType(Image)).first,
          );
          final side =
              box.shortestSide - 2 * GamepadEditMetrics.buttonImageInset;
          expect(image.width, closeTo(side, 0.5));
          expect(image.center.dx, closeTo(box.center.dx, 0.5));
          expect(image.center.dy, closeTo(box.center.dy, 0.5));
          await closePage(tester);
        });
      }

      testWidgets('${page.key}: Reset asks first, and Undo brings the layout '
          'back', (tester) async {
        await openEditor(tester, page.value.build());
        final control = _byTypeName(page.value.controlType).first;
        final home = tester.getRect(control).center;
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.drag(control, const Offset(0, 40));
        await tester.pumpAndSettle();
        final moved = tester.getRect(control).center;
        expect((moved - home).distance, greaterThan(10));

        await tester.tap(find.byTooltip('Reset'));
        await tester.pumpAndSettle();
        expect(find.text('Reset layout?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.getRect(control).center, moved);

        await tester.tap(find.byTooltip('Reset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(
          (tester.getRect(_byTypeName(page.value.controlType).first).center -
                  home)
              .distance,
          lessThan(0.5),
        );

        await tester.tap(find.byTooltip('Undo'));
        await tester.pumpAndSettle();
        expect(
          (tester.getRect(_byTypeName(page.value.controlType).first).center -
                  moved)
              .distance,
          lessThan(0.5),
        );
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

      testWidgets('${page.key}: a fast drag into a neighbour slides up to '
          '4 dp from its visible face', (tester) async {
        await openEditor(tester, page.value.build());
        final controls = _byTypeName(page.value.controlType);
        // A control and the neighbour it is dragged straight towards.
        final (index, neighbour, offset) = switch (page.key) {
          'four-button' => (2, 3, const Offset(160, 0)),
          'eight-button' => (2, 3, const Offset(160, 0)),
          _ => (0, 1, const Offset(400, 0)),
        };
        final control = controls.at(index);
        final joystick = page.key == 'joystick';
        double gapTo(int i) => _gap(
          tester.getRect(control),
          tester.getRect(controls.at(i)),
          aJoystick: joystick,
          bJoystick: joystick,
        );
        expect(gapTo(neighbour), greaterThan(GamepadEditMetrics.minControlGap));

        await tester.tap(control);
        await tester.pumpAndSettle();
        // Fast: the updates jump past the limit; the control must still
        // end up touching the 4 dp line, not stop short.
        await tester.timedDrag(
          control,
          offset,
          const Duration(milliseconds: 120),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        var closest = double.infinity;
        for (var i = 0; i < controls.evaluate().length; i++) {
          if (i == index) continue;
          final gap = gapTo(i);
          expect(
            gap,
            greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
            reason: 'gap to control $i',
          );
          if (gap < closest) closest = gap;
        }
        expect(closest, lessThan(GamepadEditMetrics.minControlGap + 0.5));

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
      final items = [
        for (final element in controls.evaluate())
          (
            tester.getRect(find.byWidget(element.widget)),
            element.widget.runtimeType.toString() == '_EditableJoystick',
          ),
      ];
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          expect(
            _gap(
              items[i].$1,
              items[j].$1,
              aJoystick: items[i].$2,
              bJoystick: items[j].$2,
            ),
            greaterThanOrEqualTo(GamepadEditMetrics.minControlGap - 0.5),
            reason: '${items[i].$1} vs ${items[j].$1}',
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
  });
}
