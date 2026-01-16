// lib/pages/joystick.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/ble/ble_manager.dart';
import '../joystick_controller.dart';
import '../widgets/joystick_widget.dart';
import '../../../../core/widgets/connection_status_badge.dart';
import '../../../../core/utils/orientation_utils.dart';
import '../joystick_theme.dart';
import '../../../home/home_page.dart';
import '../../../../core/ble/joystick_packet.dart';
import '../../../../core/ui/custom_appbars.dart';
import '../../../../core/ui/gamepad_assets.dart';
import '../../../../core/ui/gamepad_components.dart';
import '../../../../core/widgets/logo_corner.dart';

const double kJoyMinSize = 0.6;
const double kJoyMaxSize = 1.6;
const double kJoyBtnMinSize = 0.6;
const double kJoyBtnMaxSize = 1.6;

const String kJoyLeftId = 'joy_left';
const String kJoyRightId = 'joy_right';
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

  bool _editMode = false;
  String? _selectedId;
  Size? _panelSize;
  Map<String, _JoyLayout> _layout = {};
  Set<String> _activeIds = {kJoyLeftId, kJoyRightId};

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
  String _leftDebug = "0.00,0.00";
  String _rightDebug = "0.00,0.00";

  void _setLeftDebug(double x, double y) {
    _leftDebug = "${_fmt(x)},${_fmt(y)}";
  }

  void _setRightDebug(double x, double y) {
    _rightDebug = "${_fmt(x)},${_fmt(y)}";
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
    _loadLayout();

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

        if (mounted) {
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
      if (_debugTick % 3 == 0) {
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
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
        isDark ? const Color(0xFF343A46) : Colors.black.withOpacity(.20);
    final glowColor = isDark
        ? const Color(0xFF8B5CFF).withOpacity(.60)
        : const Color(0xFF5C6BFF).withOpacity(.45);

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
    if (active.contains(kJoyRightId)) {
      out[kJoyRightId] = const _JoyLayout(0.75, 0.5, 1.0);
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
    if (_activeIds.isEmpty) {
      _activeIds = {kJoyLeftId, kJoyRightId};
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
        if (id == kJoyLeftId) _resetLeftJoystick();
        if (id == kJoyRightId) _resetRightJoystick();
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
      _activeIds = {kJoyLeftId, kJoyRightId};
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

  PopupMenuButton<String> _buildEditMenu() {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
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
      onSelected: _toggleActive,
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          item(kJoyLeftId, 'Left Joystick'),
          item(kJoyRightId, 'Right Joystick'),
          const PopupMenuDivider(),
          item(kBtnTriangleId, 'Triangle'),
          item(kBtnCrossId, 'Cross'),
          item(kBtnSquareId, 'Square'),
          item(kBtnCircleId, 'Circle'),
        ];
      },
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
            color: Colors.black.withOpacity(0.35),
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
    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        appBar: JoystickAppBar(
          title: "",
          titleWidget: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _appBarBadge('Cmd', _cmdLabel()),
                  const SizedBox(width: 6),
                  _appBarBadge('JL', _leftDebug),
                  const SizedBox(width: 6),
                  _appBarBadge('JR', _rightDebug),
                  const SizedBox(width: 6),
                  const ConnectionStatusBadge(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
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
          ],
        ),
        body: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LayoutBuilder(
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
              _buildResizeBar(),
              const LogoCorner(),
            ],
          ),
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
        ? const Color(0xFF00F0FF).withOpacity(0.45)
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
        ? const Color(0xFF00F0FF).withOpacity(0.45)
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
