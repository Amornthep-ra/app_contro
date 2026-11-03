import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/app_assets.dart';
import 'package:pb_controller/features/home/widgets/home_backdrop.dart';

bool get motionRunning => HomeBackdrop.debugRunningClocks > 0;

void main() {
  Finder backgroundImage() => find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName ==
            AppAssets.controlBackgroundPortrait,
  );

  testWidgets('Home backdrop keeps the original background artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeBackdrop(animate: false)),
    );

    expect(backgroundImage(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeBackdrop),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('Home backdrop motion pauses while another page covers it', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const HomeBackdrop(animate: true),
      ),
    );

    expect(motionRunning, isTrue);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    // Covered by an opaque page: the motion clock stops.
    expect(motionRunning, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(motionRunning, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(motionRunning, isFalse);
  });

  testWidgets('Home backdrop respects the reduce-motion setting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: HomeBackdrop(animate: true),
        ),
      ),
    );
    await tester.pump();

    expect(motionRunning, isFalse);
    expect(backgroundImage(), findsOneWidget);
  });

  testWidgets('Home backdrop motion pauses while the app is in background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeBackdrop(animate: true)),
    );
    expect(motionRunning, isTrue);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(motionRunning, isFalse);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(motionRunning, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(motionRunning, isFalse);
  });
}
