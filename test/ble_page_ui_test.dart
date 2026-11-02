import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ui/lavender_glass.dart';
import 'package:pb_controller/core/widgets/ble_status_orb.dart';
import 'package:pb_controller/features/bluetooth/bluetooth_ble_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _SpyCoordinator extends BleConnectionCoordinator {
  _SpyCoordinator()
    : super(
        platform: _NoopPlatform(),
        listenToManagerAutoConnectRequests: false,
      );

  int forgetCalls = 0;
  final connected = <String>[];
  Completer<void> connectCompleter = Completer<void>();

  @override
  Future<void> forgetLastDevice() async => forgetCalls++;

  @override
  Future<void> connect(
    ScanResult result, {
    String source = 'ble_coordinator',
    bool preserveAutoConnect = false,
    int? owner,
    bool userInitiated = true,
  }) {
    connected.add(result.device.remoteId.str);
    return connectCompleter.future;
  }
}

ScanResult _scan(String id, String name, int rssi) => ScanResult(
  device: BluetoothDevice.fromId(id),
  advertisementData: AdvertisementData(
    advName: name,
    txPowerLevel: null,
    appearance: null,
    connectable: true,
    manufacturerData: const {},
    serviceData: const {},
    serviceUuids: const [],
  ),
  rssi: rssi,
  timeStamp: DateTime(2026),
);

const _lastId = 'C8:2E:18:4A:9F:01';
const _withLast = BleConnectionCoordinatorState(
  lastDeviceId: _lastId,
  lastDeviceName: 'PB-Robot-01',
);

void main() {
  late _SpyCoordinator coordinator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    coordinator = _SpyCoordinator();
  });

  tearDown(() async {
    if (!coordinator.connectCompleter.isCompleted) {
      coordinator.connectCompleter.complete();
    }
    await coordinator.dispose();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    BleConnectionCoordinatorState state, {
    bool connected = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    coordinator.debugEmitForTesting(state);
    await tester.pumpWidget(
      MaterialApp(
        home: BluetoothBlePage(
          coordinator: coordinator,
          isBleConnected: () => connected,
          enableBlePlatformBindings: false,
          pairingPromptLauncher:
              ({required context, required isThai, coordinator}) async => null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('scan results sort strongest signal first, then by name', () {
    final sorted = sortBleScanResults([
      _scan('03', 'Zeta', -83),
      _scan('02', 'Beta', -60),
      _scan('01', 'Alpha', -62),
      _scan('04', 'Gamma', -50),
    ]);
    expect(sorted.map(bleScanResultName), ['Gamma', 'Alpha', 'Beta', 'Zeta']);
  });

  testWidgets('status text sits next to the orb, not centred', (tester) async {
    // Wide screen + short text, so a centred column would visibly drift
    // away from the orb.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    coordinator.debugEmitForTesting(
      const BleConnectionCoordinatorState(scanning: true, scanSecondsLeft: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BluetoothBlePage(
          coordinator: coordinator,
          isBleConnected: () => false,
          enableBlePlatformBindings: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final orbRight = tester.getTopRight(find.byType(BleStatusOrb)).dx;
    final title = find.descendant(
      of: find.byType(AnimatedSwitcher),
      matching: find.text('Scanning…'),
    );
    expect(tester.getTopLeft(title).dx - orbRight, closeTo(16, 1));
  });

  testWidgets('idle state tells the user to tap Scan', (tester) async {
    await pumpPage(tester, const BleConnectionCoordinatorState());

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Power on your robot, then tap Scan.'), findsOneWidget);
  });

  testWidgets('scanning state says so instead of "tap Scan"', (tester) async {
    await pumpPage(
      tester,
      const BleConnectionCoordinatorState(scanning: true, scanSecondsLeft: 7),
    );

    expect(find.text('Scanning…'), findsOneWidget);
    expect(find.text('Looking for nearby robots…'), findsOneWidget);
    expect(find.text('Power on your robot, then tap Scan.'), findsNothing);
    expect(find.text('Scanning 7s'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('empty device list stays compact', (tester) async {
    await pumpPage(tester, const BleConnectionCoordinatorState());

    final panel = find.ancestor(
      of: find.text('No robots found yet'),
      matching: find.byType(GlassPanel),
    );
    expect(tester.getSize(panel).height, lessThan(240));
  });

  testWidgets('last device shows Connected instead of Connect when in use', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _withLast.copyWith(securityState: BleControlSecurityState.ready),
      connected: true,
    );

    expect(find.text('Connect'), findsNothing);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Paired'), findsOneWidget);
  });

  testWidgets('Forget asks for confirmation first', (tester) async {
    await pumpPage(tester, _withLast);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget device'));
    await tester.pumpAndSettle();
    expect(find.text('Forget PB-Robot-01?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(coordinator.forgetCalls, 0);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(coordinator.forgetCalls, 1);
  });

  testWidgets('tapping a robot shows a spinner on that row only', (
    tester,
  ) async {
    // Created inside the test body so it completes in the fake-async zone.
    coordinator.connectCompleter = Completer<void>();
    await pumpPage(
      tester,
      BleConnectionCoordinatorState(
        devices: [
          _scan('AA:01', 'PB-Robot-01', -52),
          _scan('AA:02', 'PB-LineSonic', -68),
        ],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('PB-LineSonic'));
    await tester.pump();

    expect(coordinator.connected, ['AA:02']);
    final spinner = find.byType(CircularProgressIndicator);
    expect(
      find.descendant(
        of: find.bySemanticsLabel(RegExp('Connect to PB-LineSonic')),
        matching: spinner,
      ),
      findsOneWidget,
    );
    expect(find.text('Connecting…'), findsOneWidget);

    // Other robots cannot be tapped while one is connecting.
    await tester.tap(find.text('PB-Robot-01'), warnIfMissed: false);
    await tester.pump();
    expect(coordinator.connected, ['AA:02']);

    coordinator.connectCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(spinner, findsNothing);
  });

  testWidgets('BLE page fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    coordinator.debugEmitForTesting(
      _withLast.copyWith(
        devices: [
          _scan('AA:01', 'PB-Robot-with-a-long-name', -52),
          _scan(_lastId, 'PB-Robot-01', -68),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: BluetoothBlePage(
            coordinator: coordinator,
            isBleConnected: () => false,
            enableBlePlatformBindings: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Last used'), findsOneWidget);
  });
}
