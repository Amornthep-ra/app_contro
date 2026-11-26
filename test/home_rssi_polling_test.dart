import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/routes/app_routes.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home reads RSSI only while it is on top and the app is in the
/// foreground, so the reads never compete with control writes.
void main() {
  const interval = Duration(seconds: 3);
  late int reads;

  setUp(() {
    reads = 0;
    OrientationUtils.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.connected,
      connected: true,
      deviceName: 'PB-Robot',
    );
  });

  tearDown(() {
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.disconnected,
    );
  });

  Future<GlobalKey<NavigatorState>> mountHome(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [appRouteObserver],
        home: HomePage(
          animateBackground: false,
          rssiPollInterval: interval,
          readRssi: () async {
            reads++;
            return -60;
          },
        ),
      ),
    );
    await tester.pump();
    return navigator;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('reads RSSI while Home is on top', (tester) async {
    await mountHome(tester);
    expect(reads, 1);

    await tester.pump(interval);
    await tester.pump(interval);
    expect(reads, 3);

    await unmount(tester);
  });

  testWidgets('stops while a page covers Home, resumes on return', (
    tester,
  ) async {
    final navigator = await mountHome(tester);
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Drive'))),
    );
    await tester.pumpAndSettle();
    final readsWhenCovered = reads;

    await tester.pump(interval * 5);
    expect(reads, readsWhenCovered);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    // Back on top: one read right away, then on the interval again.
    expect(reads, readsWhenCovered + 1);
    await tester.pump(interval);
    expect(reads, readsWhenCovered + 2);

    await unmount(tester);
  });

  testWidgets('stops in the background, resumes in the foreground', (
    tester,
  ) async {
    await mountHome(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final readsWhenPaused = reads;

    await tester.pump(interval * 5);
    expect(reads, readsWhenPaused);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, readsWhenPaused + 1);

    await unmount(tester);
  });

  testWidgets('stops and clears the signal on disconnect', (tester) async {
    await mountHome(tester);
    BleManager.instance.debugPresentConnectionForTesting(
      status: BleConnectionStatus.disconnected,
      connected: false,
    );
    BleManager.instance.debugEmitConnectionChangeForTesting(false);
    await tester.pump();
    final readsWhenDisconnected = reads;

    await tester.pump(interval * 5);
    expect(reads, readsWhenDisconnected);

    await unmount(tester);
  });
}
