import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/features/gamepad/control_mode_settings_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The control session shared by the three control pages
/// (ControlPageMixin): Start, Stop, the editor and leaving the page.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<int?> acquire() async =>
      BleManager.instance.claimTrafficMode(BleTrafficMode.controlBinary);

  final pages = <String, Widget Function(Future<int?> Function() acquire)>{
    'four-button': (acquire) => Gamepad4ButtonPage(acquireControl: acquire),
    'eight-button': (acquire) => GamepadModeEdit(acquireControl: acquire),
    'joystick': (acquire) => JoystickPage(acquireControl: acquire),
  };
  final modes = {
    for (final page in pages.entries) page.key: () => page.value(acquire),
  };

  void useLandscapePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(914, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Gives control back the way a test would find it: a text-mode owner
  /// can claim the link only once no control owner holds it.
  void expectControlReleased() {
    final textOwner = BleManager.instance.claimTrafficMode(
      BleTrafficMode.textCommand,
    );
    expect(textOwner, isNotNull, reason: 'control owner still held');
    BleManager.instance.releaseTrafficMode(textOwner!);
  }

  for (final mode in modes.entries) {
    testWidgets(
      '${mode.key}: Back while driving releases control and leaves once',
      (tester) async {
        useLandscapePhone(tester);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Root')),
          ),
        );
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Home')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          navigator.currentState!.push<void>(
            MaterialPageRoute(builder: (_) => mode.value()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ControlStartStopButton));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);

        final back = find.byType(GamepadAppBarBackButton);
        await tester.tap(back);
        await tester.tap(back, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Root'), findsNothing);
        expectControlReleased();
        expect(tester.takeException(), isNull);
      },
    );

    /// Root, Home, then the control page; Start pressed.
    Future<GlobalKey<NavigatorState>> openDriving(WidgetTester tester) async {
      useLandscapePhone(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Root')),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Home'))),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => mode.value()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);
      return navigator;
    }

    /// Taps Back the way the app bar does, without waiting: the stop
    /// packet is still being sent when the next line runs.
    void pressBack(WidgetTester tester) => tester
        .widget<GamepadAppBarBackButton>(find.byType(GamepadAppBarBackButton))
        .onPressed();

    testWidgets('${mode.key}: Settings tapped while leaving is ignored', (
      tester,
    ) async {
      await openDriving(tester);

      final settings = tester
          .widget<GamepadAppBarActionGroup>(
            find.byType(GamepadAppBarActionGroup),
          )
          .items
          .singleWhere((item) => item.label == 'Settings');
      pressBack(tester);
      settings.onTap!();
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(ControlModeSettingsPage), findsNothing);
      expect(find.byType(GamepadAppBarBackButton), findsNothing);
      expectControlReleased();
      expect(tester.takeException(), isNull);
    });

    testWidgets('${mode.key}: a dialog opened while leaving is closed with '
        'the page', (tester) async {
      final navigator = await openDriving(tester);

      pressBack(tester);
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Pairing')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Pairing'), findsNothing);
      expect(find.byType(GamepadAppBarBackButton), findsNothing);
      expectControlReleased();
      expect(tester.takeException(), isNull);
    });

    testWidgets('${mode.key}: a Start still pending when the app is '
        'suspended leaves Start usable', (tester) async {
      useLandscapePhone(tester);
      final gate = Completer<void>();
      var acquires = 0;
      Future<int?> slowAcquire() async {
        acquires++;
        if (acquires == 1) {
          final owner = BleManager.instance.claimTrafficMode(
            BleTrafficMode.controlBinary,
          );
          await gate.future;
          return owner;
        }
        // Back in the foreground: Start resumes control.
        BleManager.instance.debugPresentConnectionForTesting(
          status: BleConnectionStatus.connected,
          connected: true,
          deviceName: 'PB-Robot',
        );
        return BleManager.instance.resumeControl(ownerName: 'test');
      }

      addTearDown(() async {
        // Never leave control suspended for the next test.
        final manager = BleManager.instance;
        if (manager.controlSuspendedForLifecycle) {
          manager.debugPresentConnectionForTesting(
            status: BleConnectionStatus.connected,
            connected: true,
            deviceName: 'PB-Robot',
          );
          final owner = await manager.resumeControl(ownerName: 'cleanup');
          if (owner != null) manager.releaseTrafficMode(owner);
        }
        manager.debugPresentConnectionForTesting(
          status: BleConnectionStatus.disconnected,
        );
      });
      await tester.pumpWidget(MaterialApp(home: pages[mode.key]!(slowAcquire)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pump();
      // The notification shade, say, while Start waits for the robot.
      await BleManager.instance.handleAppLifecycleState(
        AppLifecycleState.inactive,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(BleManager.instance.controlSuspendedForLifecycle, isTrue);
      expect(find.bySemanticsLabel('Start control'), findsOneWidget);

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      expect(acquires, 2);
      expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('${mode.key}: opening the editor stops driving', (
      tester,
    ) async {
      useLandscapePhone(tester);
      await tester.pumpWidget(MaterialApp(home: mode.value()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ControlStartStopButton));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit layout'));
      await tester.pumpAndSettle();
      expectControlReleased();

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Start control'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
