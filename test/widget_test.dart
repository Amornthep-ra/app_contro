import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ui/app_assets.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/control_mode_preference.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/portrait_background.dart';
import 'package:pb_controller/features/bluetooth/bluetooth_ble_page.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:pb_controller/features/gamepad/control_mode_settings_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/linesonic/linesonic_page.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:pb_controller/features/gamepad/widgets/gamepad_edit_shared.dart';
import 'package:pb_controller/core/widgets/gamepad_appbar_controls.dart';
import 'package:pb_controller/core/widgets/gamepad_cat_controls.dart';
import 'package:pb_controller/core/widgets/control_preset_dialog.dart';
import 'package:pb_controller/core/widgets/cat_glass_popup.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(OrientationUtils.resetForTesting);

  testWidgets('Control BLE badge blocks management while a session is active', (
    WidgetTester tester,
  ) async {
    var blocked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusBadge(
            isControlSessionActive: () => true,
            onManagementBlocked: () => blocked++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ConnectionStatusBadge));
    await tester.pump();

    expect(blocked, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Control BLE badge opens its management sheet when idle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusBadge(isControlSessionActive: () => false),
        ),
      ),
    );

    await tester.tap(find.byType(ConnectionStatusBadge));
    await tester.pump();

    expect(find.byType(BottomSheet), findsOneWidget);
  });
  test(
    'Last control mode defaults to 4 BTN and persists the selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ControlModePreference.load(), LastControlMode.fourButton);

      await ControlModePreference.save(LastControlMode.joystick);
      expect(await ControlModePreference.load(), LastControlMode.joystick);
    },
  );

  testWidgets('Portrait background renders the shared portrait template', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PortraitBackground(child: SizedBox.expand())),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppAssets.controlBackgroundPortrait,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Orientation utility restores portrait after Control landscape', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.runAsync(() async {
      await OrientationUtils.setLandscapeOnly();
      await OrientationUtils.setPortraitOnly();
    });

    expect(platformCalls, hasLength(2));
    expect(platformCalls.first.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(platformCalls.last.arguments, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
  });

  testWidgets('Orientation coordinator ignores duplicate requests', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.runAsync(() async {
      await OrientationUtils.request(AppOrientation.landscape);
      await OrientationUtils.request(AppOrientation.landscape);
    });

    expect(platformCalls, hasLength(1));
    expect(platformCalls.single.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('Home page uses the portrait background below its app bar', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.runAsync(
      () => OrientationUtils.request(AppOrientation.portrait),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.extendBodyBehindAppBar, isTrue);
    expect(appBar.backgroundColor, Colors.transparent);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.systemOverlayStyle!.statusBarIconBrightness, Brightness.dark);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppAssets.controlBackgroundPortrait,
      ),
      findsOneWidget,
    );
    final portraitCalls = platformCalls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(portraitCalls, hasLength(1));
    expect(portraitCalls.single.arguments, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
  });

  testWidgets('Home page re-locks portrait after returning from a child page', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    LanguageController.isThai.value = false;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();

    expect(find.byType(Gamepad4ButtonPage), findsOneWidget);
    expect(find.text('Control Modes'), findsNothing);
    Navigator.of(tester.element(find.byType(Gamepad4ButtonPage))).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => OrientationUtils.request(AppOrientation.portrait),
    );

    final portraitCalls = platformCalls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(portraitCalls, hasLength(greaterThanOrEqualTo(2)));
    expect(portraitCalls.last.arguments, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
  });

  testWidgets('Home page opens the saved control mode directly', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = false;
    SharedPreferences.setMockInitialValues({'last_control_mode': 'joystick'});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();

    expect(find.byType(JoystickPage), findsOneWidget);
    expect(find.text('Control Modes'), findsNothing);
  });

  testWidgets('Home page uses light status icons in dark theme', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const HomePage()),
    );
    await tester.pump();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(
      appBar.systemOverlayStyle!.statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets(
    'Home page is English-only and removes language and theme controls',
    (WidgetTester tester) async {
      LanguageController.isThai.value = false;
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      PackageInfo.setMockInitialValues(
        appName: 'PB Controller',
        packageName: 'com.example.pb_controller',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();

      expect(find.text('EN'), findsNothing);
      expect(find.text('TH'), findsNothing);
      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/icons/HomeUnified/Theme-Palette.png',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Home page keeps Contact compact and discoverable across layouts',
    (WidgetTester tester) async {
      LanguageController.isThai.value = false;
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'PB Controller',
        packageName: 'com.example.pb_controller',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in <Size>[const Size(360, 640), const Size(800, 400)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: HomePage(),
            ),
          ),
        );
        await tester.pump();

        final contact = find.byKey(const ValueKey('home-contact-action'));
        expect(contact, findsOneWidget);
        expect(
          find.descendant(
            of: contact,
            matching: find.text('Follow us on Facebook'),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(contact).height, lessThan(104));

        final semantics = tester.getSemantics(contact);
        expect(semantics.label, contains('Contact'));
        expect(semantics.label, contains('Follow us on Facebook'));
        expect(semantics.flagsCollection.isButton, isTrue);
      }
    },
  );

  testWidgets('Home page keeps Scan devices as the BLE navigation action', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = false;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PB Controller',
      packageName: 'com.example.pb_controller',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          blePageBuilder: (_) =>
              const BluetoothBlePage(enableBlePlatformBindings: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Scan devices'), findsOneWidget);
    await tester.tap(find.text('Scan devices'));
    await tester.pumpAndSettle();
    expect(find.text('BLE Connection'), findsOneWidget);
    expect(find.text('Discovered devices'), findsOneWidget);
    final backImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppAssets.controlBack,
      ),
    );
    expect(backImage.width, 40);
    expect(backImage.height, 40);
  });

  testWidgets('LineSonic uses Cat Glass navigation and the shared back asset', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => LineSonicPage(
                    blePageBuilder: (_) => const BluetoothBlePage(
                      enableBlePlatformBindings: false,
                    ),
                  ),
                ),
              ),
              child: const Text('Open LineSonic'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open LineSonic'));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.systemOverlayStyle!.statusBarIconBrightness, Brightness.dark);
    final backImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppAssets.controlBack,
      ),
    );
    expect(backImage.width, 40);
    expect(backImage.height, 40);

    await tester.tap(find.text('PID Tuning'));
    await tester.pumpAndSettle();
    expect(find.text('PID Tuning'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read Sensor'));
    await tester.pumpAndSettle();
    expect(find.text('Read Sensor'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open BLE connection'));
    await tester.pumpAndSettle();
    expect(find.text('BLE Connection'), findsOneWidget);
  });

  test(
    'BLE device name prefers the active connection and has safe fallbacks',
    () {
      expect(
        resolveBleConnectedDeviceName(
          currentName: 'PrinceBot',
          currentId: 'AA:BB',
          lastDeviceName: 'Old bot',
        ),
        'PrinceBot',
      );
      expect(
        resolveBleConnectedDeviceName(
          currentId: 'AA:BB',
          lastDeviceName: 'Old bot',
        ),
        'AA:BB',
      );
      expect(
        resolveBleConnectedDeviceName(lastDeviceName: 'Old bot'),
        'Old bot',
      );
      expect(resolveBleConnectedDeviceName(), 'Unknown');
      expect(
        isCurrentBleDeviceId(
          candidateDeviceId: 'AA:BB',
          currentDeviceId: 'AA:BB',
        ),
        isTrue,
      );
      expect(
        isCurrentBleDeviceId(
          candidateDeviceId: 'CC:DD',
          currentDeviceId: 'AA:BB',
        ),
        isFalse,
      );
    },
  );

  test('Control settings route closes without a reverse animation', () {
    final route = controlModeSettingsRoute(
      mode: ControlMode.fourButton,
      onManageLayouts: () async {},
    );

    expect(route.transitionDuration, const Duration(milliseconds: 160));
    expect(route.reverseTransitionDuration, Duration.zero);
  });
  testWidgets('Control settings opens edit layout and returns mode actions', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = false;
    ControlModeSettingsAction? selectedAction;
    var presetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedAction = await Navigator.of(context)
                    .push<ControlModeSettingsAction>(
                      controlModeSettingsRoute(
                        mode: ControlMode.fourButton,
                        onManageLayouts: () async {
                          presetCalls++;
                          await showModalBottomSheet<void>(
                            context: context,
                            builder: (sheetContext) => TextButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Close presets'),
                            ),
                          );
                        },
                      ),
                    );
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Control mode'), findsOneWidget);
    expect(find.text('4 BTN'), findsOneWidget);
    expect(find.text('8 BTN'), findsOneWidget);
    expect(find.text('Joystick'), findsOneWidget);
    expect(find.text('Edit layout'), findsOneWidget);
    expect(find.text('Saved layouts'), findsOneWidget);

    await tester.tap(find.text('Edit layout'));
    await tester.pumpAndSettle();

    expect(selectedAction, ControlModeSettingsAction.editLayout);
    expect(find.text('Settings'), findsNothing);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved layouts'));
    await tester.pumpAndSettle();

    expect(presetCalls, 1);
    expect(selectedAction, ControlModeSettingsAction.editLayout);
    expect(find.text('Close presets'), findsOneWidget);

    await tester.tap(find.text('Close presets'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^4 BTN, selected')), findsOneWidget);

    await tester.tap(find.text('8 BTN'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(selectedAction, ControlModeSettingsAction.editLayout);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(selectedAction, ControlModeSettingsAction.selectEightButton);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joystick'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(selectedAction, ControlModeSettingsAction.selectEightButton);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(selectedAction, ControlModeSettingsAction.selectJoystick);
  });

  testWidgets('Start control uses a fixed-size action with loading state', (
    WidgetTester tester,
  ) async {
    LanguageController.isThai.value = false;
    var startCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamepadStartStopControlButton(
            isStarted: false,
            onPressed: () => startCalls++,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Start control'), findsOneWidget);
    expect(
      tester.getSize(find.byType(GamepadStartStopControlButton)),
      const Size(48, 48),
    );
    await tester.tap(find.byType(GamepadStartStopControlButton));
    expect(startCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const GamepadStartStopControlButton(
            isStarted: false,
            isBusy: true,
            onPressed: null,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Starting control'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var emergencyStopCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamepadStartStopControlButton(
            isStarted: true,
            onPressed: () => emergencyStopCalls++,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Emergency Stop'), findsOneWidget);
    // The Stop artwork alone: no red glow or halo behind it any more.
    final stopImage = tester.widget<Image>(
      find.descendant(
        of: find.byType(GamepadStartStopControlButton),
        matching: find.byType(Image),
      ),
    );
    expect((stopImage.image as AssetImage).assetName, AppAssets.controlStop);
    expect(
      find.descendant(
        of: find.byType(GamepadStartStopControlButton),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
    expect(BleManager.emergencyStopRepeats, 3);

    await tester.tap(find.byType(GamepadStartStopControlButton));
    expect(emergencyStopCalls, 1);
  });

  testWidgets('Cat speed choice shows labels and selected state', (
    WidgetTester tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            GamepadCatChoiceTile(
              asset: 'missing-low.png',
              label: 'Lo',
              accent: Colors.green,
              selected: false,
              onTap: () => selected = 'Lo',
            ),
            GamepadCatChoiceTile(
              asset: 'missing-med.png',
              label: 'Med',
              accent: Colors.yellow,
              selected: true,
              onTap: () => selected = 'Med',
            ),
            GamepadCatChoiceTile(
              asset: 'missing-hi.png',
              label: 'Hi',
              accent: Colors.red,
              selected: false,
              onTap: () => selected = 'Hi',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lo'), findsOneWidget);
    expect(find.text('Med'), findsOneWidget);
    expect(find.text('Hi'), findsOneWidget);
    expect(find.byIcon(Icons.speed_rounded), findsNWidgets(3));
    await tester.tap(find.text('Hi'));
    expect(selected, 'Hi');
  });

  testWidgets('Control preset dialog updates slots and closes after load', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var loadCalls = 0;
    var clearCalls = 0;
    final slots = <ControlPresetSlot>[
      const ControlPresetSlot(slot: 1, name: 'Preset 1', hasData: false),
      const ControlPresetSlot(slot: 2, name: 'Preset 2', hasData: false),
      const ControlPresetSlot(slot: 3, name: 'Preset 3', hasData: false),
      const ControlPresetSlot(slot: 4, name: 'Preset 4', hasData: false),
      const ControlPresetSlot(slot: 5, name: 'Preset 5', hasData: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showControlPresetDialog(
                context: context,
                isThai: false,
                slots: slots,
                onSave: (slot) => ControlPresetSlot(
                  slot: slot.slot,
                  name: 'Cruise',
                  hasData: true,
                ),
                onLoad: (_) => loadCalls++,
                onClear: (slot) {
                  clearCalls++;
                  return ControlPresetSlot(
                    slot: slot.slot,
                    name: 'Preset ${slot.slot}',
                    hasData: false,
                  );
                },
              ),
              child: const Text('Open presets'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open presets'));
    await tester.pumpAndSettle();
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('Empty'), findsNWidgets(4));

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(find.text('Cruise'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);
    expect(find.text('Empty'), findsNWidgets(4));

    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();
    expect(loadCalls, 1);
    expect(find.text('Presets'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1024, 600));
    await tester.tap(find.text('Open presets'));
    await tester.pumpAndSettle();
    expect(find.text('Preset 1'), findsOneWidget);
    expect(find.text('Preset 2'), findsOneWidget);
    expect(find.text('Preset 3'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Preset 5'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Preset 4'), findsOneWidget);
    expect(find.text('Preset 5'), findsOneWidget);
  });

  testWidgets('Cat preset name dialog validates and returns the saved name', (
    WidgetTester tester,
  ) async {
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                savedName = await showCatPresetNameDialog(
                  context: context,
                  isThai: false,
                  currentName: 'Preset 1',
                  validator: (value) =>
                      value.trim().isEmpty ? 'Required' : null,
                );
              },
              child: const Text('Rename'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Preset'), findsOneWidget);
    expect(find.byType(CatGlassModalSurface), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cruise');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(savedName, 'Cruise');
  });

  testWidgets(
    'Gamepad notices use semantic icons and replace the active notice',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.expand(key: Key('notice-host'))),
        ),
      );
      final context = tester.element(find.byKey(const Key('notice-host')));
      showGamepadTopNotice(
        context,
        message: 'Connection failed',
        style: GamepadNoticeStyle.error,
      );
      await tester.pump();
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      showGamepadTopNotice(
        context,
        message: 'Copied',
        style: GamepadNoticeStyle.success,
      );
      await tester.pump();
      expect(find.text('Connection failed'), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('Edit selection visual uses alpha glow and circular fallback', (
    WidgetTester tester,
  ) async {
    Widget subject({
      required bool selected,
      required bool dimmed,
      required bool warning,
      required bool withMask,
    }) {
      return MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 100,
            child: GamepadEditSelectionVisual(
              selected: selected,
              dimmed: dimmed,
              warning: warning,
              selectionMask: withMask
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: FlutterLogo(),
                    )
                  : null,
              child: const ColoredBox(color: Colors.purple),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      subject(selected: true, dimmed: false, warning: false, withMask: true),
    );

    final visual = find.byType(GamepadEditSelectionVisual);
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(of: visual, matching: find.byType(AnimatedOpacity)),
    );
    final scale = tester.widget<AnimatedScale>(
      find.descendant(of: visual, matching: find.byType(AnimatedScale)),
    );
    final layers = tester
        .widgetList<GamepadEditAlphaGlowLayer>(
          find.byType(GamepadEditAlphaGlowLayer),
        )
        .toList();

    expect(opacity.opacity, 1);
    expect(scale.scale, GamepadEditSelectionVisual.selectedScale);
    expect(layers, hasLength(2));
    expect(find.byKey(GamepadEditSelectionVisual.haloKey), findsNothing);
    expect(layers[0].color, GamepadEditSelectionVisual.selectionColor);
    expect(layers[0].blurSigma, GamepadEditSelectionVisual.outerGlowBlur);
    expect(layers[0].opacity, GamepadEditSelectionVisual.outerGlowOpacity);
    expect(layers[1].color, GamepadEditSelectionVisual.selectionColor);
    expect(layers[1].blurSigma, GamepadEditSelectionVisual.innerGlowBlur);
    expect(layers[1].opacity, GamepadEditSelectionVisual.innerGlowOpacity);

    await tester.pumpWidget(
      subject(selected: false, dimmed: true, warning: false, withMask: true),
    );
    final dimmedOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(of: visual, matching: find.byType(AnimatedOpacity)),
    );
    expect(dimmedOpacity.opacity, GamepadEditSelectionVisual.dimmedOpacity);

    await tester.pumpWidget(
      subject(selected: true, dimmed: false, warning: true, withMask: true),
    );
    await tester.pumpAndSettle();
    final warningLayers = tester
        .widgetList<GamepadEditAlphaGlowLayer>(
          find.byType(GamepadEditAlphaGlowLayer),
        )
        .toList();
    expect(warningLayers, hasLength(2));
    expect(
      warningLayers.every(
        (layer) => layer.color == GamepadEditSelectionVisual.warningColor,
      ),
      isTrue,
    );

    await tester.pumpWidget(
      subject(selected: true, dimmed: false, warning: false, withMask: false),
    );
    await tester.pumpAndSettle();
    final haloFinder = find.byKey(GamepadEditSelectionVisual.haloKey);
    final halo = tester.widget<AnimatedContainer>(haloFinder);
    final decoration = halo.decoration! as BoxDecoration;
    expect(find.byType(GamepadEditAlphaGlowLayer), findsNothing);
    expect(tester.getSize(haloFinder), const Size.square(100));
    expect(
      decoration.border!.top.color,
      GamepadEditSelectionVisual.selectionColor,
    );
  });

  test('Edit lock labels remain English for the legacy language flag', () {
    expect(gamepadEditLockLabel(isThai: false, locked: false), 'Lock');
    expect(gamepadEditLockLabel(isThai: false, locked: true), 'Unlock');
    expect(gamepadEditLockLabel(isThai: true, locked: false), 'Lock');
    expect(gamepadEditLockLabel(isThai: true, locked: true), 'Unlock');
  });
}
