import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/widgets/control_input_gate.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_controller.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';

void main() {
  testWidgets(
    'Stop locks and dims; Start unlocks; suspension locks; editing works',
    (tester) async {
      final suspended = ValueNotifier(false);
      addTearDown(suspended.dispose);
      var taps = 0;
      Future<void> show({bool started = false, bool editing = false}) =>
          tester.pumpWidget(
            MaterialApp(
              home: ControlInputGate(
                started: started,
                editing: editing,
                suspended: suspended,
                child: Center(
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: const SizedBox(
                      width: 100,
                      height: 100,
                      child: Text('Drive'),
                    ),
                  ),
                ),
              ),
            ),
          );
      double opacity() => tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byType(ControlInputGate),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      await show();
      expect(opacity(), 0.4);
      await tester.tap(find.text('Drive'), warnIfMissed: false);
      expect(taps, 0);
      await show(started: true);
      expect(opacity(), 1);
      await tester.tap(find.text('Drive'));
      expect(taps, 1);
      suspended.value = true;
      await tester.pump();
      expect(opacity(), 0.4);
      await tester.tap(find.text('Drive'), warnIfMissed: false);
      expect(taps, 1);
      await show(editing: true);
      expect(opacity(), 1);
      await tester.tap(find.text('Drive'));
      expect(taps, 2);
      suspended.value = false;
      await show();
      expect(opacity(), 0.4);
    },
  );

  testWidgets('stopped joystick ignores drag; Start requires a new touch', (
    tester,
  ) async {
    final suspended = ValueNotifier(false);
    addTearDown(suspended.dispose);
    final controller = JoystickController();
    Future<void> show(bool started) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ControlInputGate(
            started: started,
            editing: false,
            suspended: suspended,
            child: SizedBox(
              width: 200,
              height: 200,
              child: JoystickView(controller: controller),
            ),
          ),
        ),
      ),
    );
    await show(false);
    final center = tester.getCenter(find.byType(JoystickView));
    final held = await tester.startGesture(center);
    await held.moveTo(center + const Offset(50, 0));
    expect(controller.buildPacket().lx, 0);
    await show(true);
    await held.moveTo(center + const Offset(60, 0));
    expect(controller.buildPacket().lx, 0);
    await held.up();
    final fresh = await tester.startGesture(center);
    await fresh.moveTo(center + const Offset(50, 0));
    expect(controller.buildPacket().lx, greaterThan(0));
    await fresh.up();
    await tester.pumpAndSettle();
    expect(controller.buildPacket().lx, 0);
  });
}
