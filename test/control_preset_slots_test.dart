import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/widgets/control_preset_slots.dart';

void main() {
  test('default preset name uses the slot number', () {
    expect(defaultControlPresetName(3), 'Preset 3');
  });

  test('preset names need a letter or number and no other symbols', () {
    expect(validateControlPresetName('Race 1'), isNull);
    expect(validateControlPresetName('  my_pad-2 '), isNull);
    expect(validateControlPresetName('   '), isNotNull);
    expect(validateControlPresetName('a/b'), isNotNull);
    expect(validateControlPresetName('--'), isNotNull);
  });

  test('reads the trimmed name of a saved preset', () {
    expect(readControlPresetName('{"name":"  Race  ","layout":{}}'), 'Race');
    expect(readControlPresetName('{"name":"  "}'), isNull);
    expect(readControlPresetName('{"layout":{}}'), isNull);
    expect(readControlPresetName('[1]'), isNull);
    expect(readControlPresetName('not json'), isNull);
    expect(readControlPresetName(''), isNull);
  });
}
