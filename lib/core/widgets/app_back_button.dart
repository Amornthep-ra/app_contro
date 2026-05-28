import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final double width;
  final double height;
  final double iconSize;
  final BorderRadius? borderRadius;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.buttonKey,
    this.width = 44,
    this.height = 44,
    this.iconSize = 30,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: buttonKey,
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              final handler = onPressed;
              if (handler != null) {
                handler();
              } else {
                Navigator.maybePop(context);
              }
            },
            child: SizedBox(
              width: width,
              height: height,
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
