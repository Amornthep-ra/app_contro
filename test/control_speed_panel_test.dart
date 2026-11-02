// The 4/8 BTN speed panels float under the Speed button instead of pushing
// the pad down, so opening them never moves the drive buttons.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/gamepad_components.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/gamepad_control_toolbar.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRoboto() async {
  // Real glyph widths, so the toolbar fits like it does on a phone.
  final loader = FontLoader('Roboto');
  for (final path in [
    'assets/fonts/Roboto/static/Roboto-Regular.ttf',
    'assets/fonts/Roboto/static/Roboto-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

/// Screen size plus left/right safe-area insets (a notch in landscape).
typedef _Screen = ({Size size, double inset});

const _screens = <String, _Screen>{
  '914x411': (size: Size(914, 411), inset: 0),
  '844x390 notch': (size: Size(844, 390), inset: 47),
  '640x360': (size: Size(640, 360), inset: 0),
};

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<void> mount(WidgetTester tester, Widget page, _Screen screen) async {
    tester.view.physicalSize = screen.size;
    tester.view.devicePixelRatio = 1;
    final padding = FakeViewPadding(left: screen.inset, right: screen.inset);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  List<Rect> padButtonRects(WidgetTester tester) => [
    for (final element in find.byType(GamepadImageHoldButton).evaluate())
      tester.getRect(find.byElementPredicate((e) => e == element)),
  ];

  Finder openPanel() => find.descendant(
    of: find.byType(GamepadToolbarDropdown),
    matching: find.byType(Container),
  );

  final speedPages = <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
  };

  for (final page in speedPages.entries) {
    for (final screen in _screens.entries) {
      testWidgets('${page.key} ${screen.key}: speed panel floats under Speed '
          'without moving the pad', (tester) async {
        await mount(tester, page.value(), screen.value);
        final before = padButtonRects(tester);
        expect(before, isNotEmpty);
        expect(openPanel(), findsNothing);

        await tester.tap(find.text('Speed').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(openPanel(), findsWidgets);

        // The drive buttons keep their exact place and size.
        expect(padButtonRects(tester), before);

        // Left edge under Speed, kept inside the toolbar's margins.
        final size = screen.value.size;
        final inset = screen.value.inset;
        final speed = tester.getRect(
          find.byKey(const ValueKey('gamepad-control-slot-2')),
        );
        final panel = tester.getRect(openPanel().first);
        final bar = tester.getRect(find.byType(AppBar));
        final minLeft = inset + 12;
        final maxRight = size.width - inset - 12;
        expect(
          panel.left,
          moreOrLessEquals(
            math.max(minLeft, math.min(speed.left, maxRight - panel.width)),
            epsilon: 0.5,
          ),
        );
        expect(panel.right, lessThanOrEqualTo(maxRight + 0.5));
        expect(panel.top, greaterThanOrEqualTo(bar.bottom));

        await tester.tap(find.text('Speed').first);
        await tester.pumpAndSettle();
        expect(openPanel(), findsNothing);
        expect(padButtonRects(tester), before);

        await unmount(tester);
      });
    }
  }

  final allPages = <String, Widget Function()>{
    ...speedPages,
    'joystick': () => const JoystickPage(),
  };

  for (final page in allPages.entries) {
    for (final screen in _screens.entries) {
      testWidgets(
        '${page.key} ${screen.key}: slotLeft matches the drawn toolbar',
        (tester) async {
          await mount(tester, page.value(), screen.value);
          final layout = tester
              .widget<GamepadControlRows>(find.byType(GamepadControlRows))
              .layout;
          final inset = screen.value.inset;
          final rowWidth = screen.value.size.width - inset * 2 - 24;

          for (var i = 0; i < layout.widths.length; i++) {
            final slot = tester.getRect(
              find.byKey(ValueKey('gamepad-control-slot-$i')),
            );
            expect(
              slot.left,
              moreOrLessEquals(
                inset + 12 + layout.slotLeft(i, rowWidth),
                epsilon: 0.5,
              ),
              reason: 'slot $i',
            );
          }

          await unmount(tester);
        },
      );
    }
  }
}
