import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/gamepad_assets.dart';
import 'package:pb_controller/core/ui/lavender_glass.dart';
import 'package:pb_controller/features/gamepad/widgets/gamepad_controls_sheet.dart';

const _groups = [
  GamepadControlGroup(
    title: 'Left pad',
    choices: [
      GamepadControlChoice(id: 'L:up', label: 'Up', asset: kGamepad8AssetUp),
      GamepadControlChoice(
        id: 'L:down',
        label: 'Down',
        asset: kGamepad8AssetDown,
      ),
      GamepadControlChoice(
        id: 'L:left',
        label: 'Left',
        asset: kGamepad8AssetLeft,
      ),
      GamepadControlChoice(
        id: 'L:right',
        label: 'Right',
        asset: kGamepad8AssetRight,
      ),
    ],
  ),
  GamepadControlGroup(
    title: 'Right pad',
    choices: [
      GamepadControlChoice(
        id: 'R:triangle',
        label: 'Triangle',
        asset: kGamepad8AssetTriangle,
      ),
      GamepadControlChoice(
        id: 'R:cross',
        label: 'Cross',
        asset: kGamepad8AssetCross,
      ),
      GamepadControlChoice(
        id: 'R:square',
        label: 'Square',
        icon: Icons.crop_square,
      ),
      GamepadControlChoice(
        id: 'R:circle',
        label: 'Circle',
        icon: Icons.circle_outlined,
      ),
    ],
  ),
];

void main() {
  late Set<String> active;
  late List<String> toggled;

  setUp(() {
    active = {'L:up', 'L:down', 'R:triangle'};
    toggled = [];
  });

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showGamepadControlsSheet(
                  context: context,
                  groups: _groups,
                  isActive: active.contains,
                  onToggle: (id) {
                    toggled.add(id);
                    if (!active.remove(id)) active.add(id);
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(GamepadControlsSheet), findsOneWidget);
  }

  Finder tile(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell));

  Finder iconIn(String label, IconData icon) =>
      find.descendant(of: tile(label), matching: find.byIcon(icon));

  testWidgets('shows each control with its state; a tap applies at once', (
    tester,
  ) async {
    await open(tester, const Size(914, 411));

    expect(find.text('LEFT PAD'), findsOneWidget);
    expect(find.text('RIGHT PAD'), findsOneWidget);
    expect(iconIn('Up', Icons.check_circle_rounded), findsOneWidget);
    expect(iconIn('Left', Icons.add_circle_outline_rounded), findsOneWidget);

    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(toggled, ['L:left']);
    expect(iconIn('Left', Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Up'));
    await tester.pump();
    expect(toggled, ['L:left', 'L:up']);
    expect(iconIn('Up', Icons.add_circle_outline_rounded), findsOneWidget);
    // Still open: several controls can be changed in one go.
    expect(find.byType(GamepadControlsSheet), findsOneWidget);
  });

  testWidgets('Done and a tap outside both close the sheet', (tester) async {
    await open(tester, const Size(914, 411));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(GamepadControlsSheet), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(GamepadControlsSheet), findsNothing);
  });

  testWidgets('Done stays on screen while the list scrolls at 640x360', (
    tester,
  ) async {
    await open(tester, const Size(640, 360));
    await tester.drag(find.text('Up'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Circle'));
    await tester.pumpAndSettle();

    final done = tester.getRect(find.widgetWithText(GlassActionButton, 'Done'));
    expect(done.top, greaterThanOrEqualTo(0));
    expect(done.bottom, lessThanOrEqualTo(360));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(GamepadControlsSheet), findsNothing);
  });

  for (final (size, columns) in [
    (const Size(914, 411), 2),
    (const Size(411, 914), 1),
  ]) {
    testWidgets('tiles are at least 48 px tall, $columns column(s) at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size);
      for (final label in ['Up', 'Down', 'Triangle', 'Circle']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.getSize(tile(label)).height, greaterThanOrEqualTo(48));
      }
      await tester.ensureVisible(find.text('Up'));
      await tester.pumpAndSettle();
      final up = tester.getRect(tile('Up'));
      final down = tester.getRect(tile('Down'));
      if (columns == 2) {
        expect(down.top, up.top);
        expect(down.left, greaterThan(up.right));
      } else {
        expect(down.top, greaterThan(up.bottom));
        expect(down.left, up.left);
      }
    });
  }
}
