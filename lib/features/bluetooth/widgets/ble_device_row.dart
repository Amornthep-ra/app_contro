// lib/features/bluetooth/widgets/ble_device_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/ui/lavender_glass.dart';
import '../../../core/widgets/signal_bars.dart';

/// Display name for a scan result: platform name, then advertised name,
/// then the device id.
String bleScanResultName(ScanResult result) {
  if (result.device.platformName.isNotEmpty) return result.device.platformName;
  if (result.advertisementData.advName.isNotEmpty) {
    return result.advertisementData.advName;
  }
  return result.device.remoteId.str;
}

/// Strongest signal first. Results are grouped by signal level (not raw
/// RSSI) and then by name, so rows do not jump around on every RSSI tick.
List<ScanResult> sortBleScanResults(Iterable<ScanResult> results) {
  final sorted = results.toList();
  sorted.sort((a, b) {
    final level = bleSignalLevel(b.rssi).compareTo(bleSignalLevel(a.rssi));
    if (level != 0) return level;
    final name = bleScanResultName(
      a,
    ).toLowerCase().compareTo(bleScanResultName(b).toLowerCase());
    if (name != 0) return name;
    return a.device.remoteId.str.compareTo(b.device.remoteId.str);
  });
  return sorted;
}

/// Soft violet → cyan circle with an icon, used for robots and empty states.
class BleRoundIcon extends StatelessWidget {
  const BleRoundIcon({super.key, required this.icon, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LavenderPalette.violetBright.withValues(alpha: 0.18),
            LavenderPalette.cyan.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Icon(icon, size: size * 0.52, color: LavenderPalette.violet),
    );
  }
}

/// One discovered robot: name, "Last used", signal, and a chevron or a
/// spinner while it is the one being connected.
class BleDeviceRow extends StatelessWidget {
  const BleDeviceRow({
    super.key,
    required this.name,
    required this.rssi,
    required this.lastUsed,
    required this.connecting,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final int rssi;
  final bool lastUsed;
  final bool connecting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = !enabled && !connecting;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Connect to $name, signal ${bleSignalLabel(rssi)}',
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.5 : 1,
        duration: const Duration(milliseconds: 160),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            splashColor: LavenderPalette.violet.withValues(alpha: 0.10),
            highlightColor: LavenderPalette.violet.withValues(alpha: 0.05),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                child: Row(
                  children: [
                    const BleRoundIcon(icon: Icons.smart_toy_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: LavenderPalette.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (lastUsed) ...[
                                const SizedBox(width: 8),
                                const LavenderChip(label: 'Last used'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SignalBars(rssi: rssi, height: 12),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${bleSignalLabel(rssi)} · $rssi dBm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: LavenderPalette.inkSoft,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (connecting)
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: LavenderPalette.violet,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: LavenderPalette.inkMuted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
