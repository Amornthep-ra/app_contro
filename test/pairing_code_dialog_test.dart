import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/features/bluetooth/widgets/pairing_code_dialog.dart';

void main() {
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
