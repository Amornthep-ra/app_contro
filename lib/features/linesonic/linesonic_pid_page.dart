// lib/features/linesonic/linesonic_pid_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/widgets/gamepad_app_bar.dart';
import '../../core/widgets/portrait_background.dart';
import 'linesonic_protocol.dart';

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

  /// A step as saved by [toJson]. Values of an unexpected type fall back to
  /// defaults instead of throwing, so one odd field cannot lose all steps.
  factory _StepData.fromJson(int id, Map<String, dynamic> json) {
    final modeRaw = _jsonText(json['mode'], '').toUpperCase();
    final mode = switch (modeRaw) {
      'CHECKSUM' => _StepMode.checksum,
      'TIME' => _StepMode.time,
      _ => null,
    };
    return _StepData(
      id: id,
      mode: mode,
      kp: _jsonText(json['kp']),
      kd: _jsonText(json['kd']),
      speed: _jsonText(json['speed']),
      value: _jsonText(json['value']),
      afterMs: _jsonText(json['afterMs']),
      afterSpeed: _jsonText(json['afterSpeed']),
      stopMs: _jsonText(json['stopMs']),
      holdMs: _jsonText(json['holdMs']),
      holdThreshold: _jsonText(json['holdThreshold']),
      lineColor: _jsonInt(json['lineColor'], max: 1),
      holdMode: _jsonInt(json['holdMode'], max: 2),
      continueAfter: _jsonBool(json['continueAfter'], false),
      stopBetween: _jsonBool(json['stopBetween'], false),
      collapsed: _jsonBool(json['collapsed'], false),
      showOptions: _jsonBool(json['showOptions'], mode != null),
    );
  }

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

/// A saved field as text: numbers are accepted too (older or hand-edited
/// data), anything else is [fallback].
String _jsonText(Object? value, [String fallback = '0']) => switch (value) {
  final String text => text,
  final num number => number.toString(),
  _ => fallback,
};

/// A saved choice index in 0..[max]; text and decimals are accepted.
int _jsonInt(Object? value, {required int max}) {
  final parsed = switch (value) {
    final num number => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };
  return (parsed ?? 0).clamp(0, max);
}

bool _jsonBool(Object? value, bool fallback) =>
    value is bool ? value : fallback;

/// The step objects in a saved list; anything else in it is skipped.
List<Map<String, dynamic>> _jsonSteps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : const [];

class _PresetSlot {
  _PresetSlot({required this.name, required this.steps});

  String name;
  List<Map<String, dynamic>> steps;

  bool get isEmpty => steps.isEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'steps': steps};

  static _PresetSlot fromJson(Map<String, dynamic> json) => _PresetSlot(
    name: _jsonText(json['name'], ''),
    steps: _jsonSteps(json['steps']),
  );
}

class LineSonicPidPage extends StatefulWidget {
  const LineSonicPidPage({super.key, this.sendOverride});

  /// Replaces the BLE write in tests.
  @visibleForTesting
  final Future<BleWriteResult> Function(String command)? sendOverride;

  @override
  State<LineSonicPidPage> createState() => _LineSonicPidPageState();
}

class _LineSonicPidPageState extends State<LineSonicPidPage> {
  static const _prefsStepsKey = 'linesonic_steps_v2';
  static const _prefsPresetsKey = 'linesonic_presets_v1';
  static const _presetCount = 10;

  final List<_StepData> _steps = [];
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

  /// Saved steps and presets are in. Until then editing is off and nothing
  /// is saved, so loading cannot drop edits or saving overwrite old data.
  bool _loaded = false;

  /// Set when reading the saved data threw: the page still opens with a
  /// step, but saves nothing, so what is stored is not overwritten.
  bool _savingDisabled = false;
  int? _bleTrafficOwner;

  /// [LineSonicProtocol.sequenceShape] of the last Send All this page made
  /// on the current link; null when the board may hold other steps (none
  /// sent yet, Reset, or the link dropped).
  String? _boardShape;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _bleTrafficOwner = BleManager.instance.claimTrafficMode(
      BleTrafficMode.textCommand,
      ownerName: 'linesonic_pid',
    );
    _connectionSub = BleManager.instance.connectionStream.listen((connected) {
      if (!connected) _boardShape = null;
    });
    _initAsync();
  }

  Future<void> _initAsync() async {
    var presetsRead = true;
    var stepsRead = true;
    var failed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _leavingPage) return;
      // Each is read on its own: one unreadable entry does not stop the
      // other.
      presetsRead = await _loadPresets(prefs);
      stepsRead = await _loadSteps(prefs);
    } catch (error) {
      failed = true;
      debugPrint('PID steps load failed: $error');
    }
    if (!mounted || _leavingPage) return;
    if (_steps.isEmpty) {
      _steps.add(_newStep());
    }
    setState(() {
      _savingDisabled = failed;
      _loaded = true;
    });
    if (failed) {
      _showSnack(
        'Saved PID steps could not be read. Changes here will not be saved.',
      );
      return;
    }
    final unreadable = [
      if (!stepsRead) 'PID steps',
      if (!presetsRead) 'PID presets',
    ];
    if (unreadable.isNotEmpty) {
      _showSnack(
        'Saved ${unreadable.join(' and ')} could not be read. '
        'A copy was kept.',
      );
    }
  }

  /// Decodes the list saved under [key]; null when there is none. When it
  /// cannot be read, keeps the text under `<key>_unreadable` (before
  /// anything is saved over it) and reports false.
  Future<(List<Object?>?, bool)> _readSavedList(
    SharedPreferences prefs,
    String key,
  ) async {
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return (null, true);
    try {
      final data = jsonDecode(raw);
      if (data is List) return (data, true);
    } on FormatException {
      // Kept below.
    }
    await prefs.setString('${key}_unreadable', raw);
    return (null, false);
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _autosaveTimer?.cancel();
    _leavingPage = true;
    unawaited(_flushSteps());
    for (final s in _steps) {
      s.dispose();
    }
    final trafficOwner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (trafficOwner != null) {
      BleManager.instance.releaseTrafficMode(trafficOwner);
    }
    super.dispose();
  }

  void _scheduleAutoSave() {
    if (!_loaded || _savingDisabled) return;
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

  /// False when the saved steps could not be read (a copy is kept).
  Future<bool> _loadSteps(SharedPreferences prefs) async {
    final (data, readable) = await _readSavedList(prefs, _prefsStepsKey);
    if (data == null) return readable;
    for (final s in _steps) {
      s.dispose();
    }
    _steps.clear();
    var nextId = 1;
    for (final item in _jsonSteps(data)) {
      _steps.add(_StepData.fromJson(nextId++, item));
    }
    return true;
  }

  Future<void> _savePresetsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _presets.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsPresetsKey, jsonEncode(data));
  }

  /// False when the saved presets could not be read (a copy is kept).
  Future<bool> _loadPresets(SharedPreferences prefs) async {
    final (data, readable) = await _readSavedList(prefs, _prefsPresetsKey);
    if (data == null) return readable;
    for (var i = 0; i < _presetCount && i < data.length; i++) {
      final item = data[i];
      if (item is! Map) continue;
      _presets[i] = _PresetSlot.fromJson(Map<String, dynamic>.from(item));
      if (_presets[i].name.trim().isEmpty) {
        _presets[i].name = 'Preset ${i + 1}';
      }
    }
    return true;
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

  /// Shortest gap between two commands to the board.
  static const _minCommandGap = Duration(milliseconds: 200);

  void _setSending(bool sending) {
    if (!mounted) {
      _sending = sending;
      return;
    }
    setState(() => _sending = sending);
  }

  /// Sends [msg] and returns whether it went out. The send buttons are
  /// disabled meanwhile; a press right after the last command waits out
  /// [_minCommandGap] instead of being dropped.
  Future<bool> _sendCommand(String msg, {String? toast}) async {
    if (_sending) return false;
    _setSending(true);
    try {
      final wait = _minCommandGap - DateTime.now().difference(_lastSend);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!mounted) return false;
      final override = widget.sendOverride;
      if (override == null && !BleManager.instance.isConnected) {
        _showSnack('BLE not connected');
        return false;
      }
      final owner = _bleTrafficOwner;
      if (owner == null) {
        _showSnack('BLE is busy in control mode');
        return false;
      }
      _lastSend = DateTime.now();
      final result = override != null
          ? await override(msg)
          : await BleManager.instance.send(msg, owner: owner);
      if (result != BleWriteResult.sent) {
        _showSnack('Command not sent: ${result.name}');
        return false;
      }
      if (toast != null) _showSnack(toast);
      return true;
    } finally {
      _setSending(false);
    }
  }

  LineSonicStepInput _inputOf(_StepData s) => LineSonicStepInput(
    mode: switch (s.mode) {
      _StepMode.time => LineSonicStepMode.time,
      _StepMode.checksum => LineSonicStepMode.checksum,
      null => null,
    },
    value: s.valueCtrl.text,
    kp: s.kpCtrl.text,
    kd: s.kdCtrl.text,
    speed: s.speedCtrl.text,
    afterMs: s.afterMsCtrl.text,
    afterSpeed: s.afterSpeedCtrl.text,
    stopMs: s.stopMsCtrl.text,
    holdMs: s.holdMsCtrl.text,
    holdThreshold: s.holdThresholdCtrl.text,
    lineColor: s.lineColor,
    holdMode: s.holdMode,
    continueAfter: s.continueAfter,
    stopBetween: s.stopBetween,
  );

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The steps as numbers, or null after telling the user what to fix.
  List<LineSonicStep>? _checkedSteps() {
    final result = LineSonicProtocol.checkSteps(_steps.map(_inputOf).toList());
    if (result.tooManySteps) {
      _showSnack(
        'The board runs at most ${LineSonicProtocol.maxSteps} steps. '
        'Remove ${_steps.length - LineSonicProtocol.maxSteps}.',
      );
      return null;
    }
    if (result.errors.isNotEmpty) {
      final more = result.errors.length - 1;
      _showSnack('${result.errors.first}${more > 0 ? ' (+$more more)' : ''}');
      return null;
    }
    return result.steps;
  }

  /// False after telling the user, when [payload] would be split over
  /// several BLE writes: the board reads each write on its own.
  bool _fitsOneWrite(
    List<LineSonicStep> steps,
    String Function(List<LineSonicStep> steps) build,
  ) {
    final payload = build(steps);
    final manager = BleManager.instance;
    // Not connected: _sendCommand says so.
    if (!manager.isConnected) return true;
    final payloadSize = manager.payloadSize;
    if (LineSonicProtocol.fitsInOneWrite(payload, payloadSize: payloadSize)) {
      return true;
    }
    final fit = LineSonicProtocol.stepsThatFit(
      steps,
      payloadSize: payloadSize,
      build: build,
    );
    _showSnack(
      'Too long to send at once: this phone fits $fit of '
      '${steps.length} steps.',
    );
    return false;
  }

  Future<void> _sendSequence() async {
    final now = DateTime.now();
    if (now.difference(_lastSeqSend) < const Duration(seconds: 3)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait 3 seconds before sending again')),
      );
      return;
    }

    if (_steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No steps to send')));
      return;
    }

    final steps = _checkedSteps();
    if (steps == null) return;
    if (!_fitsOneWrite(steps, LineSonicProtocol.sequence)) return;
    if (await _sendCommand(
      LineSonicProtocol.sequence(steps),
      toast: 'Sent all',
    )) {
      _lastSeqSend = DateTime.now();
      _boardShape = LineSonicProtocol.sequenceShape(steps);
    }
  }

  Future<void> _sendSequencePd() async {
    final now = DateTime.now();
    if (now.difference(_lastPdSend) < const Duration(seconds: 1)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait 1 second before sending again')),
      );
      return;
    }

    if (_steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No steps to send')));
      return;
    }

    // The board applies SEQPD= by index to the steps it already has, and
    // ignores it without any: only send it over the steps of the last Send
    // All.
    final boardShape = _boardShape;
    if (boardShape == null) {
      _showSnack('Send All first: the board has no steps from this page.');
      return;
    }
    final result = LineSonicProtocol.checkSteps(_steps.map(_inputOf).toList());
    final pdErrors = result.errors.where(
      (e) =>
          e.field == LineSonicField.kp ||
          e.field == LineSonicField.kd ||
          e.field == LineSonicField.speed,
    );
    if (pdErrors.isNotEmpty) {
      final more = pdErrors.length - 1;
      _showSnack('${pdErrors.first}${more > 0 ? ' (+$more more)' : ''}');
      return;
    }
    final steps = result.steps;
    if (!result.ok || LineSonicProtocol.sequenceShape(steps) != boardShape) {
      _showSnack('Steps changed since Send All. Send All first.');
      return;
    }
    if (!_fitsOneWrite(steps, LineSonicProtocol.sequencePd)) return;
    if (await _sendCommand(
      LineSonicProtocol.sequencePd(steps),
      toast: 'Sent PD+Speed',
    )) {
      _lastPdSend = DateTime.now();
    }
  }

  Future<void> _sendSW1() async {
    await _sendCommand(LineSonicProtocol.sw1, toast: 'Sent SW1');
  }

  Future<void> _sendReset() async {
    // The board restarts and forgets its steps.
    if (await _sendCommand(LineSonicProtocol.reset, toast: 'Sent Reset')) {
      _boardShape = null;
    }
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
    setState(() {
      _steps[index].dispose();
      _steps.removeAt(index);
      _scheduleAutoSave();
    });
  }

  Future<void> _savePresetDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _PresetNameDialog(initialName: _presets[_selectedPreset].name),
    );
    if (name == null || !mounted) return;
    final fallbackName = 'Preset ${_selectedPreset + 1}';
    final newName = name.isEmpty ? fallbackName : name;
    setState(() {
      _presets[_selectedPreset] = _PresetSlot(
        name: newName,
        steps: _steps.map((e) => e.toJson()).toList(),
      );
    });
    await _savePresetsToPrefs();
  }

  void _loadPreset(int index) {
    final preset = _presets[index];
    if (preset.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('This preset is empty')));
      return;
    }
    setState(() {
      for (final s in _steps) {
        s.dispose();
      }
      _steps.clear();
      var nextId = 1;
      for (final item in preset.steps) {
        _steps.add(_StepData.fromJson(nextId++, item));
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

    if (selected == null || !mounted) return;
    setState(() => _selectedPreset = selected);
  }

  Widget _buildPlainBackButton() {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.chevron_left_rounded, size: 30),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.maybePop(context);
        },
        padding: EdgeInsets.zero,
        splashRadius: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 380;
    final compactBleMetrics = media.textScaler.scale(1) > 1.3
        ? GamepadAppBarMetrics.forWidth(media.size.width)
        : null;
    final sendBg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);
    final sendFg = isDark ? const Color(0xFF0B1020) : Colors.white;
    final sw1Fg = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
    final resetFg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    final pdBg = isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
    final pdFg = isDark ? const Color(0xFF0B1020) : Colors.white;

    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_exitPage());
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 44,
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: scheme.onSurface,
          leading: Navigator.of(context).canPop()
              ? _buildPlainBackButton()
              : null,
          centerTitle: true,
          title: Text(
            'PID Tuning',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: scheme.onSurface,
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: ConnectionStatusBadge(appBarMetrics: compactBleMetrics),
            ),
          ],
        ),
        body: PortraitBackground(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top + 44),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mission Timeline',
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
                                  label: Text('Preset'),
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
                                            ? '${_presets[_selectedPreset].name} (empty)'
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
                            tooltip: 'Save preset',
                            onPressed: _loaded && !_savingDisabled
                                ? _savePresetDialog
                                : null,
                            icon: const Icon(Icons.save_outlined),
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.outlined(
                            tooltip: 'Load preset',
                            onPressed: _loaded
                                ? () => _loadPreset(_selectedPreset)
                                : null,
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
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  final hasMode = step.mode != null;
                  final isTime = step.mode == _StepMode.time;
                  final isCollapsed = step.collapsed;
                  final modeLabel = hasMode
                      ? (isTime ? 'Time' : 'CheckSum')
                      : '';
                  final tone = hasMode
                      ? (isTime
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFFF59E0B))
                      : (isDark
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF94A3B8));
                  final toneBg = hasMode
                      ? (isTime
                            ? (isDark
                                  ? const Color(0xFF0B1D3A)
                                  : const Color(0xFFEFF6FF))
                            : (isDark
                                  ? const Color(0xFF3A2500)
                                  : const Color(0xFFFFF7ED)))
                      : (isDark
                            ? const Color(0xFF111827)
                            : const Color(0xFFF1F5F9));

                  return Material(
                    key: ValueKey(step.id),
                    color: toneBg,
                    elevation: 0,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tone.withValues(alpha: isDark ? 0.5 : 0.35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  step.collapsed = !step.collapsed;
                                  _scheduleAutoSave();
                                });
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tone,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'Step ${index + 1}${modeLabel.isEmpty ? '' : ' ($modeLabel)'}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          isCollapsed
                                              ? Icons.expand_more
                                              : Icons.expand_less,
                                          size: 18,
                                          color: tone,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Duplicate',
                                        onPressed: () => _duplicateStep(index),
                                        icon: const Icon(
                                          Icons.copy_all_outlined,
                                        ),
                                        iconSize: 18,
                                        visualDensity: const VisualDensity(
                                          horizontal: -2,
                                          vertical: -2,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteStep(index),
                                        icon: const Icon(Icons.delete_outline),
                                        iconSize: 18,
                                        visualDensity: const VisualDensity(
                                          horizontal: -2,
                                          vertical: -2,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Move up',
                                        onPressed: index == 0
                                            ? null
                                            : () {
                                                setState(() {
                                                  final item = _steps.removeAt(
                                                    index,
                                                  );
                                                  _steps.insert(
                                                    index - 1,
                                                    item,
                                                  );
                                                  _scheduleAutoSave();
                                                });
                                              },
                                        icon: const Icon(
                                          Icons.keyboard_arrow_up,
                                        ),
                                        iconSize: 20,
                                        visualDensity: const VisualDensity(
                                          horizontal: -2,
                                          vertical: -2,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Move down',
                                        onPressed: index == _steps.length - 1
                                            ? null
                                            : () {
                                                setState(() {
                                                  final item = _steps.removeAt(
                                                    index,
                                                  );
                                                  _steps.insert(
                                                    index + 1,
                                                    item,
                                                  );
                                                  _scheduleAutoSave();
                                                });
                                              },
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                        ),
                                        iconSize: 20,
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
                            Column(
                              children: [
                                if (isCollapsed) ...[
                                  const SizedBox(height: 6),
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
                                          value: _numOrZero(
                                            step.speedCtrl.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (!isCollapsed) ...[
                                  const SizedBox(height: 8),
                                  if (isCompact) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _NumberField(
                                            label: 'KP',
                                            controller: step.kpCtrl,
                                            onChanged: _scheduleAutoSave,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _NumberField(
                                            label: 'KD',
                                            controller: step.kdCtrl,
                                            onChanged: _scheduleAutoSave,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _NumberField(
                                      label: 'Speed',
                                      controller: step.speedCtrl,
                                      onChanged: _onSpeedChanged,
                                    ),
                                    const SizedBox(height: 8),
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
                                      onChanged: _onSpeedChanged,
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _NumberField(
                                            label: 'KP',
                                            controller: step.kpCtrl,
                                            onChanged: _scheduleAutoSave,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _NumberField(
                                            label: 'KD',
                                            controller: step.kdCtrl,
                                            onChanged: _scheduleAutoSave,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _NumberField(
                                            label: 'Speed',
                                            controller: step.speedCtrl,
                                            onChanged: _onSpeedChanged,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
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
                                      onChanged: _onSpeedChanged,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Line color',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SegmentedButton<int>(
                                          segments: [
                                            ButtonSegment(
                                              value: 0,
                                              label: Text(
                                                'Black',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            ButtonSegment(
                                              value: 1,
                                              label: Text(
                                                'White',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                          selected: <int>{step.lineColor},
                                          style: const ButtonStyle(
                                            visualDensity: VisualDensity(
                                              horizontal: -2,
                                              vertical: -2,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: WidgetStatePropertyAll(
                                              EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                            ),
                                          ),
                                          onSelectionChanged: (s) {
                                            if (s.isEmpty) return;
                                            setState(() {
                                              step.lineColor = s.first;
                                              _scheduleAutoSave();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Mode',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SegmentedButton<_StepMode>(
                                          segments: [
                                            ButtonSegment(
                                              value: _StepMode.time,
                                              label: Text(
                                                'Time',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            ButtonSegment(
                                              value: _StepMode.checksum,
                                              label: Text(
                                                'CheckSum',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                          emptySelectionAllowed: true,
                                          selected: step.mode == null
                                              ? const <_StepMode>{}
                                              : <_StepMode>{step.mode!},
                                          style: const ButtonStyle(
                                            visualDensity: VisualDensity(
                                              horizontal: -2,
                                              vertical: -2,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: WidgetStatePropertyAll(
                                              EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                            ),
                                          ),
                                          onSelectionChanged: (s) {
                                            setState(() {
                                              if (s.isEmpty) {
                                                // Toggle options visibility without clearing mode
                                                step.showOptions =
                                                    !step.showOptions;
                                              } else {
                                                final nextMode = s.first;
                                                if (step.mode != nextMode) {
                                                  step.mode = nextMode;
                                                  step.valueCtrl.text = '0';
                                                }
                                                step.showOptions = true;
                                              }
                                              _scheduleAutoSave();
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        step.showOptions
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 16,
                                        color: tone,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (step.mode != null &&
                                      step.showOptions) ...[
                                    _NumberField(
                                      label: isTime
                                          ? 'Milliseconds (ms)'
                                          : 'Line Count / Target',
                                      controller: step.valueCtrl,
                                      onChanged: _scheduleAutoSave,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SegmentedButton<int>(
                                            segments: [
                                              ButtonSegment(
                                                value: 0,
                                                label: Text(
                                                  'Off',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: 1,
                                                label: Text(
                                                  'All Black',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: 2,
                                                label: Text(
                                                  'All White',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            selected: <int>{step.holdMode},
                                            style: const ButtonStyle(
                                              visualDensity: VisualDensity(
                                                horizontal: -2,
                                                vertical: -2,
                                              ),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: WidgetStatePropertyAll(
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                            onSelectionChanged: (s) {
                                              if (s.isEmpty) return;
                                              setState(() {
                                                step.holdMode = s.first;
                                                _scheduleAutoSave();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    IgnorePointer(
                                      ignoring: step.holdMode == 0,
                                      child: Opacity(
                                        opacity: step.holdMode == 0 ? 0.4 : 1.0,
                                        child: Column(
                                          children: [
                                            _NumberField(
                                              label: 'Straight (ms)',
                                              controller: step.holdMsCtrl,
                                              onChanged: _scheduleAutoSave,
                                            ),
                                            const SizedBox(height: 6),
                                            _NumberField(
                                              label: 'SUM threshold',
                                              controller:
                                                  step.holdThresholdCtrl,
                                              onChanged: _scheduleAutoSave,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.65,
                                          child: Switch(
                                            value: step.continueAfter,
                                            onChanged: (v) {
                                              setState(() {
                                                step.continueAfter = v;
                                                _scheduleAutoSave();
                                              });
                                            },
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Continue PD after condition',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    IgnorePointer(
                                      ignoring: !step.continueAfter,
                                      child: Opacity(
                                        opacity: step.continueAfter ? 1.0 : 0.4,
                                        child: Column(
                                          children: [
                                            _NumberField(
                                              label: 'Continue (ms)',
                                              controller: step.afterMsCtrl,
                                              onChanged: _scheduleAutoSave,
                                            ),
                                            const SizedBox(height: 6),
                                            _NumberField(
                                              label: 'Continue Speed',
                                              controller: step.afterSpeedCtrl,
                                              onChanged: _scheduleAutoSave,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.65,
                                          child: Switch(
                                            value: step.stopBetween,
                                            onChanged: (v) {
                                              setState(() {
                                                step.stopBetween = v;
                                                _scheduleAutoSave();
                                              });
                                            },
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Stop before next step',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    IgnorePointer(
                                      ignoring: !step.stopBetween,
                                      child: Opacity(
                                        opacity: step.stopBetween ? 1.0 : 0.4,
                                        child: _NumberField(
                                          label: 'Stop (ms)',
                                          controller: step.stopMsCtrl,
                                          onChanged: _scheduleAutoSave,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _sending ? null : _sendSequence,
                                icon: const Icon(Icons.send),
                                label: Text('Send All'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: sendBg,
                                  foregroundColor: sendFg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: FilledButton.tonalIcon(
                                onPressed: _sending ? null : _sendSequencePd,
                                icon: const Icon(Icons.tune),
                                label: Text('Send PD+Speed'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: pdBg,
                                  foregroundColor: pdFg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: sw1Fg,
                                  side: BorderSide(color: sw1Fg),
                                ),
                                onPressed: _sending ? null : _sendSW1,
                                icon: const Icon(Icons.touch_app, size: 18),
                                label: Text('SW1'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: resetFg,
                                  side: BorderSide(color: resetFg),
                                ),
                                onPressed: _sending ? null : _sendReset,
                                icon: const Icon(
                                  Icons.power_settings_new,
                                  size: 18,
                                ),
                                label: Text('Reset Board'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add_step_linesonic_pid',
          onPressed: _loaded
              ? () {
                  setState(() {
                    _steps.add(_newStep());
                    _scheduleAutoSave();
                  });
                }
              : null,
          icon: const Icon(Icons.add),
          label: Text('Add Step'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

/// Asks for a preset name. The field's controller lives in this dialog's
/// State, so it outlives the closing animation that still builds the field.
class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Preset'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          label: Text('Preset name'),
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
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
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Digits (also Thai) and a decimal point or comma; never ; or spaces,
      // which would break the SEQ= fields.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0E50-\u0E59.,]')),
      ],
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
        label: Text(label, style: const TextStyle(fontSize: 11)),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(
            '$label ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChips extends StatelessWidget {
  final List<String> values;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _PresetChips({
    required this.values,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: values.map((v) {
        final selected = current == v;
        return ChoiceChip(
          label: Text(v, style: const TextStyle(fontSize: 10)),
          selected: selected,
          showCheckmark: false,
          selectedColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) {
            controller.text = v;
            onChanged();
          },
        );
      }).toList(),
    );
  }
}
