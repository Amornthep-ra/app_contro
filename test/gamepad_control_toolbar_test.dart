import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/gamepad_app_bar.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/core/widgets/gamepad_control_toolbar.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';

void main() {
  testWidgets(
    'reserved control widths survive all BLE and maximum telemetry values',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(640, 360), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final samples in [
            ['CMD = 255 | Med = 2', 'CMD = 0 | Lo = 1'],
            [
              'CMD = 255 | DRV = 100% | TRN = 100%',
              'CMD = 0 | DRV = 0% | TRN = 0%',
            ],
            ['JL X:-1.00 Y:-1.00', 'JL X:0.00 Y:0.00'],
            ['JR X:-1.00 Y:-1.00', 'JR X:0.00 Y:0.00'],
          ]) {
            List<Rect>? baseline;
            for (final kind in BlePresentationKind.values) {
              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Builder(
                      builder: (context) => Scaffold(
                        appBar: GamepadUnifiedAppBar(
                          controlLayout: GamepadControlLayout.measure(context, [
                            samples.first,
                            '@ble',
                          ]),
                          toolbarContent: GamepadCenteredToolbar(
                            textScaleFactor: scale,
                            children: [
                              GamepadControlPill(
                                label: kind.index.isEven
                                    ? samples.first
                                    : samples.last,
                              ),
                              GamepadControlPill(
                                label: BlePresentationState(kind).label,
                                icon: const SizedBox(width: 16, height: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: '$size $scale $kind ${samples.first}',
              );
              final rects = List.generate(
                2,
                (i) => tester.getRect(
                  find.byKey(ValueKey('gamepad-control-slot-$i')),
                ),
              );
              baseline ??= rects;
              expect(rects, baseline);
              for (final text in tester.widgetList<Text>(
                find.descendant(
                  of: find.byType(GamepadControlPill),
                  matching: find.byType(Text),
                ),
              )) {
                expect(text.style!.fontSize, 12);
                expect(text.style!.fontWeight, FontWeight.w600);
              }
              expect(
                find.descendant(
                  of: find.byType(GamepadControlPill),
                  matching: find.byType(FittedBox),
                ),
                findsNothing,
              );
            }
          }
        }
      }
    },
  );

  testWidgets('Back and Settings keep a larger safety gap', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final layout = GamepadControlLayout.measure(context, const [
                '',
                '@speed:Speed',
                'CMD = 255 | Med = 2',
                'BLE',
                '',
              ]);
              return GamepadControlScope(
                layout: layout,
                child: GamepadControlRows(
                  layout: layout,
                  children: const [
                    SizedBox(),
                    SizedBox(),
                    SizedBox(),
                    SizedBox(),
                    SizedBox(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final slots = List.generate(
      5,
      (index) =>
          tester.getRect(find.byKey(ValueKey('gamepad-control-slot-$index'))),
    );
    final gaps = List.generate(
      4,
      (index) => slots[index + 1].left - slots[index].right,
    );
    expect(gaps, const [16, 6, 6, 16]);
  });
  testWidgets('4BTN menu shows only speed names and updates current mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(640, 360), const Size(844, 390)]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Gamepad4ButtonPage(),
          ),
        );
        await tester.pump();
        for (final entry in {'Lo': 1, 'Med': 2, 'Hi': 4}.entries) {
          await tester.tap(find.byType(GamepadSpeedTogglePill));
          await tester.pumpAndSettle();
          for (final option in {'Lo': 1, 'Med': 2, 'Hi': 4}.entries) {
            expect(find.text(option.key), findsOneWidget);
            final tile = find
                .ancestor(
                  of: find.text(option.key),
                  matching: find.byType(InkWell),
                )
                .first;
            expect(tester.getSize(tile).height, 48);
            final icon = tester.widget<Image>(
              find.descendant(of: tile, matching: find.byType(Image)),
            );
            expect(icon.width, 32);
            expect(icon.height, 32);
            final tileRect = tester.getRect(tile);
            final labelRect = tester.getRect(find.text(option.key));
            expect(labelRect.bottom, lessThanOrEqualTo(tileRect.bottom));
          }
          await tester.ensureVisible(find.text(entry.key));
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(
            find.text('CMD = 0 | ${entry.key} = ${entry.value}'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
  });
}
