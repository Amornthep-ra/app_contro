import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/ui/lavender_glass.dart';
import 'package:pb_controller/core/widgets/ble_connection_sheet.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/features/bluetooth/widgets/ble_device_row.dart';
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
  int stopScanCalls = 0;
  final connected = <String>[];
  final connectCompleter = Completer<void>();

  @override
  Future<void> forgetLastDevice() async => forgetCalls++;

  @override
  Future<void> stopScan({
    bool cancelAutoConnect = true,
    bool releaseManagementLease = true,
  }) async => stopScanCalls++;

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

const _lastId = 'C8:2E:18:4A:9F:02';

final _robots = [
  _scan('C8:2E:18:4A:9F:03', 'LineSonic-A', -84),
  _scan(_lastId, 'PB-Robot-02', -71),
  _scan('C8:2E:18:4A:9F:05', 'PB-Robot-05', -90),
  _scan('C8:2E:18:4A:9F:01', 'PB-Robot-01', -52),
  _scan('C8:2E:18:4A:9F:04', 'PB-Robot-04', -63),
];

const _landscape = Size(914, 411);
const _portrait = Size(411, 914);

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(BleConnectionSheet), matching: finder);

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

  // Spinners keep animating, so step through the sheet's entrance instead
  // of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSheet(
    WidgetTester tester,
    BleConnectionCoordinatorState state, {
    bool connected = false,
    BlePresentationKind badge = BlePresentationKind.notConnected,
    Size size = _landscape,
  }) async {
    tester.view.physicalSize = size * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    coordinator.debugEmitForTesting(state);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ConnectionStatusBadge(
              coordinator: coordinator,
              isBleConnected: () => connected,
              isControlSessionActive: () => false,
              enableBlePlatformBindings: false,
              presentationState: ValueNotifier(BlePresentationState(badge)),
              pairingPromptLauncher:
                  ({required context, required isThai, coordinator}) async =>
                      null,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConnectionStatusBadge));
    await settle(tester);
    expect(find.byType(BleConnectionSheet), findsOneWidget);
  }

  group('resolveBleSheetPresentation', () {
    BlePresentationKind resolve(
      BlePresentationKind badge, {
      bool connected = false,
      bool connecting = false,
      bool scanning = false,
    }) => resolveBleSheetPresentation(
      badge: BlePresentationState(badge),
      connected: connected,
      connecting: connecting,
      scanning: scanning,
    ).kind;

    test('connected wins', () {
      expect(
        resolve(BlePresentationKind.bluetoothOff, connected: true),
        BlePresentationKind.connected,
      );
    });

    test('Bluetooth and reconnect states come from the badge', () {
      for (final kind in [
        BlePresentationKind.bluetoothOff,
        BlePresentationKind.permissionNeeded,
        BlePresentationKind.unavailable,
        BlePresentationKind.reconnecting,
        BlePresentationKind.reconnectFailed,
      ]) {
        expect(resolve(kind, scanning: true), kind);
      }
    });

    test('the sheet fills in scan/connect while the badge is idle', () {
      expect(
        resolve(BlePresentationKind.notConnected, scanning: true),
        BlePresentationKind.scanning,
      );
      expect(
        resolve(BlePresentationKind.checking, connecting: true),
        BlePresentationKind.connecting,
      );
      expect(
        resolve(BlePresentationKind.scanning),
        BlePresentationKind.notConnected,
      );
      expect(
        resolve(BlePresentationKind.connected),
        BlePresentationKind.notConnected,
      );
      expect(
        resolve(BlePresentationKind.checking),
        BlePresentationKind.checking,
      );
    });
  });

  testWidgets('while scanning: header, empty state, countdown and Stop', (
    tester,
  ) async {
    await openSheet(
      tester,
      const BleConnectionCoordinatorState(scanning: true, scanSecondsLeft: 8),
      badge: BlePresentationKind.scanning,
    );

    expect(_inSheet(find.text('Scanning…')), findsOneWidget);
    expect(_inSheet(find.text('Not connected')), findsNothing);
    expect(find.text('Looking for robots…'), findsOneWidget);
    expect(find.text('No robots found yet'), findsNothing);
    expect(find.text('Scanning 8s'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(coordinator.stopScanCalls, 1);
  });

  testWidgets('after a scan with no robots', (tester) async {
    await openSheet(tester, const BleConnectionCoordinatorState());

    expect(_inSheet(find.text('Not connected')), findsOneWidget);
    expect(find.text('No robots found yet'), findsOneWidget);
    expect(find.text('Scan devices'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('header follows the badge when Bluetooth is off', (tester) async {
    await openSheet(
      tester,
      const BleConnectionCoordinatorState(),
      badge: BlePresentationKind.bluetoothOff,
    );

    expect(_inSheet(find.text('Bluetooth off')), findsOneWidget);
    expect(find.text('Turn on Bluetooth to find your robot.'), findsOneWidget);
  });

  testWidgets('Close stays on screen with 5 robots and closes the sheet', (
    tester,
  ) async {
    await openSheet(
      tester,
      BleConnectionCoordinatorState(
        scanning: true,
        scanSecondsLeft: 6,
        devices: _robots,
        lastDeviceId: _lastId,
        lastDeviceName: 'PB-Robot-02',
      ),
      badge: BlePresentationKind.scanning,
    );

    expect(find.text('Cancel'), findsNothing);
    final close = find.widgetWithText(GlassActionButton, 'Close');
    final rect = tester.getRect(close);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(_landscape.height));
    expect(find.text('Diagnostics'), findsOneWidget);

    await tester.tap(close);
    await settle(tester);
    expect(find.byType(BleConnectionSheet), findsNothing);
  });

  testWidgets('rows: names, strongest first, Last used, Connect <name>', (
    tester,
  ) async {
    await openSheet(
      tester,
      BleConnectionCoordinatorState(
        devices: _robots,
        lastDeviceId: _lastId,
        lastDeviceName: 'PB-Robot-02',
      ),
      size: _portrait,
    );

    final names = ['PB-Robot-01', 'PB-Robot-04', 'PB-Robot-02', 'LineSonic-A'];
    final tops = [
      for (final name in names) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    // Advertised names, not MAC addresses.
    expect(find.textContaining('C8:2E:18'), findsNothing);
    expect(find.textContaining('RSSI'), findsNothing);

    final lastRow = find.widgetWithText(BleDeviceRow, 'PB-Robot-02');
    expect(
      find.descendant(of: lastRow, matching: find.text('Last used')),
      findsOneWidget,
    );
    expect(find.text('Last used'), findsOneWidget);

    expect(find.text('Connect PB-Robot-02'), findsOneWidget);
    // Narrow sheet: Scan shortens so the robot name stays readable.
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('Connect names the remembered robot when it is not in range', (
    tester,
  ) async {
    await openSheet(
      tester,
      const BleConnectionCoordinatorState(
        lastDeviceId: _lastId,
        lastDeviceName: 'PB-Robot-02',
      ),
    );
    expect(find.text('Connect PB-Robot-02'), findsOneWidget);
    expect(find.text('Scan devices'), findsOneWidget);
  });

  testWidgets('only the tapped row shows a spinner', (tester) async {
    await openSheet(tester, BleConnectionCoordinatorState(devices: _robots));

    await tester.tap(find.text('PB-Robot-04'));
    await tester.pump();
    expect(coordinator.connected, ['C8:2E:18:4A:9F:04']);

    final rowSpinners = find.descendant(
      of: find.byType(BleDeviceRow),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(rowSpinners, findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(BleDeviceRow, 'PB-Robot-04'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    // Other rows are locked while connecting.
    await tester.tap(find.text('PB-Robot-01'));
    await tester.pump();
    expect(coordinator.connected, ['C8:2E:18:4A:9F:04']);
  });

  testWidgets('diagnostics are closed until asked for, and copy', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openSheet(tester, BleConnectionCoordinatorState(devices: _robots));
    expect(find.text('BLE diagnostics'), findsNothing);

    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    expect(find.text('BLE diagnostics'), findsOneWidget);
    expect(find.text('Hide diagnostics'), findsOneWidget);
    // Opened at the top of the list, so it is in view.
    expect(
      tester.getTopLeft(find.text('BLE diagnostics')).dy,
      lessThan(tester.getTopLeft(find.text('Hide diagnostics')).dy),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, contains('payload='));
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Hide diagnostics'));
    await tester.pump();
    expect(find.text('BLE diagnostics'), findsNothing);
  });

  testWidgets('Forget is in a menu and asks first', (tester) async {
    await openSheet(
      tester,
      BleConnectionCoordinatorState(
        devices: _robots,
        lastDeviceId: _lastId,
        lastDeviceName: 'PB-Robot-02',
      ),
    );
    expect(find.text('Forget'), findsNothing);

    Future<void> chooseForget() async {
      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      await tester.tap(find.text('Forget device'));
      await settle(tester);
      expect(find.text('Forget PB-Robot-02?'), findsOneWidget);
    }

    await chooseForget();
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(coordinator.forgetCalls, 0);

    await chooseForget();
    await tester.tap(find.text('Forget'));
    await settle(tester);
    expect(coordinator.forgetCalls, 1);
  });

  testWidgets('no Forget menu without a remembered robot', (tester) async {
    await openSheet(tester, BleConnectionCoordinatorState(devices: _robots));
    expect(find.byTooltip('More options'), findsNothing);
  });

  testWidgets('connected: robot name, security line, Disconnect', (
    tester,
  ) async {
    await openSheet(
      tester,
      const BleConnectionCoordinatorState(
        securityState: BleControlSecurityState.ready,
        lastDeviceId: _lastId,
        lastDeviceName: 'PB-Robot-02',
      ),
      connected: true,
      badge: BlePresentationKind.connected,
    );

    expect(find.text('Connected · ready to control'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.byType(BleDeviceRow), findsNothing);
  });

  for (final size in [_landscape, _portrait]) {
    testWidgets('every sheet control is at least 48 px tall at $size', (
      tester,
    ) async {
      void expectTall(Finder finder) {
        expect(finder, findsOneWidget);
        expect(
          tester.getSize(finder).height,
          greaterThanOrEqualTo(48),
          reason: finder.toString(),
        );
      }

      Finder textButton(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      );

      await openSheet(
        tester,
        BleConnectionCoordinatorState(
          devices: _robots,
          lastDeviceId: _lastId,
          lastDeviceName: 'PB-Robot-02',
        ),
        size: size,
      );
      expectTall(find.widgetWithText(GlassActionButton, 'Connect PB-Robot-02'));
      expectTall(find.byType(GradientActionButton));
      expectTall(find.widgetWithText(GlassActionButton, 'Close'));
      expectTall(textButton('Diagnostics'));
      expectTall(find.byType(PopupMenuButton<String>));
      for (final row in tester.widgetList(find.byType(BleDeviceRow))) {
        expect(
          tester.getSize(find.byWidget(row)).height,
          greaterThanOrEqualTo(48),
        );
      }

      await tester.tap(find.text('Diagnostics'));
      await tester.pump();
      expectTall(textButton('Copy'));
      expectTall(textButton('Hide diagnostics'));

      coordinator.debugEmitForTesting(
        const BleConnectionCoordinatorState(scanning: true, scanSecondsLeft: 5),
      );
      await tester.pump();
      expectTall(find.widgetWithText(GlassActionButton, 'Scanning 5s'));
      expectTall(find.widgetWithText(GlassActionButton, 'Stop'));
    });
  }

  testWidgets('connected controls are at least 48 px tall', (tester) async {
    // Already shown once for this connection, so the sheet stays open
    // instead of handing over to the automatic pairing prompt.
    coordinator.markPairingPromptPresented();
    await openSheet(
      tester,
      const BleConnectionCoordinatorState(
        securityState: BleControlSecurityState.pairingRequired,
      ),
      connected: true,
      badge: BlePresentationKind.connected,
    );
    // The tooltip sits inside the button's 48 px tap padding.
    final pairCode = find.ancestor(
      of: find.byTooltip('Pair code'),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(pairCode).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSize(find.widgetWithText(GlassActionButton, 'Disconnect'))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}
