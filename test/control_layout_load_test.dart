import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/utils/orientation_utils.dart';
import 'package:pb_controller/core/widgets/control_page_mixin.dart';
import 'package:pb_controller/features/gamepad/gamepad_4_button_page.dart';
import 'package:pb_controller/features/gamepad/gamepad_mode_edit.dart';
import 'package:pb_controller/features/joystick/joystick/presentation/joystick.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Saved preferences that arrive only once [gate] completes, like a slow
/// first read from disk.
class _SlowStore extends InMemorySharedPreferencesStore {
  _SlowStore() : super.empty();

  final gate = Completer<void>();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    await gate.future;
    return super.getAllWithParameters(parameters);
  }
}

/// The editor opens only once the saved layout has loaded, so a late load
/// cannot overwrite what was just dragged.
void main() {
  setUp(() {
    OrientationUtils.resetForTesting();
    BleManager.instance.setTrafficMode(BleTrafficMode.textCommand);
  });

  tearDown(() => SharedPreferences.setMockInitialValues({}));

  final pages = <String, Widget Function()>{
    'four-button': () => const Gamepad4ButtonPage(),
    'eight-button': () => const GamepadModeEdit(),
    'joystick': () => const JoystickPage(),
  };

  for (final page in pages.entries) {
    testWidgets('${page.key}: the editor waits for the saved layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(914, 411);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('vibration'),
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('vibration'),
          null,
        ),
      );
      final store = _SlowStore();
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = store;

      await tester.pumpWidget(MaterialApp(home: page.value()));
      await tester.pump();
      final state =
          tester.state(find.byType(page.value().runtimeType))
              as ControlPageMixin;
      state.toggleEdit();
      await tester.pump();
      expect(state.editMode, isFalse);

      store.gate.complete();
      await tester.pumpAndSettle();
      state.toggleEdit();
      await tester.pump();
      expect(state.editMode, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
