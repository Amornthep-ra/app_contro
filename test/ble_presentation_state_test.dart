import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pb_controller/core/ble/ble_adapter_observation.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/ui/app_assets.dart';
import 'package:pb_controller/core/widgets/ble_presentation_icon.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BLE presentation state', () {
    test('maps every FlutterBluePlus adapter state without side effects', () {
      const cases = <BluetoothAdapterState, BleAdapterPresentationState>{
        BluetoothAdapterState.unknown: BleAdapterPresentationState.unknown,
        BluetoothAdapterState.unavailable:
            BleAdapterPresentationState.unavailable,
        BluetoothAdapterState.unauthorized:
            BleAdapterPresentationState.unauthorized,
        BluetoothAdapterState.turningOn: BleAdapterPresentationState.turningOn,
        BluetoothAdapterState.on: BleAdapterPresentationState.on,
        BluetoothAdapterState.turningOff:
            BleAdapterPresentationState.turningOff,
        BluetoothAdapterState.off: BleAdapterPresentationState.off,
      };

      for (final value in cases.entries) {
        expect(
          adapterPresentationStateFromFlutterBluePlus(value.key),
          value.value,
        );
      }
    });

    test('maps BLE presentation icons consistently for every consumer', () {
      expect(
        materialIconForBlePresentation(BlePresentationIcon.connected),
        Icons.bluetooth_connected,
      );
      expect(
        materialIconForBlePresentation(BlePresentationIcon.neutral),
        Icons.bluetooth,
      );
      expect(
        materialIconForBlePresentation(BlePresentationIcon.searching),
        Icons.bluetooth_searching,
      );
      expect(
        materialIconForBlePresentation(BlePresentationIcon.disabled),
        Icons.bluetooth_disabled,
      );
      expect(
        materialIconForBlePresentation(BlePresentationIcon.unavailable),
        Icons.error_outline,
      );
      expect(
        materialIconForBlePresentation(BlePresentationIcon.permission),
        Icons.lock_outline,
      );
    });

    test(
      'defers native adapter observation until an existing BLE flow is safe',
      () async {
        var nativeObservationStarts = 0;
        final nativeStates = StreamController<BluetoothAdapterState>.broadcast(
          sync: true,
        );
        final boundary = BleAdapterObservationBoundary(
          initialState: BluetoothAdapterState.unknown,
          initiallySafe: false,
          nativeAdapterStates: () {
            nativeObservationStarts++;
            return nativeStates.stream;
          },
        );
        final connections = StreamController<BleConnectionStatus>.broadcast(
          sync: true,
        );
        final presentation = BlePresentationStateController(
          initialAdapterState: adapterPresentationStateFromFlutterBluePlus(
            boundary.currentState,
          ),
          adapterStates: boundary.states.map(
            adapterPresentationStateFromFlutterBluePlus,
          ),
          initialConnectionStatus: BleConnectionStatus.disconnected,
          connectionStatuses: connections.stream,
        );

        await Future<void>.delayed(Duration.zero);
        expect(nativeObservationStarts, 0);
        expect(presentation.value.label, 'Checking Bluetooth…');

        boundary.recordAlreadyObserved(BluetoothAdapterState.on);
        await Future<void>.delayed(Duration.zero);
        expect(nativeObservationStarts, 1);
        expect(presentation.value.label, 'Not connected');

        nativeStates.add(BluetoothAdapterState.off);
        expect(presentation.value.label, 'Bluetooth off');
        expect(boundary.currentState, BluetoothAdapterState.off);
        final replayedStates = <BluetoothAdapterState>[];
        final replaySubscription = boundary.states.listen(replayedStates.add);
        await Future<void>.delayed(Duration.zero);
        expect(replayedStates.first, BluetoothAdapterState.off);
        await replaySubscription.cancel();

        presentation.dispose();
        await Future<void>.delayed(Duration.zero);
        expect(nativeStates.hasListener, isFalse);
        boundary.dispose();
        await nativeStates.close();
        await connections.close();
      },
    );

    test(
      'releases adapter observation while the safe boundary is closed',
      () async {
        var nativeObservationStarts = 0;
        final boundary = BleAdapterObservationBoundary(
          initialState: BluetoothAdapterState.unknown,
          initiallySafe: false,
          nativeAdapterStates: () {
            nativeObservationStarts++;
            return const Stream<BluetoothAdapterState>.empty();
          },
        );
        final connections = StreamController<BleConnectionStatus>.broadcast(
          sync: true,
        );
        final presentation = BlePresentationStateController(
          initialAdapterState: BleAdapterPresentationState.unknown,
          adapterStates: boundary.states.map(
            adapterPresentationStateFromFlutterBluePlus,
          ),
          initialConnectionStatus: BleConnectionStatus.disconnected,
          connectionStatuses: connections.stream,
        );
        await Future<void>.delayed(Duration.zero);
        expect(boundary.hasWaitingObservers, isTrue);

        presentation.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(boundary.hasWaitingObservers, isFalse);
        boundary.recordAlreadyObserved(BluetoothAdapterState.on);
        await Future<void>.delayed(Duration.zero);
        expect(nativeObservationStarts, 0);
        boundary.dispose();
        await connections.close();
      },
    );

    test('iOS native observation is passive until adapter state is cached', () {
      expect(
        isBleAdapterObservationInitiallySafe(
          platform: TargetPlatform.iOS,
          cachedState: BluetoothAdapterState.unknown,
        ),
        isFalse,
      );
      expect(
        isBleAdapterObservationInitiallySafe(
          platform: TargetPlatform.iOS,
          cachedState: BluetoothAdapterState.on,
        ),
        isTrue,
      );
      expect(
        isBleAdapterObservationInitiallySafe(
          platform: TargetPlatform.android,
          cachedState: BluetoothAdapterState.unknown,
        ),
        isTrue,
      );
    });

    test('maps adapter and connection states to accurate user wording', () {
      const cases =
          <
            ({
              BleAdapterPresentationState adapter,
              BleConnectionStatus connection,
              BlePresentationKind kind,
              String label,
            })
          >[
            (
              adapter: BleAdapterPresentationState.off,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.bluetoothOff,
              label: 'Bluetooth off',
            ),
            (
              adapter: BleAdapterPresentationState.turningOn,
              connection: BleConnectionStatus.disconnected,
              kind: BlePresentationKind.turningOn,
              label: 'Turning Bluetooth on…',
            ),
            (
              adapter: BleAdapterPresentationState.turningOff,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.turningOff,
              label: 'Turning Bluetooth off…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.connected,
              label: 'Connected',
            ),
            (
              adapter: BleAdapterPresentationState.unknown,
              connection: BleConnectionStatus.scanning,
              kind: BlePresentationKind.scanning,
              label: 'Scanning…',
            ),
            (
              adapter: BleAdapterPresentationState.unauthorized,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.permissionNeeded,
              label: 'Bluetooth permission needed',
            ),
            (
              adapter: BleAdapterPresentationState.unavailable,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.unavailable,
              label: 'Bluetooth unavailable',
            ),
            (
              adapter: BleAdapterPresentationState.unauthorized,
              connection: BleConnectionStatus.scanning,
              kind: BlePresentationKind.permissionNeeded,
              label: 'Bluetooth permission needed',
            ),
            (
              adapter: BleAdapterPresentationState.unavailable,
              connection: BleConnectionStatus.reconnecting,
              kind: BlePresentationKind.unavailable,
              label: 'Bluetooth unavailable',
            ),
            (
              adapter: BleAdapterPresentationState.unknown,
              connection: BleConnectionStatus.connected,
              kind: BlePresentationKind.connected,
              label: 'Connected',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.connecting,
              kind: BlePresentationKind.connecting,
              label: 'Connecting…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.discovering,
              kind: BlePresentationKind.connecting,
              label: 'Connecting…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.subscribing,
              kind: BlePresentationKind.connecting,
              label: 'Connecting…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.reconnecting,
              kind: BlePresentationKind.reconnecting,
              label: 'Reconnecting…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.disconnecting,
              kind: BlePresentationKind.disconnecting,
              label: 'Disconnecting…',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.reconnectFailed,
              kind: BlePresentationKind.reconnectFailed,
              label: 'Reconnect failed',
            ),
            (
              adapter: BleAdapterPresentationState.on,
              connection: BleConnectionStatus.disconnected,
              kind: BlePresentationKind.notConnected,
              label: 'Not connected',
            ),
            (
              adapter: BleAdapterPresentationState.unavailable,
              connection: BleConnectionStatus.disconnected,
              kind: BlePresentationKind.unavailable,
              label: 'Bluetooth unavailable',
            ),
            (
              adapter: BleAdapterPresentationState.unauthorized,
              connection: BleConnectionStatus.disconnected,
              kind: BlePresentationKind.permissionNeeded,
              label: 'Bluetooth permission needed',
            ),
            (
              adapter: BleAdapterPresentationState.unknown,
              connection: BleConnectionStatus.disconnected,
              kind: BlePresentationKind.checking,
              label: 'Checking Bluetooth…',
            ),
          ];

      for (final value in cases) {
        final presentation = resolveBlePresentationState(
          adapterState: value.adapter,
          connectionStatus: value.connection,
        );
        expect(presentation.kind, value.kind);
        expect(presentation.label, value.label);
      }
    });

    test(
      'combines live state changes and releases both observations',
      () async {
        final adapters =
            StreamController<BleAdapterPresentationState>.broadcast(sync: true);
        final connections = StreamController<BleConnectionStatus>.broadcast(
          sync: true,
        );
        final presentation = BlePresentationStateController(
          initialAdapterState: BleAdapterPresentationState.unknown,
          adapterStates: adapters.stream,
          initialConnectionStatus: BleConnectionStatus.disconnected,
          connectionStatuses: connections.stream,
        );

        expect(presentation.value.label, 'Checking Bluetooth…');
        adapters.add(BleAdapterPresentationState.on);
        expect(presentation.value.label, 'Not connected');
        connections.add(BleConnectionStatus.connecting);
        expect(presentation.value.label, 'Connecting…');
        connections.add(BleConnectionStatus.connected);
        expect(presentation.value.label, 'Connected');
        adapters.add(BleAdapterPresentationState.off);
        expect(presentation.value.label, 'Bluetooth off');
        adapters.add(BleAdapterPresentationState.on);
        connections.add(BleConnectionStatus.reconnecting);
        expect(presentation.value.label, 'Reconnecting…');
        connections.add(BleConnectionStatus.reconnectFailed);
        expect(presentation.value.label, 'Reconnect failed');
        expect(adapters.hasListener, isTrue);
        expect(connections.hasListener, isTrue);

        presentation.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(adapters.hasListener, isFalse);
        expect(connections.hasListener, isFalse);
        await adapters.close();
        await connections.close();
      },
    );

    testWidgets('badge displays live presentation wording and icons', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final presentation = ValueNotifier(
        const BlePresentationState(BlePresentationKind.notConnected),
      );
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              presentationState: presentation,
              enableBlePlatformBindings: false,
              iconAsset: AppAssets.controlBle,
            ),
          ),
        ),
      );

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.bluetooth)).color,
        Colors.black87,
      );
      final notConnectedSemantics = tester.getSemantics(
        find.bySemanticsLabel('Bluetooth connection: Not connected'),
      );
      expect(notConnectedSemantics.flagsCollection.isLiveRegion, isTrue);
      expect(notConnectedSemantics.flagsCollection.isButton, isTrue);

      presentation.value = const BlePresentationState(
        BlePresentationKind.bluetoothOff,
      );
      await tester.pump();

      expect(find.text('Bluetooth off'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bluetooth connection: Bluetooth off'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('Home and badge use the same live presentation state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'ble_last_device_id': 'AA:BB',
        'ble_last_device_name': 'PrinceBot',
      });
      PackageInfo.setMockInitialValues(
        appName: 'PB Controller',
        packageName: 'com.pbcontroller.app',
        version: '2.1.0',
        buildNumber: '20',
        buildSignature: '',
      );
      final presentation = ValueNotifier(
        const BlePresentationState(BlePresentationKind.notConnected),
      );
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              HomePage(blePresentationState: presentation),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConnectionStatusBadge(
                  presentationState: presentation,
                  enableBlePlatformBindings: false,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Not connected'), findsNWidgets(2));

      presentation.value = const BlePresentationState(
        BlePresentationKind.bluetoothOff,
      );
      await tester.pump();
      expect(find.text('Bluetooth off'), findsNWidgets(2));

      presentation.value = const BlePresentationState(
        BlePresentationKind.connected,
      );
      await tester.pump();
      // Home shows the device name as its title and "Connected" on the
      // status line; the badge shows "Connected".
      expect(find.text('Connected'), findsNWidgets(2));
      expect(find.text('PrinceBot'), findsOneWidget);
    });

    testWidgets('long BLE wording remains visible on a small Home', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'PB Controller',
        packageName: 'com.pbcontroller.app',
        version: '2.1.0',
        buildNumber: '20',
        buildSignature: '',
      );
      final presentation = ValueNotifier(
        const BlePresentationState(BlePresentationKind.permissionNeeded),
      );
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: HomePage(blePresentationState: presentation),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bluetooth permission needed'), findsOneWidget);
      final homeSemantics = tester.getSemantics(
        find.bySemanticsLabel(
          'Bluetooth connection: Bluetooth permission needed',
        ),
      );
      expect(homeSemantics.flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('long badge wording remains visible at 2x text scaling', (
      tester,
    ) async {
      final presentation = ValueNotifier(
        const BlePresentationState(BlePresentationKind.permissionNeeded),
      );
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: ConnectionStatusBadge(
                  presentationState: presentation,
                  enableBlePlatformBindings: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bluetooth permission needed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BLE badge composes in a small landscape app bar', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final presentation = ValueNotifier(
        const BlePresentationState(BlePresentationKind.permissionNeeded),
      );
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(640, 360),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              appBar: AppBar(
                actions: [
                  ConnectionStatusBadge(
                    presentationState: presentation,
                    enableBlePlatformBindings: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Bluetooth connection: Bluetooth permission needed',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
