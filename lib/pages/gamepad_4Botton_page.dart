// lib/gamepad_4Botton_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/ble_manager.dart'; // ⬅ เปลี่ยนมาใช้ BLE
import '../UI/gamepad_assets.dart';
import '../UI/gamepad_components.dart';
import '../widgets/logo_corner.dart';
import '../widgets/connection_status_badge.dart';
import '../utils/orientation_utils.dart';


/// ========================= PAGE CONFIG =========================
const double PAGE_PAD_H = 0;
const double PAGE_PAD_V = 8;
const double COLUMN_GAP = 6;
const int FLEX_LEFT = 4;
const int FLEX_RIGHT = 6;

const int kSendHz = 60;
const int kSendIntervalMs = 1000 ~/ kSendHz;

/// ดีไซน์ canvas อ้างอิง (แนวนอน)
const double DESIGN_W = 1280;
const double DESIGN_H = 720;

/// Helper สเกล
class _S {
  final double _sx;
  final double _sy;
  final double _sp;

  _S(this._sx, this._sy, this._sp);

  static _S from(BoxConstraints cons) {
    final sw = cons.maxWidth / DESIGN_W;
    final sh = cons.maxHeight / DESIGN_H;
    final sp = (sw + sh) / 2.0;
    return _S(sw, sh, sp.clamp(0.75, 1.35));
  }

  double w(double v) => v * _sx;
  double h(double v) => v * _sy;
  double r(double v) => v * ((_sx + _sy) / 2.0);
  double sp(double v) => v * _sp;

  EdgeInsets m(EdgeInsets e) =>
      EdgeInsets.fromLTRB(w(e.left), h(e.top), w(e.right), h(e.bottom));
  Offset o(Offset o) => Offset(w(o.dx), h(o.dy));
}

/// base config ปุ่ม hold
BtnCfg _baseHoldCfg(BuildContext ctx) {
  final s = Theme.of(ctx).colorScheme;
  return BtnCfg(
    width: 220,
    height: 160,
    margin: const EdgeInsets.all(0),
    radius: 26,
    baseColor: Colors.black,
    borderColor: lighten(Colors.black, .28),
    borderWidthOn: 2.0,
    borderWidthOff: 1.2,
    glowBlurOn: 28,
    glowSpreadOn: 1.0,
    glowBlurOff: 14,
    glowSpreadOff: 0.3,
    shadowOffsetOn: const Offset(0, 8),
    shadowOffsetOff: const Offset(0, 5),
    glowColor: const Color.fromARGB(255, 166, 101, 252).withOpacity(.85),
    iconAsset: null,
    iconFit: BoxFit.cover,
    iconPadding: EdgeInsets.zero,
    label: 'Button',
    labelFontSize: 20,
    labelColor: s.onPrimaryContainer,
    pressOverlayColor: const Color.fromARGB(255, 0, 0, 0),
    pressOverlayOpacity: .10,
  );
}

// ปุ่ม Forward / Back / Left / Right (ใช้ asset จาก gamepad_assets.dart)
BtnCfg cfgForward(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Forward',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(100, 0, 0, 10),
  iconAsset: kGamepad4AssetUp,
);

BtnCfg cfgBackward(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Backward',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(100, 20, 0, 0),
  iconAsset: kGamepad4AssetDown,
);

BtnCfg cfgLeft(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Left',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(100, 80, 40, 0),
  iconAsset: kGamepad4AssetLeft,
);

BtnCfg cfgRight(BuildContext ctx) => _baseHoldCfg(ctx).copyWith(
  label: 'Right',
  width: 240,
  height: 320,
  margin: const EdgeInsets.fromLTRB(30, 80, 80, 0),
  iconAsset: kGamepad4AssetRight,
);

/// GAP “ระดับแถว” สำหรับ Speed
const double SPEED_ROW_GAP = 6.0;

TapCfg cfgSpeedLow(BuildContext ctx) {
  final c = Colors.green;
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: [lighten(c, .18), darken(c, .06)],
    border: lighten(c, .24),
    borderWidthSelected: 2,
    borderWidthUnselected: 1.2,
    glowBlurSelected: 16,
    glowBlurUnselected: 10,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: Colors.black.withOpacity(.22),
    label: 'Low',
    fontSize: 18,
    textOn: const Color.fromARGB(255, 0, 0, 0),
    textOff: const Color.fromARGB(255, 0, 0, 0).withOpacity(.85),
  );
}

TapCfg cfgSpeedMid(BuildContext ctx) {
  final c = Colors.yellow;
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: [lighten(c, .18), darken(c, .06)],
    border: lighten(c, .24),
    borderWidthSelected: 2,
    borderWidthUnselected: 1.2,
    glowBlurSelected: 16,
    glowBlurUnselected: 10,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: Colors.black.withOpacity(.22),
    label: 'Medium',
    fontSize: 18,
    textOn: Colors.black,
    textOff: Colors.black.withOpacity(.85),
  );
}

TapCfg cfgSpeedHigh(BuildContext ctx) {
  final c = Colors.red;
  return TapCfg(
    width: 100,
    height: 80,
    margin: const EdgeInsets.symmetric(horizontal: SPEED_ROW_GAP),
    radius: 18,
    gradient: [lighten(c, .18), darken(c, .06)],
    border: lighten(c, .24),
    borderWidthSelected: 2,
    borderWidthUnselected: 1.2,
    glowBlurSelected: 16,
    glowBlurUnselected: 10,
    shadowOffsetSelected: const Offset(0, 6),
    shadowOffsetUnselected: const Offset(0, 4),
    glowColor: Colors.black.withOpacity(.22),
    label: 'High',
    fontSize: 18,
    textOn: const Color.fromARGB(255, 0, 0, 0),
    textOff: const Color.fromARGB(255, 0, 0, 0).withOpacity(.85),
  );
}

CommandCardCfg cfgCommandCard(BuildContext ctx) {
  final t = Theme.of(ctx);
  final base = t.colorScheme.surfaceVariant.withOpacity(.70);
  return CommandCardCfg(
    width: 480,
    margin: const EdgeInsets.only(top: 60),
    padding: const EdgeInsets.all(12),
    background: [lighten(base, .06), darken(base, .06)],
    radius: 16,
    borderColor: t.colorScheme.outlineVariant.withOpacity(.45),
    borderWidth: 1.2,
    shadowBlur: 12,
    shadowOffset: const Offset(0, 6),
    shadowColor: Colors.black.withOpacity(.14),
    titleFont: 18,
    valueFont: 24,
    textColor: t.textTheme.bodyMedium?.color ?? Colors.white,
    valueColor: t.textTheme.bodyLarge?.color ?? Colors.white,
    dividerColor: t.colorScheme.outlineVariant.withOpacity(.6),
  );
}

/// scale config ด้วย helper _S
BtnCfg scaleBtn(BtnCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  height: s.h(c.height),
  margin: s.m(c.margin),
  radius: s.r(c.radius),
  borderWidthOn: s.r(c.borderWidthOn),
  borderWidthOff: s.r(c.borderWidthOff),
  glowBlurOn: s.r(c.glowBlurOn),
  glowBlurOff: s.r(c.glowBlurOff),
  shadowOffsetOn: s.o(c.shadowOffsetOn),
  shadowOffsetOff: s.o(c.shadowOffsetOff),
  iconPadding: s.m(c.iconPadding),
  labelFontSize: s.sp(c.labelFontSize),
);

TapCfg scaleTap(TapCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  height: s.h(c.height),
  margin: s.m(c.margin),
  radius: s.r(c.radius),
  borderWidthSelected: s.r(c.borderWidthSelected),
  borderWidthUnselected: s.r(c.borderWidthUnselected),
  glowBlurSelected: s.r(c.glowBlurSelected),
  glowBlurUnselected: s.r(c.glowBlurUnselected),
  shadowOffsetSelected: s.o(c.shadowOffsetSelected),
  shadowOffsetUnselected: s.o(c.shadowOffsetUnselected),
  fontSize: s.sp(c.fontSize),
);

CommandCardCfg scaleCard(CommandCardCfg c, _S s) => c.copyWith(
  width: s.w(c.width),
  margin: s.m(c.margin),
  padding: s.m(c.padding),
  radius: s.r(c.radius),
  borderWidth: s.r(c.borderWidth),
  shadowBlur: s.r(c.shadowBlur),
  shadowOffset: s.o(c.shadowOffset),
  titleFont: s.sp(c.titleFont),
  valueFont: s.sp(c.valueFont),
);

/// ========================= PAGE =========================
class Gamepad_4Botton extends StatefulWidget {
  const Gamepad_4Botton({super.key});

  @override
  State<Gamepad_4Botton> createState() => _Gamepad_4BottonState();
}

class _Gamepad_4BottonState extends State<Gamepad_4Botton> {
  Timer? _tick;

  bool _f = false, _b = false, _l = false, _r = false;
  String _command = '0', _lastSent = '', _speedLabel = 'V50';

  @override
  void initState() {
    super.initState();
    OrientationUtils.setLandscape();

    _tick = Timer.periodic(
      const Duration(milliseconds: kSendIntervalMs),
      (_) => _sendLoop(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    OrientationUtils.setPortrait(); // ← คืนเป็นแนวตั้ง

    super.dispose();
  }

  void _sendLoop() {
  // ถ้ากดคู่กันในแกนเดียว ยกเลิกตัวที่หลัง (เหมือนของเดิม)
  if (_f && _b) _b = false;
  if (_l && _r) _r = false;

  // แปลงปุ่มเป็นตัวอักษรแบบ Gamepad 8
  final v = _f ? 'U' : (_b ? 'D' : '');   // แกนขึ้น-ลง
  final h = _l ? 'L' : (_r ? 'R' : '');   // แกนซ้าย-ขวา

  String cmd;

  // ไม่มีปุ่ม → ส่ง 0
  if (v.isEmpty && h.isEmpty) {
    cmd = '0';
  }
  // เดินหน้า/ถอยหลังล้วน เช่น 'U' หรือ 'D'
  else if (v.isNotEmpty && h.isEmpty) {
    cmd = v;
  }
  // ซ้าย/ขวาล้วน เช่น 'L' หรือ 'R'
  else if (v.isEmpty && h.isNotEmpty) {
    cmd = h;
  }
  // ผสม เช่น UL, UR, DL, DR
  else {
    cmd = '$v$h';
  }

  // ส่ง BLE
  BleManager.instance.send(cmd);

  if (cmd != _lastSent) {
    _command = cmd;
    _lastSent = cmd;
    setState(() {});
  }
}

  void _sendSpeed(String v) {
    _speedLabel = v;
    // เดิม: ClassicManager.instance.sendLine(v);
    BleManager.instance.send(v);
    setState(() {});
  }

  /// --------- ฝั่งซ้าย: ปุ่ม Up / Down ชิดซ้าย & กึ่งกลางแนว Y ----------
  Widget _leftColumn(BuildContext context, _S s) {
    final cfgF = scaleBtn(cfgForward(context), s);
    final cfgB = scaleBtn(cfgBackward(context), s);

    return Align(
      alignment: Alignment.centerLeft, // ชิดซ้ายของหน้าจอ
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // กึ่งกลางแกน Y
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GamepadHoldButton(
            cfg: cfgF,
            onChange: (down) => setState(() {
              _f = down;
              if (down) _b = false;
            }),
          ),
          GamepadHoldButton(
            cfg: cfgB,
            onChange: (down) => setState(() {
              _b = down;
              if (down) _f = false;
            }),
          ),
        ],
      ),
    );
  }

  /// --------- ฝั่งขวา: Speed + Left/Right (Right ชิดขวา) ----------
  Widget _rightColumn(BuildContext context, _S s) {
    final low = scaleTap(cfgSpeedLow(context), s);
    final mid = scaleTap(cfgSpeedMid(context), s);
    final high = scaleTap(cfgSpeedHigh(context), s);
    final cfgL = scaleBtn(cfgLeft(context), s);
    final cfgR = scaleBtn(cfgRight(context), s);
    final cmdCfg = scaleCard(cfgCommandCard(context), s);

    final speedRow = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: s.h(6),
      children: [
        GamepadTapButton(
          cfg: low,
          selected: _speedLabel == 'V30',
          onTap: () => _sendSpeed('V30'),
        ),
        GamepadTapButton(
          cfg: mid,
          selected: _speedLabel == 'V50',
          onTap: () => _sendSpeed('V50'),
        ),
        GamepadTapButton(
          cfg: high,
          selected: _speedLabel == 'V100',
          onTap: () => _sendSpeed('V100'),
        ),
      ],
    );

    // ใช้ Row + Expanded ให้ Left อยู่กลาง, Right ชิดขวา
    final lrRow = Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: GamepadHoldButton(
              cfg: cfgL,
              onChange: (down) => setState(() {
                _l = down;
                if (down) _r = false;
              }),
            ),
          ),
        ),
        SizedBox(width: s.w(8)),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight, // ปุ่ม Right ชิดขวา
            child: GamepadHoldButton(
              cfg: cfgR,
              onChange: (down) => setState(() {
                _r = down;
                if (down) _l = false;
              }),
            ),
          ),
        ),
      ],
    );

    final cmdCard = GamepadCommandCard(
      cfg: cmdCfg,
      command: _command,
      speed: _speedLabel,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        speedRow,
        SizedBox(height: s.h(10)),
        lrRow,
        SizedBox(height: cmdCfg.margin.top),
        cmdCard,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Gamepad(4 Button)'),
        actions: const [ConnectionStatusBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, cons) {
                final s = _S.from(cons);
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.w(PAGE_PAD_H),
                    vertical: s.h(PAGE_PAD_V),
                  ),
                  child: Center(
                    child: SizedBox.expand(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: FLEX_LEFT,
                            child: _leftColumn(context, s),
                          ),
                          SizedBox(width: s.w(COLUMN_GAP)),
                          Flexible(
                            flex: FLEX_RIGHT,
                            child: _rightColumn(context, s),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const LogoCorner(),
          ],
        ),
      ),
    );
  }
}
