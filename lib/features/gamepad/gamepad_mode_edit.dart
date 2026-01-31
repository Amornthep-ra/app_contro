// lib/features/gamepad/gamepad_mode_edit.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ble/joystick_packet.dart';
import '../../core/ui/gamepad_assets.dart';
import '../../core/ui/gamepad_components.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/ui/custom_appbars.dart';
import '../../core/ui/language_controller.dart';

const String kIdle = '0';

const String kCmdUp = 'F';
const String kCmdDown = 'B';
const String kCmdLeft = 'L';
const String kCmdRight = 'R';

const String kCmdTriangle = 'T';
const String kCmdCross = 'X';
const String kCmdSquare = 'S';
const String kCmdCircle = 'C';

const int kLoopHz = 60;
const int kLoopMs = 1000 ~/ kLoopHz;
const int kMinActiveMs = 150;
const int kMinIdleMs = 150;

const int kMaxSendHz = 40;
const int kMaxSendMs = 1000 ~/ kMaxSendHz;

const double _minBtnSize = 0.18;
const double _maxBtnSize = 0.60;

const double speedRowGap = 6.0;
const double _gamepadAppBarHeight = 48.0;
const double _speedPanelTopGap = 6.0;

Color _opacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

TapCfg cfgSpeedLow(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.green;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFF00FF9D), .10)
      : lighten(c, .24);

  final glow = isDark
      ? _opacity(const Color(0xFF00FFB2), .55)
      : _opacity(Colors.black, .22);

  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? _opacity(Colors.white, .85)
      : _opacity(const Color.fromARGB(255, 0, 0, 0), .85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Lo',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

TapCfg cfgSpeedMid(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.yellow;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFFFFD36A), .06)
      : lighten(c, .24);

  final glow = isDark
      ? _opacity(const Color(0xFFFFD54F), .55)
      : _opacity(Colors.black, .22);

  final textOn = Colors.black;
  final textOff = _opacity(Colors.black, .85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Med',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

TapCfg cfgSpeedHigh(BuildContext ctx) {
  final theme = Theme.of(ctx);
  final platformB = MediaQuery.of(ctx).platformBrightness;
  final isDark =
      theme.brightness == Brightness.dark || platformB == Brightness.dark;

  final c = Colors.red;
  final grad = [lighten(c, .18), darken(c, .06)];

  final border = isDark
      ? lighten(const Color(0xFFFF6B6B), .06)
      : lighten(c, .24);

  final glow = isDark
      ? _opacity(const Color(0xFFFF5A5A), .60)
      : _opacity(Colors.black, .22);

  final textOn = isDark ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
  final textOff = isDark
      ? _opacity(Colors.white, .85)
      : _opacity(const Color.fromARGB(255, 0, 0, 0), .85);

  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: speedRowGap),
    radius: 18,
    gradient: grad,
    border: border,
    borderWidthSelected: 2.2,
    borderWidthUnselected: 1.4,
    glowBlurSelected: 18,
    glowBlurUnselected: 12,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: glow,
    label: 'Hi',
    fontSize: 18,
    textOn: textOn,
    textOff: textOff,
  );
}

class GamepadModeEdit extends StatefulWidget {
  const GamepadModeEdit({super.key});

  @override
  State<GamepadModeEdit> createState() => _GamepadModeEditState();
}

class _GamepadModeEditState extends State<GamepadModeEdit> {
  static const _prefsLayoutLeft = 'gp8_layout_left';
  static const _prefsLayoutRight = 'gp8_layout_right';
  static const _prefsLayoutAll = 'gp8_layout_all';
  static const _prefsActiveLeft = 'gp8_active_left';
  static const _prefsActiveRight = 'gp8_active_right';
  static const _prefsDriveSpeed = 'gp8_drive_speed';
  static const _prefsTurnSpeed = 'gp8_turn_speed';
  static const _prefsTutorialSeen = 'gp8_tutorial_seen';
  static const _prefsPreset1 = 'gp8_preset_1';
  static const _prefsPreset2 = 'gp8_preset_2';
  static const _prefsPreset3 = 'gp8_preset_3';

  bool _up = false;
  bool _down = false;
  bool _left = false;
  bool _right = false;

  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;

  String _command = kIdle;

  String _moveCmd = kIdle;
  String _actionCmd = '';

  int _driveSpeed = 50;
  int _turnSpeed = 50;
  bool _speedPanelOpen = false;
  bool _showTutorial = false;
  int _tutorialStep = 0;
  bool _tutorialThai = true;
  late final VoidCallback _langListener;
  Rect? _tutorialTargetRect;
  final GlobalKey _tutorialStackKey = GlobalKey();
  final GlobalKey _tutorialCustomizeKey = GlobalKey();
  final GlobalKey _tutorialButtonsKey = GlobalKey();
  final GlobalKey _tutorialSpeedKey = GlobalKey();
  final GlobalKey _tutorialBtKey = GlobalKey();
  final GlobalKey _tutorialPresetKey = GlobalKey();
  final GlobalKey _tutorialCmdKey = GlobalKey();
  final GlobalKey _tutorialDrvKey = GlobalKey();
  final GlobalKey _tutorialTrnKey = GlobalKey();

  bool _editMode = false;
  bool _menuOpen = false;
  Offset? _menuAnchor;
  Map<String, _ButtonLayout> _layoutAll = {};
  Set<String> _leftActive = {};
  Set<String> _rightActive = {};
  final Set<String> _pressedIds = {};
  String? _selectedId;
  Size? _panelSize;

  Timer? _tick;
  String _lastPacketKey = '';
  int _lastSendMs = 0;

  Set<int> _buildPressedButtons() {
    final btns = <int>{};

    if (_up && !_down) btns.add(kBleBtnUp);
    if (_down && !_up) btns.add(kBleBtnDown);
    if (_left && !_right) btns.add(kBleBtnLeft);
    if (_right && !_left) btns.add(kBleBtnRight);

    if (_triangle) btns.add(kBleBtnTriangle);
    if (_cross) btns.add(kBleBtnCross);
    if (_square) btns.add(kBleBtnSquare);
    if (_circle) btns.add(kBleBtnCircle);

    return btns;
  }

  String _packetKey() => '$_command|$_driveSpeed|$_turnSpeed';

  int _buttonsByte() {
    final btns = _buildPressedButtons();
    int v = 0;
    for (final b in btns) {
      if (b < 1 || b > 8) continue;
      v |= (1 << (b - 1));
    }
    return v & 0xFF;
  }

  String _commandByteLabel() => _buttonsByte().toString();

  String _driveSpeedLabel() => _driveSpeed.toString();
  String _turnSpeedLabel() => _turnSpeed.toString();

  void _sendBinary({bool force = false}) {
    if (!BleManager.instance.isConnected) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final key = _packetKey();

    if (!force) {
      if ((now - _lastSendMs) < kMaxSendMs) return;

      final changed = key != _lastPacketKey;
      final active = _command != kIdle;
      final minInterval = active ? kMinActiveMs : kMinIdleMs;

      if (!changed && (now - _lastSendMs) < minInterval) {
        return;
      }
    }

    _lastPacketKey = key;
    _lastSendMs = now;

    BleManager.instance.sendJoystickBinary(
      packet: JoystickPacket(
        lx: (_driveSpeed / 100.0).clamp(0.0, 1.0),
        ly: 0,
        rx: (_turnSpeed / 100.0).clamp(0.0, 1.0),
        ry: 0,
      ),
      pressedButtons: _buildPressedButtons(),
    );
  }

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscapeOnly();
    _tutorialThai = LanguageController.isThai.value;
    _langListener = () {
      final next = LanguageController.isThai.value;
      if (next != _tutorialThai) {
        setState(() => _tutorialThai = next);
      }
    };
    LanguageController.isThai.addListener(_langListener);
    _loadLayouts();
    _loadSpeedPrefs();
    _maybeStartTutorial();

    _tick = Timer.periodic(
      const Duration(milliseconds: kLoopMs),
      (_) => _sendLoop(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    LanguageController.isThai.removeListener(_langListener);

    if (BleManager.instance.isConnected && _command != kIdle) {
      _sendBinary(force: true);
    }

    OrientationUtils.reset();
    super.dispose();
  }

  Future<void> _loadSpeedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final int? drive = prefs.getInt(_prefsDriveSpeed);
    final int? turn = prefs.getInt(_prefsTurnSpeed);
    if (!mounted) return;
    setState(() {
      if (drive != null) _driveSpeed = drive.clamp(0, 100);
      if (turn != null) _turnSpeed = turn.clamp(0, 100);
    });
  }

  Future<void> _saveSpeedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsDriveSpeed, _driveSpeed);
    await prefs.setInt(_prefsTurnSpeed, _turnSpeed);
  }

  void _setDriveSpeed(int value) {
    if (_driveSpeed == value) return;
    setState(() => _driveSpeed = value);
    _saveSpeedPrefs();
  }

  void _setTurnSpeed(int value) {
    if (_turnSpeed == value) return;
    setState(() => _turnSpeed = value);
    _saveSpeedPrefs();
  }

  Future<void> _resetSpeedPrefs() async {
    setState(() {
      _driveSpeed = 50;
      _turnSpeed = 50;
    });
    await _saveSpeedPrefs();
    _sendBinary(force: true);
  }

  Future<void> _maybeStartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsTutorialSeen) ?? false;
    if (seen || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showTutorial = true;
        _tutorialStep = 0;
        _tutorialThai = LanguageController.isThai.value;
      });
      _scheduleTutorialRectUpdate();
    });
  }

  void _scheduleTutorialRectUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showTutorial) return;
      _updateTutorialRect();
    });
  }

  List<_TutorialStep> _tutorialSteps() {
    return [
      const _TutorialStep(
        titleTh: 'ยินดีต้อนรับ',
        bodyTh: 'นี่คือวิธีใช้งาน Gamepad Mode Edit แบบสั้นๆ',
        titleEn: 'Welcome',
        bodyEn: 'This is a quick guide to Gamepad Mode Edit.',
      ),
      _TutorialStep(
        titleTh: 'Customize',
        bodyTh: 'กด Customize เพื่อเข้าโหมดแก้ไขปุ่ม',
        titleEn: 'Customize',
        bodyEn: 'Tap Customize to enter edit mode.',
        targetKey: _tutorialCustomizeKey,
      ),
      _TutorialStep(
        titleTh: 'Preset',
        bodyTh: 'บันทึก/เรียกใช้รูปแบบปุ่มและความเร็วได้ 3 แบบ',
        titleEn: 'Preset',
        bodyEn: 'Save/load 3 preset layouts and speeds.',
        targetKey: _tutorialPresetKey,
      ),
      _TutorialStep(
        titleTh: 'Buttons',
        bodyTh: 'กด Buttons เพื่อเลือกปุ่มซ้าย/ขวาที่ต้องการใช้',
        titleEn: 'Buttons',
        bodyEn: 'Tap Buttons to choose left/right buttons.',
        targetKey: _tutorialButtonsKey,
        requiresEditMode: true,
      ),
      _TutorialStep(
        titleTh: 'SPD',
        bodyTh: 'กด SPD เพื่อปรับ DRV (เดินหน้า) และ TRN (เลี้ยว)',
        titleEn: 'SPD',
        bodyEn: 'Tap SPD to adjust DRV (drive) and TRN (turn).',
        targetKey: _tutorialSpeedKey,
      ),
      _TutorialStep(
        titleTh: 'Cmd',
        bodyTh: 'Cmd คือค่ารหัสปุ่มที่กดอยู่แบบเรียลไทม์',
        titleEn: 'Cmd',
        bodyEn: 'Cmd shows the real-time button byte.',
        targetKey: _tutorialCmdKey,
      ),
      _TutorialStep(
        titleTh: 'Drv',
        bodyTh: 'Drv คือความเร็วเดินหน้า (ดูค่าล่าสุดที่ตั้งไว้)',
        titleEn: 'Drv',
        bodyEn: 'Drv is the current drive speed.',
        targetKey: _tutorialDrvKey,
      ),
      _TutorialStep(
        titleTh: 'Trn',
        bodyTh: 'Trn คือความเร็วเลี้ยว (ดูค่าล่าสุดที่ตั้งไว้)',
        titleEn: 'Trn',
        bodyEn: 'Trn is the current turn speed.',
        targetKey: _tutorialTrnKey,
      ),
      _TutorialStep(
        titleTh: 'สถานะ BLE',
        bodyTh: 'ดูสถานะการเชื่อมต่อที่นี่ (BLE Off / BLE On)',
        titleEn: 'BLE Status',
        bodyEn: 'Check connection status here (BLE Off / BLE On).',
        targetKey: _tutorialBtKey,
      ),
    ];
  }

  void _goTutorialStep(int nextStep) {
    final steps = _tutorialSteps();
    if (nextStep < 0 || nextStep >= steps.length) return;
    final step = steps[nextStep];
    if (step.requiresEditMode && !_editMode) {
      setState(() => _editMode = true);
    }
    setState(() => _tutorialStep = nextStep);
    _scheduleTutorialRectUpdate();
  }

  Future<void> _finishTutorial() async {
    setState(() {
      _showTutorial = false;
      _tutorialStep = 0;
      _editMode = false;
      _speedPanelOpen = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsTutorialSeen, true);
  }

  Future<void> _restartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsTutorialSeen, false);
    if (!mounted) return;
    setState(() {
      _showTutorial = true;
      _tutorialStep = 0;
      _tutorialThai = LanguageController.isThai.value;
      _speedPanelOpen = false;
    });
    _scheduleTutorialRectUpdate();
  }

  void _updateTutorialRect() {
    final steps = _tutorialSteps();
    if (_tutorialStep < 0 || _tutorialStep >= steps.length) {
      setState(() => _tutorialTargetRect = null);
      return;
    }
    final key = steps[_tutorialStep].targetKey;
    final stackBox =
        _tutorialStackKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox = key?.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || targetBox == null) {
      setState(() => _tutorialTargetRect = null);
      return;
    }
    final targetGlobal = targetBox.localToGlobal(Offset.zero);
    final offset = stackBox.globalToLocal(targetGlobal);
    final rect = offset & targetBox.size;
    setState(() => _tutorialTargetRect = rect);
  }

  String _presetKey(int slot) {
    switch (slot) {
      case 1:
        return _prefsPreset1;
      case 2:
        return _prefsPreset2;
      case 3:
        return _prefsPreset3;
      default:
        return _prefsPreset1;
    }
  }

  Future<void> _savePreset(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'layout': _encodeLayout(_layoutAll),
      'leftActive': _leftActive.toList(),
      'rightActive': _rightActive.toList(),
      'drive': _driveSpeed,
      'turn': _turnSpeed,
    };
    await prefs.setString(_presetKey(slot), jsonEncode(data));
  }

  Future<void> _loadPreset(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetKey(slot));
    if (raw == null || raw.isEmpty) return;
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return;
      final layoutRaw = obj['layout'];
      final leftRaw = obj['leftActive'];
      final rightRaw = obj['rightActive'];
      final drive = obj['drive'];
      final turn = obj['turn'];
      if (layoutRaw is Map) {
        _layoutAll = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (leftRaw is List) {
        _leftActive = leftRaw.map((e) => e.toString()).toSet();
      }
      if (rightRaw is List) {
        _rightActive = rightRaw.map((e) => e.toString()).toSet();
      }
      if (drive is num) _driveSpeed = drive.round().clamp(0, 100);
      if (turn is num) _turnSpeed = turn.round().clamp(0, 100);
      setState(() {});

      _saveLayout(_prefsLayoutAll, _layoutAll);
      _saveActive(_prefsActiveLeft, _leftActive);
      _saveActive(_prefsActiveRight, _rightActive);
      _saveSpeedPrefs();
      _sendBinary(force: true);
    } catch (_) {}
  }

  Future<void> _showPresetSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final exists = <int, bool>{
      1: (prefs.getString(_prefsPreset1) ?? '').isNotEmpty,
      2: (prefs.getString(_prefsPreset2) ?? '').isNotEmpty,
      3: (prefs.getString(_prefsPreset3) ?? '').isNotEmpty,
    };
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      barrierColor: Colors.black87,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget row(int slot) {
              final hasData = exists[slot] ?? false;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preset $slot',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasData)
                      TextButton(
                        onPressed: () async {
                          await _loadPreset(slot);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Load'),
                      ),
                    if (hasData)
                      TextButton(
                        onPressed: () async {
                          await prefs.remove(_presetKey(slot));
                          exists[slot] = false;
                          if (context.mounted) {
                            setSheetState(() {});
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    TextButton(
                      onPressed: () async {
                        await _savePreset(slot);
                        exists[slot] = true;
                        if (context.mounted) {
                          setSheetState(() {});
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: _opacity(Colors.black, 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Presets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  row(1),
                  row(2),
                  row(3),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _computeMoveCmd() {
    final bool up = _up && !_down;
    final bool down = _down && !_up;
    final bool left = _left && !_right;
    final bool right = _right && !_left;

    final v = up ? kCmdUp : (down ? kCmdDown : '');
    final h = left ? kCmdLeft : (right ? kCmdRight : '');

    if (v.isEmpty && h.isEmpty) {
      return kIdle;
    } else if (v.isNotEmpty && h.isEmpty) {
      return v;
    } else if (v.isEmpty && h.isNotEmpty) {
      return h;
    } else {
      return '$v$h';
    }
  }

  String _computeActionCmd() {
    final buf = StringBuffer();
    if (_triangle) buf.write(kCmdTriangle);
    if (_cross) buf.write(kCmdCross);
    if (_square) buf.write(kCmdSquare);
    if (_circle) buf.write(kCmdCircle);
    return buf.toString();
  }

  void _updateCommand() {
    _moveCmd = _computeMoveCmd();
    _actionCmd = _computeActionCmd();

    String combined;
    if (_moveCmd == kIdle && _actionCmd.isEmpty) {
      combined = kIdle;
    } else if (_moveCmd != kIdle && _actionCmd.isEmpty) {
      combined = _moveCmd;
    } else if (_moveCmd == kIdle && _actionCmd.isNotEmpty) {
      combined = _actionCmd;
    } else {
      combined = '$_moveCmd$_actionCmd';
    }

    setState(() {
      _command = combined;
    });
    if (combined == kIdle &&
        BleManager.instance.isConnected) {
      _sendBinary(force: true);
    }
  }

  Future<void> _loadLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final leftRaw = prefs.getString(_prefsLayoutLeft);
    final rightRaw = prefs.getString(_prefsLayoutRight);
    final allRaw = prefs.getString(_prefsLayoutAll);
    final leftActiveRaw = prefs.getString(_prefsActiveLeft);
    final rightActiveRaw = prefs.getString(_prefsActiveRight);

    if (allRaw != null && allRaw.isNotEmpty) {
      _layoutAll = _decodeLayout(allRaw);
    } else {
      if (leftRaw != null && leftRaw.isNotEmpty) {
        final leftLayout = _decodeLayout(leftRaw);
        _layoutAll.addAll(_remapLayout(leftLayout, 0.0, 0.5));
      }
      if (rightRaw != null && rightRaw.isNotEmpty) {
        final rightLayout = _decodeLayout(rightRaw);
        _layoutAll.addAll(_remapLayout(rightLayout, 0.5, 0.5));
      }
    }
    if (leftActiveRaw != null && leftActiveRaw.isNotEmpty) {
      _leftActive = _decodeIdList(leftActiveRaw);
    }
    if (rightActiveRaw != null && rightActiveRaw.isNotEmpty) {
      _rightActive = _decodeIdList(rightActiveRaw);
    }

    _layoutAll.removeWhere(
      (k, _) => !_leftActive.contains(k) && !_rightActive.contains(k),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveLayout(String key, Map<String, _ButtonLayout> layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_encodeLayout(layout)));
  }

  Future<void> _saveActive(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids.toList()));
  }

  Map<String, _ButtonLayout> _remapLayout(
    Map<String, _ButtonLayout> layout,
    double offsetX,
    double scaleX,
  ) {
    final out = <String, _ButtonLayout>{};
    layout.forEach((k, v) {
      out[k] = _ButtonLayout(offsetX + v.cx * scaleX, v.cy, v.size);
    });
    return out;
  }

  Map<String, _ButtonLayout> _decodeLayout(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return {};
      final out = <String, _ButtonLayout>{};
      obj.forEach((k, v) {
        if (v is Map) {
          final cx = (v['cx'] as num?)?.toDouble();
          final cy = (v['cy'] as num?)?.toDouble();
          final size = (v['size'] as num?)?.toDouble();
          if (cx != null && cy != null && size != null) {
            out[k.toString()] = _ButtonLayout(cx, cy, size);
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, double>> _encodeLayout(
    Map<String, _ButtonLayout> layout,
  ) {
    final out = <String, Map<String, double>>{};
    layout.forEach((k, v) {
      out[k] = v.toJson();
    });
    return out;
  }

  Set<String> _decodeIdList(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! List) return {};
      return obj.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  void _toggleEdit() {
    setState(() => _editMode = !_editMode);
  }

  void _selectButton(String id) {
    setState(() => _selectedId = id);
  }

  void _adjustSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;

    final panelSize = _panelSize;
    final current = _layoutAll[id];
    if (panelSize == null || current == null) return;

    final w = panelSize.width;
    final h = panelSize.height;
    final s = math.min(w, h);
    final unclamped = current.size + delta;
    final nextSize = unclamped.clamp(_minBtnSize, _maxBtnSize);
    if (nextSize == current.size) {
      _showSizeLimit(unclamped >= _maxBtnSize);
      return;
    }
    final sizePx = nextSize * s;
    final half = sizePx / 2;

    double cx = (current.cx * w).clamp(half, w - half);
    double cy = (current.cy * h).clamp(half, h - half);

    setState(() {
      final nextLayout = Map<String, _ButtonLayout>.from(_layoutAll);
      nextLayout[id] = _ButtonLayout(cx / w, cy / h, nextSize);
      _layoutAll = nextLayout;
    });
    _saveLayout(_prefsLayoutAll, _layoutAll);
  }

  void _showSizeLimit(bool atMax) {
    final msg = atMax
        ? 'Max size reached / ถึงขนาดสูงสุดแล้ว'
        : 'Min size reached / ถึงขนาดต่ำสุดแล้ว';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Widget _resizeButton(IconData icon, VoidCallback? onTap, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildResizeBar() {
    if (!_editMode) return const SizedBox.shrink();
    final hasSelection = _selectedId != null;
    final iconColor = hasSelection ? Colors.white : Colors.white54;

    return Positioned(
      top: 6,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _opacity(Colors.black, 0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Size',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              _resizeButton(
                Icons.remove,
                hasSelection ? () => _adjustSelectedSize(-0.05) : null,
                iconColor,
              ),
              const SizedBox(width: 2),
              _resizeButton(
                Icons.add,
                hasSelection ? () => _adjustSelectedSize(0.05) : null,
                iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayoutAll);
    await prefs.remove(_prefsLayoutLeft);
    await prefs.remove(_prefsLayoutRight);
    await prefs.remove(_prefsActiveLeft);
    await prefs.remove(_prefsActiveRight);
    setState(() {
      _layoutAll = {};
      _leftActive = {};
      _rightActive = {};
      _selectedId = null;
    });
  }

  void _toggleActive(String id, bool isLeft) {
    setState(() {
      if (isLeft) {
        if (_leftActive.contains(id)) {
          _leftActive.remove(id);
          _layoutAll.remove(id);
          _pressedIds.remove(id);
          if (_selectedId == id) _selectedId = null;
          if (id == 'L:up') _up = false;
          if (id == 'L:down') _down = false;
          if (id == 'L:left') _left = false;
          if (id == 'L:right') _right = false;
        } else {
          _leftActive.add(id);
        }
        _saveActive(_prefsActiveLeft, _leftActive);
      } else {
        if (_rightActive.contains(id)) {
          _rightActive.remove(id);
          _layoutAll.remove(id);
          _pressedIds.remove(id);
          if (_selectedId == id) _selectedId = null;
          if (id == 'R:triangle') _triangle = false;
          if (id == 'R:cross') _cross = false;
          if (id == 'R:square') _square = false;
          if (id == 'R:circle') _circle = false;
        } else {
          _rightActive.add(id);
        }
        _saveActive(_prefsActiveRight, _rightActive);
      }
    });
  }

  void _removeSelected() {
    final id = _selectedId;
    if (id == null) return;
    _toggleActive(id, id.startsWith('L:'));
  }

  Widget _buildEditMenu() {
    PopupMenuItem<String> header(String text) {
      return PopupMenuItem<String>(
        enabled: false,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    PopupMenuItem<String> item(String id, String label, bool active) {
      return PopupMenuItem<String>(
        value: id,
        child: Row(
          children: [
            Icon(
              active ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
    }

    if (Platform.isIOS) {
      return Material(
        color: Colors.transparent,
        child: GestureDetector(
          key: _tutorialButtonsKey,
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _menuAnchor = d.globalPosition,
          onTap: _showEditMenuIOS,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _opacity(Colors.black, 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Buttons',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Add/Remove buttons',
      offset: const Offset(0, 40),
      position: PopupMenuPosition.under,
      onOpened: () => _menuOpen = true,
      onCanceled: () => _menuOpen = false,
      child: Container(
        key: _tutorialButtonsKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _opacity(Colors.black, 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Buttons',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      onSelected: (value) {
        _menuOpen = false;
        if (value.startsWith('L:')) {
          _toggleActive(value, true);
        } else if (value.startsWith('R:')) {
          _toggleActive(value, false);
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          header('Left pad'),
          item('L:up', 'Up', _leftActive.contains('L:up')),
          item('L:down', 'Down', _leftActive.contains('L:down')),
          item('L:left', 'Left', _leftActive.contains('L:left')),
          item('L:right', 'Right', _leftActive.contains('L:right')),
          header('Right pad'),
          item('R:triangle', 'Triangle', _rightActive.contains('R:triangle')),
          item('R:cross', 'Cross', _rightActive.contains('R:cross')),
          item('R:square', 'Square', _rightActive.contains('R:square')),
          item('R:circle', 'Circle', _rightActive.contains('R:circle')),
        ];
      },
    );
  }

  Future<void> _showEditMenuIOS() async {
    if (_menuOpen) return;
    _menuOpen = true;
    if (!mounted) {
      _menuOpen = false;
      return;
    }
    final allowDismiss = ValueNotifier<bool>(false);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (allowDismiss.value) return;
      allowDismiss.value = true;
    });
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      anchorPoint: _menuAnchor,
      builder: (context) {
        CupertinoActionSheetAction action(
          String id,
          String label,
          bool active,
          void Function(VoidCallback fn) setSheetState,
        ) {
          return CupertinoActionSheetAction(
            onPressed: () {
              if (id.startsWith('L:')) {
                _toggleActive(id, true);
              } else if (id.startsWith('R:')) {
                _toggleActive(id, false);
              }
              setSheetState(() {});
            },
            child: Row(
              children: [
                Icon(
                  active
                      ? CupertinoIcons.check_mark
                      : CupertinoIcons.square,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          );
        }

        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: allowDismiss,
                builder: (context, armed, child) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: armed ? () => Navigator.pop(context) : null,
                    child: const SizedBox.expand(),
                  );
                },
              ),
              SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF7DD3FC)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: StatefulBuilder(
                      builder: (context, setSheetState) {
                        return CupertinoActionSheet(
                          title: const Text('Buttons'),
                          actions: [
                            action(
                              'L:up',
                              'Left: Up',
                              _leftActive.contains('L:up'),
                              setSheetState,
                            ),
                            action(
                              'L:down',
                              'Left: Down',
                              _leftActive.contains('L:down'),
                              setSheetState,
                            ),
                            action(
                              'L:left',
                              'Left: Left',
                              _leftActive.contains('L:left'),
                              setSheetState,
                            ),
                            action(
                              'L:right',
                              'Left: Right',
                              _leftActive.contains('L:right'),
                              setSheetState,
                            ),
                            action(
                              'R:triangle',
                              'Right: Triangle',
                              _rightActive.contains('R:triangle'),
                              setSheetState,
                            ),
                            action(
                              'R:cross',
                              'Right: Cross',
                              _rightActive.contains('R:cross'),
                              setSheetState,
                            ),
                            action(
                              'R:square',
                              'Right: Square',
                              _rightActive.contains('R:square'),
                              setSheetState,
                            ),
                            action(
                              'R:circle',
                              'Right: Circle',
                              _rightActive.contains('R:circle'),
                              setSheetState,
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            isDefaultAction: true,
                            child: const Text('Cancel'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _menuOpen = false;
  }

  Widget _appBarBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _opacity(Colors.black, 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        key: _tutorialSpeedKey,
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() => _speedPanelOpen = !_speedPanelOpen);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _speedPanelOpen
                ? _opacity(Colors.white, 0.25)
                : _opacity(Colors.white, 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _speedPanelOpen ? Colors.white : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'SPD',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.expand_more, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              trackShape: const _GradientTrackShape(),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: value.toString(),
              onChanged: (v) => onChanged(_snapSpeed(v)),
              onChangeEnd: (_) => _sendBinary(force: true),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  int _snapSpeed(double v) {
    final int raw = v.round();
    const int step = 10;
    const int snapRadius = 2; // snap when within ±2 of a 10s step
    final int mod = raw % step;
    if (mod <= snapRadius || mod >= (step - snapRadius)) {
      return ((raw + step ~/ 2) ~/ step) * step;
    }
    return raw;
  }


  Widget _buildSpeedPanel() {
    if (!_speedPanelOpen) return const SizedBox.shrink();

    final topInset = MediaQuery.of(context).padding.top;
    final panelTop = topInset + _gamepadAppBarHeight + _speedPanelTopGap;

    return Positioned(
      top: panelTop,
      left: 12,
      right: 12,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              decoration: BoxDecoration(
                color: _opacity(Colors.black, 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'SPD',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _resetSpeedPrefs,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7DD3FC),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _speedSlider(
                    label: 'DRV',
                    value: _driveSpeed,
                    onChanged: _setDriveSpeed,
                  ),
                  _speedSlider(
                    label: 'TRN',
                    value: _turnSpeed,
                    onChanged: _setTurnSpeed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    if (!_showTutorial) return const SizedBox.shrink();
    final steps = _tutorialSteps();
    final step = steps[_tutorialStep];
    final isLast = _tutorialStep == steps.length - 1;
    final rect = _tutorialTargetRect;
    final highlightRect = rect?.inflate(6);
    final screenSize = MediaQuery.of(context).size;
    const double arrowSize = 72;
    const double arrowGap = 4;
    final bool arrowAbove =
        highlightRect != null && highlightRect.top > (arrowSize + 24);
    final double arrowLeft = highlightRect == null
        ? 0
        : (highlightRect.center.dx - (arrowSize / 2))
            .clamp(8.0, screenSize.width - arrowSize - 8);
    final double arrowTop = highlightRect == null
        ? 0
        : arrowAbove
            ? (highlightRect.top - arrowSize - arrowGap)
                .clamp(8.0, screenSize.height - arrowSize - 8)
            : (highlightRect.bottom + arrowGap)
                .clamp(8.0, screenSize.height - arrowSize - 8);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black87),
          ),
          if (highlightRect != null)
            Positioned.fromRect(
              rect: highlightRect,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7DD3FC),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x807DD3FC),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (highlightRect != null)
            Positioned(
              left: arrowLeft,
              top: arrowTop,
              child: IgnorePointer(
                child: Icon(
                  arrowAbove ? Icons.south : Icons.north,
                  size: arrowSize,
                  color: const Color(0xFF7DD3FC),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: _opacity(Colors.black, 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7DD3FC)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tutorialThai ? step.titleTh : step.titleEn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tutorialThai ? step.bodyTh : step.bodyEn,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _finishTutorial,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: Text(_tutorialThai ? 'ข้าม' : 'Skip'),
                        ),
                        const Spacer(),
                        if (_tutorialStep > 0)
                          TextButton(
                            onPressed: () =>
                                _goTutorialStep(_tutorialStep - 1),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: Text(_tutorialThai ? 'ย้อนกลับ' : 'Back'),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLast
                              ? _finishTutorial
                              : () => _goTutorialStep(_tutorialStep + 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7DD3FC),
                            foregroundColor: Colors.black,
                          ),
                          child: Text(
                            isLast
                                ? (_tutorialThai ? 'เสร็จสิ้น' : 'Finish')
                                : (_tutorialThai ? 'ถัดไป' : 'Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimOverlay() {
    if (!_speedPanelOpen) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _speedPanelOpen = false),
        child: Container(
          color: Colors.black87,
        ),
      ),
    );
  }

  void _sendLoop() {
    _sendBinary();
  }

  bool _applyPressLimit(String id, bool isDown) {
    if (isDown) {
      if (_pressedIds.length >= 2 && !_pressedIds.contains(id)) {
        return false;
      }
      _pressedIds.add(id);
    } else {
      _pressedIds.remove(id);
    }
    return true;
  }

  void _onLeftPress(String id, bool isDown) {
    if (!_applyPressLimit(id, isDown)) {
      return;
    }

    if (id == kCmdUp) _up = isDown;
    if (id == kCmdDown) _down = isDown;
    if (id == kCmdLeft) _left = isDown;
    if (id == kCmdRight) _right = isDown;

    _updateCommand();
  }

  void _onRightPress(String id, bool isDown) {
    if (!_applyPressLimit(id, isDown)) {
      return;
    }

    if (id == kCmdTriangle) _triangle = isDown;
    if (id == kCmdCross) _cross = isDown;
    if (id == kCmdSquare) _square = isDown;
    if (id == kCmdCircle) _circle = isDown;

    _updateCommand();
  }

  void _onAnyPress(String id, bool isDown) {
    if (id == kCmdUp ||
        id == kCmdDown ||
        id == kCmdLeft ||
        id == kCmdRight) {
      _onLeftPress(id, isDown);
      return;
    }
    _onRightPress(id, isDown);
  }

  List<String> _allActiveIds() {
    return [
      ..._leftActive,
      ..._rightActive,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GamepadAppBar(
        title: '',
        centerTitle: true,
        gradientColors: const [
          Color(0xFF1565C0),
          Color(0xFF26A69A),
        ],
        titleWidget: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _speedToggle(),
                const SizedBox(width: 6),
                SizedBox(
                  key: _tutorialCmdKey,
                  child: _appBarBadge('Cmd', _commandByteLabel()),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  key: _tutorialDrvKey,
                  child: _appBarBadge('Drv', _driveSpeedLabel()),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  key: _tutorialTrnKey,
                  child: _appBarBadge('Trn', _turnSpeedLabel()),
                ),
                const SizedBox(width: 6),
                ConnectionStatusBadge(key: _tutorialBtKey),
              ],
            ),
          ),
        ),
        actions: [
          if (_editMode) _buildEditMenu(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _toggleEdit,
              child: Container(
                key: _tutorialCustomizeKey,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _opacity(Colors.black, 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _editMode ? 'Done' : 'Customize',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (_editMode)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: _selectedId == null ? Colors.white54 : Colors.white,
              ),
              onPressed: _selectedId == null ? null : _removeSelected,
              tooltip: 'Remove selected',
            ),
          if (_editMode)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetLayouts,
              tooltip: 'Reset layout',
            ),
          if (!_editMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  InkWell(
                    key: _tutorialPresetKey,
                    borderRadius: BorderRadius.circular(999),
                    onTap: _showPresetSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _opacity(Colors.black, 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'Preset',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _restartTutorial,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _opacity(Colors.black, 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'Tutorial',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        key: _tutorialStackKey,
        children: [
          SafeArea(
            child: Stack(
              children: [
            IgnorePointer(
              ignoring: _speedPanelOpen,
              child: Opacity(
                opacity: _speedPanelOpen ? 0.35 : 1.0,
                child: LayoutBuilder(
                  builder: (context, cons) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Expanded(
                            child: _editMode
                                ? _EditablePadPanel(
                                    ids: _allActiveIds(),
                                    specs: const {
                                      'L:up': _BtnSpec(
                                        'Up',
                                        kCmdUp,
                                        kGamepad8AssetUp,
                                      ),
                                      'L:down': _BtnSpec(
                                        'Down',
                                        kCmdDown,
                                        kGamepad8AssetDown,
                                      ),
                                      'L:left': _BtnSpec(
                                        'Left',
                                        kCmdLeft,
                                        kGamepad8AssetLeft,
                                      ),
                                      'L:right': _BtnSpec(
                                        'Right',
                                        kCmdRight,
                                        kGamepad8AssetRight,
                                      ),
                                      'R:triangle': _BtnSpec(
                                        'Triangle',
                                        kCmdTriangle,
                                        kGamepad8AssetTriangle,
                                      ),
                                      'R:cross': _BtnSpec(
                                        'Cross',
                                        kCmdCross,
                                        kGamepad8AssetCross,
                                      ),
                                      'R:square': _BtnSpec(
                                        'Square',
                                        kCmdSquare,
                                        kGamepad8AssetSquare,
                                      ),
                                      'R:circle': _BtnSpec(
                                        'Circle',
                                        kCmdCircle,
                                        kGamepad8AssetCircle,
                                      ),
                                    },
                                    layout: _layoutAll,
                                    onLayoutChanged: (next) {
                                      _layoutAll = next;
                                      _saveLayout(
                                        _prefsLayoutAll,
                                        _layoutAll,
                                      );
                                    },
                                    selectedId: _selectedId,
                                    onSelect: _selectButton,
                                    onPanelSize: (size) {
                                      _panelSize = size;
                                    },
                                  )
                                : _LayoutPadPanel(
                                    ids: _allActiveIds(),
                                    specs: const {
                                      'L:up': _BtnSpec(
                                        'Up',
                                        kCmdUp,
                                        kGamepad8AssetUp,
                                      ),
                                      'L:down': _BtnSpec(
                                        'Down',
                                        kCmdDown,
                                        kGamepad8AssetDown,
                                      ),
                                      'L:left': _BtnSpec(
                                        'Left',
                                        kCmdLeft,
                                        kGamepad8AssetLeft,
                                      ),
                                      'L:right': _BtnSpec(
                                        'Right',
                                        kCmdRight,
                                        kGamepad8AssetRight,
                                      ),
                                      'R:triangle': _BtnSpec(
                                        'Triangle',
                                        kCmdTriangle,
                                        kGamepad8AssetTriangle,
                                      ),
                                      'R:cross': _BtnSpec(
                                        'Cross',
                                        kCmdCross,
                                        kGamepad8AssetCross,
                                      ),
                                      'R:square': _BtnSpec(
                                        'Square',
                                        kCmdSquare,
                                        kGamepad8AssetSquare,
                                      ),
                                      'R:circle': _BtnSpec(
                                        'Circle',
                                        kCmdCircle,
                                        kGamepad8AssetCircle,
                                      ),
                                    },
                                    layout: _layoutAll,
                                    onPressChanged: _onAnyPress,
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildResizeBar(),
            const LogoCorner(),
              ],
            ),
          ),
          _buildDimOverlay(),
          _buildSpeedPanel(),
          _buildTutorialOverlay(),
        ],
      ),
    );
  }
}

class _GradientTrackShape extends SliderTrackShape {
  const _GradientTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required TextDirection textDirection,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final radius = Radius.circular(trackRect.height / 2);
    final rrect = RRect.fromRectAndRadius(trackRect, radius);

    const gradient = LinearGradient(
      colors: [
        Color(0xFF22C55E), // green
        Color(0xFFFACC15), // yellow
        Color(0xFFEF4444), // red
      ],
      stops: [0.0, 0.55, 1.0],
    );

    final paint = Paint()..shader = gradient.createShader(trackRect);
    context.canvas.drawRRect(rrect, paint);
  }
}

class _TutorialStep {
  final String titleTh;
  final String bodyTh;
  final String titleEn;
  final String bodyEn;
  final GlobalKey? targetKey;
  final bool requiresEditMode;
  const _TutorialStep({
    required this.titleTh,
    required this.bodyTh,
    required this.titleEn,
    required this.bodyEn,
    this.targetKey,
    this.requiresEditMode = false,
  });
}

class _BtnSpec {
  final String label, sendValue, asset;
  const _BtnSpec(this.label, this.sendValue, this.asset);
}

Map<String, _ButtonLayout> _defaultLayoutForIds(
  Size size,
  List<String> ids,
) {
  final w = size.width;
  final h = size.height;
  final s = math.min(w, h);
  final btn = s * 0.30;
  final gap = s * 0.08;
  final cy = h / 2;

  _ButtonLayout make(double x, double y) {
    return _ButtonLayout(x / w, y / h, btn / s);
  }

  final suffixMap = <String, String>{};
  for (final id in ids) {
    final parts = id.split(':');
    final key = parts.length > 1 ? parts[1] : id;
    suffixMap[key] = id;
  }

  final out = <String, _ButtonLayout>{};
  final hasMove = suffixMap.containsKey('up') ||
      suffixMap.containsKey('down') ||
      suffixMap.containsKey('left') ||
      suffixMap.containsKey('right');
  final hasAction = suffixMap.containsKey('triangle') ||
      suffixMap.containsKey('cross') ||
      suffixMap.containsKey('square') ||
      suffixMap.containsKey('circle');

  if (hasMove) {
    final cxLeft = w * 0.28;
    if (suffixMap.containsKey('up')) {
      out[suffixMap['up']!] = make(cxLeft, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('down')) {
      out[suffixMap['down']!] = make(cxLeft, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('left')) {
      out[suffixMap['left']!] = make(cxLeft - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('right')) {
      out[suffixMap['right']!] = make(cxLeft + gap + btn / 2, cy);
    }
  }

  if (hasAction) {
    final cxRight = w * 0.72;
    if (suffixMap.containsKey('triangle')) {
      out[suffixMap['triangle']!] = make(cxRight, cy - gap - btn / 2);
    }
    if (suffixMap.containsKey('cross')) {
      out[suffixMap['cross']!] = make(cxRight, cy + gap + btn / 2);
    }
    if (suffixMap.containsKey('square')) {
      out[suffixMap['square']!] = make(cxRight - gap - btn / 2, cy);
    }
    if (suffixMap.containsKey('circle')) {
      out[suffixMap['circle']!] = make(cxRight + gap + btn / 2, cy);
    }
  }

  return out;
}

class _ButtonLayout {
  final double cx;
  final double cy;
  final double size;

  const _ButtonLayout(this.cx, this.cy, this.size);

  _ButtonLayout copyWith({double? cx, double? cy, double? size}) {
    return _ButtonLayout(cx ?? this.cx, cy ?? this.cy, size ?? this.size);
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'size': size};
}

class _EditablePadPanel extends StatefulWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> layout;
  final ValueChanged<Map<String, _ButtonLayout>> onLayoutChanged;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<Size> onPanelSize;

  const _EditablePadPanel({
    required this.ids,
    required this.specs,
    required this.layout,
    required this.onLayoutChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onPanelSize,
  });

  @override
  State<_EditablePadPanel> createState() => _EditablePadPanelState();
}

class _EditablePadPanelState extends State<_EditablePadPanel> {
  late Map<String, _ButtonLayout> _layout;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _layout = Map<String, _ButtonLayout>.from(widget.layout);
  }

  @override
  void didUpdateWidget(covariant _EditablePadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layout, widget.layout)) {
      _layout = Map<String, _ButtonLayout>.from(widget.layout);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) {
      return Center(
        child: Text(
          'Tap + to add buttons',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        widget.onPanelSize(size);
        final defaults = _defaultLayoutForIds(size, widget.ids);

        bool changed = false;
        if (!_initialized) {
          _initialized = true;
        }
        for (final id in widget.ids) {
          final def = defaults[id];
          if (def != null && _layout[id] == null) {
            _layout[id] = def;
            changed = true;
          }
        }
        _layout.removeWhere((k, _) => !widget.ids.contains(k));
        if (changed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {});
            widget.onLayoutChanged(_layout);
          });
        }

        return Stack(
          children: widget.ids.map((id) {
            final spec = widget.specs[id];
            final layout = _layout[id];
            if (spec == null || layout == null) {
              return const SizedBox.shrink();
            }
            return _EditableButton(
              layout: layout,
              panelSize: size,
              asset: spec.asset,
              selected: widget.selectedId == id,
              dimmed: widget.selectedId != null && widget.selectedId != id,
              onChanged: (next) {
                setState(() => _layout[id] = next);
              },
              onEnd: () => widget.onLayoutChanged(_layout),
              onTap: () => widget.onSelect(id),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LayoutPadPanel extends StatelessWidget {
  final List<String> ids;
  final Map<String, _BtnSpec> specs;
  final Map<String, _ButtonLayout> layout;
  final void Function(String id, bool down) onPressChanged;

  const _LayoutPadPanel({
    required this.ids,
    required this.specs,
    required this.layout,
    required this.onPressChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return Center(
        child: Text(
          'No buttons',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final defaults = _defaultLayoutForIds(size, ids);
        final effective = <String, _ButtonLayout>{...defaults, ...layout};

        final w = size.width;
        final h = size.height;
        final s = math.min(w, h);

        return Stack(
          children: ids.map((id) {
            final spec = specs[id];
            final l = effective[id];
            if (spec == null || l == null) {
              return const SizedBox.shrink();
            }
            final d = l.size * s;
            final cx = l.cx * w;
            final cy = l.cy * h;

            return Positioned(
              left: cx - d / 2,
              top: cy - d / 2,
              child: _ImagePressHoldButton(
                label: spec.label,
                sendValue: spec.sendValue,
                asset: spec.asset,
                diameter: d,
                showLabel: false,
                onPressChanged: onPressChanged,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EditableButton extends StatefulWidget {
  final _ButtonLayout layout;
  final Size panelSize;
  final String asset;
  final bool selected;
  final bool dimmed;
  final ValueChanged<_ButtonLayout> onChanged;
  final VoidCallback onEnd;
  final VoidCallback onTap;

  const _EditableButton({
    required this.layout,
    required this.panelSize,
    required this.asset,
    required this.selected,
    required this.dimmed,
    required this.onChanged,
    required this.onEnd,
    required this.onTap,
  });

  @override
  State<_EditableButton> createState() => _EditableButtonState();
}

class _EditableButtonState extends State<_EditableButton> {
  late Offset _startFocal;
  late _ButtonLayout _startLayout;

  void _onScaleStart(ScaleStartDetails d) {
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final s = math.min(w, h);

    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;

    double size = (_startLayout.size * d.scale)
        .clamp(0.18, 0.60);

    final sizePx = size * s;
    final half = sizePx / 2;

    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;

    cx = cx.clamp(half, w - half);
    cy = cy.clamp(half, h - half);

    widget.onChanged(_ButtonLayout(cx / w, cy / h, size));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final s = math.min(w, h);
    final size = widget.layout.size * s;
    final cx = widget.layout.cx * w;
    final cy = widget.layout.cy * h;
    final borderColor = widget.selected
        ? const Color(0xFF00F0FF)
        : _opacity(Colors.white, 0.7);
    final borderWidth = widget.selected ? 3.0 : 2.0;
    final glowColor = widget.selected
        ? _opacity(const Color(0xFF00F0FF), 0.45)
        : Colors.transparent;
    final dimOpacity = widget.dimmed ? 0.35 : 1.0;

    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: (_) => widget.onEnd(),
        onTap: widget.onTap,
        child: Opacity(
          opacity: dimOpacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              color: _opacity(Colors.white, 0.08),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: ClipOval(
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePressHoldButton extends StatefulWidget {
  final String label;
  final String sendValue;
  final String asset;
  final double diameter;
  final bool showLabel;
  final void Function(String id, bool isDown)? onPressChanged;

  const _ImagePressHoldButton({
    required this.label,
    required this.sendValue,
    required this.asset,
    this.diameter = 120,
    this.showLabel = true,
    this.onPressChanged,
  });

  @override
  State<_ImagePressHoldButton> createState() => _ImagePressHoldButtonState();
}

class _ImagePressHoldButtonState extends State<_ImagePressHoldButton> {
  bool _pressed = false;

  void _onDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    widget.onPressChanged?.call(widget.sendValue, true);
  }

  void _onUpOrCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onPressChanged?.call(widget.sendValue, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnSize = widget.diameter;

    final themeB = theme.brightness;
    final platformB = MediaQuery.of(context).platformBrightness;
    final isDark = themeB == Brightness.dark || platformB == Brightness.dark;

    final baseColor = theme.colorScheme.surface;
    final accent = const Color(0xFF5C6BFF);

    final normalTop = isDark
        ? const Color(0xFF2B2F3A)
        : lighten(baseColor, .08);
    final normalBottom = isDark
        ? const Color(0xFF0E1015)
        : darken(baseColor, .12);

    final pressedTop = isDark ? lighten(accent, .18) : lighten(accent, .10);
    final pressedBottom = isDark ? darken(accent, .28) : darken(accent, .18);

    final gradientColors = _pressed
        ? [pressedTop, pressedBottom]
        : [normalTop, normalBottom];

    final borderColor = _pressed
        ? (isDark
              ? _opacity(const Color(0xFF00F0FF), 0.95)
              : _opacity(Colors.cyanAccent, 0.95))
        : (isDark
              ? _opacity(const Color(0xFF6B7CFF), 0.85)
              : _opacity(Colors.black, 0.45));

    final borderWidth = _pressed ? 3.0 : (isDark ? 2.2 : 1.4);

    final shadowBlur = _pressed ? 22.0 : (isDark ? 18.0 : 14.0);
    final shadowOffset = _pressed ? const Offset(0, 6) : const Offset(0, 4);

    final shadowColor = _pressed
        ? (isDark
              ? _opacity(const Color(0xFF00F0FF), 0.55)
              : _opacity(const Color(0xFF00FFFF), 0.55))
        : (isDark
              ? _opacity(Colors.black, 0.65)
              : _opacity(Colors.black, 0.30));

    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUpOrCancel(),
      onPointerCancel: (_) => _onUpOrCancel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: AnimatedScale(
              scale: _pressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: shadowBlur,
                      offset: shadowOffset,
                      color: shadowColor,
                    ),
                    if (isDark && !_pressed)
                      BoxShadow(
                        blurRadius: btnSize * 0.22,
                        spreadRadius: btnSize * 0.02,
                        color: _opacity(const Color(0xFF6B7CFF), 0.25),
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.asset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        color: _pressed
                            ? _opacity(Colors.white, 0.14)
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.label, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
