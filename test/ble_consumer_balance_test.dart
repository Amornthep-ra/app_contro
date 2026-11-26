import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/widgets/ble_connection_sheet.dart';
import 'package:pb_controller/features/bluetooth/bluetooth_ble_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The adapter is on, so the page's Bluetooth-off listener stays quiet.
final class _FakeBluetooth extends FlutterBluePlusPlatform {
  final adapter = StreamController<BmBluetoothAdapterState>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => adapter.stream;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async => BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
}

class _NoopPlatform implements BleConnectionPlatform {
  @override
  Stream<List<ScanResult>> get scanResults => const Stream.empty();
  @override
  Future<void> connect(ScanResult result) async {}
  @override
  Future<void> disconnect(ScanResult result) async {}
  @override
  Future<void> startScan({required Duration timeout}) async {}
  @override
  Future<void> stopScan() async {}
}

/// Keeps the real consumer count and records what leaving a screen did.
class _CountingCoordinator extends BleConnectionCoordinator {
  _CountingCoordinator()
    : super(
        platform: _NoopPlatform(),
        listenToManagerAutoConnectRequests: false,
      );

  int acquires = 0;
  int releases = 0;
  int stopScanCalls = 0;

  @override
  void acquire() {
    acquires++;
    super.acquire();
  }

  @override
  Future<void> release() {
    releases++;
    return super.release();
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    int? owner,
  }) async {}

  @override
  Future<void> stopScan({
    bool cancelAutoConnect = true,
    bool releaseManagementLease = true,
  }) async => stopScanCalls++;
}

/// Leaving the Bluetooth page or the connection sheet gives the coordinator
/// back, so the scan stops once no screen holds it.
void main() {
  late _CountingCoordinator coordinator;

  setUpAll(() => FlutterBluePlusPlatform.instance = _FakeBluetooth());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    coordinator = _CountingCoordinator();
  });

  tearDown(() => coordinator.dispose());

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Widget page() => BluetoothBlePage(
    coordinator: coordinator,
    isBleConnected: () => false,
    enableBlePlatformBindings: true,
    pairingPromptLauncher: ({required context, coordinator}) async => null,
  );

  Widget sheet() => Scaffold(
    body: BleConnectionSheet(
      coordinator: coordinator,
      isBleConnected: () => false,
      enableBlePlatformBindings: true,
      onPairingRequested: (_) async {},
    ),
  );

  testWidgets('leaving the Bluetooth page stops the scan', (tester) async {
    await show(tester, page());
    await leave(tester);

    expect(coordinator.releases, coordinator.acquires);
    expect(coordinator.stopScanCalls, 1);
  });

  testWidgets('after a Bluetooth page visit, closing the sheet stops the '
      'scan', (tester) async {
    await show(tester, page());
    await leave(tester);
    await show(tester, sheet());
    await leave(tester);

    expect(coordinator.releases, coordinator.acquires);
    expect(coordinator.stopScanCalls, 2);
  });
}
