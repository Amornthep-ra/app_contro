import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ui/language_controller.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:pb_controller/features/bluetooth/bluetooth_ble_page.dart';

class _NoopBleConnectionPlatform implements BleConnectionPlatform {
  @override
  Stream<List<ScanResult>> get scanResults =>
      const Stream<List<ScanResult>>.empty();

  @override
  Future<void> connect(ScanResult result) async {}

  @override
  Future<void> disconnect(ScanResult result) async {}

  @override
  Future<void> startScan({required Duration timeout}) async {}

  @override
  Future<void> stopScan() async {}
}

BleConnectionCoordinator _coordinator() => BleConnectionCoordinator(
  platform: _NoopBleConnectionPlatform(),
  listenToManagerAutoConnectRequests: false,
);

const _pairingRequired = BleConnectionCoordinatorState(
  securityState: BleControlSecurityState.pairingRequired,
);

const _pairingReady = BleConnectionCoordinatorState(
  securityState: BleControlSecurityState.ready,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LanguageController.isThai.value = false;
  });

  testWidgets(
    'BLE Connection presents one automatic pairing prompt per connection',
    (tester) async {
      final coordinator = _coordinator();
      var promptCalls = 0;
      coordinator.debugEmitForTesting(_pairingRequired);

      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothBlePage(
            coordinator: coordinator,
            isBleConnected: () => true,
            enableBlePlatformBindings: false,
            pairingPromptLauncher:
                ({required context, required isThai, coordinator}) async {
                  promptCalls++;
                  return null;
                },
          ),
        ),
      );
      await tester.pump();

      expect(promptCalls, 1);
      coordinator.debugEmitForTesting(_pairingRequired);
      await tester.pump();
      expect(promptCalls, 1);

      await tester.pumpWidget(const SizedBox());
      await coordinator.dispose();
    },
  );

  testWidgets(
    'BLE Connection manual Pair code suppresses a duplicate automatic prompt',
    (tester) async {
      final coordinator = _coordinator();
      var promptCalls = 0;
      coordinator.debugEmitForTesting(_pairingRequired);
      coordinator.markPairingPromptPresented();

      await tester.pumpWidget(
        MaterialApp(
          home: BluetoothBlePage(
            coordinator: coordinator,
            isBleConnected: () => true,
            enableBlePlatformBindings: false,
            pairingPromptLauncher:
                ({required context, required isThai, coordinator}) async {
                  promptCalls++;
                  return null;
                },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Pair code'));
      await tester.pump();

      expect(promptCalls, 1);
      coordinator.debugEmitForTesting(_pairingRequired);
      await tester.pump();
      expect(promptCalls, 1);

      await tester.pumpWidget(const SizedBox());
      await coordinator.dispose();
    },
  );

  testWidgets(
    'BLE Off presents one automatic pairing prompt after closing its sheet',
    (tester) async {
      final coordinator = _coordinator();
      var promptCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              coordinator: coordinator,
              isBleConnected: () => true,
              isControlSessionActive: () => false,
              enableBlePlatformBindings: false,
              pairingTransitionDelay: Duration.zero,
              pairingPromptLauncher:
                  ({required context, required isThai, coordinator}) async {
                    promptCalls++;
                    return null;
                  },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ConnectionStatusBadge));
      await tester.pump();
      coordinator.debugEmitForTesting(_pairingRequired);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(promptCalls, 1);
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isFalse);

      await tester.pumpWidget(const SizedBox());
      await coordinator.dispose();
    },
  );

  testWidgets(
    'BLE Off manual Pair code marks the connection prompt as presented',
    (tester) async {
      final coordinator = _coordinator();
      var promptCalls = 0;
      coordinator.debugEmitForTesting(_pairingRequired);
      coordinator.markPairingPromptPresented();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              coordinator: coordinator,
              isBleConnected: () => true,
              isControlSessionActive: () => false,
              enableBlePlatformBindings: false,
              pairingTransitionDelay: Duration.zero,
              pairingPromptLauncher:
                  ({required context, required isThai, coordinator}) async {
                    promptCalls++;
                    return null;
                  },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ConnectionStatusBadge));
      await tester.pump();
      final pairCodeButton = find.byTooltip('Pair code');
      await tester.ensureVisible(pairCodeButton);
      await tester.pumpAndSettle();
      await tester.tap(pairCodeButton);
      await tester.pumpAndSettle();

      expect(promptCalls, 1);
      coordinator.debugEmitForTesting(_pairingRequired);
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isFalse);

      await tester.pumpWidget(const SizedBox());
      await coordinator.dispose();
    },
  );

  testWidgets('paired state disables both Pair code entry points', (
    tester,
  ) async {
    final coordinator = _coordinator();
    var promptCalls = 0;
    coordinator.debugEmitForTesting(_pairingReady);

    await tester.pumpWidget(
      MaterialApp(
        home: BluetoothBlePage(
          coordinator: coordinator,
          isBleConnected: () => true,
          enableBlePlatformBindings: false,
          pairingPromptLauncher:
              ({required context, required isThai, coordinator}) async {
                promptCalls++;
                return null;
              },
        ),
      ),
    );
    await tester.pump();

    final pairedButton = find.widgetWithText(TextButton, 'Paired');
    expect(pairedButton, findsOneWidget);
    expect(tester.widget<TextButton>(pairedButton).onPressed, isNull);
    expect(promptCalls, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusBadge(
            coordinator: coordinator,
            isBleConnected: () => true,
            isControlSessionActive: () => false,
            enableBlePlatformBindings: false,
            pairingTransitionDelay: Duration.zero,
            pairingPromptLauncher:
                ({required context, required isThai, coordinator}) async {
                  promptCalls++;
                  return null;
                },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConnectionStatusBadge));
    await tester.pumpAndSettle();

    final pairedIcon = find.byTooltip('Paired');
    expect(pairedIcon, findsOneWidget);
    final pairedIconButton = find.ancestor(
      of: pairedIcon,
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(pairedIconButton).onPressed, isNull);
    expect(promptCalls, 0);

    await tester.pumpWidget(const SizedBox());
    await coordinator.dispose();
  });

  testWidgets(
    'BLE Off does not consume automatic prompt when host is disposed in delay',
    (tester) async {
      final coordinator = _coordinator();
      var promptCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              coordinator: coordinator,
              isBleConnected: () => true,
              isControlSessionActive: () => false,
              pairingTransitionDelay: const Duration(milliseconds: 200),
              enableBlePlatformBindings: false,
              pairingPromptLauncher:
                  ({required context, required isThai, coordinator}) async {
                    promptCalls++;
                    return null;
                  },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ConnectionStatusBadge));
      await tester.pump();
      coordinator.debugEmitForTesting(_pairingRequired);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(milliseconds: 250));

      expect(promptCalls, 0);
      expect(coordinator.claimAutomaticPairingPrompt(connected: true), isTrue);

      await coordinator.dispose();
    },
  );
}
