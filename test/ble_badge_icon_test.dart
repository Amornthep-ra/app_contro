// The BLE badge icon must stay in its 16 px slot inside an AppBar (PID
// Tuning), where the AppBar icon theme would otherwise draw it at 24 px on
// top of the label.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_presentation_state.dart';
import 'package:pb_controller/core/widgets/connection_status_badge.dart';

void main() {
  testWidgets('badge icon keeps its slot size inside an AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              ConnectionStatusBadge(
                isBleConnected: () => false,
                isControlSessionActive: () => false,
                enableBlePlatformBindings: false,
                presentationState: ValueNotifier(
                  const BlePresentationState(BlePresentationKind.notConnected),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final icons = find.descendant(
      of: find.byType(ConnectionStatusBadge),
      matching: find.byType(Icon),
    );
    expect(icons, findsWidgets);
    for (final icon in tester.widgetList<Icon>(icons)) {
      expect(icon.size, 16);
    }
    expect(find.text('Not connected'), findsOneWidget);
  });
}
