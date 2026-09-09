import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/features/gamepad/control_mode_settings_page.dart';

void main() {
  testWidgets('control settings follows responsive section ordering', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in <Size>[
      const Size(844, 390),
      const Size(640, 360),
      const Size(390, 844),
      const Size(360, 640),
      const Size(320, 568),
    ]) {
      for (final scale in <double>[1.0, 1.3, 2.0]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ControlModeSettingsPage(
              mode: ControlMode.fourButton,
              onManageLayouts: () {},
            ),
          ),
        );
        await tester.pump();

        final modeRect = tester.getRect(
          find.byKey(const ValueKey('control-mode-section')),
        );
        final layoutRect = tester.getRect(
          find.byKey(const ValueKey('layout-section')),
        );
        final twoColumn = size.width - 24 >= 600 && scale <= 1.3;
        if (twoColumn) {
          expect(modeRect.top, layoutRect.top);
          expect(layoutRect.left - modeRect.right, closeTo(16, 0.1));
          expect(modeRect.width, closeTo(layoutRect.width, 0.1));
        } else if (scale > 1.3 || size.width > size.height) {
          expect(layoutRect.top, lessThan(modeRect.top));
        } else {
          expect(modeRect.top, lessThan(layoutRect.top));
        }

        expect(
          tester
              .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
              .scrollDirection,
          Axis.vertical,
        );
        if ((size == const Size(844, 390) || size == const Size(640, 360)) &&
            scale == 1.0) {
          expect(find.text('Edit layout').hitTestable(), findsOneWidget);
          expect(find.text('Saved layouts').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
