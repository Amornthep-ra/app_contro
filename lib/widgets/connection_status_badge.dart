// lib/widgets/connection_status_badge.dart
import 'package:flutter/material.dart';
import '../ble/ble_manager.dart';

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,     // ⭐ ฟังสถานะ BLE
      initialData: BleManager.instance.isConnected,     // ⭐ เริ่มต้น
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;

        final bgColor = connected
            ? Colors.green.withOpacity(0.16)
            : theme.colorScheme.surfaceVariant.withOpacity(0.8);

        final borderColor =
            connected ? Colors.green : theme.colorScheme.outlineVariant;

        final icon =
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled;

        final text = connected ? 'Connected' : 'Not connected';
        final dotColor = connected ? Colors.green : Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
