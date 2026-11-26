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
    Future<BleWriteResult> Function(String command)? send,
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
    await tester.pumpWidget(
      MaterialApp(home: LineSonicPidPage(sendOverride: send)),
    );
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

  testWidgets('a step with no mode is named and nothing is sent', (
    tester,
  ) async {
    await openWithSteps(tester, [step()..['mode'] = '']);
    await tapSendAll(tester);

    expect(find.text('Step 1 · Mode: Pick Time or CheckSum.'), findsOneWidget);
    expect(find.textContaining('Command not sent'), findsNothing);
  });

  testWidgets('a stop-only step goes to the BLE write', (tester) async {
    await openWithSteps(tester, [
      step()
        ..['value'] = '0'
        ..['stopBetween'] = true
        ..['stopMs'] = '500',
    ]);
    await tapSendAll(tester);

    expect(find.textContaining('Must be more than 0'), findsNothing);
    // The test link has no characteristic, so the write itself fails.
    expect(find.textContaining('Command not sent'), findsOneWidget);
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

  group('send buttons (C-5)', () {
    /// BLE writes that reached the link (the test link has no
    /// characteristic, so each one logs no_characteristic).
    /// The test framework checks debugPrint is restored before tearDown,
    /// so each test calls the returned restore at its end.
    (List<String>, void Function()) captureWrites() {
      final writes = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.contains('no_characteristic')) {
          writes.add(message);
        }
      };
      return (writes, () => debugPrint = previous);
    }

    Future<void> tapButton(WidgetTester tester, String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }

    testWidgets('a send that did not go out starts no cooldown', (
      tester,
    ) async {
      final (writes, restore) = captureWrites();
      await openWithSteps(tester, [step()]);
      BleManager.instance.debugPresentConnectionForTesting(
        status: BleConnectionStatus.disconnected,
        connected: false,
      );
      await tapButton(tester, 'Send All');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('BLE not connected'), findsOneWidget);

      BleManager.instance.debugPresentConnectionForTesting(
        status: BleConnectionStatus.connected,
        connected: true,
        deviceName: 'LineSonic',
        mtu: 512,
      );
      await tapButton(tester, 'Send All');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Please wait 3 seconds before sending again'),
        findsNothing,
      );
      expect(writes, hasLength(1));

      // That write failed too, so a third press is not held back either.
      await tapButton(tester, 'Send All');
      await tester.pump(const Duration(milliseconds: 300));
      expect(writes, hasLength(2));
      restore();
    });

    testWidgets('a second command right after the first is not dropped', (
      tester,
    ) async {
      final (writes, restore) = captureWrites();
      await openWithSteps(tester, [step()]);
      await tapButton(tester, 'SW1');
      await tapButton(tester, 'Reset Board');
      // The second waits out the short gap between commands.
      await tester.pump(const Duration(milliseconds: 300));
      expect(writes, hasLength(2));
      restore();
    });
  });

  group('Send PD+Speed follows the last Send All (N-7)', () {
    late List<String> sent;
    Future<BleWriteResult> send(String command) async {
      sent.add(command);
      return BleWriteResult.sent;
    }

    setUp(() => sent = []);

    Future<void> press(WidgetTester tester, String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      // Past the 3 s / 1 s cooldowns and the snack bar.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 4));
    }

    /// The step's KP field (saved as 1.5; the card is opened first).
    Future<void> setKp(WidgetTester tester, String kp) async {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '1.5',
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, kp);
      await tester.pump();
    }

    testWidgets('before any Send All nothing is sent', (tester) async {
      await openWithSteps(tester, [step()], send: send);
      await press(tester, 'Send PD+Speed');

      expect(sent, isEmpty);
    });

    testWidgets('after Send All, new KP goes as SEQPD=', (tester) async {
      await openWithSteps(tester, [step()..['collapsed'] = false], send: send);
      await press(tester, 'Send All');
      await setKp(tester, '2.5');
      await press(tester, 'Send PD+Speed');

      expect(sent, [startsWith('SEQ='), 'SEQPD=2.5,0.8,50']);
    });

    testWidgets('a step added since Send All stops it', (tester) async {
      await openWithSteps(tester, [step()], send: send);
      await press(tester, 'Send All');
      await tester.tap(find.text('Add Step'));
      await tester.pump();
      await press(tester, 'Send PD+Speed');

      expect(sent, hasLength(1));
    });

    testWidgets('after Reset Board it waits for the next Send All', (
      tester,
    ) async {
      await openWithSteps(tester, [step()], send: send);
      await press(tester, 'Send All');
      await press(tester, 'Reset Board');
      await press(tester, 'Send PD+Speed');

      expect(sent, [startsWith('SEQ='), 'RESET=1']);
    });

    testWidgets('a bad KP is named, not "Send All first"', (tester) async {
      await openWithSteps(tester, [step()..['collapsed'] = false], send: send);
      await press(tester, 'Send All');
      await setKp(tester, '2000000');
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      final button = find.text('Send PD+Speed');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Step 1 · KP: Must be 1000000 or less.'),
        findsOneWidget,
      );
      expect(sent, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Save Preset (C-6)', () {
    Future<void> openSaveDialog(WidgetTester tester) async {
      await openWithSteps(tester, [step()]);
      final save = find.byIcon(Icons.save_outlined);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Save Preset'), findsOneWidget);
    }

    testWidgets('Save closes cleanly and keeps the name', (tester) async {
      await openSaveDialog(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Track A',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save Preset'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('linesonic_presets_v1'), contains('Track A'));
    });

    testWidgets('Cancel closes cleanly', (tester) async {
      await openSaveDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Save Preset'), findsNothing);
    });
  });
}
