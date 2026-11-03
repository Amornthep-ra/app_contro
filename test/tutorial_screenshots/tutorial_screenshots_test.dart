// Renders tutorial screenshots of states that need a robot (robots found,
// pairing, connected, buttons held, link lost, Bluetooth off) without a
// device or emulator. BLE is simulated; nothing here ships in the app.
//
// Run:
//   flutter test test/tutorial_screenshots/tutorial_screenshots_test.dart \
//     --dart-define=SHOT_DIR=<output folder>
//
// Output is Pixel 9 size (1080 x 2424 px, 2.625 dpr), English UI.
// Skipped in a normal `flutter test` run (no SHOT_DIR).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/core/widgets/control_start_stop.dart';
import 'package:pb_controller/features/bluetooth/bluetooth_ble_page.dart';
import 'package:pb_controller/features/bluetooth/widgets/pairing_code_dialog.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:pb_controller/features/joystick/joystick/joystick_view.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:pb_controller/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outDir = String.fromEnvironment('SHOT_DIR');
const _dpr = 2.625;
const _portrait = Size(1080, 2424);
const _landscape = Size(2424, 1080);

// Pixel 9 system bar insets in logical pixels (status bar, gesture bar,
// camera cutout on the left in landscape).
const _portraitInsets = EdgeInsets.fromLTRB(0, 52, 0, 24);
const _landscapeInsets = EdgeInsets.fromLTRB(52, 52, 0, 24);

// ---------------------------------------------------------------------------
// Simulated BLE
// ---------------------------------------------------------------------------

final class _FakeBluetooth extends FlutterBluePlusPlatform {
  final adapter = StreamController<BmBluetoothAdapterState>.broadcast();

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged => adapter.stream;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async => BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on);
}

class _NoopPlatform implements BleConnectionPlatform {
  @override
  Stream<List<ScanResult>> get scanResults => const Stream.empty();
  @override
  Future<void> connect(ScanResult result) async {}
  @override
  Future<void> disconnect(ScanResult result) async {}
  @override
  Future<void> startScan({required Duration timeout}) async {}
  @override
  Future<void> stopScan() async {}
}

/// Coordinator whose connect never finishes, to hold the "Connecting…" row.
class _PendingCoordinator extends BleConnectionCoordinator {
  _PendingCoordinator()
    : super(
        platform: _NoopPlatform(),
        listenToManagerAutoConnectRequests: false,
      );

  final pending = Completer<void>();

  @override
  Future<void> connect(
    ScanResult result, {
    String source = 'ble_coordinator',
    bool preserveAutoConnect = false,
    int? owner,
    bool userInitiated = true,
  }) => pending.future;
}

ScanResult _robot(String id, String name, int rssi) => ScanResult(
  device: BluetoothDevice.fromId(id),
  advertisementData: AdvertisementData(
    advName: name,
    txPowerLevel: null,
    appearance: null,
    connectable: true,
    manufacturerData: const {},
    serviceData: const {},
    serviceUuids: const [],
  ),
  rssi: rssi,
  timeStamp: DateTime(2026),
);

const _lastId = 'C8:2E:18:4A:9F:01';
const _lastName = 'PB-Robot-01';
final _robots = [
  _robot(_lastId, _lastName, -52),
  _robot('C8:2E:18:4A:9F:02', 'PB-Robot-02', -67),
  _robot('C8:2E:18:4A:9F:03', 'LineSonic-A', -81),
];

const _connectedState = BleConnectionCoordinatorState(
  securityState: BleControlSecurityState.ready,
  lastDeviceId: _lastId,
  lastDeviceName: _lastName,
);

void _present(
  BleConnectionStatus status, {
  bool? connected,
  BleConnectionCoordinatorState state = const BleConnectionCoordinatorState(),
}) {
  BleManager.instance.debugPresentConnectionForTesting(
    status: status,
    connected: connected,
    deviceName: _lastName,
  );
  BleConnectionCoordinator.instance.debugEmitForTesting(state);
}

// ---------------------------------------------------------------------------
// Rendering helpers
// ---------------------------------------------------------------------------

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(
        Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
      );
    }
    await loader.load();
  }

  await load('Roboto', [
    'assets/fonts/Roboto/static/Roboto-Regular.ttf',
    'assets/fonts/Roboto/static/Roboto-Bold.ttf',
    'assets/fonts/Roboto/static/Roboto-Italic.ttf',
    'assets/fonts/Roboto/static/Roboto-BoldItalic.ttf',
  ]);
  await load('Kanit', [
    'assets/fonts/Kanit/Kanit-Regular.ttf',
    'assets/fonts/Kanit/Kanit-Bold.ttf',
  ]);

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons =
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'materialicons-regular.otf';
    if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
  }
  // Android renders 'monospace' with its system mono font.
  for (final mono in [
    r'C:\Windows\Fonts\consola.ttf',
    '/System/Library/Fonts/Menlo.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
  ]) {
    if (File(mono).existsSync()) {
      await load('monospace', [mono]);
      break;
    }
  }
}

final _boundary = GlobalKey();

Future<void> _loadImages(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(() async {
      final pending = <Future<void>>[];
      for (final element in find.byType(Image).evaluate()) {
        final image = (element.widget as Image).image;
        pending.add(precacheImage(image, element));
      }
      for (final element in find.byType(DecoratedBox).evaluate()) {
        final decoration = (element.widget as DecoratedBox).decoration;
        if (decoration is BoxDecoration && decoration.image != null) {
          pending.add(precacheImage(decoration.image!.image, element));
        }
      }
      await Future.wait(pending);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }
}

/// Steps time forward without pumpAndSettle (spinners never settle).
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

var _subdir = 'simulated';

Future<void> _shot(WidgetTester tester, String name) async {
  await _loadImages(tester);
  await tester.pump(const Duration(milliseconds: 16));
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory('$_outDir/$_subdir')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _mountApp(WidgetTester tester, {required bool landscape}) async {
  final insets = landscape ? _landscapeInsets : _portraitInsets;
  tester.view.physicalSize = landscape ? _landscape : _portrait;
  tester.view.devicePixelRatio = _dpr;
  final padding = FakeViewPadding(
    left: insets.left * _dpr,
    top: insets.top * _dpr,
    right: insets.right * _dpr,
    bottom: insets.bottom * _dpr,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(key: _boundary, child: const MyApp()),
  );
  await _settle(tester);
}

Future<void> _open(WidgetTester tester, Widget page) async {
  final context = tester.element(find.byType(HomePage));
  unawaited(
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
  await _settle(tester, frames: 10);
}

Future<void> _unmount(WidgetTester tester) async {
  _present(BleConnectionStatus.disconnected);
  // Opening the sheet starts a scan; end it so its timer stops.
  unawaited(BleConnectionCoordinator.instance.stopScan());
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(ConnectionStatusBadge).first);
  await _settle(tester);
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.byType(ControlStartStopButton));
  await _settle(tester, frames: 6);
}

/// Hold buttons are the round pad controls; pick by position.
List<Rect> _padButtons(WidgetTester tester) {
  final rects =
      find
          .byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'GamepadImageHoldButton',
          )
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList()
        ..sort((a, b) => a.left.compareTo(b.left));
  return rects;
}

Rect _topMost(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.top <= b.top ? a : b);

Rect _rightMost(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.left >= b.left ? a : b);

// ---------------------------------------------------------------------------

void main() {
  final fakeBluetooth = _FakeBluetooth();

  setUpAll(() async {
    await _loadFonts();
    FlutterBluePlusPlatform.instance = fakeBluetooth;
    // Pad buttons give haptic feedback; there is no motor under test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('vibration'),
          (_) async => null,
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageController.isThai.value = false;
    OrientationUtils.resetForTesting();
    _present(BleConnectionStatus.disconnected);
  });

  tearDown(() {
    _present(BleConnectionStatus.disconnected);
  });

  group('tutorial screenshots', skip: _outDir.isEmpty, () {
    // ----------------------------------------------------------- portrait
    testWidgets('01 home connected', (tester) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: _connectedState,
      );
      await _mountApp(tester, landscape: false);
      await _shot(tester, '01_home_connected');
      await _unmount(tester);
    });

    testWidgets('02-03 BLE page: robots found, then connecting', (
      tester,
    ) async {
      final coordinator = _PendingCoordinator();
      coordinator.debugEmitForTesting(
        BleConnectionCoordinatorState(
          devices: _robots,
          lastDeviceId: _lastId,
          lastDeviceName: _lastName,
        ),
      );
      await _mountApp(tester, landscape: false);
      await _open(
        tester,
        BluetoothBlePage(
          coordinator: coordinator,
          isBleConnected: () => false,
          enableBlePlatformBindings: false,
          pairingPromptLauncher:
              ({required context, required isThai, coordinator}) async => null,
        ),
      );
      await _shot(tester, '02_ble_page_robots_found');

      await tester.tap(find.text(_lastName).last);
      await _settle(tester, frames: 4);
      await _shot(tester, '03_ble_page_connecting');

      coordinator.pending.complete();
      await _unmount(tester);
      await coordinator.dispose();
    });

    testWidgets('04 BLE page connected', (tester) async {
      final coordinator = _PendingCoordinator();
      coordinator.debugEmitForTesting(_connectedState);
      _present(BleConnectionStatus.connected, connected: true);
      await _mountApp(tester, landscape: false);
      await _open(
        tester,
        BluetoothBlePage(
          coordinator: coordinator,
          isBleConnected: () => true,
          enableBlePlatformBindings: false,
          pairingPromptLauncher:
              ({required context, required isThai, coordinator}) async => null,
        ),
      );
      await _shot(tester, '04_ble_page_connected');
      await _unmount(tester);
      await coordinator.dispose();
    });

    // ---------------------------------------------------------- landscape
    testWidgets('05-06 sheet: robots found, connecting', (tester) async {
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      // The sheet scans on open; show the result that scan would bring.
      await _openSheet(tester);
      unawaited(BleConnectionCoordinator.instance.stopScan());
      await tester.pump();
      BleConnectionCoordinator.instance.debugEmitForTesting(
        BleConnectionCoordinatorState(
          devices: _robots,
          lastDeviceId: _lastId,
          lastDeviceName: _lastName,
        ),
      );
      await _settle(tester, frames: 4);
      await _shot(tester, '05_sheet_robots_found');

      _present(
        BleConnectionStatus.connecting,
        state: BleConnectionCoordinatorState(
          connecting: true,
          devices: _robots,
          lastDeviceId: _lastId,
          lastDeviceName: _lastName,
        ),
      );
      await _settle(tester, frames: 4);
      await _shot(tester, '06_sheet_connecting');
      await _unmount(tester);
    });

    testWidgets('07-09 pair code: empty, too short, wrong code', (
      tester,
    ) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: const BleConnectionCoordinatorState(
          securityState: BleControlSecurityState.pairingRequired,
          lastDeviceId: _lastId,
          lastDeviceName: _lastName,
        ),
      );
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      final context = tester.element(find.byType(Gamepad4ButtonPage));
      unawaited(
        showDialog<Object?>(
          context: context,
          builder: (_) => PairingCodeDialog(
            isThai: false,
            onPair: (_) async => const BlePairingAttemptResult(
              ready: false,
              failure: BlePairingFailure.codeRejected,
            ),
          ),
        ),
      );
      await _settle(tester, frames: 6);
      await _shot(tester, '07_pair_code');

      Finder inDialog(Finder f) =>
          find.descendant(of: find.byType(PairingCodeDialog), matching: f);
      final field = inDialog(find.byType(TextField)).hitTestable().first;
      final pair = inDialog(find.text('Pair')).hitTestable().first;
      await tester.enterText(field, 'PB01');
      await tester.pump();
      await _settle(tester, frames: 4);
      await _shot(tester, '08_pair_code_too_short');

      await tester.enterText(field, 'PBROBOT99');
      await tester.pump();
      await tester.tap(pair);
      await _settle(tester, frames: 4);

      await _shot(tester, '09_pair_code_wrong');
      await _unmount(tester);
    });

    testWidgets('10 sheet connected', (tester) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: _connectedState,
      );
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      await _openSheet(tester);
      await _shot(tester, '10_sheet_connected');
      await _unmount(tester);
    });

    testWidgets('11-14 4 BTN: connected, Start, buttons change CMD', (
      tester,
    ) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: _connectedState,
      );
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      await _shot(tester, '11_4btn_connected');

      await _start(tester);
      await _shot(tester, '12_4btn_started');

      final buttons = _padButtons(tester);
      final leftPair = buttons.take(2);
      final up = _topMost(leftPair);
      final right = _rightMost(buttons);
      final upHold = await tester.startGesture(up.center, pointer: 1);
      await _settle(tester, frames: 3);
      await _shot(tester, '13_4btn_forward_held');

      final rightHold = await tester.startGesture(right.center, pointer: 2);
      await _settle(tester, frames: 3);
      await _shot(tester, '14_4btn_forward_right_held');

      await upHold.up();
      await rightHold.up();
      await _settle(tester, frames: 3);
      await _unmount(tester);
    });

    testWidgets('15 8 BTN: Start, pad and action buttons change CMD', (
      tester,
    ) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: _connectedState,
      );
      await _mountApp(tester, landscape: true);
      await _open(tester, GamepadModeEdit(acquireControl: () async => 1));
      await _start(tester);

      final buttons = _padButtons(tester);
      final mid = (buttons.first.left + buttons.last.right) / 2;
      final left = buttons.where((r) => r.center.dx < mid);
      final rightSide = buttons.where((r) => r.center.dx >= mid);
      final up = await tester.startGesture(_topMost(left).center, pointer: 1);
      final triangle = await tester.startGesture(
        _topMost(rightSide).center,
        pointer: 2,
      );
      await _settle(tester, frames: 3);
      await _shot(tester, '15_8btn_up_triangle_held');

      await up.up();
      await triangle.up();
      await _settle(tester, frames: 3);
      await _unmount(tester);
    });

    testWidgets('16 Joystick: Start, both sticks moved', (tester) async {
      _present(
        BleConnectionStatus.connected,
        connected: true,
        state: _connectedState,
      );
      await _mountApp(tester, landscape: true);
      await _open(tester, JoystickPage(acquireControl: () async => 1));
      await _start(tester);

      final sticks =
          find
              .byType(JoystickView)
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .toList()
            ..sort((a, b) => a.left.compareTo(b.left));
      final leftStick = await tester.startGesture(
        sticks.first.center,
        pointer: 1,
      );
      final rightStick = await tester.startGesture(
        sticks.last.center,
        pointer: 2,
      );
      final reachL = sticks.first.width * 0.3;
      final reachR = sticks.last.width * 0.3;
      for (var i = 1; i <= 6; i++) {
        await leftStick.moveBy(Offset(reachL * 0.15, -reachL * 0.8 / 6 * 1.0));
        await rightStick.moveBy(Offset(reachR / 6, 0));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await _settle(tester, frames: 3);
      await _shot(tester, '16_joystick_moved');

      await leftStick.up();
      await rightStick.up();
      await _settle(tester, frames: 3);
      await _unmount(tester);
    });

    testWidgets('17 Start without a robot', (tester) async {
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => null));
      await tester.tap(find.byType(ControlStartStopButton));
      await _settle(tester, frames: 4);
      await _shot(tester, '17_start_without_robot');
      await _settle(tester, frames: 40);
      await _unmount(tester);
    });

    testWidgets('18-19 link lost: reconnecting, then failed', (tester) async {
      _present(BleConnectionStatus.reconnecting, state: _connectedState);
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      await _shot(tester, '18_reconnecting');

      _present(
        BleConnectionStatus.reconnectFailed,
        state: const BleConnectionCoordinatorState(
          lastDeviceId: _lastId,
          lastDeviceName: _lastName,
          failureReason: 'link_lost',
        ),
      );
      await _settle(tester, frames: 3);
      await _openSheet(tester);
      await _shot(tester, '19_connection_lost_sheet');
      await _unmount(tester);
    });

    testWidgets('20 Bluetooth off', (tester) async {
      await _mountApp(tester, landscape: true);
      await _open(tester, Gamepad4ButtonPage(acquireControl: () async => 1));
      fakeBluetooth.adapter.add(
        BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.off),
      );
      await _settle(tester, frames: 3);
      await _openSheet(tester);
      await _shot(tester, '20_bluetooth_off_sheet');
      fakeBluetooth.adapter.add(
        BmBluetoothAdapterState(adapterState: BmAdapterStateEnum.on),
      );
      await _unmount(tester);
    });
  });
}
