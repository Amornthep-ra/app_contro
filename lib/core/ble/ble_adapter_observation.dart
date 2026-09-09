import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

bool isBleAdapterObservationInitiallySafe({
  required TargetPlatform platform,
  required BluetoothAdapterState cachedState,
}) {
  final usesCoreBluetooth =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  return !usesCoreBluetooth || cachedState != BluetoothAdapterState.unknown;
}

/// Delays CoreBluetooth observation until an existing BLE flow has already
/// produced an adapter state, avoiding permission and power UI on app launch.
class BleAdapterObservationBoundary {
  BleAdapterObservationBoundary({
    required BluetoothAdapterState initialState,
    required bool initiallySafe,
    required Stream<BluetoothAdapterState> Function() nativeAdapterStates,
  }) : _currentState = initialState,
       _observationSafe = initiallySafe,
       _nativeAdapterStates = nativeAdapterStates;

  factory BleAdapterObservationBoundary.production() {
    final cachedState = FlutterBluePlus.adapterStateNow;
    return BleAdapterObservationBoundary(
      initialState: cachedState,
      initiallySafe:
          kIsWeb ||
          isBleAdapterObservationInitiallySafe(
            platform: defaultTargetPlatform,
            cachedState: cachedState,
          ),
      nativeAdapterStates: () => FlutterBluePlus.adapterState,
    );
  }

  static final BleAdapterObservationBoundary instance =
      BleAdapterObservationBoundary.production();

  final Stream<BluetoothAdapterState> Function() _nativeAdapterStates;
  final StreamController<void> _safeEvents = StreamController<void>.broadcast(
    sync: true,
  );

  BluetoothAdapterState _currentState;
  bool _observationSafe;
  bool _disposed = false;

  BluetoothAdapterState get currentState => _currentState;

  @visibleForTesting
  bool get hasWaitingObservers => _safeEvents.hasListener;

  Stream<BluetoothAdapterState> get states => Stream.multi((events) {
    StreamSubscription<void>? safeSubscription;
    StreamSubscription<BluetoothAdapterState>? nativeSubscription;

    void startNativeObservation() {
      if (_disposed) {
        events.close();
        return;
      }
      events.addSync(_currentState);
      nativeSubscription = _nativeAdapterStates().distinct().listen(
        (state) {
          _currentState = state;
          events.addSync(state);
        },
        onError: events.addError,
        onDone: events.close,
      );
    }

    if (_disposed) {
      events.close();
    } else if (_observationSafe) {
      startNativeObservation();
    } else {
      safeSubscription = _safeEvents.stream.listen((_) {
        unawaited(safeSubscription?.cancel());
        safeSubscription = null;
        startNativeObservation();
      });
    }

    events.onCancel = () async {
      await safeSubscription?.cancel();
      await nativeSubscription?.cancel();
    };
  });

  /// Records a state obtained by an existing, user-driven native BLE flow.
  ///
  /// This method never starts native BLE work. Its first call only opens the
  /// boundary for presentation listeners after native observation is known to
  /// be safe.
  void recordAlreadyObserved(BluetoothAdapterState state) {
    if (_disposed) return;
    _currentState = state;
    if (_observationSafe) return;
    _observationSafe = true;
    _safeEvents.add(null);
  }

  /// Opens the boundary only when another native BLE operation has already
  /// populated FlutterBluePlus' in-memory adapter state.
  void recordCachedStateIfAvailable() {
    final cachedState = FlutterBluePlus.adapterStateNow;
    if (cachedState != BluetoothAdapterState.unknown) {
      recordAlreadyObserved(cachedState);
    }
  }

  @visibleForTesting
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_safeEvents.close());
  }
}
