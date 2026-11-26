import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/ui/lavender_glass.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home opens the Bluetooth page once per tap burst, like its tiles.
///
/// Flutter already ignores taps on Home while the new page slides in, so
/// this passes without Home's own guard too; it keeps that behavior and
/// checks Scan works again after Back.
void main() {
  setUp(() {
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

  testWidgets('Scan devices opens one Bluetooth page, and again after Back', (
    tester,
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
    final presentation = ValueNotifier(
      const BlePresentationState(BlePresentationKind.notConnected),
    );
    addTearDown(presentation.dispose);
    var pages = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        // As in the app (main.dart): pages slide in from the right.
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: HomePage(
          blePresentationState: presentation,
          animateBackground: false,
          blePageBuilder: (_) {
            pages++;
            return const Scaffold(body: Text('BLE page'));
          },
        ),
      ),
    );
    await tester.pump();

    final scan = find.text('Scan devices');
    final leftEdge =
        tester
            .getRect(
              find.ancestor(
                of: scan,
                matching: find.byType(GradientActionButton),
              ),
            )
            .centerLeft +
        const Offset(8, 0);
    await tester.tap(scan);
    // The new page slides in from the right; Home's left part, with the
    // start of Scan devices, can still be tapped meanwhile.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(leftEdge);
    await tester.pumpAndSettle();
    expect(pages, 1);
    expect(find.text('BLE page'), findsOneWidget);

    // Back on Home, Scan works again.
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(scan);
    await tester.pumpAndSettle();
    expect(pages, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
