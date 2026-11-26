import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/control_preset_dialog.dart' show controlPresetSlotCount;

/// The saved layout presets of one control page, kept in SharedPreferences
/// under `<prefix>_preset_<slot>` (slots 1 to [controlPresetSlotCount]).
///
/// Each preset is a JSON object; the page decides what it holds. An
/// optional `name` is stored with it.
class ControlPresetStore {
  const ControlPresetStore(this.prefix);

  /// Key prefix of the page: `gp4`, `gp8` or `joy`.
  final String prefix;

  String keyFor(int slot) {
    RangeError.checkValueInInterval(slot, 1, controlPresetSlotCount, 'slot');
    return '${prefix}_preset_$slot';
  }

  /// Saves [data] in [slot], with [name] when it is not blank.
  Future<void> save(int slot, Map<String, Object> data, {String? name}) async {
    final stored = <String, Object>{...data};
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) stored['name'] = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(slot), jsonEncode(stored));
  }

  /// The preset in [slot], or null when the slot is empty or what is
  /// stored there is not a JSON object.
  Future<Map<String, Object?>?> load(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(slot));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}
