import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/features/bluetooth/widgets/pairing_code_dialog.dart';

void main() {
  for (final readyAfterReconnect in [false, true]) {
    testWidgets(
      'reconnect replaces pending dialog only when needed: $readyAfterReconnect',
      (tester) async {
        final coordinator = _SessionCoordinator();
        coordinator.debugEmitForTesting(
          const BleConnectionCoordinatorState(
            securityState: BleControlSecurityState.pairingRequired,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBadge(
                autoPromptPairing: true,
                coordinator: coordinator,
                isBleConnected: () => true,
                enableBlePlatformBindings: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PairingCodeDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Example1');
        await tester.pump();
        await tester.tap(find.text('Pair'));
        await tester.pump();
        coordinator.generation++;
        coordinator.releaseAutomaticPairingPrompt();
        expect(coordinator.pairingPromptPresentedForConnection, isFalse);
        coordinator.debugEmitForTesting(
          BleConnectionCoordinatorState(
            securityState: readyAfterReconnect
                ? BleControlSecurityState.ready
                : BleControlSecurityState.pairingRequired,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(PairingCodeDialog),
          readyAfterReconnect ? findsNothing : findsOneWidget,
        );
        coordinator.result.complete(
          const BlePairingAttemptResult(
            ready: true,
            failure: BlePairingFailure.none,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(PairingCodeDialog),
          readyAfterReconnect ? findsNothing : findsOneWidget,
        );
        expect(coordinator.cancellations, 0);
        if (!readyAfterReconnect) {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(coordinator.cancellations, 1);
        }
        await tester.pumpWidget(const SizedBox());
        await coordinator.dispose();
      },
    );
  }
  testWidgets(
    'session change removes only stale dialog without cancelling new link',
    (tester) async {
      final coordinator = _SessionCoordinator();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => promptForBlePairingCode(
                  context: context,
                  isThai: false,
                  coordinator: coordinator,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other page')),
        ),
      );
      await tester.pumpAndSettle();
      coordinator.generation++;
      coordinator.debugEmitForTesting(const BleConnectionCoordinatorState());
      await tester.pumpAndSettle();
      expect(find.byType(PairingCodeDialog, skipOffstage: false), findsNothing);
      expect(find.text('Other page'), findsOneWidget);
      expect(coordinator.cancellations, 0);
      await tester.pumpWidget(const SizedBox());
      await coordinator.dispose();
    },
  );
  testWidgets('Cancel closes the pairing dialog without a code', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHost()));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pair returns a valid code and keeps invalid code disabled', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHost()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'BAD');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pair'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'iLoU1234');
    await tester.pump();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();

    expect(find.text('iLoU1234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage failure keeps the dialog open and explains the retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => PairingCodeDialog(
                  isThai: false,
                  onPair: (_) async => const BlePairingAttemptResult(
                    ready: false,
                    failure: BlePairingFailure.storageError,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7K9M2PQT');
    await tester.pump();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();

    expect(find.byType(PairingCodeDialog), findsOneWidget);
    expect(
      find.text(
        'Connected, but the pairing code could not be saved. Try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'dialog remains laid out with a small height and keyboard inset',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(const MaterialApp(home: _DialogHost()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(PairingCodeDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Landscape phones with the keyboard up leave about 100-170 px. The
  // dialog used to show only Cancel and Pair there (and overflowed).
  for (final (size, keyboard) in [
    (const Size(800, 360), 240.0),
    (const Size(914, 411), 200.0),
  ]) {
    testWidgets('code field and Pair stay visible above a landscape keyboard: '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: _DialogHost()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final visibleBottom = size.height - keyboard;
      for (final finder in [
        find.byType(TextField),
        find.widgetWithText(TextButton, 'Cancel'),
        find.widgetWithText(FilledButton, 'Pair'),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
        expect(
          rect.bottom,
          lessThanOrEqualTo(visibleBottom),
          reason: '$finder',
        );
      }

      await tester.enterText(find.byType(TextField), 'iLoU1234');
      await tester.pump();
      await tester.tap(find.text('Pair'));
      await tester.pumpAndSettle();
      expect(find.text('iLoU1234'), findsOneWidget);
    });
  }

  testWidgets('the field keeps focus and text when the keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: _DialogHost()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('English/Number · 8–16'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ABCD12');
    await tester.pump();
    final fieldState = tester.state(find.byType(EditableText));

    // The keyboard slides up: the dialog switches to its one-row layout.
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();

    expect(find.text('English/Number · 8–16'), findsNothing);
    expect(tester.state(find.byType(EditableText)), same(fieldState));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, 'ABCD12');
    expect(tester.takeException(), isNull);
  });
}

class _SessionCoordinator extends BleConnectionCoordinator {
  final result = Completer<BlePairingAttemptResult>();
  @override
  Future<BlePairingAttemptResult> savePairingCode(String code) => result.future;
  _SessionCoordinator() : super(listenToManagerAutoConnectRequests: false);
  int generation = 0;
  int cancellations = 0;
  @override
  int get pairingConnectionGeneration => generation;
  @override
  Future<void> cancelPairing(int generation) async {
    cancellations++;
  }
}

class _DialogHost extends StatefulWidget {
  const _DialogHost();

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  String? _result;
  var _closed = false;

  Future<void> _open() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const PairingCodeDialog(isThai: false),
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _closed = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(onPressed: _open, child: const Text('Open')),
          if (_closed) Text(_result ?? 'cancelled'),
        ],
      ),
    ),
  );
}
