import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/gamepad_edit_metrics.dart';

void main() {
  group('GamepadEditMetrics', () {
    test('uses the shortest panel side on phone-sized panels', () {
      const panel = Size(844, 390);

      expect(GamepadEditMetrics.panelUnit(panel), 390);
      expect(GamepadEditMetrics.sizePx(panel, 0.30), 117);
    });

    test('caps the panel unit on tablet-sized panels', () {
      const panel = Size(1194, 834);

      expect(
        GamepadEditMetrics.panelUnit(panel),
        GamepadEditMetrics.maxPanelUnit,
      );
      expect(GamepadEditMetrics.sizePx(panel, 0.30), 156);
    });

    test('centers a phone-like default layout frame on tablet panels', () {
      const panel = Size(1194, 834);
      final frame = GamepadEditMetrics.defaultLayoutFrame(panel);

      expect(frame.width, closeTo(1125.33, 0.01));
      expect(frame.height, 520);
      expect(frame.left, closeTo(34.33, 0.01));
      expect(frame.top, 157);
    });
  });
}
