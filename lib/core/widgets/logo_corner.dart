// lib/core/widgets/logo_corner.dart
import 'package:flutter/material.dart';
import '../ui/app_assets.dart';

class LogoCorner extends StatelessWidget {
  const LogoCorner({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(
            opacity: 0.95,
            child: SizedBox(
              width: 56,
              height: 56,
              child: ClipOval(
                child: Image.asset(
                  AppAssets.cornerLogo,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
