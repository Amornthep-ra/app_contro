import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home shows the last device the coordinator keeps, so a device forgotten
/// on another page disappears from Home too.
void main() {
  setUp(() {
    OrientationUtils.resetForTesting();
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> mountHome(WidgetTester tester) async {
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
    final presentation = ValueNotifier(
      const BlePresentationState(BlePresentationKind.notConnected),
    );
    addTearDown(presentation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          blePresentationState: presentation,
          animateBackground: false,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Reconnect shows for the saved device, not after Forget', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ble_last_device_id': 'AA:BB',
      'ble_last_device_name': 'PrinceBot',
    });
    await mountHome(tester);
    expect(find.text('Reconnect'), findsOneWidget);

    // Forget on another page clears the saved device; the coordinator
    // then holds no device, and Home follows without reopening.
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => BleConnectionCoordinator.instance.loadSavedDevice(),
    );
    await tester.pump();
    expect(find.text('Reconnect'), findsNothing);

    await unmount(tester);
  });

  testWidgets('no saved device: no Reconnect', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mountHome(tester);
    expect(find.text('Reconnect'), findsNothing);
    await unmount(tester);
  });
}
