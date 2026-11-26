import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ui/control_preset_store.dart';
import 'package:pb_controller/core/widgets/control_preset_slots.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keys match the ones older builds saved under', () {
    expect(const ControlPresetStore('gp4').keyFor(1), 'gp4_preset_1');
    expect(const ControlPresetStore('gp8').keyFor(3), 'gp8_preset_3');
    expect(const ControlPresetStore('joy').keyFor(5), 'joy_preset_5');
    expect(() => const ControlPresetStore('gp4').keyFor(0), throwsRangeError);
    expect(() => const ControlPresetStore('gp4').keyFor(6), throwsRangeError);
  });

  test('a saved preset loads back with its trimmed name', () async {
    const store = ControlPresetStore('gp4');
    await store.save(2, {
      'active': ['F', 'B'],
      'speed': 'Med',
    }, name: '  Race  ');

    final preset = await store.load(2);
    expect(preset, {
      'active': ['F', 'B'],
      'speed': 'Med',
      'name': 'Race',
    });
    // The preset sheet still reads the name from the same key.
    final prefs = await SharedPreferences.getInstance();
    expect(readControlPresetName(prefs.getString('gp4_preset_2')!), 'Race');
  });

  test('a blank name is not stored', () async {
    const store = ControlPresetStore('joy');
    await store.save(1, {'active': <String>[]}, name: '   ');
    expect((await store.load(1))!.containsKey('name'), isFalse);
  });

  test('an older build preset still loads', () async {
    SharedPreferences.setMockInitialValues({
      'gp8_preset_4': jsonEncode({'drive': 70, 'turn': 40, 'name': 'Old'}),
    });
    final preset = await const ControlPresetStore('gp8').load(4);
    expect(preset, {'drive': 70, 'turn': 40, 'name': 'Old'});
  });

  test('empty, broken or non-object presets load as null', () async {
    SharedPreferences.setMockInitialValues({
      'gp4_preset_2': '',
      'gp4_preset_3': '{not json',
      'gp4_preset_4': '[1, 2]',
    });
    const store = ControlPresetStore('gp4');
    expect(await store.load(1), isNull);
    expect(await store.load(2), isNull);
    expect(await store.load(3), isNull);
    expect(await store.load(4), isNull);
  });
}
