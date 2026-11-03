// Joystick idle keepalive (docs/UI_HANDOFF.md section 14): while Start is on
// and nothing is touched, the page re-sends the zero frame every 150 ms so
// the board's 400 ms watchdog never drops the session.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/joystick_packet.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  test('the idle keepalive is due after 6 ticks of 25 ms (150 ms)', () {
    expect(kJoystickIdleKeepaliveMs, 150);
    expect(kJoystickTickMs, 25);
    expect(joystickIdleKeepaliveDue(5), isFalse);
    expect(joystickIdleKeepaliveDue(6), isTrue);
    expect(joystickIdleKeepaliveDue(7), isTrue);
  });

  /// Opens the Joystick page with a Start that claims control at once and
  /// records when each control frame is handed to BleManager.
  Future<List<(int, JoystickPacket, Set<int>)>> openPage(
    WidgetTester tester,
    ValueGetter<int> elapsedMs,
  ) async {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final frames = <(int, JoystickPacket, Set<int>)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: JoystickPage(
          acquireControl: () async => BleManager.instance.claimTrafficMode(
            BleTrafficMode.controlBinary,
          ),
          onControlFrameForTesting: (packet, buttons) =>
              frames.add((elapsedMs(), packet, buttons)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return frames;
  }

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  bool isZero((int, JoystickPacket, Set<int>) frame) {
    final (_, p, buttons) = frame;
    return p.lx == 0 && p.ly == 0 && p.rx == 0 && p.ry == 0 && buttons.isEmpty;
  }

  testWidgets('after Start, an untouched Joystick keeps sending the zero '
      'frame every 150 ms', (tester) async {
    var elapsed = 0;
    final frames = await openPage(tester, () => elapsed);

    // Nothing before Start.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      elapsed += 25;
    }
    expect(frames, isEmpty);

    await tester.tap(find.byType(GamepadStartStopControlButton));
    await tester.pump();
    expect(frames, isNotEmpty, reason: 'Start sends a zero frame');
    final startedAt = elapsed;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      elapsed += 25;
    }

    expect(frames.every(isZero), isTrue);
    final times = [for (final f in frames) f.$1];
    // One Start frame plus one every 150 ms over 1 s.
    expect(times.length, greaterThanOrEqualTo(7));
    var previous = startedAt;
    for (final t in times.skip(1)) {
      expect(t - previous, lessThanOrEqualTo(kJoystickIdleKeepaliveMs));
      previous = t;
    }
    expect(elapsed - previous, lessThan(400), reason: 'no 400 ms silence');
    await closePage(tester);
  });

  testWidgets('no keepalive in the layout editor', (tester) async {
    var elapsed = 0;
    final frames = await openPage(tester, () => elapsed);
    await tester.tap(find.byType(GamepadStartStopControlButton));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit layout'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done'), findsOneWidget);

    final before = frames.length;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      elapsed += 25;
    }
    expect(frames.length, before);
    await closePage(tester);
  });
}
