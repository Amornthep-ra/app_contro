import 'package:flutter/material.dart';
import '../widgets/joystick.dart';

class JoystickTestPage extends StatefulWidget {
  const JoystickTestPage({super.key});

  @override
  State<JoystickTestPage> createState() => _JoystickTestPageState();
}

class _JoystickTestPageState extends State<JoystickTestPage> {
  double lx = 0, ly = 0; // Joystick ซ้าย
  double rx = 0, ry = 0; // Joystick ขวา

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
                  Text("Left Stick  :  X=$lx  |  Y=$ly",
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  Text("Right Stick :  X=$rx  |  Y=$ry",
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // JOYSTICK LEFT
                  Joystick(
                    size: 200,
                    knobSize: 90,
                    onMove: (dx, dy) {
                      setState(() {
                        lx = dx;
                        ly = dy;
                      });
                    },
                  ),

                  // JOYSTICK RIGHT
                  Joystick(
                    size: 200,
                    knobSize: 90,
                    onMove: (dx, dy) {
                      setState(() {
                        rx = dx;
                        ry = dy;
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
