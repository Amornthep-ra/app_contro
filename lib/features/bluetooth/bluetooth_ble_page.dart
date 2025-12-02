// lib/features/bluetooth/bluetooth_ble_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/connection/app_connection.dart';
import '../../core/ble/ble_manager.dart';

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
  StreamSubscription<List<ScanResult>>? _scanSub;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  StreamSubscription<bool>? _isScanningSub;

  final Map<String, _BleEntry> _deviceMap = {};

  BluetoothDevice? _connectedDevice;
  static String? _lastDeviceName;

  Timer? _cleanupTimer;

  bool isRobot(ScanResult r) {
    return r.advertisementData.serviceUuids.any(
      (uuid) => uuid.str.toLowerCase().startsWith("6e400001"),
    );
  }

  @override
  void initState() {
    super.initState();
    _bindBluetoothState();
    _prepareAndScan();

    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pruneOldDevices();
    });
  }

  void _bindBluetoothState() {
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;

      if (state != BluetoothAdapterState.on) {
        BleManager.instance.disconnect();
        AppConnection.instance.setBleConnected(false);

        setState(() {
          _connectedDevice = null;
          _scanning = false;
          _deviceMap.clear();
        });

        _showSnack('Bluetooth ถูกปิด กรุณาเปิดใหม่เพื่อเชื่อมต่ออีกครั้ง');
      } else {
        if (_connectedDevice == null && !_scanning) {
          _startScan();
        }
      }
    });

    _isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!mounted) return;
      if (_scanning != isScanning) {
        setState(() {
          _scanning = isScanning;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _cleanupTimer?.cancel();

    _adapterStateSub?.cancel();
    _isScanningSub?.cancel();

    super.dispose();
  }

  Future<void> _prepareAndScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showSnack('กรุณาเปิด Bluetooth แล้วลองใหม่');
      AppConnection.instance.setBleConnected(false);
      return;
    }
    await _startScan();
  }

  Future<void> _startScan() async {
    if (_scanning) return;

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showSnack('กรุณาเปิด Bluetooth แล้วลองใหม่');
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
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      _showSnack('เริ่มสแกนไม่สำเร็จ: $e');
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _pruneOldDevices() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() => _pruneOldDevicesLocked(now));
  }

  void _pruneOldDevicesLocked(DateTime now) {
    const timeout = Duration(seconds: 3);
    _deviceMap.removeWhere(
      (_, entry) => now.difference(entry.lastSeen) > timeout,
    );
  }

  Future<void> _disconnect() async {
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
    });

    AppConnection.instance.setBleConnected(false);
    _showSnack('ตัดการเชื่อมต่อแล้ว');

    await _startScan();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _connect(ScanResult r) async {
    final d = r.device;

    try {
      await FlutterBluePlus.stopScan();

      await d.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      if (!mounted) return;

      setState(() => _connectedDevice = d);
      AppConnection.instance.setBleConnected(true);

      final showName = d.platformName.isEmpty ? d.remoteId.str : d.platformName;
      _lastDeviceName = showName;

      _showSnack('เชื่อมต่อกับ $showName สำเร็จ');

      BleManager.instance.setDevice(d);

      final ok = await BleManager.instance.discoverServices();
      if (!ok) _showSnack("ไม่พบ UART RX/TX characteristic");
    } catch (e) {
      AppConnection.instance.setBleConnected(false);
      if (!mounted) return;

      _showSnack('เชื่อมต่อไม่สำเร็จ: $e');
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on && !_scanning) {
        _startScan();
      }
    }
  }

  String _signalLabel(int rssi) {
    if (rssi >= -55) return 'Very strong';
    if (rssi >= -65) return 'Strong';
    if (rssi >= -75) return 'Medium';
    if (rssi >= -85) return 'Weak';
    return 'Very weak';
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
            name = "Unknown";
          }
        } else {
          name = "Not Connect";
        }

        final t = Theme.of(context).textTheme;
        final titleStyle =
            t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 15,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ) ??
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            );

        final grad = connected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0EA5E9).withOpacity(0.30),
                  const Color(0xFF22D3EE).withOpacity(0.18),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.04),
                ],
              );

        final border = connected
            ? const Color(0xFF38BDF8).withOpacity(0.55)
            : const Color(0xFF60A5FA).withOpacity(0.35);

        final actions = <Widget>[];

        if (!connected) {
          actions.add(
            _smallAction(
              icon: _scanning ? Icons.hourglass_top : Icons.refresh,
              label: _scanning ? "Scanning..." : "Scan",
              onTap: _scanning ? null : _startScan,
            ),
          );
        } else {
          actions.add(
            _smallAction(
              icon: Icons.link_off,
              label: "Disconnect",
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
                    color: Colors.black.withOpacity(0.22),
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
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        connected ? "Connected: $name" : "Not Connect",
                        key: ValueKey(
                          connected ? "connected_$name" : "disconnected",
                        ),
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: base.withOpacity(0.75), width: 1),
          boxShadow: [BoxShadow(blurRadius: 8, color: base.withOpacity(0.25))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Bluetooth (BLE)'),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 158, 184, 247),
                    Color.fromARGB(255, 192, 203, 250),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildBleStatusBar(),
        ),
      ),
      body: results.isEmpty
          ? const Center(
              child: Text(
                'No PrinceBot device found.\nTap Scan to try again.',
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
                  onTap: () => _connect(r),
                );
              },
            ),
    );
  }
}
