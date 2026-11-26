import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/features/linesonic/linesonic_sensor_page.dart';

/// Auto on the Sensor page: no snack bar flood when reads fail, and no
/// reads while the app is in the background.
///
/// The test link has no characteristic, so every read fails and logs
/// no_characteristic; the tests count those.
void main() {
  setUp(() {
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  tearDown(() {
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.disconnected,
    );
  });

  /// The framework checks debugPrint is restored before tearDown, so each
  /// test calls the returned restore at its end.
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

  Future<void> openSensorPage(WidgetTester tester) async {
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.connected,
      connected: true,
      deviceName: 'LineSonic',
      mtu: 512,
    );
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LineSonicSensorPage()));
    await tester.pump();
  }

  Future<void> turnAutoOn(WidgetTester tester) async {
    await tester.tap(find.text('Auto Off'));
    await tester.pump();
  }

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('failing reads stop Auto with one message', (tester) async {
    final (writes, restore) = captureWrites();
    await openSensorPage(tester);
    await turnAutoOn(tester);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(writes, hasLength(3));
    expect(find.text('Auto Off'), findsOneWidget);
    expect(
      find.text('Auto stopped: the board is not receiving commands'),
      findsOneWidget,
    );
    // Only that message is on screen, not one per failed read.
    expect(find.byType(SnackBar), findsOneWidget);
    restore();
    await closePage(tester);
  });

  testWidgets('Auto pauses in the background and resumes', (tester) async {
    final (writes, restore) = captureWrites();
    await openSensorPage(tester);
    await turnAutoOn(tester);
    await tester.pump(const Duration(milliseconds: 250));
    expect(writes, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(writes, hasLength(1));
    expect(find.text('Auto On'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 250));
    expect(writes, hasLength(2));
    restore();
    await closePage(tester);
  });

  testWidgets('Auto turned off stays off after the app comes back', (
    tester,
  ) async {
    final (writes, restore) = captureWrites();
    await openSensorPage(tester);
    await turnAutoOn(tester);
    await tester.tap(find.text('Auto On'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));

    expect(writes, isEmpty);
    expect(find.text('Auto Off'), findsOneWidget);
    restore();
    await closePage(tester);
  });
}
