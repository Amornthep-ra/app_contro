import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/lavender_glass.dart';

const _bluetoothSettingsChannel = MethodChannel(
  'com.pbcontroller.app/bluetooth_settings',
);

/// Asks the user to turn Bluetooth on before a scan. Returns true when
/// they chose Open settings (the system Bluetooth panel on Android, the
/// app's settings elsewhere), false when they closed the dialog.
Future<bool> promptToTurnOnBluetooth(BuildContext context) async {
  final openSettings = await showLavenderConfirmDialog(
    context: context,
    icon: Icons.bluetooth_disabled_rounded,
    title: 'Bluetooth is off',
    message: 'Turn on Bluetooth to scan for and connect to your robot.',
    confirmLabel: 'Open settings',
  );
  if (openSettings) await openBluetoothSettings();
  return openSettings;
}

Future<void> openBluetoothSettings() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final opened = await _bluetoothSettingsChannel.invokeMethod<bool>(
        'openBluetoothSettings',
      );
      if (opened == true) return;
    } on PlatformException {
      // Fall through to the app settings page when the device cannot open
      // the system Bluetooth panel.
    }
  }

  await openAppSettings();
}
