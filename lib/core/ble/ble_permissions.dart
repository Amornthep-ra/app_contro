import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureBleScanPermissions() async {
  if (!Platform.isAndroid) return true;

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;
  final permissions = sdkInt >= 31
      ? <Permission>[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ]
      : <Permission>[
          Permission.locationWhenInUse,
        ];

  for (final permission in permissions) {
    final status = await permission.status;
    if (status.isGranted) continue;

    final requested = await permission.request();
    if (!requested.isGranted) return false;
  }

  return true;
}
