import 'package:flutter/material.dart';
import '../joystick_controller.dart';
import '../joystick_view.dart';

class JoystickWidget extends StatelessWidget {
  final JoystickController controller;
  final bool isLeft;
  final void Function(double x, double y)? onChanged;
  final String? knobImage;
  final String? baseImage;
  final JoystickAxisLock axisLock;

  const JoystickWidget({
    super.key,
    required this.controller,
    this.isLeft = true,
    this.onChanged,
    this.knobImage,
    this.baseImage,
    this.axisLock = JoystickAxisLock.none,
  });

  @override
  Widget build(BuildContext context) {
    return JoystickView(
      controller: controller,
      isLeft: isLeft,
      onChanged: onChanged,
      knobImage: knobImage,
      baseImage: baseImage,
      axisLock: axisLock,
    );
  }
}


