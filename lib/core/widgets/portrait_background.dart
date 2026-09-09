import 'package:flutter/material.dart';

import '../ui/app_assets.dart';

class PortraitBackground extends StatelessWidget {
  final Widget child;

  const PortraitBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF5F0FF)),
        Image.asset(
          AppAssets.controlBackgroundPortrait,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        child,
      ],
    );
  }
}
