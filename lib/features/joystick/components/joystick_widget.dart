import 'package:flutter/material.dart';
import 'joystick_controller.dart';
import 'joystick_view.dart';

class JoystickWidget extends StatelessWidget {
  final JoystickController controller;
  final bool isLeft;
  final void Function(double x, double y)? onChanged;
  final String? knobImage;

  const JoystickWidget({
    super.key,
    required this.controller,
    this.isLeft = true,
    this.onChanged,
    this.knobImage,
  });

  @override
  Widget build(BuildContext context) {
    return JoystickView(
      controller: controller,
      isLeft: isLeft,
      onChanged: onChanged,
      knobImage: knobImage,
    );
  }
}
