import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/features/linesonic/linesonic_sensor_page.dart';

/// The Sensor page says which scale its numbers are on, and does not read
/// TX after Read Now (the board puts "ACK" there).
void main() {
  late List<String> sent;
  late int txReads;
  late StreamController<List<int>> notifications;

  setUp(() {
    sent = [];
    txReads = 0;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.connected,
      connected: true,
      deviceName: 'LineSonic',
      mtu: 512,
    );
  });

  tearDown(() async {
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.disconnected,
    );
  });

  Future<void> openPage(WidgetTester tester, {String tx = 'ACK\n'}) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Sync: events reach the page as soon as they are added.
    notifications = StreamController<List<int>>.broadcast(sync: true);
    addTearDown(notifications.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LineSonicSensorPage(
          sendOverride: (command) async {
            sent.add(command);
            return BleWriteResult.sent;
          },
          readTxOverride: () async {
            txReads++;
            return tx.codeUnits;
          },
          dataOverride: notifications.stream,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> receive(WidgetTester tester, String line) async {
    notifications.add('$line\n'.codeUnits);
    await tester.pump();
  }

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('Read Now sends SENS=1 and does not read TX after it', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.text('Read Now'));
    await tester.pump(const Duration(seconds: 1));

    expect(sent, ['SENS=1']);
    expect(txReads, 0);
    await closePage(tester);
  });

  testWidgets('a reply without SUM is labelled raw ADC', (tester) async {
    await openPage(tester);
    await receive(tester, 'SENS=1023,2048,512');

    expect(find.text('Sensor Values (raw ADC)'), findsOneWidget);
    expect(find.text('S2: 2048'), findsOneWidget);
    expect(find.textContaining('SUM:'), findsNothing);
    await closePage(tester);
  });

  testWidgets('a line with SUM is on the 0-100 scale CheckSum uses', (
    tester,
  ) async {
    await openPage(tester);
    await receive(tester, 'SENS=40,60,SUM=100');

    expect(find.text('Sensor Values (0-100)'), findsOneWidget);
    expect(find.text('SUM: 100'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Read (force) that finds ACK keeps the values', (tester) async {
    await openPage(tester);
    await receive(tester, 'SENS=40,60,SUM=100');
    await tester.tap(find.text('Read (force)'));
    await tester.pump();

    expect(txReads, 1);
    expect(find.text('S1: 40'), findsOneWidget);
    expect(
      find.textContaining('READ: ACK (the reply to a command, not a reading)'),
      findsOneWidget,
    );
    await closePage(tester);
  });
}
