// lib/features/linesonic/linesonic_pid_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/lavender_glass.dart';
import '../../core/ui/language_controller.dart';
import 'widgets/linesonic_scaffold.dart';

enum _StepMode { time, checksum }

class _StepData {
  _StepData({
    required this.id,
    required this.mode,
    required String kp,
    required String kd,
    required String speed,
    required String value,
    required String afterMs,
    required String afterSpeed,
    required String stopMs,
    required String holdMs,
    required String holdThreshold,
    required this.lineColor,
    required this.holdMode,
    required this.continueAfter,
    required this.stopBetween,
    this.collapsed = false,
    bool? showOptions,
  }) : kpCtrl = TextEditingController(text: kp),
       kdCtrl = TextEditingController(text: kd),
       speedCtrl = TextEditingController(text: speed),
       valueCtrl = TextEditingController(text: value),
       afterMsCtrl = TextEditingController(text: afterMs),
       afterSpeedCtrl = TextEditingController(text: afterSpeed),
       stopMsCtrl = TextEditingController(text: stopMs),
       holdMsCtrl = TextEditingController(text: holdMs),
       holdThresholdCtrl = TextEditingController(text: holdThreshold),
       showOptions = showOptions ?? (mode != null);

  final int id;
  _StepMode? mode;
  final TextEditingController kpCtrl;
  final TextEditingController kdCtrl;
  final TextEditingController speedCtrl;
  final TextEditingController valueCtrl;
  final TextEditingController afterMsCtrl;
  final TextEditingController afterSpeedCtrl;
  final TextEditingController stopMsCtrl;
  final TextEditingController holdMsCtrl;
  final TextEditingController holdThresholdCtrl;
  int lineColor;
  int holdMode; // 0=off, 1=all black, 2=all white
  bool continueAfter;
  bool stopBetween;
  bool collapsed;
  bool showOptions;

  Map<String, dynamic> toJson() => {
    'mode': mode == null
        ? ''
        : (mode == _StepMode.checksum ? 'CHECKSUM' : 'TIME'),
    'kp': kpCtrl.text.trim().isEmpty ? '0' : kpCtrl.text.trim(),
    'kd': kdCtrl.text.trim().isEmpty ? '0' : kdCtrl.text.trim(),
    'speed': speedCtrl.text.trim().isEmpty ? '0' : speedCtrl.text.trim(),
    'value': valueCtrl.text.trim().isEmpty ? '0' : valueCtrl.text.trim(),
    'continueAfter': continueAfter,
    'afterMs': afterMsCtrl.text.trim().isEmpty ? '0' : afterMsCtrl.text.trim(),
    'afterSpeed': afterSpeedCtrl.text.trim().isEmpty
        ? '0'
        : afterSpeedCtrl.text.trim(),
    'stopBetween': stopBetween,
    'stopMs': stopMsCtrl.text.trim().isEmpty ? '0' : stopMsCtrl.text.trim(),
    'holdMode': holdMode,
    'holdMs': holdMsCtrl.text.trim().isEmpty ? '0' : holdMsCtrl.text.trim(),
    'holdThreshold': holdThresholdCtrl.text.trim().isEmpty
        ? '0'
        : holdThresholdCtrl.text.trim(),
    'lineColor': lineColor,
    'collapsed': collapsed,
    'showOptions': showOptions,
  };

  void dispose() {
    kpCtrl.dispose();
    kdCtrl.dispose();
    speedCtrl.dispose();
    valueCtrl.dispose();
    afterMsCtrl.dispose();
    afterSpeedCtrl.dispose();
    stopMsCtrl.dispose();
    holdMsCtrl.dispose();
    holdThresholdCtrl.dispose();
  }
}

class _PresetSlot {
  _PresetSlot({required this.name, required this.steps});

  String name;
  List<Map<String, dynamic>> steps;

  bool get isEmpty => steps.isEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'steps': steps};

  static _PresetSlot fromJson(Map<String, dynamic> json) => _PresetSlot(
    name: (json['name'] as String?) ?? 'Preset',
    steps:
        (json['steps'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [],
  );
}

class LineSonicPidPage extends StatefulWidget {
  const LineSonicPidPage({super.key});

  @override
  State<LineSonicPidPage> createState() => _LineSonicPidPageState();
}

class _LineSonicPidPageState extends State<LineSonicPidPage> {
  static const _prefsStepsKey = 'linesonic_steps_v2';
  static const _prefsPresetsKey = 'linesonic_presets_v1';
  static const _presetCount = 10;

  final List<_StepData> _steps = [];

  /// Deleted steps whose Undo snack bar is still showing; disposed when it
  /// closes (or with the page).
  final Set<_StepData> _pendingDeleted = {};
  final List<_PresetSlot> _presets = List.generate(
    _presetCount,
    (i) => _PresetSlot(name: 'Preset ${i + 1}', steps: []),
  );
  int _selectedPreset = 0;

  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSeqSend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPdSend = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;
  Timer? _autosaveTimer;
  Future<void> _saveQueue = Future<void>.value();
  int _saveGeneration = 0;
  bool _stepsDirty = false;
  bool _leavingPage = false;
  int? _bleTrafficOwner;
  bool get _isThai => LanguageController.isThai.value;

  @override
  void initState() {
    super.initState();
    _bleTrafficOwner = BleManager.instance.claimTrafficMode(
      BleTrafficMode.textCommand,
      ownerName: 'linesonic_pid',
    );
    _initAsync();
  }

  Future<void> _initAsync() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _leavingPage) return;
    _loadPresets(prefs);
    _loadSteps(prefs);
    if (_steps.isEmpty) {
      _steps.add(_newStep());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _leavingPage = true;
    unawaited(_flushSteps());
    for (final s in _steps) {
      s.dispose();
    }
    for (final s in _pendingDeleted) {
      s.dispose();
    }
    _pendingDeleted.clear();
    final trafficOwner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (trafficOwner != null) {
      BleManager.instance.releaseTrafficMode(trafficOwner);
    }
    super.dispose();
  }

  void _scheduleAutoSave() {
    _stepsDirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_flushSteps()),
    );
  }

  void _onSpeedChanged() {
    setState(() {});
    _scheduleAutoSave();
  }

  Future<void> _flushSteps() {
    _autosaveTimer?.cancel();
    if (!_stepsDirty) return _saveQueue;
    final snapshot = jsonEncode(_steps.map((e) => e.toJson()).toList());
    final generation = ++_saveGeneration;
    _stepsDirty = false;
    _saveQueue = _saveQueue
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(_prefsStepsKey, snapshot)) {
            throw StateError('PID steps could not be saved');
          }
        })
        .catchError((Object error, StackTrace stack) {
          if (generation == _saveGeneration) _stepsDirty = true;
          debugPrint('PID autosave failed: $error');
        });
    return _saveQueue;
  }

  Future<void> _exitPage() async {
    if (_leavingPage) return;
    _leavingPage = true;
    await _flushSteps();
    if (!mounted) return;
    if (_stepsDirty) {
      _leavingPage = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save changes. Please try again.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  void _loadSteps(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsStepsKey);
    if (raw == null || raw.trim().isEmpty) return;
    final data = jsonDecode(raw);
    if (data is! List) return;
    for (final s in _steps) {
      s.dispose();
    }
    _steps.clear();
    var nextId = 1;
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final modeRaw = (item['mode'] as String?) ?? '';
      final continueAfter = (item['continueAfter'] as bool?) ?? false;
      final parsedMode = modeRaw.toUpperCase() == 'CHECKSUM'
          ? _StepMode.checksum
          : (modeRaw.toUpperCase() == 'TIME' ? _StepMode.time : null);
      final collapsed = (item['collapsed'] as bool?) ?? false;
      final showOptions =
          (item['showOptions'] as bool?) ?? (parsedMode != null);
      _steps.add(
        _StepData(
          id: nextId++,
          mode: parsedMode,
          kp: (item['kp'] as String?) ?? '0',
          kd: (item['kd'] as String?) ?? '0',
          speed: (item['speed'] as String?) ?? '0',
          value: (item['value'] as String?) ?? '0',
          afterMs: (item['afterMs'] as String?) ?? '0',
          afterSpeed: (item['afterSpeed'] as String?) ?? '0',
          stopMs: (item['stopMs'] as String?) ?? '0',
          holdMs: (item['holdMs'] as String?) ?? '0',
          holdThreshold: (item['holdThreshold'] as String?) ?? '0',
          lineColor: (item['lineColor'] as int?) ?? 0,
          holdMode: (item['holdMode'] as int?) ?? 0,
          continueAfter: continueAfter,
          stopBetween: (item['stopBetween'] as bool?) ?? false,
          collapsed: collapsed,
          showOptions: showOptions,
        ),
      );
    }
  }

  Future<void> _savePresetsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _presets.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsPresetsKey, jsonEncode(data));
  }

  void _loadPresets(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsPresetsKey);
    if (raw == null || raw.trim().isEmpty) return;
    final data = jsonDecode(raw);
    if (data is! List) return;
    for (var i = 0; i < _presetCount && i < data.length; i++) {
      final item = data[i];
      if (item is! Map<String, dynamic>) continue;
      _presets[i] = _PresetSlot.fromJson(item);
      if (_presets[i].name.trim().isEmpty) {
        _presets[i].name = 'Preset ${i + 1}';
      }
    }
  }

  _StepData _newStep({
    _StepMode? mode,
    String kp = '0',
    String kd = '0',
    String speed = '0',
    String value = '0',
    String afterMs = '0',
    String afterSpeed = '0',
    String stopMs = '0',
    String holdMs = '0',
    String holdThreshold = '0',
    int lineColor = 0,
    int holdMode = 0,
    bool continueAfter = false,
    bool stopBetween = false,
  }) {
    final nextId = _steps.isEmpty
        ? 1
        : _steps.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    return _StepData(
      id: nextId,
      mode: mode,
      kp: kp,
      kd: kd,
      speed: speed,
      value: value,
      afterMs: afterMs,
      afterSpeed: afterSpeed,
      stopMs: stopMs,
      holdMs: holdMs,
      holdThreshold: holdThreshold,
      lineColor: lineColor,
      holdMode: holdMode,
      continueAfter: continueAfter,
      stopBetween: stopBetween,
      showOptions: mode != null,
    );
  }

  String _numOrZero(String raw) {
    final v = raw.trim();
    return v.isEmpty ? '0' : v;
  }

  Future<void> _sendCommand(String msg, {String? toast}) async {
    final now = DateTime.now();
    if (_sending ||
        now.difference(_lastSend) < const Duration(milliseconds: 200)) {
      return;
    }
    _sending = true;
    _lastSend = now;

    if (!BleManager.instance.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isThai
                ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d BLE'
                : 'BLE not connected',
          ),
        ),
      );
      _sending = false;
      return;
    }

    final owner = _bleTrafficOwner;
    if (owner == null) {
      _sending = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BLE is busy in control mode')),
        );
      }
      return;
    }
    final result = await BleManager.instance.send(msg, owner: owner);
    _sending = false;
    if (result != BleWriteResult.sent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Command not sent: ${result.name}')),
        );
      }
      return;
    }
    if (toast != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toast)));
    }
  }

  String _buildSeqPayload() {
    final parts = <String>[];
    for (final s in _steps) {
      final mode = s.mode == _StepMode.checksum ? 'CHECKSUM' : 'TIME';
      final value = _numOrZero(s.valueCtrl.text);
      final kp = _numOrZero(s.kpCtrl.text);
      final kd = _numOrZero(s.kdCtrl.text);
      final speed = _numOrZero(s.speedCtrl.text);
      final afterMs = s.continueAfter ? _numOrZero(s.afterMsCtrl.text) : '0';
      final afterSpeed = s.continueAfter
          ? _numOrZero(s.afterSpeedCtrl.text)
          : '0';
      final stopMs = s.stopBetween ? _numOrZero(s.stopMsCtrl.text) : '0';
      final holdMs = s.holdMode == 0 ? '0' : _numOrZero(s.holdMsCtrl.text);
      final holdThreshold = s.holdMode == 0
          ? '0'
          : _numOrZero(s.holdThresholdCtrl.text);
      final holdMode = s.holdMode;
      final lineColor = s.lineColor;
      parts.add(
        '$mode,$value,$kp,$kd,$speed,$afterMs,$afterSpeed,$stopMs,$lineColor,$holdMs,$holdThreshold,$holdMode',
      );
    }
    return 'SEQ=${parts.join(';')}';
  }

  String _buildSeqPdPayload() {
    final parts = <String>[];
    for (final s in _steps) {
      final kp = _numOrZero(s.kpCtrl.text);
      final kd = _numOrZero(s.kdCtrl.text);
      final speed = _numOrZero(s.speedCtrl.text);
      parts.add('$kp,$kd,$speed');
    }
    return 'SEQPD=${parts.join(';')}';
  }

  Future<void> _sendSequence() async {
    final now = DateTime.now();
    if (now.difference(_lastSeqSend) < const Duration(seconds: 3)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isThai
                ? 'Please wait 3 seconds before sending again'
                : 'Please wait 3 seconds before sending again',
          ),
        ),
      );
      return;
    }

    if (_steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isThai ? 'No steps to send' : 'No steps to send'),
        ),
      );
      return;
    }

    final payload = _buildSeqPayload();
    await _sendCommand(payload, toast: _isThai ? 'Sent all' : 'Sent all');
    _lastSeqSend = DateTime.now();
  }

  Future<void> _sendSequencePd() async {
    final now = DateTime.now();
    if (now.difference(_lastPdSend) < const Duration(seconds: 1)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isThai
                ? 'Please wait 1 second before sending again'
                : 'Please wait 1 second before sending again',
          ),
        ),
      );
      return;
    }

    if (_steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isThai ? 'No steps to send' : 'No steps to send'),
        ),
      );
      return;
    }

    final payload = _buildSeqPdPayload();
    await _sendCommand(
      payload,
      toast: _isThai ? 'Sent PD+Speed' : 'Sent PD+Speed',
    );
    _lastPdSend = DateTime.now();
  }

  Future<void> _sendSW1() async {
    await _sendCommand('SW1=1', toast: _isThai ? 'Sent SW1' : 'Sent SW1');
  }

  Future<void> _sendReset() async {
    await _sendCommand('RESET=1', toast: _isThai ? 'Sent Reset' : 'Sent Reset');
  }

  void _duplicateStep(int index) {
    final s = _steps[index];
    setState(() {
      _steps.insert(
        index + 1,
        _newStep(
          mode: s.mode,
          kp: _numOrZero(s.kpCtrl.text),
          kd: _numOrZero(s.kdCtrl.text),
          speed: _numOrZero(s.speedCtrl.text),
          value: _numOrZero(s.valueCtrl.text),
          afterMs: _numOrZero(s.afterMsCtrl.text),
          afterSpeed: _numOrZero(s.afterSpeedCtrl.text),
          stopMs: _numOrZero(s.stopMsCtrl.text),
          holdMs: _numOrZero(s.holdMsCtrl.text),
          holdThreshold: _numOrZero(s.holdThresholdCtrl.text),
          lineColor: s.lineColor,
          holdMode: s.holdMode,
          continueAfter: s.continueAfter,
          stopBetween: s.stopBetween,
        ),
      );
      _scheduleAutoSave();
    });
  }

  void _deleteStep(int index) {
    final removed = _steps[index];
    setState(() {
      _steps.removeAt(index);
      _scheduleAutoSave();
    });
    _pendingDeleted.add(removed);
    var restored = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text('Step ${index + 1} deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (!mounted || !_pendingDeleted.remove(removed)) return;
                restored = true;
                setState(() {
                  _steps.insert(index.clamp(0, _steps.length), removed);
                  _scheduleAutoSave();
                });
              },
            ),
          ),
        )
        .closed
        .then((_) {
          if (!restored && _pendingDeleted.remove(removed)) {
            removed.dispose();
          }
        });
  }

  Future<void> _savePresetDialog() async {
    final isThai = _isThai;
    final controller = TextEditingController(
      text: _presets[_selectedPreset].name,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isThai ? 'Save Preset' : 'Save Preset'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            label: Text(isThai ? 'Preset name' : 'Preset name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isThai ? 'Cancel' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(isThai ? 'Save' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final current = _presets[_selectedPreset];
    if (!current.isEmpty) {
      final replace = await showLavenderConfirmDialog(
        context: context,
        title: 'Replace "${current.name}"?',
        message:
            'Preset ${_selectedPreset + 1} already has saved steps. '
            'Save the steps on screen over them?',
        confirmLabel: 'Replace',
        icon: Icons.save_rounded,
      );
      if (!replace || !mounted) return;
    }
    final fallbackName = isThai
        ? 'Preset ${_selectedPreset + 1}'
        : 'Preset ${_selectedPreset + 1}';
    final newName = name.isEmpty ? fallbackName : name;
    setState(() {
      _presets[_selectedPreset] = _PresetSlot(
        name: newName,
        steps: _steps.map((e) => e.toJson()).toList(),
      );
    });
    await _savePresetsToPrefs();
  }

  Future<void> _loadPreset(int index) async {
    final preset = _presets[index];
    if (preset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isThai ? 'This preset is empty' : 'This preset is empty',
          ),
        ),
      );
      return;
    }
    final load = await showLavenderConfirmDialog(
      context: context,
      title: 'Load "${preset.name}"?',
      message: 'The steps on screen will be replaced by this preset.',
      confirmLabel: 'Load',
      icon: Icons.download_rounded,
    );
    if (!load || !mounted) return;
    setState(() {
      for (final s in _steps) {
        s.dispose();
      }
      _steps.clear();
      var nextId = 1;
      for (final item in preset.steps) {
        final modeRaw = (item['mode'] as String?) ?? '';
        final continueAfter = (item['continueAfter'] as bool?) ?? false;
        final parsedMode = modeRaw.toUpperCase() == 'CHECKSUM'
            ? _StepMode.checksum
            : (modeRaw.toUpperCase() == 'TIME' ? _StepMode.time : null);
        final collapsed = (item['collapsed'] as bool?) ?? false;
        final showOptions =
            (item['showOptions'] as bool?) ?? (parsedMode != null);
        _steps.add(
          _StepData(
            id: nextId++,
            mode: parsedMode,
            kp: (item['kp'] as String?) ?? '0',
            kd: (item['kd'] as String?) ?? '0',
            speed: (item['speed'] as String?) ?? '0',
            value: (item['value'] as String?) ?? '0',
            afterMs: (item['afterMs'] as String?) ?? '0',
            afterSpeed: (item['afterSpeed'] as String?) ?? '0',
            stopMs: (item['stopMs'] as String?) ?? '0',
            holdMs: (item['holdMs'] as String?) ?? '0',
            holdThreshold: (item['holdThreshold'] as String?) ?? '0',
            lineColor: (item['lineColor'] as int?) ?? 0,
            holdMode: (item['holdMode'] as int?) ?? 0,
            continueAfter: continueAfter,
            stopBetween: (item['stopBetween'] as bool?) ?? false,
            collapsed: collapsed,
            showOptions: showOptions,
          ),
        );
      }
      _scheduleAutoSave();
    });
  }

  Future<void> _deletePreset(int index) async {
    setState(() {
      _presets[index] = _PresetSlot(name: 'Preset ${index + 1}', steps: []);
    });
    await _savePresetsToPrefs();
  }

  Future<void> _openPresetPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _presetCount,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final title = _presets[i].isEmpty
                  ? '${_presets[i].name} (empty)'
                  : _presets[i].name;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title, overflow: TextOverflow.ellipsis),
                leading: i == _selectedPreset
                    ? const Icon(Icons.check_circle, size: 18)
                    : const SizedBox(width: 18),
                trailing: _presets[i].isEmpty
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final delete = await showLavenderConfirmDialog(
                            context: ctx,
                            title: 'Delete "${_presets[i].name}"?',
                            message:
                                'Its saved steps are removed. '
                                'The steps on screen stay.',
                            confirmLabel: 'Delete',
                            icon: Icons.delete_outline_rounded,
                            destructive: true,
                          );
                          if (!delete) return;
                          await _deletePreset(i);
                          if (ctx.mounted) Navigator.pop(ctx, _selectedPreset);
                        },
                        child: const Text('Delete'),
                      ),
                onTap: () => Navigator.pop(ctx, i),
              );
            },
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() => _selectedPreset = selected);
  }

  void _moveStep(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _steps.length) return;
    setState(() {
      final item = _steps.removeAt(index);
      _steps.insert(target, item);
      _scheduleAutoSave();
    });
  }

  void _setMode(_StepData step, _StepMode mode) {
    setState(() {
      if (step.mode == mode) {
        // Tapping the selected mode shows / hides its options.
        step.showOptions = !step.showOptions;
      } else {
        step.mode = mode;
        step.valueCtrl.text = '0';
        step.showOptions = true;
      }
      _scheduleAutoSave();
    });
  }

  Widget _buildStepCard(BuildContext context, int index, bool isCompact) {
    final step = _steps[index];
    final tone = _StepTone.of(step.mode);
    final isTime = step.mode == _StepMode.time;
    final modeLabel = switch (step.mode) {
      _StepMode.time => ' (Time)',
      _StepMode.checksum => ' (CheckSum)',
      null => '',
    };
    final collapsed = step.collapsed;

    Widget gap([double h = 10]) => SizedBox(height: h);

    final header = Row(
      children: [
        Expanded(
          child: Tooltip(
            message: collapsed ? 'Expand step' : 'Collapse step',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                step.collapsed = !step.collapsed;
                _scheduleAutoSave();
              }),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tone.solid,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Step ${index + 1}$modeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      collapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      size: 22,
                      color: tone.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _StepIconButton(
          tooltip: 'Move up',
          icon: Icons.keyboard_arrow_up_rounded,
          onPressed: index == 0 ? null : () => _moveStep(index, -1),
        ),
        _StepIconButton(
          tooltip: 'Move down',
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: index == _steps.length - 1
              ? null
              : () => _moveStep(index, 1),
        ),
        PopupMenuButton<_StepAction>(
          tooltip: 'More',
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: LavenderPalette.ink,
          ),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (action) => switch (action) {
            _StepAction.duplicate => _duplicateStep(index),
            _StepAction.delete => _deleteStep(index),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _StepAction.duplicate,
              child: _MenuRow(icon: Icons.copy_all_rounded, label: 'Duplicate'),
            ),
            PopupMenuItem(
              value: _StepAction.delete,
              child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: LavenderPalette.coral,
              ),
            ),
          ],
        ),
      ],
    );

    final List<Widget> body;
    if (collapsed) {
      body = [
        gap(4),
        Row(
          children: [
            Expanded(
              child: _ValuePill(
                label: 'KP',
                value: _numOrZero(step.kpCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValuePill(
                label: 'KD',
                value: _numOrZero(step.kdCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ValuePill(
                label: 'Speed',
                value: _numOrZero(step.speedCtrl.text),
              ),
            ),
          ],
        ),
      ];
    } else {
      final kp = _NumberField(
        label: 'KP',
        controller: step.kpCtrl,
        onChanged: _scheduleAutoSave,
      );
      final kd = _NumberField(
        label: 'KD',
        controller: step.kdCtrl,
        onChanged: _scheduleAutoSave,
      );
      final speed = _NumberField(
        label: 'Speed',
        controller: step.speedCtrl,
        onChanged: _onSpeedChanged,
      );
      final holdOff = step.holdMode == 0;
      body = [
        gap(6),
        if (isCompact) ...[
          Row(
            children: [
              Expanded(child: kp),
              const SizedBox(width: 10),
              Expanded(child: kd),
            ],
          ),
          gap(),
          speed,
        ] else
          Row(
            children: [
              Expanded(child: kp),
              const SizedBox(width: 10),
              Expanded(child: kd),
              const SizedBox(width: 10),
              Expanded(child: speed),
            ],
          ),
        gap(6),
        _PresetChips(
          values: const [
            '0',
            '10',
            '20',
            '30',
            '40',
            '50',
            '60',
            '70',
            '80',
            '90',
            '100',
          ],
          controller: step.speedCtrl,
          accent: tone.ink,
          onChanged: _onSpeedChanged,
        ),
        gap(8),
        const _FieldCaption('Line color'),
        _GlassSegments<int>(
          accent: tone.ink,
          selected: step.lineColor,
          options: const [(0, 'Black'), (1, 'White')],
          onSelected: (v) => setState(() {
            step.lineColor = v;
            _scheduleAutoSave();
          }),
        ),
        gap(),
        Row(
          children: [
            const Expanded(child: _FieldCaption('Mode')),
            if (step.mode != null)
              _StepIconButton(
                tooltip: step.showOptions ? 'Hide options' : 'Show options',
                icon: step.showOptions
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: tone.ink,
                onPressed: () => setState(() {
                  step.showOptions = !step.showOptions;
                  _scheduleAutoSave();
                }),
              ),
          ],
        ),
        _GlassSegments<_StepMode>(
          accent: tone.ink,
          selected: step.mode,
          options: const [
            (_StepMode.time, 'Time'),
            (_StepMode.checksum, 'CheckSum'),
          ],
          onSelected: (mode) => _setMode(step, mode),
        ),
        if (step.mode != null && step.showOptions) ...[
          gap(),
          _NumberField(
            label: isTime ? 'Milliseconds (ms)' : 'Line Count / Target',
            controller: step.valueCtrl,
            onChanged: _scheduleAutoSave,
          ),
          gap(),
          const _FieldCaption('Junction hold'),
          _GlassSegments<int>(
            accent: tone.ink,
            selected: step.holdMode,
            options: const [(0, 'Off'), (1, 'All Black'), (2, 'All White')],
            onSelected: (v) => setState(() {
              step.holdMode = v;
              _scheduleAutoSave();
            }),
          ),
          gap(8),
          _DisabledWhen(
            disabled: holdOff,
            child: Column(
              children: [
                _NumberField(
                  label: 'Straight (ms)',
                  controller: step.holdMsCtrl,
                  onChanged: _scheduleAutoSave,
                ),
                gap(8),
                _NumberField(
                  label: 'SUM threshold',
                  controller: step.holdThresholdCtrl,
                  onChanged: _scheduleAutoSave,
                ),
              ],
            ),
          ),
          gap(6),
          _SwitchRow(
            label: 'Continue PD after condition',
            value: step.continueAfter,
            accent: tone.ink,
            onChanged: (v) => setState(() {
              step.continueAfter = v;
              _scheduleAutoSave();
            }),
          ),
          _DisabledWhen(
            disabled: !step.continueAfter,
            child: Column(
              children: [
                _NumberField(
                  label: 'Continue (ms)',
                  controller: step.afterMsCtrl,
                  onChanged: _scheduleAutoSave,
                ),
                gap(8),
                _NumberField(
                  label: 'Continue Speed',
                  controller: step.afterSpeedCtrl,
                  onChanged: _scheduleAutoSave,
                ),
              ],
            ),
          ),
          gap(6),
          _SwitchRow(
            label: 'Stop before next step',
            value: step.stopBetween,
            accent: tone.ink,
            onChanged: (v) => setState(() {
              step.stopBetween = v;
              _scheduleAutoSave();
            }),
          ),
          _DisabledWhen(
            disabled: !step.stopBetween,
            child: _NumberField(
              label: 'Stop (ms)',
              controller: step.stopMsCtrl,
              onChanged: _scheduleAutoSave,
            ),
          ),
        ],
      ];
    }

    return Padding(
      key: ValueKey(step.id),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassPanel(
        radius: 22,
        tint: tone.tint,
        tintStrength: 0.12,
        shadowStrength: 0.6,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addStep() {
    setState(() {
      _steps.add(_newStep());
      _scheduleAutoSave();
    });
  }

  /// Fixed glass bar: Send PD+Speed / Send All, then SW1 / Reset board.
  Widget _buildActionBar() {
    final busy = _sending;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: GlassPanel(
        radius: 26,
        shadowStrength: 0.8,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: GlassActionButton(
                    label: 'Send PD+Speed',
                    icon: Icons.tune_rounded,
                    height: 48,
                    onPressed: busy ? null : _sendSequencePd,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientActionButton(
                    label: 'Send All',
                    icon: Icons.send_rounded,
                    height: 48,
                    onPressed: busy ? null : _sendSequence,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GlassActionButton(
                    label: 'SW1',
                    icon: Icons.touch_app_rounded,
                    height: 48,
                    accent: LavenderPalette.cyanDeep,
                    onPressed: busy ? null : _sendSW1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassActionButton(
                    label: 'Reset Board',
                    icon: Icons.power_settings_new_rounded,
                    height: 48,
                    accent: LavenderPalette.coral,
                    onPressed: busy ? null : _sendReset,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 380;

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_exitPage());
          },
          child: LineSonicScaffold(
            title: 'PID Tuning',
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: LineSonicScaffold.contentTop(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThai ? 'Mission Timeline' : 'Mission Timeline',
                          style: t.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _openPresetPicker,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    label: Text(isThai ? 'Preset' : 'Preset'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _presets[_selectedPreset].isEmpty
                                              ? '${_presets[_selectedPreset].name} (${isThai ? 'empty' : 'empty'})'
                                              : _presets[_selectedPreset].name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: isThai ? 'Save preset' : 'Save preset',
                              onPressed: _savePresetDialog,
                              icon: const Icon(Icons.save_outlined),
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton.outlined(
                              tooltip: isThai ? 'Load preset' : 'Load preset',
                              onPressed: () => _loadPreset(_selectedPreset),
                              icon: const Icon(Icons.download_outlined),
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverReorderableList(
                  itemCount: _steps.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _steps.removeAt(oldIndex);
                      _steps.insert(newIndex, item);
                      _scheduleAutoSave();
                    });
                  },
                  itemBuilder: (context, index) =>
                      _buildStepCard(context, index, isCompact),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: GlassActionButton(
                      label: 'Add Step',
                      icon: Icons.add_rounded,
                      height: 52,
                      onPressed: _addStep,
                    ),
                  ),
                ),
              ],
            ),
            bottomBar: _buildActionBar(),
          ),
        );
      },
    );
  }
}

enum _StepAction { duplicate, delete }

/// Colours for a step card: Time = violet, CheckSum = cyan, no mode = muted.
class _StepTone {
  const _StepTone(this.tint, this.solid, this.ink);

  final Color tint;
  final Color solid;
  final Color ink;

  static _StepTone of(_StepMode? mode) => switch (mode) {
    _StepMode.time => const _StepTone(
      LavenderPalette.violetBright,
      LavenderPalette.violet,
      LavenderPalette.violetDeep,
    ),
    _StepMode.checksum => const _StepTone(
      LavenderPalette.cyan,
      LavenderPalette.cyanDeep,
      LavenderPalette.cyanDeep,
    ),
    null => const _StepTone(
      LavenderPalette.inkMuted,
      Color(0xFF8C8399),
      LavenderPalette.inkSoft,
    ),
  };
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = LavenderPalette.ink,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 48 px icon button used on step cards.
class _StepIconButton extends StatelessWidget {
  const _StepIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = LavenderPalette.ink,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      color: color,
      disabledColor: LavenderPalette.ink.withValues(alpha: 0.22),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
    );
  }
}

class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: LavenderPalette.inkSoft,
        ),
      ),
    );
  }
}

/// Glass segmented control with 48 px segments.
class _GlassSegments<T> extends StatelessWidget {
  const _GlassSegments({
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(color: LavenderPalette.ink.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: Material(
                  color: value == selected
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: value == selected
                        ? BorderSide(color: accent.withValues(alpha: 0.45))
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: value == selected
                                  ? accent
                                  : LavenderPalette.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label + full-size switch; the whole 48 px row toggles it.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LavenderPalette.ink,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims and blocks a group of fields that do not apply right now.
class _DisabledWhen extends StatelessWidget {
  const _DisabledWhen({required this.disabled, required this.child});

  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: disabled,
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: LavenderPalette.ink,
      ),
      onTap: () {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      onChanged: (_) => onChanged(),
      onEditingComplete: () {
        if (controller.text.trim().isEmpty) {
          controller.text = '0';
        }
        FocusScope.of(context).unfocus();
        onChanged();
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          color: LavenderPalette.inkSoft,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: LavenderPalette.violetDeep,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        border: border(LavenderPalette.ink.withValues(alpha: 0.14)),
        enabledBorder: border(LavenderPalette.ink.withValues(alpha: 0.14)),
        focusedBorder: border(LavenderPalette.violet, 1.6),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String label;
  final String value;

  const _ValuePill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LavenderPalette.ink.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LavenderPalette.inkSoft,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LavenderPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick speed values; each chip is a 48 px target around a 36 px pill.
class _PresetChips extends StatelessWidget {
  final List<String> values;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final Color accent;

  const _PresetChips({
    required this.values,
    required this.controller,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    return Wrap(
      spacing: 2,
      children: values.map((v) {
        final selected = current == v;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Speed $v',
          excludeSemantics: true,
          child: InkResponse(
            radius: 26,
            onTap: () {
              controller.text = v;
              onChanged();
            },
            child: SizedBox(
              height: 48,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48),
                child: Center(
                  widthFactor: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 34,
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: 0.5)
                            : LavenderPalette.ink.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? accent : LavenderPalette.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
