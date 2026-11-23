import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/gamepad_components.dart';
import 'cat_glass_popup.dart';
import 'control_preset_dialog.dart';

/// Name shown for a preset slot that has no name of its own.
String defaultControlPresetName(int slot) => 'Preset $slot';

final RegExp _presetAllowedPattern = RegExp(r'^[A-Za-z0-9 _-]+$');
final RegExp _presetRequiredChars = RegExp(r'[A-Za-z0-9]');

/// Error text for a preset name the user typed, or null when it is fine.
String? validateControlPresetName(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return 'Enter a preset name using letters or numbers.';
  }
  if (!_presetAllowedPattern.hasMatch(value)) {
    return 'Only letters, numbers, spaces, - and _ are allowed.';
  }
  if (!_presetRequiredChars.hasMatch(value)) {
    return 'Use at least one letter or number. Symbols alone are not allowed.';
  }
  return null;
}

/// The `name` stored in a saved preset's JSON, or null if it has none.
String? readControlPresetName(String raw) {
  try {
    final obj = jsonDecode(raw);
    if (obj is! Map) return null;
    final name = obj['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
  } catch (_) {}
  return null;
}

/// Opens the preset dialog of a control page whose presets are stored in
/// SharedPreferences under [presetKey]. Saving asks for a name first;
/// clearing removes the stored preset. The page saves and loads its own data.
Future<void> showControlPresetSheet({
  required BuildContext context,
  required String Function(int slot) presetKey,
  required Future<void> Function(int slot, String name) onSave,
  required Future<void> Function(int slot) onLoad,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  ControlPresetSlot makeSlot(int slot) {
    final raw = prefs.getString(presetKey(slot)) ?? '';
    return ControlPresetSlot(
      slot: slot,
      name: readControlPresetName(raw) ?? defaultControlPresetName(slot),
      hasData: raw.isNotEmpty,
    );
  }

  await showControlPresetDialog(
    context: context,
    slots: List<ControlPresetSlot>.generate(
      controlPresetSlotCount,
      (index) => makeSlot(index + 1),
    ),
    onSave: (slot) async {
      gamepadBuzz();
      final name = await showCatPresetNameDialog(
        context: context,
        currentName: slot.hasData ? slot.name : null,
        validator: validateControlPresetName,
      );
      if (name == null) return null;
      await onSave(slot.slot, name);
      final trimmed = name.trim();
      return ControlPresetSlot(
        slot: slot.slot,
        name: trimmed.isEmpty ? defaultControlPresetName(slot.slot) : trimmed,
        hasData: true,
      );
    },
    onLoad: (slot) async {
      gamepadBuzz();
      await onLoad(slot.slot);
    },
    onClear: (slot) async {
      gamepadBuzz();
      await prefs.remove(presetKey(slot.slot));
      return ControlPresetSlot(
        slot: slot.slot,
        name: defaultControlPresetName(slot.slot),
        hasData: false,
      );
    },
  );
}
