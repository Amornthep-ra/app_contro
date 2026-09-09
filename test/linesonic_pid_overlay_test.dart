import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/features/linesonic/linesonic_pid_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  testWidgets('PID route owns dark status icons and restores its destination', (
    tester,
  ) async {
    const destinationStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final testCase in <(Size, double)>[
      (const Size(390, 844), 2.0),
      (const Size(360, 640), 1.0),
    ]) {
      tester.view.physicalSize = testCase.$1;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(testCase.$2)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(systemOverlayStyle: destinationStyle),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const LineSonicPidPage(),
                  ),
                ),
                child: const Text('Open PID'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open PID'));
      await tester.pumpAndSettle();

      final pidAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(pidAppBar.systemOverlayStyle!.statusBarColor, Colors.transparent);
      expect(
        pidAppBar.systemOverlayStyle!.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        pidAppBar.systemOverlayStyle!.statusBarBrightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final destinationAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(destinationAppBar.systemOverlayStyle, destinationStyle);
      expect(tester.takeException(), isNull);
    }
  });
}
