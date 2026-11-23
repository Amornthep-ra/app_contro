import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/widgets/gamepad_edit_shared.dart';

void main() {
  test('undo and redo walk the recorded states', () {
    final history = GamepadEditHistory<int>();
    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);

    history.push(1);
    history.push(2);
    expect(history.undo(3), 2);
    expect(history.canRedo, isTrue);
    expect(history.undo(2), 1);
    expect(history.canUndo, isFalse);
    expect(history.redo(1), 2);
    expect(history.redo(2), 3);
    expect(history.canRedo, isFalse);
  });

  test('a new edit drops the redo list', () {
    final history = GamepadEditHistory<int>();
    history.push(1);
    history.undo(2);
    expect(history.canRedo, isTrue);
    history.push(1);
    expect(history.canRedo, isFalse);
  });

  test('keeps at most maxEntries undo steps, dropping the oldest', () {
    final history = GamepadEditHistory<int>(maxEntries: 2);
    history.push(1);
    history.push(2);
    history.push(3);
    expect(history.undo(4), 3);
    expect(history.undo(3), 2);
    expect(history.canUndo, isFalse);
  });

  test('layout JSON round-trips and keeps sizes inside per-id limits', () {
    final layout = {
      'a': const GamepadButtonLayout(0.25, 0.5, 0.3),
      'b': const GamepadButtonLayout(0.75, 0.5, 2.0),
    };
    final raw = jsonEncode(encodeGamepadLayout(layout));
    final decoded = decodeGamepadLayout(
      raw,
      minSize: (_) => 0.1,
      maxSize: (id) => id == 'b' ? 1.0 : 0.8,
      defaultSize: 0.3,
    );
    expect(decoded['a']!.cx, 0.25);
    expect(decoded['a']!.size, 0.3);
    expect(decoded['b']!.size, 1.0);
    expect(
      decodeGamepadLayout(
        'not json',
        minSize: (_) => 0.1,
        maxSize: (_) => 1,
        defaultSize: 0.3,
      ),
      isEmpty,
    );
  });

  test('id lists read only JSON lists', () {
    expect(decodeGamepadIdList('["L:up", 2]'), {'L:up', '2'});
    expect(decodeGamepadIdList('{"a":1}'), isEmpty);
    expect(decodeGamepadIdList(''), isEmpty);
  });
}
