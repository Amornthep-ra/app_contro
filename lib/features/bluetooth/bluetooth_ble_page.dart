// lib/features/bluetooth/bluetooth_ble_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connection/app_connection.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ui/language_controller.dart';

class BluetoothBlePage extends StatefulWidget {
  const BluetoothBlePage({super.key});

  @override
  State<BluetoothBlePage> createState() => _BluetoothBlePageState();
}

class _BleEntry {
  final ScanResult result;
  final DateTime lastSeen;

  const _BleEntry(this.result, this.lastSeen);

  _BleEntry copyWith({ScanResult? result, DateTime? lastSeen}) {
    return _BleEntry(result ?? this.result, lastSeen ?? this.lastSeen);
  }
}

class _BluetoothBlePageState extends State<BluetoothBlePage> {
  bool _scanning = false;
  bool _connecting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<bool>? _connStateSub;

  final Map<String, _BleEntry> _deviceMap = {};

  BluetoothDevice? _connectedDevice;
  static String? _lastDeviceName;

  Timer? _cleanupTimer;

  static const int _scanTimeoutSeconds = 10;
  int _scanSecondsLeft = 0;
  Timer? _scanCountdownTimer;

  static const _prefsLastDeviceIdKey = 'ble_last_device_id';
  static const _prefsLastDeviceNameKey = 'ble_last_device_name';

  String? _lastDeviceId;
  String? _lastDeviceNamePersisted;
  bool _pendingConnectLast = false;
  DateTime? _lastDisconnectTime;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  Color _textPrimary(BuildContext context) =>
      _isDark(context) ? Colors.white : Colors.black87;
  Color _textSecondary(BuildContext context) =>
      _isDark(context) ? Colors.white70 : Colors.black54;
  Color _textTertiary(BuildContext context) =>
      _isDark(context) ? Colors.white54 : Colors.black45;
  Color _panelBg(BuildContext context) =>
      _opacity(_isDark(context) ? Colors.white : Colors.black, 0.06);
  Color _panelBorder(BuildContext context) =>
      _opacity(_isDark(context) ? Colors.white : Colors.black, 0.12);
  Color _pillBg(BuildContext context) =>
      _opacity(_isDark(context) ? Colors.white : Colors.black, 0.08);

  String _t(String th, String en) =>
      LanguageController.isThai.value ? th : en;

  bool isRobot(ScanResult r) {
    return r.advertisementData.serviceUuids.any(
      (uuid) => uuid.str.toLowerCase().startsWith("6e400001"),
    );
  }

  @override
  void initState() {
    super.initState();
    _bindBluetoothState();
    _bindConnectionGuard();

    _loadPrefs();

    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pruneOldDevices();
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _lastDeviceId = prefs.getString(_prefsLastDeviceIdKey);
    _lastDeviceNamePersisted = prefs.getString(_prefsLastDeviceNameKey);
    if (_lastDeviceName == null || _lastDeviceName!.isEmpty) {
      _lastDeviceName = _lastDeviceNamePersisted;
    }
    if (mounted) setState(() {});
    _queueAutoConnectLast();
  }

  void _queueAutoConnectLast() {
    if (_lastDeviceId == null) return;
    if (_connecting || BleManager.instance.isConnected) return;
    if (_pendingConnectLast) return;
    _pendingConnectLast = true;
    if (!_scanning) {
      _startScan();
    }
  }

  void _bindBluetoothState() {
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;

      if (state != BluetoothAdapterState.on) {
        BleManager.instance.disconnect();
        AppConnection.instance.setBleConnected(false);

        _scanCountdownTimer?.cancel();
        _scanCountdownTimer = null;

        setState(() {
          _connectedDevice = null;
          _scanning = false;
          _scanSecondsLeft = 0;
          _deviceMap.clear();
          _connecting = false;
          _pendingConnectLast = false;
        });

        _showSnack(
          _t(
            'Bluetooth ถูกปิด กรุณาเปิดใหม่เพื่อเชื่อมต่ออีกครั้ง',
            'Bluetooth is off. Please turn it on to reconnect.',
          ),
        );
      } else {
        _queueAutoConnectLast();
      }
    });

    _isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!mounted) return;
      if (_scanning != isScanning) {
        setState(() {
          _scanning = isScanning;
          if (!isScanning) {
            _scanCountdownTimer?.cancel();
            _scanCountdownTimer = null;
            _scanSecondsLeft = 0;
            _pendingConnectLast = false;
          }
        });
      }
    });
  }

  void _bindConnectionGuard() {
    _connStateSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;

      if (!connected) {
        AppConnection.instance.setBleConnected(false);
        setState(() {
          _connectedDevice = null;
          _connecting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _cleanupTimer?.cancel();

    _scanCountdownTimer?.cancel();
    _scanCountdownTimer = null;

    _adapterStateSub?.cancel();
    _isScanningSub?.cancel();
    _connStateSub?.cancel();

    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning || _connecting) return;

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      await _promptEnableBluetooth();
      AppConnection.instance.setBleConnected(false);
      return;
    }

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (!mounted) return;
      final now = DateTime.now();

      setState(() {
        for (final r in list) {
          if (!isRobot(r)) continue;

          final id = r.device.remoteId.str;
          final old = _deviceMap[id];

          if (old == null) {
            _deviceMap[id] = _BleEntry(r, now);
          } else {
            _deviceMap[id] = old.copyWith(result: r, lastSeen: now);
          }
        }

        _pruneOldDevicesLocked(now);
      });

      if (_pendingConnectLast && _lastDeviceId != null) {
        final entry = _deviceMap[_lastDeviceId!];
        if (entry != null && !_connecting) {
          _pendingConnectLast = false;
          _connect(entry.result);
        }
      }
    });

    try {
      setState(() {
        _scanSecondsLeft = _scanTimeoutSeconds;
      });

      _scanCountdownTimer?.cancel();
      _scanCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (!_scanning || _scanSecondsLeft <= 1) {
            _scanSecondsLeft = 0;
            timer.cancel();
          } else {
            _scanSecondsLeft--;
          }
        });
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: _scanTimeoutSeconds),
      );
    } catch (e) {
      _scanCountdownTimer?.cancel();
      _scanCountdownTimer = null;
      _scanSecondsLeft = 0;

      _showSnack(_t('เริ่มสแกนไม่สำเร็จ: $e', 'Start scan failed: $e'));
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _stopScan() async {
    if (!_scanning) return;
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _scanCountdownTimer?.cancel();
    _scanCountdownTimer = null;
    if (mounted) {
      setState(() {
        _scanning = false;
        _scanSecondsLeft = 0;
      });
    } else {
      _scanning = false;
      _scanSecondsLeft = 0;
    }
  }

  Future<void> _promptEnableBluetooth() async {
    _showSnack(
      _t(
        'Bluetooth ถูกปิด โปรดเปิด Bluetooth แล้วลองอีกครั้ง',
        'Bluetooth is off. Please turn it on and try again.',
      ),
    );

    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn(timeout: 30);
        return;
      } catch (_) {}
    }

    await openAppSettings();
  }

  void _pruneOldDevices() {
    if (!_scanning) return;
    final now = DateTime.now();
    _pruneOldDevicesLocked(now);
  }

  void _pruneOldDevicesLocked(DateTime now) {
    const timeout = Duration(seconds: 20);
    _deviceMap.removeWhere(
      (_, entry) => now.difference(entry.lastSeen) > timeout,
    );
  }

  Future<void> _disconnect() async {

    _lastDisconnectTime = DateTime.now();

    await BleManager.instance.disconnect();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSub?.cancel();
    _scanSub = null;

    if (!mounted) return;

    setState(() {
      _connectedDevice = null;
      _scanning = false;
      _connecting = false;
      _pendingConnectLast = false;
    });

    AppConnection.instance.setBleConnected(false);
    _showSnack(_t('ตัดการเชื่อมต่อแล้ว', 'Disconnected'));
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: _opacity(Colors.black, 0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(milliseconds: 1600),
          elevation: 6,
        ),
      );
  }

  Future<void> _connect(ScanResult r) async {
    if (_connecting) return;

    if (_lastDisconnectTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastDisconnectTime!) <
          const Duration(seconds: 3)) {
        debugPrint("Cooldown: wait a moment before reconnect");
        _showSnack(
          _t('รอสักครู่ก่อนเชื่อมต่อใหม่', 'Please wait before reconnecting.'),
        );
        return;
      }
    }

    final d = r.device;

    if (mounted) {
      setState(() {
        _connecting = true;
      });
    } else {
      _connecting = true;
    }

    try {
      await FlutterBluePlus.stopScan();
      await BleManager.instance.disconnect();
      try {
        await d.disconnect();
      } catch (_) {}

      await d.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );


      if (mounted) {
        setState(() => _connectedDevice = d);
      }
      AppConnection.instance.setBleConnected(true);

      final showName = d.platformName.isNotEmpty
          ? d.platformName
          : d.remoteId.str;
      _lastDeviceName = showName;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastDeviceIdKey, d.remoteId.str);
      await prefs.setString(_prefsLastDeviceNameKey, showName);
      _lastDeviceId = d.remoteId.str;
      _lastDeviceNamePersisted = showName;

      if (mounted) {
        _showSnack(_t('เชื่อมต่อกับ $showName สำเร็จ', 'Connected to $showName'));
      }

      BleManager.instance.setDevice(d);

      final ok = await BleManager.instance.discoverServices();
      if (!ok) {
        if (mounted) {
          _showSnack(
            _t('ไม่พบ UART RX/TX characteristic', 'UART RX/TX characteristic not found'),
          );
        }
      } else {
        BleManager.instance.send("HELLO_APP");
      }
    } catch (e) {
      AppConnection.instance.setBleConnected(false);

      if (mounted) {
        _showSnack(_t('เชื่อมต่อไม่สำเร็จ: $e', 'Connect failed: $e'));
        final state = await FlutterBluePlus.adapterState.first;
        if (state == BluetoothAdapterState.on && !_scanning) {
          _startScan();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      } else {
        _connecting = false;
      }
    }
  }

  String _signalLabel(int rssi) {
    if (rssi >= -55) return _t('แรงมาก', 'Very strong');
    if (rssi >= -65) return _t('แรง', 'Strong');
    if (rssi >= -75) return _t('ปานกลาง', 'Medium');
    if (rssi >= -85) return _t('อ่อน', 'Weak');
    return _t('อ่อนมาก', 'Very weak');
  }

  IconData _signalIcon(int rssi) {
    return Icons.bluetooth;
  }

  Color _signalColor(BuildContext context, int rssi) {
    if (rssi >= -65) {
      return const Color(0xFF22C55E);
    } else if (rssi >= -80) {
      return const Color(0xFFEAB308);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  Widget _buildBleStatusBar() {
    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,
      initialData: BleManager.instance.isConnected,
      builder: (context, snap) {
        final isDark = _isDark(context);
        final connected = snap.data ?? false;

        String name;
        if (connected) {
          if (_connectedDevice != null) {
            if (_connectedDevice!.platformName.isNotEmpty) {
              name = _connectedDevice!.platformName;
            } else {
              name = _connectedDevice!.remoteId.str;
            }
          } else if (_lastDeviceName != null && _lastDeviceName!.isNotEmpty) {
            name = _lastDeviceName!;
          } else {
            name = _t('ไม่ทราบชื่อ', 'Unknown');
          }
        } else {
          name = _t('ยังไม่เชื่อมต่อ', 'Not connected');
        }

        final titleColor = _textPrimary(context);
        final t = Theme.of(context).textTheme;
        final titleStyle =
            t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor,
              fontSize: 15,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ) ??
            TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: titleColor,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            );

        final grad = connected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _opacity(const Color(0xFF0EA5E9), 0.30),
                  _opacity(const Color(0xFF22D3EE), 0.18),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _opacity(isDark ? Colors.white : Colors.black, 0.10),
                  _opacity(isDark ? Colors.white : Colors.black, 0.04),
                ],
              );

        final border = connected
            ? _opacity(const Color(0xFF38BDF8), 0.55)
            : _opacity(isDark ? const Color(0xFF60A5FA) : Colors.black, 0.25);

        final actions = <Widget>[];

        if (!connected) {
          final icon = (_connecting || _scanning)
              ? Icons.hourglass_top
              : Icons.refresh;
          final label = _connecting
              ? _t('กำลังเชื่อมต่อ...', 'Connecting...')
              : (_scanning
                    ? (_scanSecondsLeft > 0
                          ? _t('กำลังสแกน (${_scanSecondsLeft}s)', 'Scanning (${_scanSecondsLeft}s)')
                          : _t('กำลังสแกน...', 'Scanning...'))
                    : _t('สแกน', 'Scan'));

          actions.add(
            _smallAction(
              icon: icon,
              label: label,
              onTap: (_scanning || _connecting) ? null : _startScan,
            ),
          );
          if (_scanning) {
            actions.add(
              _smallAction(
                icon: Icons.stop_circle,
                label: _t('หยุด', 'Stop'),
                onTap: _stopScan,
                danger: true,
              ),
            );
          }
        } else {
          actions.add(
            _smallAction(
              icon: Icons.link_off,
              label: _t('ยกเลิกการเชื่อมต่อ', 'Disconnect'),
              onTap: _disconnect,
              danger: true,
            ),
          );
        }

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: grad,
                border: Border.all(color: border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: _opacity(Colors.black, 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: _textPrimary(context),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    fit: FlexFit.loose,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          connected
                              ? _t('เชื่อมต่อ: $name', 'Connected: $name')
                              : _t('ยังไม่เชื่อมต่อ', 'Not connected'),
                          key: ValueKey(
                            connected ? "connected_$name" : "disconnected",
                          ),
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...actions,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _smallAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final base = danger ? const Color(0xFFFF6B6B) : const Color(0xFF38BDF8);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _pillBg(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _opacity(base, 0.75), width: 1),
          boxShadow: [BoxShadow(blurRadius: 8, color: _opacity(base, 0.25))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _textPrimary(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _textPrimary(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _deviceMap.values.map((e) => e.result).where((r) {
      if (_connectedDevice == null) {
        return true;
      }
      return r.device.remoteId != _connectedDevice!.remoteId;
    }).toList();

    final lastId = _lastDeviceId;
    final lastName = _resolveLastDeviceName(lastId);

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(_t('Bluetooth Low Energy (BLE)', 'Bluetooth Low Energy (BLE)')),
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 89, 139, 255),
                        Color.fromARGB(255, 192, 203, 250),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Builder(
            builder: (context) {
              final pad = MediaQuery.of(context).padding;
              final size = MediaQuery.of(context).size;
              return Transform.translate(
                offset: Offset(-pad.left, 0),
                child: SizedBox(
                  width: size.width + pad.left + pad.right,
                  child: _buildBleStatusBar(),
                ),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          if (lastId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: _lastDeviceCard(
                name: lastName ?? lastId,
                id: lastId,
                onConnect: (_connecting || _scanning)
                    ? null
                    : () {
                        final entry = _deviceMap[lastId];
                        if (entry != null) {
                          _connect(entry.result);
                        } else {
                          _pendingConnectLast = true;
                          _startScan();
                        }
                      },
                onScan: (_scanning || _connecting) ? null : _startScan,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: _scanStatusBar(),
          ),
          Expanded(
            child: results.isEmpty
                  ? Center(
                      child: Text(
                        _scanning
                            ? _t(
                                'กำลังสแกนอุปกรณ์ PrinceBot...',
                                'Scanning for PrinceBot devices...',
                              )
                            : _t(
                                'ไม่พบอุปกรณ์ PrinceBot\nกด Scan เพื่อลองอีกครั้ง',
                                'No PrinceBot device found.\nTap Scan to try again.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final r = results[index];

                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : (r.advertisementData.advName.isNotEmpty
                              ? r.advertisementData.advName
                              : r.device.remoteId.str);

                      final rssi = r.rssi;
                      final signalText = _signalLabel(rssi);
                      final signalColor = _signalColor(context, rssi);
                      final signalIcon = _signalIcon(rssi);

                      return ListTile(
                        leading: Icon(signalIcon, color: signalColor),
                        title: Text(name),
                        subtitle: Text('RSSI: $rssi dBm • $signalText'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _connecting ? null : () => _connect(r),
                      );
                    },
                  ),
          ),
        ],
      ),
        );
      },
    );
  }

  String? _resolveLastDeviceName(String? deviceId) {
    if (deviceId == null) return _lastDeviceName ?? _lastDeviceNamePersisted;
    final entry = _deviceMap[deviceId];
    if (entry != null) {
      final r = entry.result;
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : (r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.remoteId.str);
      return name.isNotEmpty ? name : deviceId;
    }
    return _lastDeviceName ?? _lastDeviceNamePersisted ?? deviceId;
  }

  Widget _scanStatusBar() {
    final String status = _connecting
        ? _t('กำลังเชื่อมต่อ...', 'Connecting...')
        : (_scanning
            ? (_scanSecondsLeft > 0
                ? _t(
                    'กำลังสแกน... ${_scanSecondsLeft}s',
                    'Scanning... ${_scanSecondsLeft}s',
                  )
                : _t('กำลังสแกน...', 'Scanning...'))
            : _t('พร้อมสแกน', 'Ready to scan'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panelBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            _scanning ? Icons.bluetooth_searching : Icons.bluetooth,
            size: 16,
            color: _textSecondary(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary(context),
              ),
            ),
          ),
          if (_scanning)
            TextButton(
              onPressed: _stopScan,
              child: Text(_t('หยุด', 'Stop')),
            )
          else
            TextButton(
              onPressed: _connecting ? null : _startScan,
              child: Text(_t('สแกน', 'Scan')),
            ),
        ],
      ),
    );
  }

  Widget _lastDeviceCard({
    required String name,
    required String id,
    required VoidCallback? onConnect,
    required VoidCallback? onScan,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: _textPrimary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('อุปกรณ์ล่าสุด', 'Last device'),
                  style: TextStyle(
                    color: _textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textTertiary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onConnect,
            child: Text(_t('เชื่อมต่อ', 'Connect')),
          ),
          TextButton(
            onPressed: onScan,
            child: Text(_t('สแกน', 'Scan')),
          ),
        ],
      ),
    );
  }
}

