import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_controller.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';

void main() {
  testWidgets(
    'release zeros immediately; new drag cancels return; base stays cached',
    (tester) async {
      final controller = JoystickController();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: JoystickView(controller: controller),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(JoystickView));
      final gesture = await tester.startGesture(center);
      await gesture.moveTo(center + const Offset(55, 0));
      await tester.pump();
      expect(controller.buildPacket().lx, greaterThan(0.5));
      CustomPainter painter() => tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(JoystickView),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      final before = painter();
      await gesture.moveTo(center + const Offset(60, 0));
      await tester.pump();
      expect(painter().shouldRepaint(before), isFalse);
      await gesture.up();
      expect(controller.buildPacket().lx, 0);
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.buildPacket().lx, 0);
      final next = await tester.startGesture(center);
      await next.moveTo(center + const Offset(-60, 0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.buildPacket().lx, lessThan(-0.5));
      await next.cancel();
      expect(controller.buildPacket().lx, 0);
      await tester.pumpAndSettle();
      expect(controller.buildPacket().lx, 0);
    },
  );

  testWidgets('two fingers preserve independent axis locks and release', (
    tester,
  ) async {
    final controller = JoystickController();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: JoystickView(
                  key: const ValueKey('left'),
                  controller: controller,
                  axisLock: JoystickAxisLock.yOnly,
                ),
              ),
              SizedBox(
                width: 200,
                height: 200,
                child: JoystickView(
                  key: const ValueKey('right'),
                  controller: controller,
                  isLeft: false,
                  axisLock: JoystickAxisLock.xOnly,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final lc = tester.getCenter(find.byKey(const ValueKey('left')));
    final rc = tester.getCenter(find.byKey(const ValueKey('right')));
    final left = await tester.startGesture(lc, pointer: 1);
    final right = await tester.startGesture(rc, pointer: 2);
    await left.moveTo(lc + const Offset(40, -60));
    await right.moveTo(rc + const Offset(60, 40));
    await tester.pump();
    expect(controller.buildPacket().lx, 0);
    expect(controller.buildPacket().ly, lessThan(-0.5));
    expect(controller.buildPacket().rx, greaterThan(0.5));
    expect(controller.buildPacket().ry, 0);
    await left.up();
    expect(controller.buildPacket().ly, 0);
    expect(controller.buildPacket().rx, greaterThan(0.5));
    await right.up();
    expect(controller.buildPacket().rx, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('light and dark joystick previews have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 340);
    if (Platform.isWindows) {
      await tester.runAsync(() async {
        final font = File(r'C:\Windows\Fonts\segoeui.ttf');
        if (await font.exists()) {
          final loader = FontLoader('Roboto')
            ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            );
          await loader.load();
        }
      });
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      final key = GlobalKey();
      final controller = JoystickController();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: brightness == Brightness.light
                  ? const Color(0xFFF5EDF9)
                  : const Color(0xFF21182D),
              body: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final isLeft in [true, false])
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLeft ? 'JOY LEFT' : 'JOY RIGHT',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: JoystickView(
                              controller: controller,
                              isLeft: isLeft,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/pb-joystick-${brightness.name}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
