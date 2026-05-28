import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/features/controller/controller_home_page.dart';

void main() {
  testWidgets('Control Modes renders Thai strings without mojibake', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = true;

    await tester.pumpWidget(
      const MaterialApp(
        home: ControllerHomePage(),
      ),
    );

    expect(find.text('โหมดการควบคุม'), findsOneWidget);
    expect(find.text('Gamepad Mode Edit'), findsOneWidget);
    expect(find.text('Gamepad (4 Buttons)'), findsOneWidget);
    expect(find.text('Joystick Mode'), findsOneWidget);
    expect(find.text('คู่มือ'), findsOneWidget);
    expect(find.text('ควบคุม 8 ปุ่ม ปรับแต่งตำแหน่งได้'), findsOneWidget);
    expect(find.text('ควบคุมทิศทางแบบ 4 ปุ่ม'), findsOneWidget);
    expect(find.text('ควบคุมด้วยสติ๊กอิสระ'), findsOneWidget);
    expect(find.text('วิธีใช้งานและการตั้งค่า'), findsOneWidget);
    expect(find.text('ยังไม่ได้เชื่อมต่อ'), findsOneWidget);
    expect(find.text('เชื่อมต่ออีกครั้ง'), findsOneWidget);
    expect(find.byTooltip('คู่มือ'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
