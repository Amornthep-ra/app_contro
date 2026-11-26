import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_connection_coordinator.dart';
import 'ble_manager.dart';

/// The connect flow shared by the Bluetooth page and the connection sheet:
/// following the coordinator, reconnecting to the last device when opened,
/// connecting to a tapped device and which row shows a spinner.
///
/// Each screen keeps its own layout and dialogs and listens to this
/// controller for the state it shows.
class BleConnectFlowController extends ChangeNotifier {
  BleConnectFlowController({
    required this.coordinator,
    required this.initialSource,
    required this.manualSource,
    required this.connectSource,
    this.autoConnectTimeout = const Duration(seconds: 10),
    this.onCoordinatorState,
  }) {
    _subscription = coordinator.stream.listen(applyState);
  }

  final BleConnectionCoordinator coordinator;

  /// Log sources of the reconnect on open, the "Connect last" button and a
  /// tapped device, kept per screen so logs read as before.
  final String initialSource;
  final String manualSource;
  final String connectSource;
  final Duration autoConnectTimeout;

  /// Runs after each coordinator state is applied (pairing prompts, the
  /// sheet's own device list).
  final void Function(BleConnectionCoordinatorState state)? onCoordinatorState;

  StreamSubscription<BleConnectionCoordinatorState>? _subscription;
  bool _acquired = false;
  bool _disposed = false;

  bool scanning = false;
  bool connecting = false;
  int scanSecondsLeft = 0;
  BleControlSecurityState securityState = BleControlSecurityState.disconnected;

  /// Null when no device is remembered (the coordinator stores '').
  String? lastDeviceId;
  String? lastDeviceName;
  List<ScanResult> devices = const [];

  /// True while reconnecting to the last device.
  bool pendingConnectLast = false;

  /// Row the user tapped (or the last device), so only it shows a spinner.
  String? connectingDeviceId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void applyState(BleConnectionCoordinatorState state) {
    if (_disposed) return;
    scanning = state.scanning;
    connecting = state.connecting;
    if (!state.connecting) connectingDeviceId = null;
    scanSecondsLeft = state.scanSecondsLeft;
    securityState = state.securityState;
    lastDeviceId = state.lastDeviceId?.isEmpty == true
        ? null
        : state.lastDeviceId;
    lastDeviceName = state.lastDeviceName?.isEmpty == true
        ? null
        : state.lastDeviceName;
    devices = state.devices;
    _notify();
    onCoordinatorState?.call(state);
  }

  /// Holds the coordinator for this screen, loads the saved device and
  /// reconnects to it when nothing is connected.
  Future<void> start() async {
    if (_acquired || _disposed) return;
    _acquired = true;
    coordinator.acquire();
    await coordinator.initialize();
    if (_disposed) return;
    applyState(coordinator.state);
    _queueAutoConnectLast();
  }

  void _queueAutoConnectLast() {
    if (lastDeviceId == null) return;
    if (connecting || BleManager.instance.isConnected) return;
    if (pendingConnectLast) return;
    pendingConnectLast = true;
    unawaited(_connectRememberedDevice(initialSource));
  }

  Future<void> _connectRememberedDevice(
    String source, {
    bool userInitiated = false,
  }) async {
    try {
      await coordinator.autoConnectLastDevice(
        timeout: autoConnectTimeout,
        source: source,
        userInitiated: userInitiated,
      );
    } finally {
      pendingConnectLast = false;
      if (connectingDeviceId == lastDeviceId) connectingDeviceId = null;
      _notify();
    }
  }

  /// The "Connect last" button.
  Future<void> connectLast() async {
    if (lastDeviceId == null || pendingConnectLast) return;
    pendingConnectLast = true;
    connectingDeviceId = lastDeviceId;
    _notify();
    await _connectRememberedDevice(manualSource, userInitiated: true);
  }

  /// A tapped device in the list.
  Future<void> connect(ScanResult result) async {
    final id = result.device.remoteId.str;
    connectingDeviceId = id;
    _notify();
    try {
      await coordinator.connect(result, source: connectSource);
    } finally {
      if (connectingDeviceId == id) {
        connectingDeviceId = null;
        _notify();
      }
    }
  }

  /// The link went down: nothing is connecting any more.
  void markDisconnected() {
    connecting = false;
    connectingDeviceId = null;
    _notify();
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) =>
      coordinator.startScan(timeout: timeout);

  Future<void> stopScan() => coordinator.stopScan();

  Future<void> disconnect() => coordinator.disconnect();

  Future<void> forgetLastDevice() => coordinator.forgetLastDevice();

  /// Whether the robot is connected now and is the remembered one, for the
  /// Forget wording.
  bool isConnectedTo(String id, {required bool connected}) {
    final currentId = BleManager.instance.currentDeviceId;
    return connected && (currentId == null || currentId == id);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    if (_acquired) unawaited(coordinator.release());
    super.dispose();
  }
}
