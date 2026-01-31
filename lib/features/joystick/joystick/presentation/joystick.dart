// lib/pages/joystick.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/ble/ble_manager.dart';
import '../joystick_controller.dart';
import '../widgets/joystick_widget.dart';
import '../joystick_view.dart';
import '../../../../core/widgets/connection_status_badge.dart';
import '../../../../core/utils/orientation_utils.dart';
import '../joystick_theme.dart';
import '../../../home/home_page.dart';
import '../../../../core/ble/joystick_packet.dart';
import '../../../../core/ui/custom_appbars.dart';
import '../../../../core/ui/gamepad_assets.dart';
import '../../../../core/ui/gamepad_components.dart';
import '../../../../core/widgets/logo_corner.dart';
import '../../../../core/ui/language_controller.dart';

const double kJoyMinSize = 0.6;
const double kJoyMaxSize = 1.6;
const double kJoyBtnMinSize = 0.6;
const double kJoyBtnMaxSize = 1.6;

const String kJoyLeftId = 'joy_left';
const String kJoyRightId = 'joy_right';
const String kJoyYOnlyId = 'joy_y_only';
const String kJoyXOnlyId = 'joy_x_only';
const String kBtnTriangleId = 'btn_triangle';
const String kBtnCrossId = 'btn_cross';
const String kBtnSquareId = 'btn_square';
const String kBtnCircleId = 'btn_circle';

class JoystickPage extends StatefulWidget {
  const JoystickPage({super.key});

  @override
  State<JoystickPage> createState() => _JoystickPageState();
}

class _JoystickPageState extends State<JoystickPage> {
  final JoystickController _controller = JoystickController();
  Timer? _timer;

  static const _prefsLayout = 'joy_dual_layout';
  static const _prefsActive = 'joy_dual_active';
  static const double _baseJoyRatio = 0.45;
  static const _prefsTutorialSeen = 'joy_tutorial_seen';
  static const _prefsPreset1 = 'joy_preset_1';
  static const _prefsPreset2 = 'joy_preset_2';
  static const _prefsPreset3 = 'joy_preset_3';

  bool _editMode = false;
  bool _menuOpen = false;
  Offset? _menuAnchor;
  String? _selectedId;
  Size? _panelSize;
  Map<String, _JoyLayout> _layout = {};
  Set<String> _activeIds = {};

  bool _triangle = false;
  bool _cross = false;
  bool _square = false;
  bool _circle = false;
  int _lastButtonsKey = 0;

  double _smoothLX = 0.0, _smoothLY = 0.0;
  double _smoothRX = 0.0, _smoothRY = 0.0;

  double _lastLX = 0.0, _lastLY = 0.0;
  double _lastRX = 0.0, _lastRY = 0.0;

  static const double _deadZone = 0.05;
  static const double _smooth = 0.85;
  static const double _delta = 0.005;

  int _debugTick = 0;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _fmt(double v) => v.toStringAsFixed(2);
  String _leftDebug = "X:0.00 Y:0.00";
  String _rightDebug = "X:0.00 Y:0.00";

  bool _showTutorial = false;
  int _tutorialStep = 0;
  bool _tutorialThai = true;
  late final VoidCallback _langListener;
  Rect? _tutorialTargetRect;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  final GlobalKey _tutorialStackKey = GlobalKey();
  final GlobalKey _tutorialCustomizeKey = GlobalKey();
  final GlobalKey _tutorialItemsKey = GlobalKey();
  final GlobalKey _tutorialAreaKey = GlobalKey();
  final GlobalKey _tutorialBtKey = GlobalKey();
  final GlobalKey _tutorialPresetKey = GlobalKey();
  final GlobalKey _tutorialCmdKey = GlobalKey();
  final GlobalKey _tutorialJlKey = GlobalKey();
  final GlobalKey _tutorialJrKey = GlobalKey();

  void _setLeftDebug(double x, double y) {
    _leftDebug = "X:${_fmt(x)} Y:${_fmt(y)}";
  }

  void _setRightDebug(double x, double y) {
    _rightDebug = "X:${_fmt(x)} Y:${_fmt(y)}";
  }

  void _sendBinary(JoystickPacket packet, {Set<int>? buttons}) {
    BleManager.instance.sendJoystickBinary(
      packet: packet,
      pressedButtons: buttons ?? const <int>{},
    );
  }

  void _resetLeftJoystick() {
    _smoothLX = 0;
    _smoothLY = 0;
    _lastLX = 0;
    _lastLY = 0;

    _controller.setLeftJoystick(0, 0);

    _sendBinary(
      JoystickPacket(lx: 0, ly: 0, rx: _lastRX, ry: _lastRY),
      buttons: _pressedButtons(),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      _sendBinary(
        JoystickPacket(lx: 0, ly: 0, rx: _lastRX, ry: _lastRY),
        buttons: _pressedButtons(),
      );
    });

    if (mounted) {
      setState(() => _setLeftDebug(0, 0));
    }
  }

  void _resetRightJoystick() {
    _smoothRX = 0;
    _smoothRY = 0;
    _lastRX = 0;
    _lastRY = 0;

    _controller.setRightJoystick(0, 0);

    _sendBinary(
      JoystickPacket(lx: _lastLX, ly: _lastLY, rx: 0, ry: 0),
      buttons: _pressedButtons(),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      _sendBinary(
        JoystickPacket(lx: _lastLX, ly: _lastLY, rx: 0, ry: 0),
        buttons: _pressedButtons(),
      );
    });

    if (mounted) {
      setState(() => _setRightDebug(0, 0));
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _sendZeroAndClear({bool updateUi = true}) {
    _smoothLX = 0;
    _smoothLY = 0;
    _smoothRX = 0;
    _smoothRY = 0;

    _lastLX = 0;
    _lastLY = 0;
    _lastRX = 0;
    _lastRY = 0;

    _controller.setLeftJoystick(0, 0);
    _controller.setRightJoystick(0, 0);

    _lastButtonsKey = _buttonsKey();
    _sendBinary(
      JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
      buttons: _pressedButtons(),
    );
    Future.delayed(const Duration(milliseconds: 20), () {
      _sendBinary(
        JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
        buttons: _pressedButtons(),
      );
    });

    if (updateUi && mounted) {
      setState(() {
        _setLeftDebug(0, 0);
        _setRightDebug(0, 0);
      });
    }
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
    _loadLayout();
    _maybeStartTutorial();

    _timer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if (_editMode) return;
      final packet = _controller.buildPacket();
      final buttonsKey = _buttonsKey();
      final buttonsChanged = buttonsKey != _lastButtonsKey;

      const zeroEps = 0.015;

      final nearZero =
          packet.lx.abs() < zeroEps &&
          packet.ly.abs() < zeroEps &&
          packet.rx.abs() < zeroEps &&
          packet.ry.abs() < zeroEps;

      if (nearZero &&
          (_lastLX != 0 || _lastLY != 0 || _lastRX != 0 || _lastRY != 0)) {
        _lastLX = 0;
        _lastLY = 0;
        _lastRX = 0;
        _lastRY = 0;

        _smoothLX = 0;
        _smoothLY = 0;
        _smoothRX = 0;
        _smoothRY = 0;

        _controller.setLeftJoystick(0, 0);
        _controller.setRightJoystick(0, 0);

        _lastButtonsKey = buttonsKey;
        _sendBinary(
          JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
          buttons: _pressedButtons(),
        );
        Future.delayed(const Duration(milliseconds: 20), () {
          _sendBinary(
            JoystickPacket(lx: 0, ly: 0, rx: 0, ry: 0),
            buttons: _pressedButtons(),
          );
        });

        if (mounted && !_menuOpen) {
          setState(() {
            _setLeftDebug(0, 0);
            _setRightDebug(0, 0);
          });
        }
        return;
      }

      final changed =
          (packet.lx - _lastLX).abs() > _delta ||
          (packet.ly - _lastLY).abs() > _delta ||
          (packet.rx - _lastRX).abs() > _delta ||
          (packet.ry - _lastRY).abs() > _delta;

      if (!changed && !buttonsChanged) return;

      _lastLX = packet.lx;
      _lastLY = packet.ly;
      _lastRX = packet.rx;
      _lastRY = packet.ry;
      _lastButtonsKey = buttonsKey;

      _sendBinary(packet, buttons: _pressedButtons());

      _debugTick++;
      if (!mounted) return;
      if (_debugTick % 3 == 0 && !_menuOpen) {
        setState(() {
          _setLeftDebug(packet.lx, packet.ly);
          _setRightDebug(packet.rx, packet.ry);
        });
      }
    });
  }

  @override
  void dispose() {
    _stopTimer();
    _sendZeroAndClear(updateUi: false);
    LanguageController.isThai.removeListener(_langListener);
    OrientationUtils.reset();
    super.dispose();
  }

  (double, double) _process(double rawX, double rawY, double sx, double sy) {
    double x = (rawX.abs() < _deadZone) ? 0 : rawX;
    double y = (rawY.abs() < _deadZone) ? 0 : rawY;

    final fx = _lerp(sx, x, _smooth);
    final fy = _lerp(sy, y, _smooth);

    const eps = 0.01;
    final snapX = (fx.abs() < eps) ? 0.0 : fx;
    final snapY = (fy.abs() < eps) ? 0.0 : fy;

    return (snapX, snapY);
  }

  Set<int> _pressedButtons() {
    final btns = <int>{};
    if (_triangle) btns.add(kBleBtnTriangle);
    if (_cross) btns.add(kBleBtnCross);
    if (_square) btns.add(kBleBtnSquare);
    if (_circle) btns.add(kBleBtnCircle);
    return btns;
  }

  int _buttonsKey() {
    final btns = _pressedButtons();
    int v = 0;
    for (final b in btns) {
      if (b < 1 || b > 8) continue;
      v |= (1 << (b - 1));
    }
    return v & 0xFF;
  }

  String _cmdLabel() => _buttonsKey().toString();

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

  double _baseJoySize(Size panel) =>
      math.min(panel.width, panel.height) * _baseJoyRatio;

  double _baseBtnSize(Size panel) => _baseJoySize(panel) * 0.55;

  BtnCfg _buttonCfg(BuildContext context, String label, String asset, double size) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0D0F14) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF343A46) : _opacity(Colors.black, .20);
    final glowColor = isDark
        ? _opacity(const Color(0xFF8B5CFF), .60)
        : _opacity(const Color(0xFF5C6BFF), .45);

    return BtnCfg(
      width: size,
      height: size,
      margin: EdgeInsets.zero,
      radius: size * 0.26,
      baseColor: baseColor,
      borderColor: borderColor,
      borderWidthOn: 2.2,
      borderWidthOff: 1.4,
      glowBlurOn: 18,
      glowSpreadOn: 1.0,
      glowBlurOff: 12,
      glowSpreadOff: 0.4,
      shadowOffsetOn: const Offset(0, 6),
      shadowOffsetOff: const Offset(0, 4),
      glowColor: glowColor,
      iconAsset: asset,
      iconFit: BoxFit.cover,
      iconPadding: EdgeInsets.zero,
      label: label,
      labelFontSize: size * 0.18,
      labelColor: Colors.white,
      pressOverlayColor: Colors.white,
      pressOverlayOpacity: 0.10,
    );
  }

  Map<String, _JoyLayout> _defaultLayout(Size panel, Set<String> active) {
    final out = <String, _JoyLayout>{};
    if (active.contains(kJoyLeftId)) {
      out[kJoyLeftId] = const _JoyLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyYOnlyId)) {
      out[kJoyYOnlyId] = const _JoyLayout(0.25, 0.5, 1.0);
    }
    if (active.contains(kJoyRightId)) {
      out[kJoyRightId] = const _JoyLayout(0.75, 0.5, 1.0);
    }
    if (active.contains(kJoyXOnlyId)) {
      out[kJoyXOnlyId] = const _JoyLayout(0.75, 0.5, 1.0);
    }
    if (active.contains(kBtnTriangleId)) {
      out[kBtnTriangleId] = const _JoyLayout(0.82, 0.38, 1.0);
    }
    if (active.contains(kBtnCrossId)) {
      out[kBtnCrossId] = const _JoyLayout(0.82, 0.62, 1.0);
    }
    if (active.contains(kBtnSquareId)) {
      out[kBtnSquareId] = const _JoyLayout(0.72, 0.5, 1.0);
    }
    if (active.contains(kBtnCircleId)) {
      out[kBtnCircleId] = const _JoyLayout(0.92, 0.5, 1.0);
    }
    return out;
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsLayout);
    final activeRaw = prefs.getString(_prefsActive);
    if (raw != null && raw.isNotEmpty) {
      _layout = _decodeLayout(raw);
    }
    if (activeRaw != null && activeRaw.isNotEmpty) {
      _activeIds = _decodeIdList(activeRaw);
    }
    _layout.removeWhere((k, _) => !_activeIds.contains(k));
    if (mounted) setState(() {});
  }

  Future<void> _saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLayout, jsonEncode(_encodeLayout(_layout)));
  }

  Future<void> _saveActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActive, jsonEncode(_activeIds.toList()));
  }

  Map<String, _JoyLayout> _decodeLayout(String raw) {
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return {};
      final out = <String, _JoyLayout>{};
      obj.forEach((k, v) {
        if (v is Map) {
          final cx = (v['cx'] as num?)?.toDouble();
          final cy = (v['cy'] as num?)?.toDouble();
          final size = (v['size'] as num?)?.toDouble() ?? 1.0;
          if (cx != null && cy != null) {
            out[k.toString()] = _JoyLayout(cx, cy, size);
          }
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, double>> _encodeLayout(
    Map<String, _JoyLayout> layout,
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
    setState(() {
      _editMode = !_editMode;
      if (_editMode && _panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        _layout = {...defaults, ..._layout};
      }
    });
  }

  bool _isLeftJoy(String id) => id == kJoyLeftId || id == kJoyYOnlyId;
  bool _isRightJoy(String id) => id == kJoyRightId || id == kJoyXOnlyId;

  void _selectJoystick(String id) {
    setState(() => _selectedId = id);
  }

  void _toggleActive(String id) {
    setState(() {
      if (_activeIds.contains(id)) {
        _activeIds.remove(id);
        _layout.remove(id);
        if (_selectedId == id) _selectedId = null;
        _clearButtonState(id);
        if (_isLeftJoy(id)) _resetLeftJoystick();
        if (_isRightJoy(id)) _resetRightJoystick();
      } else {
        _activeIds.add(id);
        if (_panelSize != null) {
          final defaults = _defaultLayout(_panelSize!, _activeIds);
          final def = defaults[id];
          if (def != null) {
            _layout[id] = def;
          }
        }
      }
    });
    _saveActive();
  }

  void _removeSelected() {
    final id = _selectedId;
    if (id == null) return;
    _toggleActive(id);
  }

  void _resetLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLayout);
    await prefs.remove(_prefsActive);
    setState(() {
      _layout = {};
      _activeIds = {};
      _selectedId = null;
      _clearButtonState(null);
    });
  }

  void _clearButtonState(String? id) {
    if (id == null || id == kBtnTriangleId) _triangle = false;
    if (id == null || id == kBtnCrossId) _cross = false;
    if (id == null || id == kBtnSquareId) _square = false;
    if (id == null || id == kBtnCircleId) _circle = false;
  }

  Widget _buildEditMenu() {
    if (Platform.isIOS) {
      return _buildEditMenuIOS();
    }
    PopupMenuItem<String> item(String id, String label) {
      final active = _activeIds.contains(id);
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

    return PopupMenuButton<String>(
      tooltip: 'Add/Remove items',
      offset: const Offset(0, 40),
      position: PopupMenuPosition.under,
      onOpened: () => _menuOpen = true,
      onCanceled: () => _menuOpen = false,
      child: Container(
        key: _tutorialItemsKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _opacity(Colors.black, 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Items',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      onSelected: (value) {
        _menuOpen = false;
        _toggleActive(value);
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          item(kJoyLeftId, 'Left Joystick'),
          item(kJoyRightId, 'Right Joystick'),
          item(kJoyYOnlyId, 'Joystick (Y only)'),
          item(kJoyXOnlyId, 'Joystick (X only)'),
          const PopupMenuDivider(),
          item(kBtnTriangleId, 'Triangle'),
          item(kBtnCrossId, 'Cross'),
          item(kBtnSquareId, 'Square'),
          item(kBtnCircleId, 'Circle'),
        ];
      },
    );
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
        bodyTh: 'นี่คือวิธีใช้งาน Joystick แบบสั้นๆ',
        titleEn: 'Welcome',
        bodyEn: 'This is a quick guide to Joystick.',
      ),
      _TutorialStep(
        titleTh: 'Customize',
        bodyTh: 'กด Customize เพื่อเข้าโหมดแก้ไขตำแหน่ง',
        titleEn: 'Customize',
        bodyEn: 'Tap Customize to enter edit mode.',
        targetKey: _tutorialCustomizeKey,
      ),
      _TutorialStep(
        titleTh: 'Preset',
        bodyTh: 'บันทึก/เรียกใช้รูปแบบจอยและปุ่มได้ 3 แบบ',
        titleEn: 'Preset',
        bodyEn: 'Save/load 3 preset joystick layouts.',
        targetKey: _tutorialPresetKey,
      ),
      _TutorialStep(
        titleTh: 'Items',
        bodyTh: 'กด Items เพื่อเลือกจอย/ปุ่มที่จะใช้งาน',
        titleEn: 'Items',
        bodyEn: 'Tap Items to choose joysticks/buttons.',
        targetKey: _tutorialItemsKey,
        requiresEditMode: true,
      ),
      _TutorialStep(
        titleTh: 'พื้นที่ควบคุม',
        bodyTh: 'ลากจอยเพื่อบังคับทิศทาง',
        titleEn: 'Control Area',
        bodyEn: 'Drag the joystick to control direction.',
        targetKey: _tutorialAreaKey,
      ),
      _TutorialStep(
        titleTh: 'Cmd',
        bodyTh: 'Cmd คือค่ารหัสปุ่มที่กดอยู่แบบเรียลไทม์',
        titleEn: 'Cmd',
        bodyEn: 'Cmd shows the real-time button byte.',
        targetKey: _tutorialCmdKey,
      ),
      _TutorialStep(
        titleTh: 'JL',
        bodyTh: 'JL คือค่าจอยซ้าย (X,Y) แบบเรียลไทม์',
        titleEn: 'JL',
        bodyEn: 'JL shows left joystick X,Y values.',
        targetKey: _tutorialJlKey,
      ),
      _TutorialStep(
        titleTh: 'JR',
        bodyTh: 'JR คือค่าจอยขวา (X,Y) แบบเรียลไทม์',
        titleEn: 'JR',
        bodyEn: 'JR shows right joystick X,Y values.',
        targetKey: _tutorialJrKey,
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
      _editMode = false;
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
      'layout': _encodeLayout(_layout),
      'active': _activeIds.toList(),
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
      final activeRaw = obj['active'];
      if (layoutRaw is Map) {
        _layout = _decodeLayout(jsonEncode(layoutRaw));
      }
      if (activeRaw is List) {
        _activeIds = activeRaw.map((e) => e.toString()).toSet();
      }
      if (_panelSize != null) {
        final defaults = _defaultLayout(_panelSize!, _activeIds);
        _layout = {...defaults, ..._layout};
      }
      setState(() {});
      _saveLayout();
      _saveActive();
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

  Widget _buildEditMenuIOS() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        key: _tutorialItemsKey,
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
            'Items',
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
              _toggleActive(id);
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
                          title: const Text('Items'),
                          actions: [
                            action(
                              kJoyLeftId,
                              'Left Joystick',
                              _activeIds.contains(kJoyLeftId),
                              setSheetState,
                            ),
                            action(
                              kJoyRightId,
                              'Right Joystick',
                              _activeIds.contains(kJoyRightId),
                              setSheetState,
                            ),
                            action(
                              kJoyYOnlyId,
                              'Joystick (Y only)',
                              _activeIds.contains(kJoyYOnlyId),
                              setSheetState,
                            ),
                            action(
                              kJoyXOnlyId,
                              'Joystick (X only)',
                              _activeIds.contains(kJoyXOnlyId),
                              setSheetState,
                            ),
                            action(
                              kBtnTriangleId,
                              'Triangle',
                              _activeIds.contains(kBtnTriangleId),
                              setSheetState,
                            ),
                            action(
                              kBtnCrossId,
                              'Cross',
                              _activeIds.contains(kBtnCrossId),
                              setSheetState,
                            ),
                            action(
                              kBtnSquareId,
                              'Square',
                              _activeIds.contains(kBtnSquareId),
                              setSheetState,
                            ),
                            action(
                              kBtnCircleId,
                              'Circle',
                              _activeIds.contains(kBtnCircleId),
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

  Widget _buildEmptyState() {
    if (_editMode || _activeIds.isNotEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _opacity(Colors.black, 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'No buttons or joysticks yet\nTap Customize → Items to add',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _adjustSelectedSize(double delta) {
    final id = _selectedId;
    if (id == null) return;
    final panel = _panelSize;
    if (panel == null) return;
    final current = _layout[id];
    if (current == null) return;

    final w = panel.width;
    final h = panel.height;
    final base = _isButtonId(id) ? _baseBtnSize(panel) : _baseJoySize(panel);
    final unclamped = current.size + delta;
    final minSize = _isButtonId(id) ? kJoyBtnMinSize : kJoyMinSize;
    final maxSize = _isButtonId(id) ? kJoyBtnMaxSize : kJoyMaxSize;
    final nextSize = unclamped.clamp(minSize, maxSize);
    final sizePx = base * nextSize;
    final half = sizePx / 2;

    double cx = (current.cx * w).clamp(half, w - half);
    double cy = (current.cy * h).clamp(half, h - half);

    setState(() {
      final next = Map<String, _JoyLayout>.from(_layout);
      next[id] = _JoyLayout(cx / w, cy / h, nextSize);
      _layout = next;
    });
    _saveLayout();
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

  bool _isButtonId(String id) {
    return id == kBtnTriangleId ||
        id == kBtnCrossId ||
        id == kBtnSquareId ||
        id == kBtnCircleId;
  }

  void _onButtonChanged(String id, bool down) {
    if (_editMode) return;
    if (id == kBtnTriangleId) _triangle = down;
    if (id == kBtnCrossId) _cross = down;
    if (id == kBtnSquareId) _square = down;
    if (id == kBtnCircleId) _circle = down;

    _lastButtonsKey = _buttonsKey();
    _sendBinary(
      _controller.buildPacket(),
      buttons: _pressedButtons(),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _onBack() async {
    OrientationUtils.reset();
    _sendZeroAndClear();
    _stopTimer();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: JoystickAppBar(
          title: "",
          gradientColors: const [
            Color(0xFF3949AB),
            Color(0xFF00ACC1),
          ],
          titleWidget: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: _tutorialCmdKey,
                    child: _appBarBadge('Cmd', _cmdLabel()),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: _tutorialJlKey,
                    child: _appBarBadge('JL', _leftDebug),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: _tutorialJrKey,
                    child: _appBarBadge('JR', _rightDebug),
                  ),
                  const SizedBox(width: 6),
                  ConnectionStatusBadge(key: _tutorialBtKey),
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBack,
          ),
          actions: [
            if (_editMode) _buildEditMenu(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _toggleEdit,
                child: Container(
                  key: _tutorialCustomizeKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                onPressed: _resetLayout,
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
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: _tutorialAreaKey,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        _panelSize = size;
                        final defaults = _defaultLayout(size, _activeIds);
                        final effective = {
                          ...defaults,
                          ..._layout,
                        };

                        final base = _baseJoySize(size);
                        final btnBase = _baseBtnSize(size);

                        final widgets = <Widget>[];
                        if (_activeIds.contains(kJoyLeftId)) {
                          widgets.add(
                            _buildJoystick(
                              id: kJoyLeftId,
                              size: size,
                              baseSize: base,
                              layout: effective[kJoyLeftId]!,
                              isLeft: true,
                              axisLock: JoystickAxisLock.none,
                            ),
                          );
                        }
                        if (_activeIds.contains(kJoyYOnlyId)) {
                          widgets.add(
                            _buildJoystick(
                              id: kJoyYOnlyId,
                              size: size,
                              baseSize: base,
                              layout: effective[kJoyYOnlyId]!,
                              isLeft: true,
                              axisLock: JoystickAxisLock.yOnly,
                            ),
                          );
                        }
                        if (_activeIds.contains(kJoyRightId)) {
                          widgets.add(
                            _buildJoystick(
                              id: kJoyRightId,
                              size: size,
                              baseSize: base,
                              layout: effective[kJoyRightId]!,
                              isLeft: false,
                              axisLock: JoystickAxisLock.none,
                            ),
                          );
                        }
                        if (_activeIds.contains(kJoyXOnlyId)) {
                          widgets.add(
                            _buildJoystick(
                              id: kJoyXOnlyId,
                              size: size,
                              baseSize: base,
                              layout: effective[kJoyXOnlyId]!,
                              isLeft: false,
                              axisLock: JoystickAxisLock.xOnly,
                            ),
                          );
                        }
                        if (_activeIds.contains(kBtnTriangleId)) {
                          widgets.add(
                            _buildButton(
                              id: kBtnTriangleId,
                              label: 'Triangle',
                              asset: kGamepad8AssetTriangle,
                              size: size,
                              baseSize: btnBase,
                              layout: effective[kBtnTriangleId]!,
                            ),
                          );
                        }
                        if (_activeIds.contains(kBtnCrossId)) {
                          widgets.add(
                            _buildButton(
                              id: kBtnCrossId,
                              label: 'Cross',
                              asset: kGamepad8AssetCross,
                              size: size,
                              baseSize: btnBase,
                              layout: effective[kBtnCrossId]!,
                            ),
                          );
                        }
                        if (_activeIds.contains(kBtnSquareId)) {
                          widgets.add(
                            _buildButton(
                              id: kBtnSquareId,
                              label: 'Square',
                              asset: kGamepad8AssetSquare,
                              size: size,
                              baseSize: btnBase,
                              layout: effective[kBtnSquareId]!,
                            ),
                          );
                        }
                        if (_activeIds.contains(kBtnCircleId)) {
                          widgets.add(
                            _buildButton(
                              id: kBtnCircleId,
                              label: 'Circle',
                              asset: kGamepad8AssetCircle,
                              size: size,
                              baseSize: btnBase,
                              layout: effective[kBtnCircleId]!,
                            ),
                          );
                        }

                        return Stack(children: widgets);
                      },
                    ),
                  ),
                  _buildResizeBar(),
                  const LogoCorner(),
                  _buildEmptyState(),
                ],
              ),
            ),
            _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildJoystick({
    required String id,
    required Size size,
    required double baseSize,
    required _JoyLayout layout,
    required bool isLeft,
    required JoystickAxisLock axisLock,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final joySize = baseSize * layout.size;
    final half = joySize / 2;
    final cx = (layout.cx * size.width).clamp(half, size.width - half);
    final cy = (layout.cy * size.height).clamp(half, size.height - half);

    final joyWidget = SizedBox(
      width: joySize,
      height: joySize,
      child: JoystickWidget(
        controller: _controller,
        isLeft: isLeft,
        axisLock: axisLock,
        knobImage:
            isLeft ? joystickTheme.leftKnobImage : joystickTheme.rightKnobImage,
        onChanged: (x, y) {
          if (_editMode) return;
          if (isLeft) {
            final (sx, sy) = _process(x, y, _smoothLX, _smoothLY);
            _smoothLX = sx;
            _smoothLY = sy;
            _controller.setLeftJoystick(sx, sy);
            if (x == 0 && y == 0) {
              _resetLeftJoystick();
              return;
            }
          } else {
            final (sx, sy) = _process(x, y, _smoothRX, _smoothRY);
            _smoothRX = sx;
            _smoothRY = sy;
            _controller.setRightJoystick(sx, sy);
            if (x == 0 && y == 0) {
              _resetRightJoystick();
              return;
            }
          }
        },
      ),
    );

    if (!_editMode) {
      return Positioned(
        left: cx - half,
        top: cy - half,
        child: joyWidget,
      );
    }

    return _EditableJoystick(
      id: id,
      panelSize: size,
      baseSize: baseSize,
      layout: layout,
      selected: selected,
      dimmed: dimmed,
      onSelect: () => _selectJoystick(id),
      onChanged: (next) {
        setState(() => _layout[id] = next);
      },
      onEnd: _saveLayout,
      child: joyWidget,
    );
  }

  Widget _buildButton({
    required String id,
    required String label,
    required String asset,
    required Size size,
    required double baseSize,
    required _JoyLayout layout,
  }) {
    final selected = _selectedId == id;
    final dimmed = _selectedId != null && _selectedId != id;
    final btnSize = baseSize * layout.size;
    final half = btnSize / 2;
    final cx = (layout.cx * size.width).clamp(half, size.width - half);
    final cy = (layout.cy * size.height).clamp(half, size.height - half);
    final cfg = _buttonCfg(context, label, asset, btnSize);

    final btnWidget = SizedBox(
      width: btnSize,
      height: btnSize,
      child: GamepadHoldButton(
        cfg: cfg,
        onChange: (down) => _onButtonChanged(id, down),
      ),
    );

    if (!_editMode) {
      return Positioned(
        left: cx - half,
        top: cy - half,
        child: btnWidget,
      );
    }

    return _EditableButtonItem(
      panelSize: size,
      baseSize: baseSize,
      layout: layout,
      selected: selected,
      dimmed: dimmed,
      onSelect: () => _selectJoystick(id),
      onChanged: (next) {
        setState(() => _layout[id] = next);
      },
      onEnd: _saveLayout,
      child: btnWidget,
    );
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

class _JoyLayout {
  final double cx;
  final double cy;
  final double size;

  const _JoyLayout(this.cx, this.cy, this.size);

  _JoyLayout copyWith({double? cx, double? cy, double? size}) {
    return _JoyLayout(cx ?? this.cx, cy ?? this.cy, size ?? this.size);
  }

  Map<String, double> toJson() => {'cx': cx, 'cy': cy, 'size': size};
}

class _EditableJoystick extends StatefulWidget {
  final String id;
  final Size panelSize;
  final double baseSize;
  final _JoyLayout layout;
  final bool selected;
  final bool dimmed;
  final VoidCallback onSelect;
  final ValueChanged<_JoyLayout> onChanged;
  final VoidCallback onEnd;
  final Widget child;

  const _EditableJoystick({
    required this.id,
    required this.panelSize,
    required this.baseSize,
    required this.layout,
    required this.selected,
    required this.dimmed,
    required this.onSelect,
    required this.onChanged,
    required this.onEnd,
    required this.child,
  });

  @override
  State<_EditableJoystick> createState() => _EditableJoystickState();
}

class _EditableJoystickState extends State<_EditableJoystick> {
  late Offset _startFocal;
  late _JoyLayout _startLayout;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  void _onScaleStart(ScaleStartDetails d) {
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;

    final nextSize =
        (_startLayout.size * d.scale).clamp(kJoyMinSize, kJoyMaxSize);
    final sizePx = widget.baseSize * nextSize;
    final half = sizePx / 2;

    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;

    cx = cx.clamp(half, w - half);
    cy = cy.clamp(half, h - half);

    widget.onChanged(_JoyLayout(cx / w, cy / h, nextSize));
  }

  @override
  Widget build(BuildContext context) {
    final joySize = widget.baseSize * widget.layout.size;
    final half = joySize / 2;
    final cx = (widget.layout.cx * widget.panelSize.width)
        .clamp(half, widget.panelSize.width - half);
    final cy = (widget.layout.cy * widget.panelSize.height)
        .clamp(half, widget.panelSize.height - half);
    final dimOpacity = widget.dimmed ? 0.35 : 1.0;
    final borderColor =
        widget.selected ? const Color(0xFF00F0FF) : Colors.white70;
    final borderWidth = widget.selected ? 3.0 : 2.0;
    final glowColor = widget.selected
        ? _opacity(const Color(0xFF00F0FF), 0.45)
        : Colors.transparent;

    return Positioned(
      left: cx - half,
      top: cy - half,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: (_) => widget.onEnd(),
        onTap: widget.onSelect,
        child: Opacity(
          opacity: dimOpacity,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IgnorePointer(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _EditableButtonItem extends StatefulWidget {
  final Size panelSize;
  final double baseSize;
  final _JoyLayout layout;
  final bool selected;
  final bool dimmed;
  final VoidCallback onSelect;
  final ValueChanged<_JoyLayout> onChanged;
  final VoidCallback onEnd;
  final Widget child;

  const _EditableButtonItem({
    required this.panelSize,
    required this.baseSize,
    required this.layout,
    required this.selected,
    required this.dimmed,
    required this.onSelect,
    required this.onChanged,
    required this.onEnd,
    required this.child,
  });

  @override
  State<_EditableButtonItem> createState() => _EditableButtonItemState();
}

class _EditableButtonItemState extends State<_EditableButtonItem> {
  late Offset _startFocal;
  late _JoyLayout _startLayout;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  void _onScaleStart(ScaleStartDetails d) {
    _startFocal = d.focalPoint;
    _startLayout = widget.layout;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = widget.panelSize.width;
    final h = widget.panelSize.height;
    final dx = d.focalPoint.dx - _startFocal.dx;
    final dy = d.focalPoint.dy - _startFocal.dy;

    final nextSize =
        (_startLayout.size * d.scale).clamp(kJoyBtnMinSize, kJoyBtnMaxSize);
    final sizePx = widget.baseSize * nextSize;
    final half = sizePx / 2;

    double cx = _startLayout.cx * w + dx;
    double cy = _startLayout.cy * h + dy;

    cx = cx.clamp(half, w - half);
    cy = cy.clamp(half, h - half);

    widget.onChanged(_JoyLayout(cx / w, cy / h, nextSize));
  }

  @override
  Widget build(BuildContext context) {
    final btnSize = widget.baseSize * widget.layout.size;
    final half = btnSize / 2;
    final cx = (widget.layout.cx * widget.panelSize.width)
        .clamp(half, widget.panelSize.width - half);
    final cy = (widget.layout.cy * widget.panelSize.height)
        .clamp(half, widget.panelSize.height - half);
    final dimOpacity = widget.dimmed ? 0.35 : 1.0;
    final borderColor =
        widget.selected ? const Color(0xFF00F0FF) : Colors.white70;
    final borderWidth = widget.selected ? 3.0 : 2.0;
    final glowColor = widget.selected
        ? _opacity(const Color(0xFF00F0FF), 0.45)
        : Colors.transparent;

    return Positioned(
      left: cx - half,
      top: cy - half,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: (_) => widget.onEnd(),
        onTap: widget.onSelect,
        child: Opacity(
          opacity: dimOpacity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IgnorePointer(child: widget.child),
          ),
        ),
      ),
    );
  }
}
