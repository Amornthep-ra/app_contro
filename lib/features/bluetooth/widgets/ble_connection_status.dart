// lib/features/bluetooth/widgets/ble_connection_status.dart
import 'package:flutter/material.dart';

import '../../../core/ble/ble_connection_coordinator.dart';
import '../../../core/ui/lavender_glass.dart';

/// Name shown for the connected robot: its name, then its id, then the
/// remembered last-device name.
String resolveBleConnectedDeviceName({
  String? currentName,
  String? currentId,
  String? lastDeviceName,
  String unknownName = 'Unknown',
}) {
  final name = currentName?.trim();
  if (name != null && name.isNotEmpty) return name;

  final id = currentId?.trim();
  if (id != null && id.isNotEmpty) return id;

  final lastName = lastDeviceName?.trim();
  if (lastName != null && lastName.isNotEmpty) return lastName;

  return unknownName;
}

/// One line under a connected robot's name: whether it is ready to control,
/// needs the pairing code, or cannot be used.
class BleSecurityLine extends StatelessWidget {
  const BleSecurityLine({super.key, required this.state});

  final BleControlSecurityState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      BleControlSecurityState.ready => (
        'Connected · ready to control',
        LavenderPalette.success,
        Icons.check_circle_rounded,
      ),
      BleControlSecurityState.pairingRequired => (
        'Enter the pairing code to unlock control',
        LavenderPalette.coral,
        Icons.lock_outline_rounded,
      ),
      BleControlSecurityState.authenticating => (
        'Connected · verifying…',
        LavenderPalette.violet,
        Icons.shield_outlined,
      ),
      BleControlSecurityState.authenticationFailed => (
        'Pairing failed · enter the code again',
        LavenderPalette.coral,
        Icons.error_outline_rounded,
      ),
      BleControlSecurityState.unsupportedFirmware => (
        'Secure firmware update required',
        LavenderPalette.coral,
        Icons.system_update_alt_rounded,
      ),
      BleControlSecurityState.disconnected => (
        'Connected',
        LavenderPalette.success,
        Icons.check_circle_rounded,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
