import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/ui/lavender_glass.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/features/linesonic/linesonic_page.dart';
import 'package:pb_controller/features/linesonic/linesonic_pid_page.dart';
import 'package:pb_controller/features/linesonic/linesonic_sensor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadRoboto() async {
  // Real glyph widths so header / segment fitting matches a phone.
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

Map<String, Object?> _step({
  String mode = '',
  String kp = '0',
  String kd = '0',
  String speed = '0',
  bool collapsed = false,
  int holdMode = 0,
}) => {
  'mode': mode,
  'kp': kp,
  'kd': kd,
  'speed': speed,
  'value': '0',
  'continueAfter': false,
  'afterMs': '0',
  'afterSpeed': '0',
  'stopBetween': false,
  'stopMs': '0',
  'holdMode': holdMode,
  'holdMs': '0',
  'holdThreshold': '0',
  'lineColor': 0,
  'collapsed': collapsed,
  'showOptions': mode.isNotEmpty,
};

const _phone = Size(411, 914);
const _small = Size(360, 640);

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    LanguageController.isThai.value = false;
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    Size size = _phone,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Under 48 px on either side, measured on the hit-testable box.
  List<String> smallTargets(WidgetTester tester, Finder finder, String kind) {
    final failures = <String>[];
    for (final element in finder.evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (!box.attached || !box.hasSize) continue;
      final size = box.size;
      if (size.width < 47.5 || size.height < 47.5) {
        failures.add('$kind ${size.width}x${size.height}');
      }
    }
    return failures;
  }

  group('header', () {
    for (final (name, page, title) in [
      ('hub', const LineSonicPage(), 'LineSonic'),
      ('PID', const LineSonicPidPage(), 'PID Tuning'),
      ('Sensor', const LineSonicSensorPage(), 'Read Sensor'),
    ]) {
      testWidgets('$name: cat Back, shared badge, title fits at 360 / 1.3', (
        tester,
      ) async {
        await open(tester, page, size: _small, textScale: 1.3);

        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.byType(ConnectionStatusBadge), findsOneWidget);
        expect(find.text('BLE Off'), findsNothing);
        expect(find.byType(FrostedBarBackground), findsOneWidget);

        // The title is scaled down to fit, never cut to "PID …".
        final titleRect = tester.getRect(find.text(title));
        final backRect = tester.getRect(find.byTooltip('Back'));
        final badgeRect = tester.getRect(find.byType(ConnectionStatusBadge));
        expect(titleRect.left, greaterThanOrEqualTo(backRect.right));
        expect(titleRect.right, lessThanOrEqualTo(badgeRect.left));
        final text = tester.widget<Text>(find.text(title));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets('frosted strip appears once content scrolls under it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'linesonic_steps_v2': jsonEncode([_step(mode: 'TIME'), _step()]),
      });
      await open(tester, const LineSonicPidPage());
      FrostedBarBackground strip() => tester.widget<FrostedBarBackground>(
        find.byType(FrostedBarBackground),
      );
      expect(strip().visible, isFalse);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await settle(tester);
      expect(strip().visible, isTrue);
      await close(tester);
    });
  });

  testWidgets('hub tiles open PID Tuning and Read Sensor', (tester) async {
    await open(tester, const LineSonicPage());
    expect(find.byType(GlassPanel), findsNWidgets(2));

    await tester.tap(find.text('PID Tuning'));
    await settle(tester);
    expect(find.byType(LineSonicPidPage), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await tester.tap(find.text('Read Sensor'));
    await settle(tester);
    expect(find.byType(LineSonicSensorPage), findsOneWidget);
    await close(tester);
  });

  group('PID Tuning', () {
    testWidgets('step card fill stops at the card (no edge-to-edge band)', (
      tester,
    ) async {
      await open(tester, const LineSonicPidPage());
      final card = find.ancestor(
        of: find.text('Step 1'),
        matching: find.byType(GlassPanel),
      );
      final rect = tester.getRect(card);
      expect(rect.left, 16);
      expect(rect.right, _phone.width - 16);
      // Nothing in the list paints a coloured Material wider than the card.
      for (final element
          in find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Material),
              )
              .evaluate()) {
        final material = element.widget as Material;
        if (material.type == MaterialType.transparency) continue;
        final color = material.color;
        if (color == null || color.a == 0) continue;
        final box = element.renderObject! as RenderBox;
        expect(box.size.width, lessThan(_phone.width - 31));
      }
      await close(tester);
    });

    for (final (label, size, scale) in [
      ('411', _phone, 1.0),
      ('360 / 1.3', _small, 1.3),
    ]) {
      testWidgets('controls are at least 48 px ($label)', (tester) async {
        SharedPreferences.setMockInitialValues({
          'linesonic_steps_v2': jsonEncode([
            _step(mode: 'TIME', holdMode: 1),
            _step(mode: 'CHECKSUM', collapsed: true),
          ]),
        });
        await open(
          tester,
          const LineSonicPidPage(),
          size: size,
          textScale: scale,
        );
        final failures = <String>[
          ...smallTargets(tester, find.byType(IconButton), 'IconButton'),
          ...smallTargets(
            tester,
            find.descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(TextField),
            ),
            'TextField',
          ),
          ...smallTargets(
            tester,
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.label?.startsWith('Speed ') ?? false),
            ),
            'Speed chip',
          ),
        ];
        // Segments: 42 px pill inside a 3 px glass rim -> 48 px row.
        for (final element
            in find
                .ancestor(of: find.text('Black'), matching: find.byType(Row))
                .evaluate()) {
          final box = element.renderObject! as RenderBox;
          if (box.size.height < 42) failures.add('segment ${box.size}');
        }
        for (final element in find.byType(Switch).evaluate()) {
          final row = find.ancestor(
            of: find.byWidget(element.widget),
            matching: find.byType(InkWell),
          );
          final box = row.evaluate().first.renderObject! as RenderBox;
          if (box.size.height < 47.5) failures.add('switch row ${box.size}');
        }
        expect(failures, isEmpty);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Junction hold'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets('step colours follow the mode', (tester) async {
      SharedPreferences.setMockInitialValues({
        'linesonic_steps_v2': jsonEncode([
          _step(mode: 'TIME', collapsed: true),
          _step(mode: 'CHECKSUM', collapsed: true),
          _step(collapsed: true),
        ]),
      });
      await open(tester, const LineSonicPidPage());
      Color? tint(String text) => tester
          .widget<GlassPanel>(
            find.ancestor(
              of: find.text(text),
              matching: find.byType(GlassPanel),
            ),
          )
          .tint;
      expect(tint('Step 1 (Time)'), LavenderPalette.violetBright);
      expect(tint('Step 2 (CheckSum)'), LavenderPalette.cyan);
      expect(tint('Step 3'), LavenderPalette.inkMuted);
      await close(tester);
    });

    testWidgets('⋯ menu duplicates; Delete can be undone', (tester) async {
      SharedPreferences.setMockInitialValues({
        'linesonic_steps_v2': jsonEncode([
          _step(mode: 'TIME', kp: '1.5', collapsed: true),
          _step(kp: '2.5', collapsed: true),
        ]),
      });
      await open(tester, const LineSonicPidPage());

      await tester.tap(find.byTooltip('More').first);
      await settle(tester);
      await tester.tap(find.text('Duplicate'));
      await settle(tester);
      // The copy is inserted right after the original, with its values.
      expect(find.text('Step 1 (Time)'), findsOneWidget);
      expect(find.text('Step 2 (Time)'), findsOneWidget);
      expect(find.text('1.5'), findsNWidgets(2));

      await tester.tap(find.byTooltip('More').first);
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Step 1 deleted'), findsOneWidget);
      expect(find.text('Step 2 (Time)'), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Step 1 (Time)'), findsOneWidget);
      expect(find.text('Step 2 (Time)'), findsOneWidget);
      expect(find.text('1.5'), findsNWidgets(2));
      await close(tester);
    });

    testWidgets('Load preset asks before replacing the steps', (tester) async {
      SharedPreferences.setMockInitialValues({
        'linesonic_steps_v2': jsonEncode([_step(kp: '9', collapsed: true)]),
        'linesonic_presets_v1': jsonEncode([
          {
            'name': 'Track A',
            'steps': [_step(mode: 'TIME', kp: '4', collapsed: true)],
          },
        ]),
      });
      await open(tester, const LineSonicPidPage());

      await tester.tap(find.byTooltip('Load preset'));
      await settle(tester);
      expect(find.text('Load "Track A"?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('9'), findsOneWidget);

      await tester.tap(find.byTooltip('Load preset'));
      await settle(tester);
      await tester.tap(find.text('Load'));
      await settle(tester);
      expect(find.text('9'), findsNothing);
      expect(find.text('Step 1 (Time)'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Save over a saved preset and Delete preset ask first', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'linesonic_presets_v1': jsonEncode([
          {
            'name': 'Track A',
            'steps': [_step(mode: 'TIME')],
          },
        ]),
      });
      await open(tester, const LineSonicPidPage());

      await tester.tap(find.byTooltip('Save preset'));
      await settle(tester);
      expect(find.text('Save preset'), findsWidgets);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Replace "Track A"?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      await tester.tap(find.byTooltip('Choose preset'));
      await settle(tester);
      expect(find.text('1 step'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('Delete "Track A"?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Track A'), findsWidgets);
      await close(tester);
    });

    testWidgets('bottom action bar hides while the keyboard is up', (
      tester,
    ) async {
      await open(tester, const LineSonicPidPage());
      for (final label in ['Send PD+Speed', 'Send All', 'SW1', 'Reset Board']) {
        expect(find.text(label), findsOneWidget);
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThan(_phone.height));
      }
      expect(find.text('Add Step'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await settle(tester);
      expect(find.text('Send All'), findsNothing);
      tester.view.resetViewInsets();
      await settle(tester);
      expect(find.text('Send All'), findsOneWidget);
      await close(tester);
    });
  });

  group('Read Sensor', () {
    testWidgets('values show as tiles with SUM; Read (force) is in the log', (
      tester,
    ) async {
      await open(
        tester,
        const LineSonicSensorPage(
          debugReceivedLines: ['SENS=812,1934,3011,SUM=5757'],
        ),
      );
      expect(find.text('S1'), findsOneWidget);
      expect(find.text('1934'), findsOneWidget);
      expect(find.text('S3'), findsOneWidget);
      expect(find.text('SUM'), findsOneWidget);
      expect(find.text('5757'), findsOneWidget);
      expect(find.text('No data yet'), findsNothing);

      final logPanel = find.ancestor(
        of: find.text('TX / RX'),
        matching: find.byType(GlassPanel),
      );
      expect(
        find.descendant(of: logPanel, matching: find.text('Read (force)')),
        findsOneWidget,
      );
      expect(find.textContaining('RX: SENS=812'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('No logs yet'), findsOneWidget);
      await close(tester);
    });

    testWidgets('interval segments and buttons are 48 px', (tester) async {
      await open(tester, const LineSonicSensorPage(), size: _small);
      await tester.tap(find.text('500'));
      await settle(tester);
      final failures = <String>[
        ...smallTargets(tester, find.byType(TextButton), 'TextButton'),
      ];
      for (final label in ['Read Now', 'Auto Off']) {
        final box = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        if (box.height < 47.5) failures.add('$label $box');
      }
      final segment = tester.getSize(
        find.ancestor(of: find.text('500'), matching: find.byType(InkWell)),
      );
      if (segment.height < 42) failures.add('segment $segment');
      expect(failures, isEmpty);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await close(tester);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
