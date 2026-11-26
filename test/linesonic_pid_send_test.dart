import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/features/linesonic/linesonic_pid_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Send All checks the steps with LineSonicProtocol before anything goes
/// to the board.
void main() {
  Map<String, Object> step({String speed = '50'}) => {
    'mode': 'TIME',
    'kp': '1.5',
    'kd': '0.8',
    'speed': speed,
    'value': '1000',
    'continueAfter': false,
    'afterMs': '0',
    'afterSpeed': '0',
    'stopBetween': false,
    'stopMs': '0',
    'holdMode': 0,
    'holdMs': '0',
    'holdThreshold': '0',
    'lineColor': 0,
    'collapsed': true,
    'showOptions': false,
  };

  setUp(() {
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  tearDown(() {
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.disconnected,
    );
  });

  Future<void> openWithSteps(
    WidgetTester tester,
    List<Map<String, Object>> steps, {
    int mtu = 512,
  }) async {
    SharedPreferences.setMockInitialValues({
      'linesonic_steps_v2': jsonEncode(steps),
    });
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.connected,
      connected: true,
      deviceName: 'LineSonic',
      mtu: mtu,
    );
    // Wide: the default test font is far wider than a real one.
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LineSonicPidPage()));
    await tester.pumpAndSettle();
  }

  Future<void> tapSendAll(WidgetTester tester) async {
    final send = find.text('Send All');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
  }

  testWidgets('a field out of range is named and nothing is sent', (
    tester,
  ) async {
    await openWithSteps(tester, [step(), step(speed: '150')]);
    await tapSendAll(tester);

    expect(find.text('Step 2 · Speed: Must be 100 or less.'), findsOneWidget);
    expect(find.text('Sent all'), findsNothing);
    expect(find.textContaining('Command not sent'), findsNothing);
  });

  testWidgets('steps that need more than one write are not sent', (
    tester,
  ) async {
    // MTU 185 leaves 182 bytes: fewer than 10 steps fit.
    await openWithSteps(tester, List.generate(10, (_) => step()), mtu: 185);
    await tapSendAll(tester);

    expect(
      find.textContaining('Too long to send at once: this phone fits'),
      findsOneWidget,
    );
    expect(find.textContaining('Command not sent'), findsNothing);
  });

  testWidgets('valid steps that fit go to the BLE write', (tester) async {
    await openWithSteps(tester, [step()]);
    await tapSendAll(tester);

    // The test link has no characteristic, so the write itself fails:
    // the checks let the command through.
    expect(find.textContaining('Command not sent'), findsOneWidget);
  });
}
