// lib/core/widgets/connection_status_badge.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/language_controller.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_permissions.dart';
import '../connection/app_connection.dart';
import 'gamepad_app_bar.dart';

String _t(bool isThai, String th, String en) => isThai ? th : en;

const _tutorialCardSurface = Color(0xFF1F2329);
const _tutorialCtaBlue = Color(0xFF3B82F6);

class ConnectionStatusBadgeController {
  _ConnectionStatusBadgeState? _state;

  void _attach(_ConnectionStatusBadgeState state) {
    _state = state;
  }

  void _detach(_ConnectionStatusBadgeState state) {
    if (_state == state) {
      _state = null;
    }
  }

  void openTutorialSheet() {
    _state?._openSheet(showTutorial: true);
  }
}

class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({
    super.key,
    this.controller,
    this.appBarMetrics,
    this.showTutorial = false,
    this.tutorialIsFirst = false,
    this.tutorialIsLast = false,
    this.onTutorialSkip,
    this.onTutorialBack,
    this.onTutorialNext,
    this.onTutorialFinish,
    this.tutorialTitle,
    this.tutorialBody,
  });

  final ConnectionStatusBadgeController? controller;
  final GamepadAppBarMetrics? appBarMetrics;
  final bool showTutorial;
  final bool tutorialIsFirst;
  final bool tutorialIsLast;
  final VoidCallback? onTutorialSkip;
  final VoidCallback? onTutorialBack;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialFinish;
  final String? tutorialTitle;
  final String? tutorialBody;

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge> {
  bool _sheetOpen = false;
  Offset? _sheetAnchor;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  void _openSheet({bool showTutorial = false}) {
    if (Platform.isIOS) {
      _openSheetIOS(showTutorial: showTutorial);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black87,
      builder: (context) => _ConnectionSheet(
        showTutorial: showTutorial,
        tutorialIsFirst: widget.tutorialIsFirst,
        tutorialIsLast: widget.tutorialIsLast,
        tutorialTitle: widget.tutorialTitle,
        tutorialBody: widget.tutorialBody,
        onTutorialSkip: widget.onTutorialSkip,
        onTutorialBack: widget.onTutorialBack,
        onTutorialNext: widget.onTutorialNext,
        onTutorialFinish: widget.onTutorialFinish,
      ),
    );
  }

  Future<void> _openSheetIOS({bool showTutorial = false}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final allowDismiss = ValueNotifier<bool>(false);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (allowDismiss.value) return;
      allowDismiss.value = true;
    });
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      anchorPoint: _sheetAnchor,
      builder: (context) {
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
                child: Material(
                  color: Colors.transparent,
                  child: _ConnectionSheet(
                    showTutorial: showTutorial,
                    tutorialIsFirst: widget.tutorialIsFirst,
                    tutorialIsLast: widget.tutorialIsLast,
                    tutorialTitle: widget.tutorialTitle,
                    tutorialBody: widget.tutorialBody,
                    onTutorialSkip: widget.onTutorialSkip,
                    onTutorialBack: widget.onTutorialBack,
                    onTutorialNext: widget.onTutorialNext,
                    onTutorialFinish: widget.onTutorialFinish,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _sheetOpen = false;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThai = LanguageController.isThai.value;

    return StreamBuilder<BleConnectionStatus>(
      stream: BleManager.instance.statusStream,
      initialData: BleManager.instance.connectionStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? BleConnectionStatus.disconnected;
        final connected = status == BleConnectionStatus.connected;
        final reconnecting = status == BleConnectionStatus.reconnecting;
        final failed = status == BleConnectionStatus.reconnectFailed;
        final metrics = widget.appBarMetrics;
        final isDark = theme.brightness == Brightness.dark;
        final accentColor = connected
            ? const Color(0xFF34D399)
            : reconnecting
                ? const Color(0xFFF59E0B)
                : failed
                    ? const Color(0xFFF87171)
                    : const Color(0xFF60A5FA);

        final bgColor = _opacity(
          Color.lerp(
                isDark ? const Color(0xFF101827) : theme.colorScheme.surface,
                isDark ? Colors.white : Colors.black,
                isDark ? 0.04 : 0.02,
              ) ??
              theme.colorScheme.surface,
          isDark ? 0.92 : 0.97,
        );
        final borderColor = _opacity(
          theme.colorScheme.outline,
          isDark ? 0.45 : 0.22,
        );

        final icon = connected
            ? Icons.bluetooth_connected
            : reconnecting
                ? Icons.bluetooth_searching
                : Icons.bluetooth_disabled;

        final text = connected
            ? _t(isThai, 'BLE เปิด', 'BLE On')
            : reconnecting
                ? _t(isThai, 'กำลังเชื่อมต่อ...', 'Reconnecting...')
                : failed
                    ? _t(isThai, 'เชื่อมต่อไม่สำเร็จ', 'Reconnect failed')
                    : _t(isThai, 'BLE ปิด', 'BLE Off');
        final dotColor = connected
            ? Colors.green
            : reconnecting
                ? const Color(0xFFF59E0B)
                : Colors.redAccent;
        final iconGap = metrics?.labelIconGap ?? 4.0;
        final borderRadius =
            metrics?.borderRadius ?? BorderRadius.circular(20);
        final padding =
            metrics?.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
        final textStyle = (theme.textTheme.bodySmall ?? const TextStyle())
            .copyWith(
              fontSize:
                  metrics?.telemetryLabelFontSize ??
                  theme.textTheme.bodySmall?.fontSize,
              fontWeight: FontWeight.w800,
              color:
                  Color.lerp(
                    accentColor,
                    isDark ? Colors.white : theme.colorScheme.onSurface,
                    isDark ? 0.46 : 0.68,
                  ) ??
                  theme.colorScheme.onSurface,
            );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTapDown: (d) => _sheetAnchor = d.globalPosition,
            onTap: () => _openSheet(showTutorial: widget.showTutorial),
            child: ConstrainedBox(
              constraints:
                  metrics != null
                      ? BoxConstraints(minWidth: metrics.labelButtonWidth)
                      : const BoxConstraints(),
              child: Container(
                height: metrics?.controlHeight,
                alignment: Alignment.center,
                margin:
                    metrics == null
                        ? const EdgeInsets.only(right: 6, top: 4, bottom: 4)
                        : EdgeInsets.zero,
                padding: padding,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: borderRadius,
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: _opacity(
                        Colors.black,
                        isDark ? 0.12 : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _opacity(Colors.white, isDark ? 0.06 : 0.16),
                      blurRadius: 10,
                      spreadRadius: 0.4,
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: metrics?.iconSize ?? 16, color: accentColor),
                    SizedBox(width: iconGap),
                    Text(
                      text,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                    SizedBox(width: iconGap),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _opacity(dotColor, 0.55),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BleEntry {
  final ScanResult result;
  final DateTime lastSeen;

  const _BleEntry(this.result, this.lastSeen);

  _BleEntry copyWith({ScanResult? result, DateTime? lastSeen}) {
    return _BleEntry(result ?? this.result, lastSeen ?? this.lastSeen);
  }
}

class _MockBleDevice {
  final String name;
  final String id;
  final int rssi;

  const _MockBleDevice({
    required this.name,
    required this.id,
    required this.rssi,
  });
}

class _ConnectionSheet extends StatefulWidget {
  const _ConnectionSheet({
    this.showTutorial = false,
    this.tutorialIsFirst = false,
    this.tutorialIsLast = false,
    this.tutorialTitle,
    this.tutorialBody,
    this.onTutorialSkip,
    this.onTutorialBack,
    this.onTutorialNext,
    this.onTutorialFinish,
  });

  final bool showTutorial;
  final bool tutorialIsFirst;
  final bool tutorialIsLast;
  final String? tutorialTitle;
  final String? tutorialBody;
  final VoidCallback? onTutorialSkip;
  final VoidCallback? onTutorialBack;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialFinish;

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  static const _prefsLastDeviceId = 'ble_last_device_id';

  bool _scanning = false;
  bool _connecting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _cleanupTimer;
  final Map<String, _BleEntry> _deviceMap = {};
  String? _lastDeviceId;
  bool _pendingConnectLast = false;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  TextStyle _sheetTextStyle(
    bool isThai, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
    );
  }

  Widget _buildTutorialCard({
    required BuildContext context,
    required bool isThai,
    required String title,
    required String body,
  }) {
    final cardWidth =
        (MediaQuery.of(context).size.width - 56).clamp(220.0, 420.0).toDouble();
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: isThai ? 19.0 : 18.0,
      fontWeight: FontWeight.w800,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
      height: 1.15,
    );
    final bodyStyle = TextStyle(
      color: const Color(0xFFD3DAE6),
      fontSize: isThai ? 14.5 : 14.0,
      fontWeight: FontWeight.w500,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
      height: 1.45,
    );
    final linkStyle = TextStyle(
      color: const Color(0xFFB6BEC9),
      fontSize: isThai ? 13.5 : 13.0,
      fontWeight: FontWeight.w500,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
    );
    final ctaStyle = TextStyle(
      color: Colors.white,
      fontSize: isThai ? 13.5 : 13.0,
      fontWeight: FontWeight.w700,
      fontFamily: isThai ? 'Kanit' : 'Roboto',
      decoration: TextDecoration.none,
    );
    final linkButtonStyle = TextButton.styleFrom(
      foregroundColor: const Color(0xFFB6BEC9),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: _opacity(const Color(0xFFB6BEC9), 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _tutorialCardSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _opacity(Colors.white, 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _opacity(Colors.black, 0.34),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 10),
                Text(body, style: bodyStyle),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _handleTutorialAction(widget.onTutorialSkip),
                      style: linkButtonStyle,
                      child: Text(
                        _t(isThai, 'ข้าม', 'Skip'),
                        style: linkStyle,
                      ),
                    ),
                    const Spacer(),
                    if (!widget.tutorialIsFirst) ...[
                      TextButton(
                        onPressed: () => _handleTutorialAction(widget.onTutorialBack),
                        style: linkButtonStyle,
                        child: Text(
                          _t(isThai, 'ย้อนกลับ', 'Back'),
                          style: linkStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () => _handleTutorialAction(
                        widget.tutorialIsLast
                            ? widget.onTutorialFinish
                            : widget.onTutorialNext,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tutorialCtaBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(96, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _t(
                          isThai,
                          widget.tutorialIsLast ? 'เสร็จสิ้น' : 'ถัดไป',
                          widget.tutorialIsLast ? 'Finish' : 'Next',
                        ),
                        style: ctaStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLastDevice();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pruneOldDevices(),
    );
    if (!widget.showTutorial) {
      _startScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  bool _isRobot(ScanResult r) {
    return r.advertisementData.serviceUuids.any(
      (uuid) => uuid.str.toLowerCase().startsWith(BleManager.uartServicePrefix),
    );
  }

  void _pruneOldDevices() {
    if (!_scanning) return;
    final now = DateTime.now();
    _deviceMap.removeWhere(
      (_, entry) => now.difference(entry.lastSeen) > const Duration(seconds: 20),
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsLastDeviceId);
    if (mounted) {
      setState(() {
        _lastDeviceId = id;
      });
    } else {
      _lastDeviceId = id;
    }
    _queueAutoConnectLast();
  }

  void _queueAutoConnectLast() {
    if (widget.showTutorial) return;
    if (_lastDeviceId == null) return;
    if (_connecting || BleManager.instance.isConnected) return;
    if (_pendingConnectLast) return;
    _pendingConnectLast = true;
    if (!_scanning) {
      _startScan();
    }
  }

  Future<void> _saveLastDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastDeviceId, id);
    if (mounted) {
      setState(() {
        _lastDeviceId = id;
      });
    } else {
      _lastDeviceId = id;
    }
  }

  Future<void> _forgetLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLastDeviceId);
    if (mounted) {
      setState(() {
        _lastDeviceId = null;
      });
    } else {
      _lastDeviceId = null;
    }
  }

  Future<void> _promptEnableBluetooth() async {
    final isThai = LanguageController.isThai.value;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              isThai,
              'บลูทูธปิดอยู่ กรุณาเปิดบลูทูธก่อน',
              'Bluetooth is off. Please turn it on.',
            ),
          ),
        ),
      );
    }

    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn(timeout: 30);
        return;
      } catch (_) {}
    }

    await openAppSettings();
  }

  Future<void> _startScan() async {
    if (_scanning || _connecting) return;

    final permissionsOk = await ensureBleScanPermissions();
    if (!permissionsOk) {
      if (mounted) {
        final isThai = LanguageController.isThai.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                isThai,
                'กรุณาอนุญาตสิทธิ์ Bluetooth เพื่อค้นหาอุปกรณ์',
                'Please allow Bluetooth permission to scan for devices.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      await _promptEnableBluetooth();
      return;
    }

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        for (final r in list) {
          if (!_isRobot(r)) continue;
          final id = r.device.remoteId.str;
          final old = _deviceMap[id];
          if (old == null) {
            _deviceMap[id] = _BleEntry(r, now);
          } else {
            _deviceMap[id] = old.copyWith(result: r, lastSeen: now);
          }
        }
      });

      if (_pendingConnectLast && _lastDeviceId != null) {
        final entry = _deviceMap[_lastDeviceId!];
        if (entry != null && !_connecting) {
          _pendingConnectLast = false;
          _connect(entry.result);
        }
      }
    });

    setState(() => _scanning = true);
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      } else {
        _scanning = false;
      }
    }
  }

  Future<void> _disconnect() async {
    await BleManager.instance.disconnect();
    AppConnection.instance.setBleConnected(false);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connectLast() async {
    final isThai = LanguageController.isThai.value;
    final id = _lastDeviceId;
    if (id == null) return;
    final entry = _deviceMap[id];
    if (entry == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
          _t(isThai, 'ไม่พบอุปกรณ์ล่าสุด', 'Last device not found'),
            ),
          ),
        );
      }
      return;
    }
    await _connect(entry.result);
  }

  Future<void> _connect(ScanResult r) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      await FlutterBluePlus.stopScan();
      await BleManager.instance.disconnect(source: 'manual_connect_replace');
      try {
        await r.device.disconnect();
      } catch (_) {}

      await r.device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      BleManager.instance.setDevice(r.device);
      final ok = await BleManager.instance.discoverServices();
      if (ok) {
        await _saveLastDeviceId(r.device.remoteId.str);
        AppConnection.instance.setBleConnected(true);
        await BleManager.instance.sendSystemText(
          "HELLO_APP",
          source: 'connection_status_badge',
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        await BleManager.instance.disconnect(source: 'services_missing');
        AppConnection.instance.setBleConnected(false);
      }
    } catch (_) {
      AppConnection.instance.setBleConnected(false);
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      } else {
        _connecting = false;
      }
    }
  }

  void _handleTutorialAction(VoidCallback? action) {
    if (action == null) return;
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    final connected = BleManager.instance.isConnected;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark
        ? _opacity(const Color(0xFF0B1220), 0.88)
        : _opacity(const Color(0xFFF8FAFC), 0.96);
    final sheetBorder = isDark
        ? _opacity(const Color(0xFF7DD3FC), 0.38)
        : _opacity(const Color(0xFF0EA5E9), 0.24);
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bodyColor = isDark
        ? _opacity(Colors.white, 0.7)
        : _opacity(theme.colorScheme.onSurface, 0.72);
    final tileColor = isDark
        ? _opacity(Colors.white, 0.05)
        : _opacity(const Color(0xFF0F172A), 0.04);
    final tileBorder = isDark
        ? _opacity(Colors.white, 0.08)
        : _opacity(const Color(0xFF0F172A), 0.12);
    final accent = connected ? const Color(0xFF22C55E) : const Color(0xFF38BDF8);
    final devices = _deviceMap.values.map((e) => e.result).toList();
    final maxH = MediaQuery.of(context).size.height * 0.6;
    final mockDevices = const [
      _MockBleDevice(
        name: 'PrinceBot-01',
        id: '64:B7:08:6F:D4:06',
        rssi: -45,
      ),
      _MockBleDevice(
        name: 'PrinceBot-02',
        id: '64:B7:08:6F:D4:07',
        rssi: -62,
      ),
      _MockBleDevice(
        name: 'LineSonic-01',
        id: '64:B7:08:6F:D4:09',
        rssi: -70,
      ),
    ];
    final showMock = widget.showTutorial;
    final tutorialLock = widget.showTutorial;

    final previewPanel = Container(
      margin: widget.showTutorial ? EdgeInsets.zero : const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sheetBorder),
        boxShadow: [
          BoxShadow(
            color: _opacity(Colors.black, isDark ? 0.26 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.showTutorial ? maxH * 0.72 : maxH,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _opacity(accent, isDark ? 0.55 : 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _opacity(accent, isDark ? 0.2 : 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _opacity(accent, isDark ? 0.45 : 0.28),
                      ),
                    ),
                    child: Icon(
                      connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      connected
                          ? '${_t(isThai, 'เชื่อมต่อแล้ว', 'Connected')}: ${BleManager.instance.currentDeviceName ?? BleManager.instance.currentDeviceId ?? _t(isThai, 'ไม่ทราบชื่อ', 'Unknown')}'
                          : _t(isThai, 'ยังไม่เชื่อมต่อ', 'Not connected'),
                      style: _sheetTextStyle(
                        isThai,
                        size: 14,
                        weight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: tutorialLock ? null : _disconnect,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        backgroundColor: _opacity(
                          Colors.redAccent,
                          isDark ? 0.14 : 0.1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: _opacity(Colors.redAccent, 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        _t(isThai, 'ยกเลิกการเชื่อมต่อ', 'Disconnect'),
                        style: _sheetTextStyle(
                          isThai,
                          size: 13,
                          weight: FontWeight.w600,
                          color: tutorialLock
                              ? _opacity(titleColor, 0.35)
                              : Colors.redAccent,
                        ),
                      ),
                    )
                  else ...[
                    if (_lastDeviceId != null)
                      TextButton(
                        onPressed:
                            (tutorialLock || _connecting) ? null : _connectLast,
                        style: TextButton.styleFrom(
                          foregroundColor: titleColor,
                          backgroundColor: _opacity(
                            accent,
                            isDark ? 0.16 : 0.1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(color: _opacity(accent, 0.3)),
                          ),
                        ),
                        child: Text(
                          _t(isThai, 'เชื่อมต่ออุปกรณ์ล่าสุด', 'Connect last'),
                          style: _sheetTextStyle(
                            isThai,
                            size: 13,
                            weight: FontWeight.w600,
                            color: tutorialLock
                                ? _opacity(titleColor, 0.35)
                                : titleColor,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed:
                          (tutorialLock || _scanning) ? null : _startScan,
                      style: TextButton.styleFrom(
                        foregroundColor: titleColor,
                        backgroundColor: _opacity(
                          accent,
                          isDark ? 0.16 : 0.1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: _opacity(accent, 0.3)),
                        ),
                      ),
                      child: Text(
                        _scanning
                            ? _t(isThai, 'กำลังค้นหา...', 'Scanning...')
                            : _t(isThai, 'ค้นหา', 'Scan'),
                        style: _sheetTextStyle(
                          isThai,
                          size: 13,
                          weight: FontWeight.w600,
                          color: tutorialLock
                              ? _opacity(titleColor, 0.35)
                              : titleColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (!connected)
                showMock
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(isThai, 'ตัวอย่างอุปกรณ์ที่พบ', 'Example devices'),
                            style: _sheetTextStyle(
                              isThai,
                              size: 13,
                              weight: FontWeight.w600,
                              color: bodyColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ListView.builder(
                            itemCount: mockDevices.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final d = mockDevices[index];
                              return ListTile(
                                dense: true,
                                tileColor: tileColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: tileBorder),
                                ),
                                title: Text(
                                  d.name,
                                  style: _sheetTextStyle(
                                    isThai,
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                ),
                                subtitle: Text(
                                  'MAC: ${d.id} • RSSI: ${d.rssi} dBm',
                                  style: _sheetTextStyle(
                                    isThai,
                                    size: 12,
                                    weight: FontWeight.w400,
                                    color: bodyColor,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: _opacity(titleColor, 0.45),
                                ),
                                onTap: null,
                              );
                            },
                          ),
                        ],
                      )
                    : devices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                _t(isThai, 'ไม่พบอุปกรณ์', 'No devices found'),
                                style: _sheetTextStyle(
                                  isThai,
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: bodyColor,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: devices.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final r = devices[index];
                              final name = r.device.platformName.isNotEmpty
                                  ? r.device.platformName
                                  : r.device.remoteId.str;
                              return ListTile(
                                dense: true,
                                tileColor: tileColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: tileBorder),
                                ),
                                title: Text(
                                  name,
                                  style: _sheetTextStyle(
                                    isThai,
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                ),
                                subtitle: Text(
                                  'MAC: ${r.device.remoteId.str} • RSSI: ${r.rssi} dBm',
                                  style: _sheetTextStyle(
                                    isThai,
                                    size: 12,
                                    weight: FontWeight.w400,
                                    color: bodyColor,
                                  ),
                                ),
                                trailing: _connecting
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: titleColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.chevron_right,
                                        color: _opacity(titleColor, 0.62),
                                      ),
                                onTap: (tutorialLock || _connecting)
                                    ? null
                                    : () => _connect(r),
                              );
                            },
                          ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_lastDeviceId != null)
                      TextButton(
                        onPressed: _forgetLastDevice,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          backgroundColor: _opacity(
                            Colors.redAccent,
                            isDark ? 0.12 : 0.08,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: _opacity(Colors.redAccent, 0.28),
                            ),
                          ),
                        ),
                        child: Text(
                        _t(isThai, 'ลืมอุปกรณ์', 'Forget'),
                          style: _sheetTextStyle(
                            isThai,
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: bodyColor,
                        backgroundColor: _opacity(
                          titleColor,
                          isDark ? 0.12 : 0.08,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: _opacity(titleColor, 0.18)),
                        ),
                      ),
                      child: Text(
                        _t(isThai, 'ยกเลิก', 'Cancel'),
                        style: _sheetTextStyle(
                          isThai,
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: bodyColor,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.showTutorial) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTutorialCard(
                    context: context,
                    isThai: isThai,
                    title:
                        widget.tutorialTitle ??
                        _t(isThai, 'สถานะ BLE', 'BLE Status'),
                    body:
                        widget.tutorialBody ??
                        _t(
                          isThai,
                          'แสดงสถานะ Bluetooth และตัวอย่างแผง BLE (โหมดสอนเป็นแบบดูอย่างเดียว)',
                          'Shows Bluetooth status with a BLE panel preview (view-only in tutorial).',
                        ),
                  ),
                  const SizedBox(height: 12),
                  previewPanel,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(child: previewPanel);
  }
}








