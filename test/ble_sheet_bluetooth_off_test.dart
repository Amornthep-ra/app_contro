import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/widgets/ble_connection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The adapter state the tests set; a new listener gets it first.
class _Adapter {
  final _changes = StreamController<BluetoothAdapterState>.broadcast(
    sync: true,
  );
  BluetoothAdapterState state = BluetoothAdapterState.off;

  void set(BluetoothAdapterState value) {
    state = value;
    _changes.add(value);
  }

  Stream<BluetoothAdapterState> states() async* {
    yield state;
    yield* _changes.stream;
  }
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

class _ScanCountingCoordinator extends BleConnectionCoordinator {
  _ScanCountingCoordinator()
    : super(
        platform: _NoopPlatform(),
        listenToManagerAutoConnectRequests: false,
      );

  int scans = 0;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    int? owner,
  }) async => scans++;
}

/// "Scan devices" in the connection sheet (the BLE icon on Controller and
/// LineSonic pages) asks to turn Bluetooth on, like the Bluetooth page.
void main() {
  late _Adapter bluetooth;
  late _ScanCountingCoordinator coordinator;
  late List<String> settingsCalls;

  setUp(() {
    bluetooth = _Adapter();
    SharedPreferences.setMockInitialValues({});
    coordinator = _ScanCountingCoordinator();
    settingsCalls = [];
  });

  tearDown(() => coordinator.dispose());

  Future<void> openSheet(
    WidgetTester tester,
    BluetoothAdapterState state,
  ) async {
    bluetooth.set(state);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.pbcontroller.app/bluetooth_settings'),
      (call) async {
        settingsCalls.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.pbcontroller.app/bluetooth_settings'),
        null,
      ),
    );
    tester.view.physicalSize = const Size(914, 411) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BleConnectionSheet(
            coordinator: coordinator,
            isBleConnected: () => false,
            enableBlePlatformBindings: false,
            onPairingRequested: (_) async {},
            adapterStates: bluetooth.states,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapScan(WidgetTester tester) async {
    await tester.tap(find.text('Scan devices'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Bluetooth on: Scan devices scans', (tester) async {
    await openSheet(tester, BluetoothAdapterState.on);
    await tapScan(tester);

    expect(find.text('Bluetooth is off'), findsNothing);
    expect(coordinator.scans, 1);
  });

  testWidgets('Bluetooth off: asks, opens settings, scans once it is on', (
    tester,
  ) async {
    await openSheet(tester, BluetoothAdapterState.off);
    await tapScan(tester);

    expect(find.text('Bluetooth is off'), findsOneWidget);
    expect(coordinator.scans, 0);

    await tester.tap(find.text('Open settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settingsCalls, ['openBluetoothSettings']);
    expect(coordinator.scans, 0);

    bluetooth.set(BluetoothAdapterState.on);
    await tester.pump();
    expect(coordinator.scans, 1);
  });

  testWidgets('Bluetooth off, Cancel: no settings, no scan', (tester) async {
    await openSheet(tester, BluetoothAdapterState.off);
    await tapScan(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));

    bluetooth.set(BluetoothAdapterState.on);
    await tester.pump();
    expect(settingsCalls, isEmpty);
    expect(coordinator.scans, 0);
  });
}
