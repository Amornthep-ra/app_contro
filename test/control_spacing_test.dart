// Touch areas of close controls (see docs/UI_HANDOFF.md section 12).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/gamepad_components.dart';
import 'package:pb_controller/core/ui/gamepad_edit_metrics.dart';
import 'package:pb_controller/core/widgets/circular_hit_area.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          call,
        ) async {
          return call.method == 'hasVibrator' ? true : null;
        });
  });

  testWidgets('CircularHitArea only takes touches inside its circle', (
    tester,
  ) async {
    var outer = 0;
    var inner = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => outer++,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 100,
              height: 100,
              child: GestureDetector(
                onTap: () => inner++,
                child: const CircularHitArea(radius: 30),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(50, 50)); // centre
    await tester.tapAt(const Offset(75, 50)); // 25 from centre
    await tester.tapAt(const Offset(95, 95)); // box corner
    await tester.tapAt(const Offset(50, 85)); // 35 from centre
    expect(inner, 2);
    expect(outer, 2);
  });

  testWidgets('two buttons placed 4 dp apart never share a touch', (
    tester,
  ) async {
    // Two 88 px buttons whose visible faces are 4 dp apart: their boxes
    // overlap by ~20 px. The later one is drawn on top.
    const d = 88.0;
    final face = GamepadEditMetrics.buttonVisibleRadius(d);
    final a = const Offset(100, 100);
    final b = Offset(100 + 2 * face + 4, 100);
    final pressed = <String>[];
    Widget button(String id, Offset centre, Offset other) => Positioned(
      left: centre.dx - d / 2,
      top: centre.dy - d / 2,
      child: GamepadImageHoldButton(
        label: id,
        sendValue: id,
        asset: 'assets/icons/Gamepad_Mode_Edit/Button-Up.png',
        diameter: d,
        showLabel: false,
        touchRadius: GamepadEditMetrics.touchRadius(
          centre: centre,
          visibleRadius: face,
          maxRadius: d / 2,
          others: [(other, face)],
        ),
        onPressChanged: (id, down) {
          if (down) pressed.add(id);
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: [button('A', a, b), button('B', b, a)]),
      ),
    );
    Future<String?> pressAt(Offset point) async {
      pressed.clear();
      final gesture = await tester.startGesture(point);
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      return pressed.isEmpty ? null : pressed.single;
    }

    expect((b.dx - d / 2) < (a.dx + d / 2), isTrue, reason: 'boxes overlap');
    // Inside B's box but on A's side of the midline: A, not B on top.
    final mid = (a.dx + b.dx) / 2;
    expect(await pressAt(Offset(mid - 1, 100)), 'A');
    expect(await pressAt(Offset(mid + 1, 100)), 'B');
    expect(await pressAt(a), 'A');
    expect(await pressAt(b), 'B');
    // A far corner of A's box is outside its touch circle.
    expect(await pressAt(Offset(a.dx - d / 2 + 2, a.dy - d / 2 + 2)), isNull);
  });

  testWidgets('a button with no neighbour keeps its whole circle', (
    tester,
  ) async {
    var downs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: GamepadImageHoldButton(
                label: 'A',
                sendValue: 'A',
                asset: 'assets/icons/Gamepad_Mode_Edit/Button-Up.png',
                diameter: 88,
                showLabel: false,
                touchRadius: GamepadEditMetrics.touchRadius(
                  centre: const Offset(44, 44),
                  visibleRadius: GamepadEditMetrics.buttonVisibleRadius(88),
                  maxRadius: 44,
                  others: const [],
                ),
                onPressChanged: (_, down) {
                  if (down) downs++;
                },
              ),
            ),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(const Offset(44, 2));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(downs, 1);
  });
}
