// lib/core/widgets/cat_back_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_assets.dart';

/// The cat "Back" button used in portrait page headers.
///
/// The icon is 40 px so its arrow reads clearly next to a 20 pt title; the
/// tap target is 48 px. Use [leadingWidthFor] as the AppBar's
/// `leadingWidth` so the icon's left edge lines up with the page content.
class CatBackButton extends StatelessWidget {
  const CatBackButton({super.key, this.onPressed});

  static const double iconSize = 40;
  static const double tapTarget = 48;

  /// `AppBar.leadingWidth` that puts the icon's left edge at [contentInset].
  static double leadingWidthFor(double contentInset) =>
      contentInset - (tapTarget - iconSize) / 2 + tapTarget;

  /// Ready-made AppBar `leading` for a page whose content starts at
  /// [contentInset]; pair it with [leadingWidthFor].
  static Widget leading({VoidCallback? onPressed}) => Align(
    alignment: Alignment.centerRight,
    child: CatBackButton(onPressed: onPressed),
  );

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: Semantics(
        button: true,
        label: 'Back',
        excludeSemantics: true,
        child: InkResponse(
          radius: tapTarget / 2,
          onTap: () {
            HapticFeedback.selectionClick();
            final handler = onPressed;
            if (handler != null) {
              handler();
            } else {
              Navigator.maybePop(context);
            }
          },
          child: SizedBox.square(
            dimension: tapTarget,
            child: Center(
              child: Image.asset(
                AppAssets.controlBack,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.chevron_left_rounded, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
