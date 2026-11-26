import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/features/linesonic/linesonic_pid_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved PID steps and presets that cannot be read must not leave the page
/// empty or be overwritten without a copy.
void main() {
  const stepsKey = 'linesonic_steps_v2';
  const presetsKey = 'linesonic_presets_v1';

  Map<String, Object> step({Object kp = '1.5', Object holdMode = 0}) => {
    'mode': 'TIME',
    'kp': kp,
    'kd': '0.8',
    'speed': '50',
    'value': '1000',
    'continueAfter': false,
    'afterMs': '0',
    'afterSpeed': '0',
    'stopBetween': false,
    'stopMs': '0',
    'holdMode': holdMode,
    'holdMs': '150',
    'holdThreshold': '700',
    'lineColor': 0,
    'collapsed': true,
    'showOptions': false,
  };

  setUp(() {
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  Future<void> openPage(WidgetTester tester, Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    // Wide: the default test font is far wider than a real one.
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LineSonicPidPage()));
    await tester.pumpAndSettle();
  }

  /// Step cards show "Step N" in their headers.
  Finder stepCards() => find.textContaining(RegExp(r'^Step \d+'));

  testWidgets('unreadable steps: one new step, a copy kept, a message', (
    tester,
  ) async {
    await openPage(tester, {stepsKey: '{not json'});

    expect(stepCards(), findsOneWidget);
    expect(
      find.text('Saved PID steps could not be read. A copy was kept.'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${stepsKey}_unreadable'), '{not json');
  });

  testWidgets('numbers where text was expected still load', (tester) async {
    await openPage(tester, {
      stepsKey: jsonEncode([step(kp: 1.5, holdMode: '2'), step()]),
    });

    expect(stepCards(), findsNWidgets(2));
    expect(find.textContaining('could not be read'), findsNothing);
  });

  testWidgets('a broken item is skipped, the others load', (tester) async {
    await openPage(tester, {
      stepsKey: jsonEncode([step(), 'broken', 42, step()]),
    });

    expect(stepCards(), findsNWidgets(2));
    expect(find.textContaining('could not be read'), findsNothing);
  });

  testWidgets('unreadable presets do not stop the steps loading', (
    tester,
  ) async {
    await openPage(tester, {
      stepsKey: jsonEncode([step(), step(), step()]),
      presetsKey: 'oops',
    });

    expect(stepCards(), findsNWidgets(3));
    expect(
      find.text('Saved PID presets could not be read. A copy was kept.'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${presetsKey}_unreadable'), 'oops');
  });

  testWidgets('normal saved data loads as before, with no copy', (
    tester,
  ) async {
    await openPage(tester, {
      stepsKey: jsonEncode([step(), step()]),
      presetsKey: jsonEncode([
        {
          'name': 'Track A',
          'steps': [step()],
        },
      ]),
    });

    expect(stepCards(), findsNWidgets(2));
    expect(find.textContaining('could not be read'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${stepsKey}_unreadable'), isNull);
    expect(prefs.getString('${presetsKey}_unreadable'), isNull);
  });
}
