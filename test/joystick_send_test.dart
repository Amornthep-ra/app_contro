// What the Joystick page sends while driving: button edges, held sticks,
// and nothing once the layout editor opens.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/joystick_packet.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sent {
  _Sent(this.packet, this.buttons, this.force);
  final JoystickPacket packet;
  final Set<int> buttons;
  final bool force;
}

void main() {
  final sent = <_Sent>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), (
          call,
        ) async {
          return call.method == 'hasVibrator' ? true : null;
        });
    SharedPreferences.setMockInitialValues({
      'joy_dual_active': jsonEncode(['joy_left', 'btn_triangle']),
      'joy_dual_layout': jsonEncode({
        'joy_left': {'cx': 0.25, 'cy': 0.5, 'size': 1.0},
        'btn_triangle': {'cx': 0.75, 'cy': 0.5, 'size': 1.0},
      }),
    });
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
    sent.clear();
  });

  Future<void> mountAndStart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: JoystickPage(
          acquireControl: () async => 1,
          sendControlPacket: (packet, buttons, force) =>
              sent.add(_Sent(packet, buttons, force)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ControlStartStopButton));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);
    // Let the idle keepalive settle, then watch only what follows.
    await tester.pump(const Duration(milliseconds: 200));
    sent.clear();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('a quick tap on a face button sends its press and release '
      'past the rate limiter', (tester) async {
    await mountAndStart(tester);
    final triangle = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_JoyImagePressHoldButton',
    );
    final gesture = await tester.startGesture(tester.getRect(triangle).center);
    await tester.pump(const Duration(milliseconds: 10));
    await gesture.up();
    await tester.pump();

    final press = sent.indexWhere(
      (s) => s.buttons.contains(kBleBtnTriangle) && s.force,
    );
    expect(press, isNonNegative, reason: 'press sent with force');
    expect(
      sent.skip(press + 1).any((s) => s.buttons.isEmpty && s.force),
      isTrue,
      reason: 'release sent with force',
    );
    await unmount(tester);
  });

  testWidgets('a stick pushed to the rim and held still sends full value', (
    tester,
  ) async {
    await mountAndStart(tester);
    final stick = tester.getRect(find.byType(JoystickView));
    // Well past the knob's travel to the right: full right.
    final gesture = await tester.startGesture(
      stick.center + Offset(stick.width * 0.45, 0),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(sent, isNotEmpty);
    expect(sent.last.packet.lx, greaterThanOrEqualTo(0.99));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 25));
    expect(sent.last.packet.lx, 0);
    await unmount(tester);
  });

  testWidgets('opening the layout editor stops driving; Start is needed '
      'again after it', (tester) async {
    await mountAndStart(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit layout'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    sent.clear();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('Start control'), findsOneWidget);
    expect(sent, isEmpty, reason: 'nothing is sent until Start');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
