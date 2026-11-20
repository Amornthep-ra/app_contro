// Round hold buttons: touch only inside the circle, one hold per finger set.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/gamepad_components.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          call,
        ) async {
          return call.method == 'hasVibrator' ? true : null;
        });
  });

  const diameter = 100.0;
  final events = <String>[];

  Widget button(String value, Offset topLeft) => Positioned(
    left: topLeft.dx,
    top: topLeft.dy,
    child: GamepadImageHoldButton(
      label: value,
      sendValue: value,
      asset: 'missing.png',
      diameter: diameter,
      showLabel: false,
      onPressChanged: (id, down) => events.add('$id ${down ? 'down' : 'up'}'),
    ),
  );

  Future<void> pumpPad(WidgetTester tester, List<Widget> buttons) async {
    events.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(children: buttons),
      ),
    );
  }

  testWidgets('a corner of the button on top does not take a touch on the '
      'circle under it', (tester) async {
    // Diagonal neighbours, like ← and ↑ on the 8 button pad: B is drawn on
    // top and its square's bottom-left corner covers A's top-right edge.
    await pumpPad(tester, [
      button('A', const Offset(0, 100)),
      button('B', const Offset(70, 30)),
    ]);
    // Inside A's circle (centre 50,150), outside B's (centre 120,80) but
    // inside B's square.
    const point = Offset(80, 120);
    expect((point - const Offset(50, 150)).distance, lessThan(diameter / 2));
    expect((point - const Offset(120, 80)).distance, greaterThan(diameter / 2));

    final gesture = await tester.startGesture(point);
    await tester.pump();
    expect(events, ['A down']);
    await gesture.up();
    await tester.pump();
    expect(events, ['A down', 'A up']);
  });

  testWidgets('a square corner outside the circle presses nothing', (
    tester,
  ) async {
    await pumpPad(tester, [button('A', Offset.zero)]);
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(events, isEmpty);
  });

  testWidgets('lifting a second finger keeps the button held', (
    tester,
  ) async {
    await pumpPad(tester, [button('A', Offset.zero)]);
    final first = await tester.startGesture(const Offset(50, 50), pointer: 1);
    final second = await tester.startGesture(
      const Offset(60, 55),
      pointer: 2,
    );
    await tester.pump();
    expect(events, ['A down']);

    await second.up();
    await tester.pump();
    expect(events, ['A down'], reason: 'first finger is still down');

    await first.up();
    await tester.pump();
    expect(events, ['A down', 'A up']);
  });

  testWidgets('a finger sliding well off the button lets go', (tester) async {
    await pumpPad(tester, [button('A', const Offset(100, 100))]);
    final gesture = await tester.startGesture(const Offset(150, 150));
    await tester.pump();
    // Still within 1.3 radii of the centre: held.
    await gesture.moveTo(const Offset(150, 210));
    await tester.pump();
    expect(events, ['A down']);
    // Past it: released, even though the finger is still down.
    await gesture.moveTo(const Offset(150, 230));
    await tester.pump();
    expect(events, ['A down', 'A up']);
    await gesture.up();
    await tester.pump();
    expect(events, ['A down', 'A up']);
  });
}
