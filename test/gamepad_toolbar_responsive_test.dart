import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/core/widgets/gamepad_app_bar.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/gamepad/widgets/gamepad_telemetry_chip.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  test('toolbar metrics meet the baseline size specification', () {
    final metrics = GamepadAppBarMetrics.forWidth(844);
    expect(GamepadAppBarMetrics.toolbarHeight, 56);
    expect(metrics.controlHeight, 36);
    expect(metrics.tapTargetExtent, 48);
    expect(metrics.iconButtonExtent, 80);
    expect(metrics.labelButtonWidth, 80);
    expect(metrics.controlGap, 8);
    expect(metrics.iconSize, 18);
    expect(metrics.telemetryLabelFontSize, 14);
    expect(metrics.telemetryValueFontSize, 14);
  });

  testWidgets('visible controls are compact inside aligned 48px hit targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: GamepadUnifiedAppBar(
            leading: GamepadAppBarBackButton(onPressed: () {}),
            speedToggle: GamepadSpeedTogglePill(
              expanded: false,
              onTap: () {},
              accent: Colors.blue,
              label: 'Med',
            ),
            cmdChip: const GamepadTelemetryChip(
              icon: Icons.tune,
              label: 'CMD',
              value: '7',
            ),
            bleBadge: ConnectionStatusBadge(
              appBarMetrics: GamepadAppBarMetrics.forWidth(844),
              enableBlePlatformBindings: false,
            ),
            actions: [
              GamepadActionPill(
                label: 'Settings',
                icon: Icons.settings_outlined,
                accent: Colors.blueGrey,
                onTap: () {},
                iconOnly: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final surfaceFinder = find.byKey(
      const ValueKey('gamepad-visual-control-surface'),
    );
    final surfaceCount = surfaceFinder.evaluate().length;
    expect(surfaceCount, greaterThan(0));
    for (int index = 0; index < surfaceCount; index++) {
      final size = tester.getSize(surfaceFinder.at(index));
      expect(size.width, 80);
      expect(size.height, inInclusiveRange(36, 48));
    }

    final hitTargets = <Rect>[
      tester.getRect(find.byType(GamepadAppBarBackButton)),
      tester.getRect(find.byType(GamepadSpeedTogglePill)),
      tester.getRect(find.byType(ConnectionStatusBadge)),
      tester.getRect(find.byType(GamepadActionPill)),
    ];
    for (final rect in hitTargets) {
      expect(rect.width, 80);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(
        (rect.center.dy - hitTargets.first.center.dy).abs(),
        lessThanOrEqualTo(1),
      );
    }
    for (int i = 0; i < hitTargets.length; i++) {
      for (int j = i + 1; j < hitTargets.length; j++) {
        final overlap = hitTargets[i].intersect(hitTargets[j]);
        expect(overlap.width <= 0 || overlap.height <= 0, isTrue);
      }
    }
    expect(hitTargets[0].center.dx, lessThan(hitTargets[1].center.dx));
    expect(hitTargets[1].center.dx, lessThan(hitTargets[2].center.dx));
    expect(hitTargets[2].center.dx, lessThan(hitTargets[3].center.dx));

    final slots = _toolbarSlotRects(tester);
    expect(slots, hasLength(5));
    for (final slot in slots) {
      expect(slot.width, 80);
      expect(slot.height, 48);
    }
    final orderedSlots = [...slots]..sort((a, b) => a.left.compareTo(b.left));
    for (var index = 1; index < orderedSlots.length; index++) {
      expect(orderedSlots[index].left - orderedSlots[index - 1].right, 8);
    }
    expect(
      (orderedSlots.first.left + orderedSlots.last.right) / 2,
      closeTo(844 / 2, 0.1),
    );
  });

  testWidgets('toolbar keeps telemetry visible at every responsive size', (
    tester,
  ) async {
    Future<void> pumpToolbar(Size size, double textScale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            appBar: GamepadUnifiedAppBar(
              textScaleFactor: textScale,
              viewportWidth: size.width,
              leading: GamepadAppBarBackButton(onPressed: () {}),
              speedToggle: GamepadSpeedTogglePill(
                expanded: false,
                onTap: () {},
                accent: Colors.blue,
                label: 'Med',
              ),
              cmdChip: const GamepadTelemetryChip(
                icon: Icons.tune,
                label: 'CMD',
                value: '7',
              ),
              bleBadge: const SizedBox(width: 48, height: 48),
              actions: const [SizedBox(width: 48, height: 48)],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpToolbar(const Size(900, 390), 1.3);
    expect(find.byType(GamepadTelemetryChip), findsOneWidget);
    expect(find.byKey(const ValueKey('control-status-popover')), findsNothing);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 56);

    await pumpToolbar(const Size(899, 390), 1.0);
    expect(find.byType(GamepadTelemetryChip), findsOneWidget);
    expect(find.byKey(const ValueKey('control-status-popover')), findsNothing);

    await pumpToolbar(const Size(1000, 390), 1.31);
    expect(find.byType(GamepadTelemetryChip), findsOneWidget);
    expect(find.byKey(const ValueKey('control-status-popover')), findsNothing);

    await pumpToolbar(const Size(1000, 390), 2.0);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 72);
  });

  testWidgets('joystick inline telemetry fits at the 900px threshold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: JoystickPage()));
    await tester.pump();

    expect(find.byType(GamepadTelemetryChip), findsNWidgets(3));
    expect(find.byKey(const ValueKey('control-status-popover')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final telemetryCount in <String, int>{
    'four-button': 1,
    'eight-button': 1,
    'joystick': 3,
  }.entries) {
    testWidgets(
      '${telemetryCount.key} toolbar fits the forced portrait viewport',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final size in <Size>[
          const Size(390, 844),
          const Size(360, 640),
          const Size(320, 568),
        ]) {
          tester.view.physicalSize = size;
          for (final textScale in <double>[1.0, 1.3, 2.0]) {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) {
                    final metrics = GamepadAppBarMetrics.forWidth(size.width);
                    final telemetry = List<Widget>.generate(
                      telemetryCount.value,
                      (index) => GamepadTelemetryChip(
                        icon: Icons.tune,
                        label: index == 0 ? 'CMD' : 'J$index',
                        value: index == 0 ? '0' : '0,0',
                        metrics: metrics,
                      ),
                    );
                    return Scaffold(
                      appBar: GamepadUnifiedAppBar(
                        textScaleFactor: textScale,
                        viewportWidth: size.width,
                        leading: GamepadAppBarBackButton(onPressed: () {}),
                        speedToggle: telemetryCount.key == 'joystick'
                            ? null
                            : GamepadSpeedTogglePill(
                                expanded: false,
                                onTap: () {},
                                accent: Colors.blue,
                                label: telemetryCount.key == 'eight-button'
                                    ? 'DRV 50% / TRN 50%'
                                    : 'Lo',
                              ),
                        cmdChip: telemetry[0],
                        drvChip: telemetry.length > 1 ? telemetry[1] : null,
                        trnChip: telemetry.length > 2 ? telemetry[2] : null,
                        bleBadge: ConnectionStatusBadge(
                          appBarMetrics: metrics,
                          enableBlePlatformBindings: false,
                        ),
                        actions: [
                          GamepadActionPill(
                            label: 'Settings',
                            icon: Icons.settings_outlined,
                            accent: Colors.blueGrey,
                            onTap: () {},
                            iconOnly: true,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
            await tester.pump();

            _expectMinimumHitTarget(
              tester,
              find.byType(GamepadAppBarBackButton),
            );
            _expectMinimumHitTarget(tester, find.byType(ConnectionStatusBadge));
            final settingsRect = tester.getRect(find.byType(GamepadActionPill));
            expect(
              settingsRect.width,
              greaterThanOrEqualTo(48),
              reason: '${telemetryCount.key} Settings width at $textScale',
            );
            expect(
              settingsRect.height,
              greaterThanOrEqualTo(48),
              reason: '${telemetryCount.key} Settings height at $textScale',
            );
            if (telemetryCount.key != 'joystick') {
              _expectMinimumHitTarget(
                tester,
                find.byType(GamepadSpeedTogglePill),
              );
            }
            expect(
              find.byType(GamepadTelemetryChip),
              findsNWidgets(telemetryCount.value),
            );
            expect(
              find.byKey(const ValueKey('control-status-popover')),
              findsNothing,
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${telemetryCount.key} portrait toolbar at $size and scale $textScale',
            );
          }
        }
      },
    );
  }

  for (final mode in <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  }.entries) {
    testWidgets('${mode.key} toolbar remains usable across target layouts', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in <Size>[const Size(844, 390), const Size(640, 360)]) {
        for (final textScale in <double>[1.0, 1.3, 2.0]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: mode.value(),
            ),
          );
          await tester.pump();

          _expectMinimumHitTarget(tester, find.byType(GamepadAppBarBackButton));
          _expectMinimumHitTarget(tester, find.byType(ConnectionStatusBadge));
          _expectMinimumHitTarget(tester, find.byType(GamepadActionPill).last);
          if (mode.key != 'joystick') {
            _expectMinimumHitTarget(
              tester,
              find.byType(GamepadSpeedTogglePill),
            );
          }
          expect(
            find.byKey(const ValueKey('control-status-popover')),
            findsNothing,
          );
          expect(
            find.byType(GamepadTelemetryChip),
            findsNWidgets(mode.key == 'joystick' ? 3 : 1),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${mode.key} at $size with text scale $textScale',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    });
  }

  for (final mode in <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  }.entries) {
    testWidgets(
      '${mode.key} edit toolbar keeps every action in one ordered row',
      (tester) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: mode.value(),
          ),
        );
        await tester.pump();

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        final editLayout = find.text('Edit layout');
        await tester.ensureVisible(editLayout);
        await tester.tap(editLayout);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('gamepad-edit-more')), findsNothing);
        for (final label in <String>[
          'Done',
          'Lock',
          'Decrease size',
          'Increase size',
          'Grid',
          'Undo',
          'Redo',
          'Reset',
          'Delete',
        ]) {
          expect(find.byTooltip(label), findsOneWidget);
        }
        final editTools = find.byType(GamepadToolIconPill);
        expect(editTools, findsNWidgets(9));
        for (var index = 0; index < editTools.evaluate().length; index++) {
          final rect = tester.getRect(editTools.at(index));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        final rows = <double, List<Rect>>{};
        for (final rect in _toolbarSlotRects(tester)) {
          rows.putIfAbsent(rect.top, () => []).add(rect);
        }
        expect(rows.length, 1);
        for (final row in rows.values) {
          row.sort((a, b) => a.left.compareTo(b.left));
          expect((row.first.left + row.last.right) / 2, closeTo(320, 0.1));
          for (var index = 1; index < row.length; index++) {
            expect(row[index].left - row[index - 1].right, 8);
          }
        }
        final orderedLabels = <String>[
          'Done',
          'Lock',
          'Decrease size',
          'Increase size',
          'Grid',
          'Undo',
          'Redo',
          'Reset',
          'Delete',
        ];
        final centers = [
          for (final label in orderedLabels)
            tester.getRect(find.byTooltip(label)).center.dx,
        ];
        for (var index = 1; index < centers.length; index++) {
          expect(centers[index], greaterThan(centers[index - 1]));
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  for (final mode in <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  }.entries) {
    testWidgets(
      '${mode.key} edit toolbar stays inside safe bounds across row thresholds',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final size in [const Size(844, 390), const Size(932, 430)]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.fromLTRB(62, 24, 62, 21),
                    viewPadding: const EdgeInsets.fromLTRB(62, 24, 62, 21),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: mode.value(),
              ),
            );
            await tester.pump();
            await tester.tap(find.byTooltip('Settings'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Edit layout'));
            await tester.tap(find.text('Edit layout'));
            await tester.pumpAndSettle();

            expect(
              find.byKey(const ValueKey('gamepad-edit-more')),
              findsNothing,
            );
            expect(find.byTooltip('Undo'), findsOneWidget);
            expect(find.byTooltip('Redo'), findsOneWidget);
            expect(find.byTooltip('Done'), findsOneWidget);
            final toolbar = tester.getRect(find.byType(NavigationToolbar));
            for (final slot in _toolbarSlotRects(tester)) {
              expect(slot.left, greaterThanOrEqualTo(62));
              expect(slot.right, lessThanOrEqualTo(size.width - 62));
              expect(
                slot.top,
                greaterThanOrEqualTo(toolbar.top),
                reason: 'Edit action must not be clipped above the toolbar',
              );
              expect(
                slot.bottom,
                lessThanOrEqualTo(toolbar.bottom),
                reason: 'Edit action must not be clipped below the toolbar',
              );
            }
            expect(tester.takeException(), isNull);

            await tester.tap(find.byTooltip('Grid'));
            await tester.pump();
            await tester.tap(find.byTooltip('Done'));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Settings'), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        }
      },
    );
  }
}

void _expectMinimumHitTarget(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
}

List<Rect> _toolbarSlotRects(WidgetTester tester) {
  final slots = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'gamepad-toolbar-slot-',
        ),
  );
  return [
    for (var index = 0; index < slots.evaluate().length; index++)
      tester.getRect(slots.at(index)),
  ];
}
