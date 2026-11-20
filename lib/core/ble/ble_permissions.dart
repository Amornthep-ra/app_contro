import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_adapter_observation.dart';

enum BleScanPermissionResult {
  granted,
  permissionDenied,
  bluetoothOff,
  locationServiceOff,
}

@visibleForTesting
BleScanPermissionResult decideBleScanPermissionResult({
  required bool bluetoothOn,
  required bool permissionsGranted,
  required bool requiresLocationService,
  required bool locationServiceEnabled,
}) {
  if (!permissionsGranted) return BleScanPermissionResult.permissionDenied;
  if (requiresLocationService && !locationServiceEnabled) {
    return BleScanPermissionResult.locationServiceOff;
  }
  if (!bluetoothOn) return BleScanPermissionResult.bluetoothOff;
  return BleScanPermissionResult.granted;
}

/// Scan result for a CoreBluetooth (iOS/macOS) adapter state. Only states
/// that certainly block a scan are reported; anything else lets the scan run
/// as before, so an unclear state never blocks the user.
@visibleForTesting
BleScanPermissionResult appleScanPermissionResult(BluetoothAdapterState state) {
  switch (state) {
    case BluetoothAdapterState.off:
      return BleScanPermissionResult.bluetoothOff;
    case BluetoothAdapterState.unauthorized:
      return BleScanPermissionResult.permissionDenied;
    case BluetoothAdapterState.unknown:
    case BluetoothAdapterState.unavailable:
    case BluetoothAdapterState.turningOn:
    case BluetoothAdapterState.on:
    case BluetoothAdapterState.turningOff:
      return BleScanPermissionResult.granted;
  }
}

Future<BleScanPermissionResult> _ensureAppleScanPermissions() async {
  // CoreBluetooth reports `unknown` until it has initialized, which can take
  // a moment on first use. Wait briefly for a real state.
  BluetoothAdapterState state;
  try {
    state = await FlutterBluePlus.adapterState
        .firstWhere((value) => value != BluetoothAdapterState.unknown)
        .timeout(const Duration(seconds: 2));
  } on TimeoutException {
    return BleScanPermissionResult.granted;
  }
  BleAdapterObservationBoundary.instance.recordAlreadyObserved(state);
  return appleScanPermissionResult(state);
}

Future<BleScanPermissionResult> ensureBleScanPermissions() async {
  if (Platform.isIOS || Platform.isMacOS) return _ensureAppleScanPermissions();
  if (!Platform.isAndroid) return BleScanPermissionResult.granted;

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;
  final requiresLocationService = sdkInt < 31;
  final permissions = sdkInt >= 31
      ? <Permission>[Permission.bluetoothScan, Permission.bluetoothConnect]
      : <Permission>[Permission.locationWhenInUse];

  for (final permission in permissions) {
    final status = await permission.status;
    if (status.isGranted) continue;

    final requested = await permission.request();
    if (!requested.isGranted) {
      return BleScanPermissionResult.permissionDenied;
    }
  }

  if (requiresLocationService) {
    final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
    if (!serviceStatus.isEnabled) {
      return BleScanPermissionResult.locationServiceOff;
    }
  }

  final adapterState = await FlutterBluePlus.adapterState.first;
  BleAdapterObservationBoundary.instance.recordAlreadyObserved(adapterState);
  if (adapterState != BluetoothAdapterState.on) {
    return BleScanPermissionResult.bluetoothOff;
  }

  return BleScanPermissionResult.granted;
}
