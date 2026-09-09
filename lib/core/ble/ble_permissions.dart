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

Future<BleScanPermissionResult> ensureBleScanPermissions() async {
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
