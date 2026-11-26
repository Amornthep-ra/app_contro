import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Linked is not the same as usable: Home says when the board still needs
/// its pair code or is being checked.
void main() {
  late int prompts;

  setUp(() {
    prompts = 0;
    OrientationUtils.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    BleConnectionCoordinator.instance.debugEmitForTesting(
      const BleConnectionCoordinatorState(),
    );
  });

  Future<void> mountConnected(
    WidgetTester tester,
    BleControlSecurityState security,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    BleConnectionCoordinator.instance.debugEmitForTesting(
      BleConnectionCoordinatorState(securityState: security),
    );
    final presentation = ValueNotifier(
      const BlePresentationState(BlePresentationKind.connected),
    );
    addTearDown(presentation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          blePresentationState: presentation,
          animateBackground: false,
          readRssi: () async => -60,
          pairingPromptLauncher: ({required context, coordinator}) async {
            prompts++;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('pair code needed: says so and offers Enter pair code', (
    tester,
  ) async {
    await mountConnected(tester, BleControlSecurityState.pairingRequired);

    expect(
      find.text('Enter the pairing code to unlock control'),
      findsOneWidget,
    );
    expect(find.text('Connected'), findsNothing);
    expect(find.text('Enter pair code'), findsOneWidget);

    await tester.tap(find.text('Enter pair code'));
    await tester.pump();
    expect(prompts, 1);
    await unmount(tester);
  });

  testWidgets('being checked: says so, no pair code button', (tester) async {
    await mountConnected(tester, BleControlSecurityState.authenticating);

    expect(find.text('Connected · verifying…'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    expect(find.text('Enter pair code'), findsNothing);
    await unmount(tester);
  });

  for (final unlocked in [
    BleControlSecurityState.ready,
    BleControlSecurityState.disconnected,
  ]) {
    testWidgets('${unlocked.name}: plain Connected as before', (tester) async {
      await mountConnected(tester, unlocked);

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Enter pair code'), findsNothing);
      await unmount(tester);
    });
  }

  testWidgets('pairing done: the line turns into Connected', (tester) async {
    await mountConnected(tester, BleControlSecurityState.pairingRequired);
    BleConnectionCoordinator.instance.debugEmitForTesting(
      const BleConnectionCoordinatorState(
        securityState: BleControlSecurityState.ready,
      ),
    );
    // The coordinator stream delivers on the next microtask.
    await tester.pump();
    await tester.pump();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Enter pair code'), findsNothing);
    await unmount(tester);
  });
}
