import 'package:flutter/material.dart';

@immutable
class GamepadSkin extends ThemeExtension<GamepadSkin> {
  final Color tutorialSurface;
  final Color tutorialCta;

  const GamepadSkin({
    required this.tutorialSurface,
    required this.tutorialCta,
  });

  const GamepadSkin.light()
      : tutorialSurface = const Color(0xFF1F2329),
        tutorialCta = const Color(0xFF3B82F6);

  const GamepadSkin.dark()
      : tutorialSurface = const Color(0xFF1F2329),
        tutorialCta = const Color(0xFF3B82F6);

  @override
  GamepadSkin copyWith({Color? tutorialSurface, Color? tutorialCta}) {
    return GamepadSkin(
      tutorialSurface: tutorialSurface ?? this.tutorialSurface,
      tutorialCta: tutorialCta ?? this.tutorialCta,
    );
  }

  @override
  GamepadSkin lerp(ThemeExtension<GamepadSkin>? other, double t) {
    if (other is! GamepadSkin) {
      return this;
    }
    return GamepadSkin(
      tutorialSurface: Color.lerp(tutorialSurface, other.tutorialSurface, t) ??
          tutorialSurface,
      tutorialCta: Color.lerp(tutorialCta, other.tutorialCta, t) ?? tutorialCta,
    );
  }
}
