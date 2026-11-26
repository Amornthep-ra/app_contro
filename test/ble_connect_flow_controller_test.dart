import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connect_flow_controller.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoPlatform implements BleConnectionPlatform {
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

/// Records what the controller asks of the coordinator.
class _RecordingCoordinator extends BleConnectionCoordinator {
  _RecordingCoordinator()
    : super(
        platform: _NoPlatform(),
        managerConnectionStream: const Stream.empty(),
        listenToManagerAutoConnectRequests: false,
      );

  var acquires = 0;
  var releases = 0;
  final autoConnects = <(String, bool)>[];
  final connects = <String>[];
  Completer<void>? connectGate;
  Completer<bool>? autoConnectGate;
  BleConnectionCoordinatorState initialState =
      const BleConnectionCoordinatorState();

  @override
  void acquire() => acquires++;

  @override
  Future<void> release() async => releases++;

  @override
  Future<void> initialize() async => debugEmitForTesting(initialState);

  @override
  Future<bool> autoConnectLastDevice({
    required Duration timeout,
    required String source,
    int? owner,
    bool userInitiated = false,
  }) {
    autoConnects.add((source, userInitiated));
    return autoConnectGate?.future ?? Future.value(false);
  }

  @override
  Future<void> connect(
    ScanResult result, {
    String source = 'ble_coordinator',
    bool preserveAutoConnect = false,
    int? owner,
    bool userInitiated = true,
  }) async {
    connects.add(source);
    await connectGate?.future;
  }
}

ScanResult _result(String id) => ScanResult(
  device: BluetoothDevice.fromId(id),
  advertisementData: AdvertisementData(
    advName: 'PrinceBot',
    txPowerLevel: null,
    appearance: null,
    connectable: true,
    manufacturerData: const {},
    serviceData: const {},
    serviceUuids: const [],
  ),
  rssi: -50,
  timeStamp: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  BleConnectFlowController controllerFor(
    _RecordingCoordinator coordinator, {
    void Function(BleConnectionCoordinatorState)? onState,
  }) => BleConnectFlowController(
    coordinator: coordinator,
    initialSource: 'test_initial',
    manualSource: 'test_manual',
    connectSource: 'test_connect',
    onCoordinatorState: onState,
  );

  test('follows the coordinator; an empty saved device is none', () async {
    final coordinator = _RecordingCoordinator();
    final seen = <BleConnectionCoordinatorState>[];
    final flow = controllerFor(coordinator, onState: seen.add);
    var notified = 0;
    flow.addListener(() => notified++);

    coordinator.debugEmitForTesting(
      BleConnectionCoordinatorState(
        scanning: true,
        scanSecondsLeft: 7,
        lastDeviceId: '',
        lastDeviceName: '',
        devices: [_result('AA')],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(flow.scanning, isTrue);
    expect(flow.scanSecondsLeft, 7);
    expect(flow.lastDeviceId, isNull);
    expect(flow.lastDeviceName, isNull);
    expect(flow.devices, hasLength(1));
    expect(notified, greaterThan(0));
    expect(seen, hasLength(1));
    flow.dispose();
  });

  test('start reconnects to the saved device once', () async {
    final coordinator = _RecordingCoordinator()
      ..initialState = const BleConnectionCoordinatorState(
        lastDeviceId: 'AA',
        lastDeviceName: 'PrinceBot',
      )
      ..autoConnectGate = Completer<bool>();
    final flow = controllerFor(coordinator);

    await flow.start();
    await flow.start();
    expect(coordinator.acquires, 1);
    expect(coordinator.autoConnects, [('test_initial', false)]);
    expect(flow.pendingConnectLast, isTrue);

    // "Connect last" is ignored while that runs.
    await flow.connectLast();
    expect(coordinator.autoConnects, hasLength(1));

    coordinator.autoConnectGate!.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(flow.pendingConnectLast, isFalse);

    flow.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.releases, 1);
  });

  test('start with no saved device does not reconnect', () async {
    final coordinator = _RecordingCoordinator();
    final flow = controllerFor(coordinator);
    await flow.start();
    expect(coordinator.autoConnects, isEmpty);
    flow.dispose();
  });

  test('Connect last is user initiated and spins its row', () async {
    final coordinator = _RecordingCoordinator()
      ..initialState = const BleConnectionCoordinatorState(lastDeviceId: 'AA')
      ..autoConnectGate = Completer<bool>();
    final flow = controllerFor(coordinator);
    coordinator.debugEmitForTesting(coordinator.initialState);
    await Future<void>.delayed(Duration.zero);

    final done = flow.connectLast();
    expect(flow.connectingDeviceId, 'AA');
    expect(coordinator.autoConnects, [('test_manual', true)]);

    coordinator.autoConnectGate!.complete(false);
    await done;
    expect(flow.connectingDeviceId, isNull);
    expect(flow.pendingConnectLast, isFalse);
    flow.dispose();
  });

  test('a tapped device spins until its connect finishes', () async {
    final coordinator = _RecordingCoordinator()..connectGate = Completer();
    final flow = controllerFor(coordinator);

    final done = flow.connect(_result('BB'));
    expect(flow.connectingDeviceId, 'BB');
    expect(coordinator.connects, ['test_connect']);

    coordinator.connectGate!.complete();
    await done;
    expect(flow.connectingDeviceId, isNull);
    flow.dispose();
  });

  test('a disconnect clears the spinner', () async {
    final coordinator = _RecordingCoordinator()..connectGate = Completer();
    final flow = controllerFor(coordinator);
    unawaited(flow.connect(_result('BB')));
    flow.markDisconnected();
    expect(flow.connectingDeviceId, isNull);
    expect(flow.connecting, isFalse);
    coordinator.connectGate!.complete();
    flow.dispose();
  });

  test('dispose without start does not release the coordinator', () async {
    final coordinator = _RecordingCoordinator();
    controllerFor(coordinator).dispose();
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.releases, 0);
  });
}
