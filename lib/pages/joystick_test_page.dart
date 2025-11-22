import 'package:flutter/material.dart';
import '../shared/joystick/joystick_widget.dart';
import '../shared/joystick/joystick_controller.dart';

class JoystickTestPage extends StatefulWidget {
  const JoystickTestPage({super.key});

  @override
  State<JoystickTestPage> createState() => _JoystickTestPageState();
}

class _JoystickTestPageState extends State<JoystickTestPage> {
  final joystickController = JoystickController();

  double lx = 0, ly = 0; // normalized -1..1
  double rx = 0, ry = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Joystick Test"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ค่าแสดงบนหน้าจอ
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Left Stick  :  X=${(lx * 100).toStringAsFixed(0)}  |  Y=${(ly * 100).toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Right Stick :  X=${(rx * 100).toStringAsFixed(0)}  |  Y=${(ry * 100).toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // JOYSTICK LEFT
                  JoystickWidget(
                    controller: joystickController,
                    isLeft: true,
                    onChanged: (x, y) {
                      setState(() {
                        lx = x;
                        ly = y;
                      });
                    },
                  ),

                  // JOYSTICK RIGHT
                  JoystickWidget(
                    controller: joystickController,
                    isLeft: false,
                    onChanged: (x, y) {
                      setState(() {
                        rx = x;
                        ry = y;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
