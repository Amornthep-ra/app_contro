import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_adapter_observation.dart';
import 'ble_manager.dart';

enum BleAdapterPresentationState {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off,
}

BleAdapterPresentationState adapterPresentationStateFromFlutterBluePlus(
  BluetoothAdapterState state,
) => switch (state) {
  BluetoothAdapterState.unknown => BleAdapterPresentationState.unknown,
  BluetoothAdapterState.unavailable => BleAdapterPresentationState.unavailable,
  BluetoothAdapterState.unauthorized =>
    BleAdapterPresentationState.unauthorized,
  BluetoothAdapterState.turningOn => BleAdapterPresentationState.turningOn,
  BluetoothAdapterState.on => BleAdapterPresentationState.on,
  BluetoothAdapterState.turningOff => BleAdapterPresentationState.turningOff,
  BluetoothAdapterState.off => BleAdapterPresentationState.off,
};

class BlePresentationStateController
    extends ValueNotifier<BlePresentationState> {
  BlePresentationStateController({
    required BleAdapterPresentationState initialAdapterState,
    required Stream<BleAdapterPresentationState> adapterStates,
    required BleConnectionStatus initialConnectionStatus,
    required Stream<BleConnectionStatus> connectionStatuses,
  }) : _adapterState = initialAdapterState,
       _connectionStatus = initialConnectionStatus,
       super(
         resolveBlePresentationState(
           adapterState: initialAdapterState,
           connectionStatus: initialConnectionStatus,
         ),
       ) {
    _adapterSubscription = adapterStates.listen(
      _setAdapterState,
      onError: (Object _, StackTrace __) {
        _setAdapterState(BleAdapterPresentationState.unknown);
      },
    );
    _connectionSubscription = connectionStatuses.listen(_setConnectionStatus);
  }

  factory BlePresentationStateController.production() {
    final manager = BleManager.instance;
    final adapterObservation = BleAdapterObservationBoundary.instance;
    return BlePresentationStateController(
      initialAdapterState: adapterPresentationStateFromFlutterBluePlus(
        adapterObservation.currentState,
      ),
      adapterStates: adapterObservation.states.map(
        adapterPresentationStateFromFlutterBluePlus,
      ),
      initialConnectionStatus: manager.connectionStatus,
      connectionStatuses: manager.statusStream,
    );
  }

  BleAdapterPresentationState _adapterState;
  BleConnectionStatus _connectionStatus;
  late final StreamSubscription<BleAdapterPresentationState>
  _adapterSubscription;
  late final StreamSubscription<BleConnectionStatus> _connectionSubscription;
  bool _disposed = false;

  void _setAdapterState(BleAdapterPresentationState state) {
    if (_disposed) return;
    _adapterState = state;
    _emitResolvedState();
  }

  void _setConnectionStatus(BleConnectionStatus status) {
    if (_disposed) return;
    _connectionStatus = status;
    _emitResolvedState();
  }

  void _emitResolvedState() {
    value = resolveBlePresentationState(
      adapterState: _adapterState,
      connectionStatus: _connectionStatus,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_adapterSubscription.cancel());
    unawaited(_connectionSubscription.cancel());
    super.dispose();
  }
}

enum BlePresentationKind {
  checking,
  unavailable,
  permissionNeeded,
  turningOn,
  turningOff,
  bluetoothOff,
  notConnected,
  scanning,
  connecting,
  reconnecting,
  disconnecting,
  reconnectFailed,
  connected,
}

enum BlePresentationIcon {
  connected,
  neutral,
  searching,
  disabled,
  unavailable,
  permission,
}

enum BlePresentationTone { connected, busy, failure, neutral }

class BlePresentationState {
  const BlePresentationState(this.kind);

  final BlePresentationKind kind;

  String get label => switch (kind) {
    BlePresentationKind.checking => 'Checking Bluetooth…',
    BlePresentationKind.unavailable => 'Bluetooth unavailable',
    BlePresentationKind.permissionNeeded => 'Bluetooth permission needed',
    BlePresentationKind.turningOn => 'Turning Bluetooth on…',
    BlePresentationKind.turningOff => 'Turning Bluetooth off…',
    BlePresentationKind.bluetoothOff => 'Bluetooth off',
    BlePresentationKind.notConnected => 'Not connected',
    BlePresentationKind.scanning => 'Scanning…',
    BlePresentationKind.connecting => 'Connecting…',
    BlePresentationKind.reconnecting => 'Reconnecting…',
    BlePresentationKind.disconnecting => 'Disconnecting…',
    BlePresentationKind.reconnectFailed => 'Reconnect failed',
    BlePresentationKind.connected => 'Connected',
  };

  /// Shorter wording for narrow toolbars. Screen readers still get
  /// [semanticLabel], which uses the full [label].
  String get shortLabel => switch (kind) {
    BlePresentationKind.checking => 'Checking…',
    BlePresentationKind.unavailable => 'Unavailable',
    BlePresentationKind.permissionNeeded => 'Needs permission',
    BlePresentationKind.turningOn => 'Turning on…',
    BlePresentationKind.turningOff => 'Turning off…',
    _ => label,
  };

  String get semanticLabel => 'Bluetooth connection: $label';

  bool get isConnected => kind == BlePresentationKind.connected;

  bool get isBusy => switch (kind) {
    BlePresentationKind.checking ||
    BlePresentationKind.turningOn ||
    BlePresentationKind.turningOff ||
    BlePresentationKind.scanning ||
    BlePresentationKind.connecting ||
    BlePresentationKind.reconnecting ||
    BlePresentationKind.disconnecting => true,
    _ => false,
  };

  bool get isFailure => switch (kind) {
    BlePresentationKind.unavailable ||
    BlePresentationKind.permissionNeeded ||
    BlePresentationKind.bluetoothOff ||
    BlePresentationKind.reconnectFailed => true,
    _ => false,
  };

  BlePresentationIcon get icon => switch (kind) {
    BlePresentationKind.connected => BlePresentationIcon.connected,
    BlePresentationKind.notConnected ||
    BlePresentationKind.disconnecting => BlePresentationIcon.neutral,
    BlePresentationKind.checking ||
    BlePresentationKind.turningOn ||
    BlePresentationKind.turningOff ||
    BlePresentationKind.scanning ||
    BlePresentationKind.connecting ||
    BlePresentationKind.reconnecting => BlePresentationIcon.searching,
    BlePresentationKind.bluetoothOff => BlePresentationIcon.disabled,
    BlePresentationKind.unavailable ||
    BlePresentationKind.reconnectFailed => BlePresentationIcon.unavailable,
    BlePresentationKind.permissionNeeded => BlePresentationIcon.permission,
  };

  BlePresentationTone get tone {
    if (isConnected) return BlePresentationTone.connected;
    if (isBusy) return BlePresentationTone.busy;
    if (isFailure) return BlePresentationTone.failure;
    return BlePresentationTone.neutral;
  }
}

BlePresentationState resolveBlePresentationState({
  required BleAdapterPresentationState adapterState,
  required BleConnectionStatus connectionStatus,
}) {
  switch (adapterState) {
    case BleAdapterPresentationState.off:
      return const BlePresentationState(BlePresentationKind.bluetoothOff);
    case BleAdapterPresentationState.turningOn:
      return const BlePresentationState(BlePresentationKind.turningOn);
    case BleAdapterPresentationState.turningOff:
      return const BlePresentationState(BlePresentationKind.turningOff);
    case BleAdapterPresentationState.unavailable:
      return const BlePresentationState(BlePresentationKind.unavailable);
    case BleAdapterPresentationState.unauthorized:
      return const BlePresentationState(BlePresentationKind.permissionNeeded);
    case BleAdapterPresentationState.unknown:
    case BleAdapterPresentationState.on:
      break;
  }

  final connectionPresentation = switch (connectionStatus) {
    BleConnectionStatus.connected => BlePresentationKind.connected,
    BleConnectionStatus.scanning => BlePresentationKind.scanning,
    BleConnectionStatus.connecting ||
    BleConnectionStatus.discovering ||
    BleConnectionStatus.subscribing => BlePresentationKind.connecting,
    BleConnectionStatus.reconnecting => BlePresentationKind.reconnecting,
    BleConnectionStatus.disconnecting => BlePresentationKind.disconnecting,
    BleConnectionStatus.reconnectFailed => BlePresentationKind.reconnectFailed,
    BleConnectionStatus.disconnected => null,
  };
  if (connectionPresentation != null) {
    return BlePresentationState(connectionPresentation);
  }

  return BlePresentationState(switch (adapterState) {
    BleAdapterPresentationState.on => BlePresentationKind.notConnected,
    BleAdapterPresentationState.unavailable => BlePresentationKind.unavailable,
    BleAdapterPresentationState.unauthorized =>
      BlePresentationKind.permissionNeeded,
    BleAdapterPresentationState.unknown => BlePresentationKind.checking,
    BleAdapterPresentationState.turningOn => BlePresentationKind.turningOn,
    BleAdapterPresentationState.turningOff => BlePresentationKind.turningOff,
    BleAdapterPresentationState.off => BlePresentationKind.bluetoothOff,
  });
}
