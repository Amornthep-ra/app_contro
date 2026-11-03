// lib/core/widgets/signal_bars.dart
import 'package:flutter/material.dart';

import '../ui/lavender_glass.dart';

/// 0–4 bars for a BLE RSSI value (dBm).
int bleSignalLevel(int? rssi) {
  if (rssi == null) return 0;
  if (rssi >= -55) return 4;
  if (rssi >= -65) return 3;
  if (rssi >= -75) return 2;
  if (rssi >= -85) return 1;
  return 0;
}

/// Green when strong, amber when usable, coral only when really weak.
Color bleSignalColor(int? rssi) {
  if (rssi == null) return LavenderPalette.inkMuted;
  if (rssi >= -65) return LavenderPalette.success;
  if (rssi >= -80) return LavenderPalette.warning;
  return LavenderPalette.coral;
}

String bleSignalLabel(int rssi) => switch (bleSignalLevel(rssi)) {
  4 => 'Very strong',
  3 => 'Strong',
  2 => 'Medium',
  1 => 'Weak',
  _ => 'Very weak',
};

/// Four rising bars, like a phone's signal indicator.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.rssi, this.height = 14});

  final int? rssi;
  final double height;

  @override
  Widget build(BuildContext context) {
    final level = bleSignalLevel(rssi);
    final color = bleSignalColor(rssi);
    final barWidth = height / 4;
    return Semantics(
      label: rssi == null ? 'No signal' : 'Signal ${bleSignalLabel(rssi!)}',
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            return Container(
              width: barWidth,
              height: height * (0.36 + 0.213 * i),
              margin: EdgeInsets.only(right: i == 3 ? 0 : barWidth * 0.55),
              decoration: BoxDecoration(
                color: i < level ? color : color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
