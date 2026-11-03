import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/widgets/control_input_gate.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_controller.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';

void main() {
  testWidgets(
    'Stop locks and desaturates; Start unlocks; suspension locks; editing works',
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
      Finder lockedLook() => find.byKey(const ValueKey('control-locked-look'));
      await show();
      expect(opacity(), ControlInputGate.lockedOpacity);
      expect(lockedLook(), findsOneWidget);
      await tester.tap(find.text('Drive'), warnIfMissed: false);
      expect(taps, 0);
      await show(started: true);
      expect(opacity(), 1);
      expect(lockedLook(), findsNothing);
      await tester.tap(find.text('Drive'));
      expect(taps, 1);
      suspended.value = true;
      await tester.pump();
      expect(opacity(), ControlInputGate.lockedOpacity);
      expect(lockedLook(), findsOneWidget);
      await tester.tap(find.text('Drive'), warnIfMissed: false);
      expect(taps, 1);
      await show(editing: true);
      expect(opacity(), 1);
      expect(lockedLook(), findsNothing);
      await tester.tap(find.text('Drive'));
      expect(taps, 2);
      suspended.value = false;
      await show();
      expect(opacity(), ControlInputGate.lockedOpacity);
      expect(lockedLook(), findsOneWidget);
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

  testWidgets('tapping locked controls asks the page to explain', (
    tester,
  ) async {
    final suspended = ValueNotifier(false);
    addTearDown(suspended.dispose);
    var explained = 0;
    var driven = 0;
    Future<void> show({required bool started}) => tester.pumpWidget(
      MaterialApp(
        home: ControlInputGate(
          started: started,
          editing: false,
          suspended: suspended,
          onLockedTap: () => explained++,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => driven++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    await show(started: false);
    await tester.tapAt(tester.getCenter(find.byType(ControlInputGate)));
    await tester.pump();
    expect(explained, 1);
    expect(driven, 0);

    await show(started: true);
    await tester.tapAt(tester.getCenter(find.byType(ControlInputGate)));
    await tester.pump();
    expect(explained, 1);
    expect(driven, 1);
  });

  testWidgets('controls keep their state across lock and unlock', (
    tester,
  ) async {
    final suspended = ValueNotifier(false);
    addTearDown(suspended.dispose);
    final key = GlobalKey<_CounterState>();
    Future<void> show(bool started) => tester.pumpWidget(
      MaterialApp(
        home: ControlInputGate(
          started: started,
          editing: false,
          suspended: suspended,
          onLockedTap: () {},
          child: _Counter(key: key),
        ),
      ),
    );

    await show(true);
    key.currentState!.count = 7;
    await show(false);
    await show(true);
    expect(key.currentState!.count, 7);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Text('$count');
}
