import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_pairing_store.dart';
import 'package:pb_controller/core/ble/ble_permissions.dart';
import 'package:pb_controller/core/ble/ble_secure_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBleConnectionPlatform implements BleConnectionPlatform {
  final StreamController<List<ScanResult>> _scanResults =
      StreamController<List<ScanResult>>.broadcast();
  Object? startError;
  Object? connectError;
  Completer<void>? stopScanGate;
  var startCalls = 0;
  var stopCalls = 0;
  var connectCalls = 0;

  void emitScanResults(List<ScanResult> results) => _scanResults.add(results);

  @override
  Stream<List<ScanResult>> get scanResults => _scanResults.stream;

  @override
  Future<void> connect(ScanResult result) async {
    connectCalls++;
    if (connectError != null) throw connectError!;
  }

  @override
  Future<void> disconnect(ScanResult result) async {}

  @override
  Future<void> startScan({required Duration timeout}) async {
    startCalls++;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stopScan() async {
    stopCalls++;
    await stopScanGate?.future;
  }

  Future<void> dispose() => _scanResults.close();
}

class _MemoryPairingStore implements BlePairingStore {
  final removedBoardIds = <String>[];

  @override
  Future<void> remove(String boardId) async => removedBoardIds.add(boardId);

  @override
  Future<List<int>?> readSecret(String boardId) async => null;

  @override
  Future<void> save(BlePairingRecord record) async {}
}

ScanResult _scanResult({
  String id = '01:02:03:04:05:06',
  bool nordicUart = false,
  int rssi = -55,
}) {
  return ScanResult(
    device: BluetoothDevice.fromId(id),
    advertisementData: AdvertisementData(
      advName: 'PrinceBot',
      txPowerLevel: null,
      appearance: null,
      connectable: true,
      manufacturerData: const {},
      serviceData: const {},
      serviceUuids: nordicUart
          ? [Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')]
          : const [],
    ),
    rssi: rssi,
    timeStamp: DateTime.now(),
  );
}

void main() {
  test('requests a pairing code only when no saved credential exists', () {
    expect(
      requiresBlePairingCode(BleControlSecurityState.pairingRequired),
      isTrue,
    );
    expect(
      requiresBlePairingCode(BleControlSecurityState.authenticationFailed),
      isFalse,
    );
    expect(requiresBlePairingCode(BleControlSecurityState.ready), isFalse);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'shares one automatic pairing prompt per connection and resets on link loss',
    () async {
      final connectionEvents = StreamController<bool>.broadcast();
      final coordinator = BleConnectionCoordinator(
        platform: _FakeBleConnectionPlatform(),
        managerConnectionStream: connectionEvents.stream,
        listenToManagerAutoConnectRequests: false,
      );
      coordinator.debugEmitForTesting(
        const BleConnectionCoordinatorState(
          securityState: BleControlSecurityState.pairingRequired,
        ),
      );

      expect(
        coordinator.claimAutomaticPairingPrompt(connected: false),
        isFalse,
      );
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isTrue);
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isFalse);

      connectionEvents.add(false);
      await Future<void>.delayed(Duration.zero);
      coordinator.debugEmitForTesting(
        const BleConnectionCoordinatorState(
          securityState: BleControlSecurityState.pairingRequired,
        ),
      );
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isTrue);
      coordinator.releaseAutomaticPairingPrompt();
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isTrue);
      coordinator.markPairingPromptPresented();
      coordinator.releaseAutomaticPairingPrompt();
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isFalse);

      await coordinator.dispose();
      await connectionEvents.close();
    },
  );

  group('BleConnectionCoordinatorState', () {
    test(
      'Forget clears the remembered device and its pairing secret',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
          'ble_last_device_name': 'PrinceBot',
          'ble_last_board_id': 'BOARD-A',
        });
        final pairingStore = _MemoryPairingStore();
        final coordinator = BleConnectionCoordinator(
          platform: _FakeBleConnectionPlatform(),
          pairingStore: pairingStore,
        );
        coordinator.debugEmitForTesting(
          const BleConnectionCoordinatorState(
            securityState: BleControlSecurityState.pairingRequired,
          ),
        );
        expect(
          coordinator.claimAutomaticPairingPrompt(connected: true),
          isTrue,
        );

        await coordinator.forgetLastDevice();
        coordinator.debugEmitForTesting(
          const BleConnectionCoordinatorState(
            securityState: BleControlSecurityState.pairingRequired,
          ),
        );

        expect(
          coordinator.claimAutomaticPairingPrompt(connected: true),
          isTrue,
        );
        expect(pairingStore.removedBoardIds, ['BOARD-A']);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('ble_last_device_id'), isNull);
        expect(prefs.getString('ble_last_board_id'), isNull);
        await coordinator.dispose();
      },
    );

    test(
      'clears secure readiness immediately when the BLE link is lost',
      () async {
        final events = StreamController<bool>.broadcast();
        final coordinator = BleConnectionCoordinator(
          platform: _FakeBleConnectionPlatform(),
          managerConnectionStream: events.stream,
          listenToManagerAutoConnectRequests: false,
          canManageConnection: ({int? owner}) => true,
        );
        const board = BleBoardCapabilities(
          protocolVersion: 2,
          boardId: 'BOARD-A',
          boardModel: 'ESP32',
          firmwareVersion: '2.1.0',
          boardNonce: 'nonce',
          boardTag: 'tag',
        );

        // Model a ready coordinator before the manager reports a remote link loss.
        coordinator.debugEmitForTesting(
          const BleConnectionCoordinatorState(
            securityState: BleControlSecurityState.ready,
            boardCapabilities: board,
            lastDeviceId: '01:02:03:04:05:06',
          ),
        );
        events.add(false);
        await Future<void>.delayed(Duration.zero);

        expect(
          coordinator.state.securityState,
          BleControlSecurityState.disconnected,
        );
        expect(coordinator.state.boardCapabilities, isNull);
        await coordinator.dispose();
        await events.close();
      },
    );

    test('clears stale board capabilities before connecting another board', () {
      const board = BleBoardCapabilities(
        protocolVersion: 2,
        boardId: 'BOARD-A',
        boardModel: 'ESP32',
        firmwareVersion: '2.1.0',
        boardNonce: 'nonce',
        boardTag: 'tag',
      );
      const connected = BleConnectionCoordinatorState(
        boardCapabilities: board,
        securityState: BleControlSecurityState.ready,
      );

      final connecting = connected.copyWith(
        connecting: true,
        clearBoardCapabilities: true,
        securityState: BleControlSecurityState.disconnected,
      );

      expect(connecting.boardCapabilities, isNull);
      expect(connecting.securityState, BleControlSecurityState.disconnected);
    });

    test(
      'persists a candidate pairing secret only after matching readiness',
      () {
        const board = BleBoardCapabilities(
          protocolVersion: 2,
          boardId: 'BOARD-B',
          boardModel: 'ESP32',
          firmwareVersion: '2.1.0',
          boardNonce: 'nonce',
          boardTag: 'tag',
        );
        const ready = BleConnectionCoordinatorState(
          boardCapabilities: board,
          securityState: BleControlSecurityState.ready,
        );
        const failed = BleConnectionCoordinatorState(
          boardCapabilities: board,
          securityState: BleControlSecurityState.authenticationFailed,
        );

        expect(
          shouldPersistBlePairingSecret(state: ready, boardId: 'BOARD-B'),
          isTrue,
        );
        expect(
          shouldPersistBlePairingSecret(state: failed, boardId: 'BOARD-B'),
          isFalse,
        );
        expect(
          shouldPersistBlePairingSecret(state: ready, boardId: 'BOARD-A'),
          isFalse,
        );
      },
    );

    test('keeps scan and connect transitions independent', () {
      const initial = BleConnectionCoordinatorState();
      final scanning = initial.copyWith(scanning: true, clearFailure: true);
      final connecting = scanning.copyWith(scanning: false, connecting: true);

      expect(scanning.scanning, isTrue);
      expect(scanning.connecting, isFalse);
      expect(connecting.scanning, isFalse);
      expect(connecting.connecting, isTrue);
    });

    test('clears a previous failure for a new operation', () {
      const failed = BleConnectionCoordinatorState(
        failureReason: 'scan_failed:test',
      );

      final retrying = failed.copyWith(scanning: true, clearFailure: true);

      expect(retrying.failureReason, isNull);
      expect(retrying.scanning, isTrue);
    });

    test('preserves remembered-device details across a scan update', () {
      const remembered = BleConnectionCoordinatorState(
        lastDeviceId: 'device-id',
        lastDeviceName: 'PrinceBot',
      );

      final scanning = remembered.copyWith(scanning: true);

      expect(scanning.lastDeviceId, 'device-id');
      expect(scanning.lastDeviceName, 'PrinceBot');
    });
  });

  group('BleConnectionCoordinator platform seam', () {
    test(
      'manual disconnect suppresses delayed link-loss and automatic reconnect',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
          'ble_last_device_name': 'PrinceBot',
        });
        final connectionEvents = StreamController<bool>.broadcast();
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          managerConnectionStream: connectionEvents.stream,
          listenToManagerAutoConnectRequests: false,
          canManageConnection: ({int? owner}) => true,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
        );
        await coordinator.initialize();

        await coordinator.disconnect();
        // The manager's broadcast stream can deliver this after disconnect()
        // has completed, so suppression must represent user intent, not only
        // an in-progress transport operation.
        connectionEvents.add(false);
        await Future<void>.delayed(Duration.zero);
        final reconnected = await coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'bluetooth_page_initial',
        );

        expect(coordinator.state.failureReason, 'manual_disconnect');
        expect(reconnected, isFalse);
        expect(platform.startCalls, 0);

        final manuallyReconnected = await coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'bluetooth_page_manual',
          userInitiated: true,
        );
        expect(manuallyReconnected, isFalse);
        expect(platform.startCalls, 1);

        await coordinator.dispose();
        await connectionEvents.close();
        await platform.dispose();
      },
    );

    test('blocks scan and connect transport while control owns BLE', () async {
      final platform = _FakeBleConnectionPlatform();
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        canManageConnection: ({int? owner}) => false,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      await coordinator.startScan();
      await coordinator.connect(_scanResult(nordicUart: true));
      await coordinator.disconnect();
      final autoConnected = await coordinator.autoConnectLastDevice(
        timeout: const Duration(milliseconds: 10),
        source: 'test',
      );

      expect(platform.startCalls, 0);
      expect(platform.connectCalls, 0);
      expect(autoConnected, isFalse);
      expect(coordinator.state.failureReason, 'ble_busy_in_control');

      await coordinator.dispose();
      await platform.dispose();
    });

    test('rechecks policy after a permission prompt before scanning', () async {
      final platform = _FakeBleConnectionPlatform();
      final permissionGate = Completer<BleScanPermissionResult>();
      var canManage = true;
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        canManageConnection: ({int? owner}) => canManage,
        ensureScanPermissions: () => permissionGate.future,
      );

      final scan = coordinator.startScan();
      await Future<void>.delayed(Duration.zero);
      canManage = false;
      permissionGate.complete(BleScanPermissionResult.granted);
      await scan;

      expect(platform.startCalls, 0);
      expect(coordinator.state.failureReason, 'ble_busy_in_control');

      await coordinator.dispose();
      await platform.dispose();
    });

    test('rechecks policy after stopping scan before connecting', () async {
      final platform = _FakeBleConnectionPlatform();
      final stopGate = Completer<void>();
      platform.stopScanGate = stopGate;
      var canManage = true;
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        canManageConnection: ({int? owner}) => canManage,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      final connect = coordinator.connect(_scanResult(nordicUart: true));
      await Future<void>.delayed(Duration.zero);
      canManage = false;
      stopGate.complete();
      await connect;

      expect(platform.connectCalls, 0);
      expect(coordinator.state.failureReason, 'ble_busy_in_control');

      await coordinator.dispose();
      await platform.dispose();
    });

    test(
      'reports permission failure without starting the platform scan',
      () async {
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async =>
              BleScanPermissionResult.permissionDenied,
        );

        await coordinator.startScan();

        expect(platform.startCalls, 0);
        expect(
          coordinator.state.failureReason,
          'scan_unavailable:permissionDenied',
        );
        await platform.dispose();
      },
    );

    test('maps a platform scan failure to coordinator state', () async {
      final platform = _FakeBleConnectionPlatform()
        ..startError = StateError('no radio');
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      await coordinator.startScan();

      expect(platform.startCalls, 1);
      expect(coordinator.state.scanning, isFalse);
      expect(coordinator.state.failureReason, startsWith('scan_failed:'));
      await platform.dispose();
    });

    test(
      'cancels an active platform scan through the same coordinator',
      () async {
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
        );

        await coordinator.startScan();
        expect(coordinator.state.scanning, isTrue);
        await coordinator.stopScan();

        expect(platform.stopCalls, 1);
        expect(coordinator.state.scanning, isFalse);
        await platform.dispose();
      },
    );

    test('removes scan results that have exceeded the device TTL', () async {
      var now = DateTime(2026, 1, 1, 12);
      final platform = _FakeBleConnectionPlatform();
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
        now: () => now,
      );

      await coordinator.startScan(timeout: const Duration(minutes: 1));
      platform.emitScanResults([_scanResult(nordicUart: true)]);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.state.devices, hasLength(1));

      now = now.add(const Duration(seconds: 21));
      coordinator.pruneStaleDevices();

      expect(coordinator.state.devices, isEmpty);
      await coordinator.dispose();
      await platform.dispose();
    });

    test(
      'scans again instead of connecting with an expired cached device',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        var now = DateTime(2026, 1, 1, 12);
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
          now: () => now,
        );

        await coordinator.startScan(timeout: const Duration(minutes: 1));
        platform.emitScanResults([_scanResult(nordicUart: true)]);
        await Future<void>.delayed(Duration.zero);
        await coordinator.stopScan();
        now = now.add(const Duration(seconds: 21));

        final connected = await coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'expired_cache',
        );

        expect(connected, isFalse);
        expect(platform.startCalls, 2);
        expect(platform.connectCalls, 0);
        expect(coordinator.state.failureReason, 'last_device_not_found');
        await coordinator.dispose();
        await platform.dispose();
      },
    );

    test(
      'refreshes last seen time and scan result for a repeated device',
      () async {
        var now = DateTime(2026, 1, 1, 12);
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
          now: () => now,
        );

        await coordinator.startScan(timeout: const Duration(minutes: 1));
        platform.emitScanResults([_scanResult(nordicUart: true, rssi: -70)]);
        await Future<void>.delayed(Duration.zero);

        now = now.add(const Duration(seconds: 19));
        platform.emitScanResults([_scanResult(nordicUart: true, rssi: -42)]);
        await Future<void>.delayed(Duration.zero);
        now = now.add(const Duration(seconds: 19));
        coordinator.pruneStaleDevices();

        expect(coordinator.state.devices, hasLength(1));
        expect(coordinator.state.devices.single.rssi, -42);
        await coordinator.dispose();
        await platform.dispose();
      },
    );

    test('counts down during a scan and resets when scanning stops', () async {
      final platform = _FakeBleConnectionPlatform();
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      await coordinator.startScan(timeout: const Duration(seconds: 2));
      expect(coordinator.state.scanSecondsLeft, 2);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(coordinator.state.scanSecondsLeft, 1);

      await coordinator.stopScan();
      expect(coordinator.state.scanning, isFalse);
      expect(coordinator.state.scanSecondsLeft, 0);
      await coordinator.dispose();
      await platform.dispose();
    });

    test('clears countdown state after a scan failure and timeout', () async {
      final failedPlatform = _FakeBleConnectionPlatform()
        ..startError = StateError('no radio');
      final failedCoordinator = BleConnectionCoordinator(
        platform: failedPlatform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      await failedCoordinator.startScan(timeout: const Duration(seconds: 2));
      expect(failedCoordinator.state.scanning, isFalse);
      expect(failedCoordinator.state.scanSecondsLeft, 0);
      await failedCoordinator.dispose();
      await failedPlatform.dispose();

      final timeoutPlatform = _FakeBleConnectionPlatform();
      final timeoutCoordinator = BleConnectionCoordinator(
        platform: timeoutPlatform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      await timeoutCoordinator.startScan(
        timeout: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(timeoutCoordinator.state.scanning, isFalse);
      expect(timeoutCoordinator.state.scanSecondsLeft, 0);
      await timeoutCoordinator.dispose();
      await timeoutPlatform.dispose();
    });

    test('maps a platform connect failure to coordinator state', () async {
      final platform = _FakeBleConnectionPlatform()
        ..connectError = StateError('connection rejected');
      final coordinator = BleConnectionCoordinator(platform: platform);

      await coordinator.connect(_scanResult());

      expect(platform.connectCalls, 1);
      expect(coordinator.state.connecting, isFalse);
      expect(coordinator.state.failureReason, startsWith('connect_failed:'));
      await platform.dispose();
    });

    test(
      'connects immediately when the remembered device appears in scan',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
          'ble_last_device_name': 'PrinceBot',
        });
        final platform = _FakeBleConnectionPlatform()
          ..connectError = StateError('connection rejected');
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
        );

        final result = coordinator.autoConnectLastDevice(
          timeout: const Duration(seconds: 1),
          source: 'test',
        );
        await Future<void>.delayed(Duration.zero);
        platform.emitScanResults([_scanResult(nordicUart: true)]);

        expect(await result, isFalse);
        expect(platform.stopCalls, greaterThanOrEqualTo(1));
        expect(platform.connectCalls, 1);
        await platform.dispose();
      },
    );

    test(
      'waits for scan timeout before reporting remembered device missing',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
        );

        final result = coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'test',
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(await result, isFalse);
        expect(coordinator.state.failureReason, 'last_device_not_found');
        expect(platform.connectCalls, 0);
        expect(coordinator.state.scanning, isFalse);
        await platform.dispose();
      },
    );

    test('completes auto-connect after scan permission is denied', () async {
      SharedPreferences.setMockInitialValues({
        'ble_last_device_id': '01:02:03:04:05:06',
      });
      final platform = _FakeBleConnectionPlatform();
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        ensureScanPermissions: () async =>
            BleScanPermissionResult.permissionDenied,
      );

      final connected = await coordinator.autoConnectLastDevice(
        timeout: const Duration(seconds: 1),
        source: 'test',
      );

      expect(connected, isFalse);
      expect(platform.startCalls, 0);
      expect(
        coordinator.state.failureReason,
        'scan_unavailable:permissionDenied',
      );
      await platform.dispose();
    });

    test('completes auto-connect when an active scan is cancelled', () async {
      SharedPreferences.setMockInitialValues({
        'ble_last_device_id': '01:02:03:04:05:06',
      });
      final platform = _FakeBleConnectionPlatform();
      final coordinator = BleConnectionCoordinator(
        platform: platform,
        ensureScanPermissions: () async => BleScanPermissionResult.granted,
      );

      final result = coordinator.autoConnectLastDevice(
        timeout: const Duration(seconds: 1),
        source: 'test',
      );
      await Future<void>.delayed(Duration.zero);
      await coordinator.stopScan();

      expect(await result, isFalse);
      expect(coordinator.state.failureReason, 'auto_connect_cancelled');
      expect(coordinator.state.scanning, isFalse);
      await platform.dispose();
    });

    test(
      'shares one pending auto-connect request for the same device',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        final platform = _FakeBleConnectionPlatform();
        final coordinator = BleConnectionCoordinator(
          platform: platform,
          ensureScanPermissions: () async => BleScanPermissionResult.granted,
        );

        final first = coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'first',
        );
        final second = coordinator.autoConnectLastDevice(
          timeout: const Duration(milliseconds: 10),
          source: 'second',
        );

        expect(await first, isFalse);
        expect(await second, isFalse);
        expect(platform.startCalls, 1);
        await platform.dispose();
      },
    );
  });

  group('BleManager auto-connect request seam', () {
    BleConnectionCoordinator createCoordinator(
      _FakeBleConnectionPlatform platform, {
      required BleScanPermissionCheck permissionCheck,
    }) => BleConnectionCoordinator(
      platform: platform,
      ensureScanPermissions: permissionCheck,
      listenToManagerAutoConnectRequests: true,
    );

    Future<void> disposeCoordinator(
      BleConnectionCoordinator coordinator,
      _FakeBleConnectionPlatform platform,
    ) async {
      await coordinator.dispose();
      await platform.dispose();
    }

    test('completes manager request when scan permission is denied', () async {
      SharedPreferences.setMockInitialValues({
        'ble_last_device_id': '01:02:03:04:05:06',
      });
      final platform = _FakeBleConnectionPlatform();
      final coordinator = createCoordinator(
        platform,
        permissionCheck: () async => BleScanPermissionResult.permissionDenied,
      );

      final connected = await BleManager.instance.requestAutoConnectForTesting(
        source: 'manager_permission_denied',
      );

      expect(connected, isFalse);
      expect(platform.startCalls, 0);
      expect(
        coordinator.state.failureReason,
        'scan_unavailable:permissionDenied',
      );
      await disposeCoordinator(coordinator, platform);
    });

    test(
      'connects immediately after manager request finds its target',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        final platform = _FakeBleConnectionPlatform()
          ..connectError = StateError('connection rejected');
        final coordinator = createCoordinator(
          platform,
          permissionCheck: () async => BleScanPermissionResult.granted,
        );

        final result = BleManager.instance.requestAutoConnectForTesting(
          source: 'manager_target_found',
        );
        await Future<void>.delayed(Duration.zero);
        platform.emitScanResults([_scanResult(nordicUart: true)]);

        expect(await result, isFalse);
        expect(platform.startCalls, 1);
        expect(platform.connectCalls, 1);
        await disposeCoordinator(coordinator, platform);
      },
    );

    test(
      'completes manager request when the remembered target times out',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        final platform = _FakeBleConnectionPlatform();
        final coordinator = createCoordinator(
          platform,
          permissionCheck: () async => BleScanPermissionResult.granted,
        );

        final result = BleManager.instance.requestAutoConnectForTesting(
          timeout: const Duration(milliseconds: 10),
          source: 'manager_timeout',
        );

        expect(await result, isFalse);
        expect(platform.startCalls, 1);
        expect(coordinator.state.failureReason, 'last_device_not_found');
        await disposeCoordinator(coordinator, platform);
      },
    );

    test(
      'completes manager request when coordinator scan is cancelled',
      () async {
        SharedPreferences.setMockInitialValues({
          'ble_last_device_id': '01:02:03:04:05:06',
        });
        final platform = _FakeBleConnectionPlatform();
        final coordinator = createCoordinator(
          platform,
          permissionCheck: () async => BleScanPermissionResult.granted,
        );

        final result = BleManager.instance.requestAutoConnectForTesting(
          source: 'manager_cancel',
        );
        await Future<void>.delayed(Duration.zero);
        await coordinator.stopScan();

        expect(await result, isFalse);
        expect(platform.startCalls, 1);
        expect(coordinator.state.failureReason, 'auto_connect_cancelled');
        await disposeCoordinator(coordinator, platform);
      },
    );
  });
}
