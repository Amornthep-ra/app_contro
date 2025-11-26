// lib/pages/bluetooth_ble_page.dart
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

class _BluetoothBlePageState extends State<BluetoothBlePage> {
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = const [];

  BluetoothDevice? _connectedDevice;

  bool isRobot(ScanResult r) {
    return r.advertisementData.serviceUuids.any(
      (uuid) => uuid.str.toLowerCase().startsWith("6e400001"),
    );
  }

  @override
  void initState() {
    super.initState();
    _prepareAndScan();
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

    setState(() {
      _scanning = true;
      _results = [];
    });

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (mounted) setState(() => _results = list);
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    } catch (e) {
      _showSnack('เริ่มสแกนไม่สำเร็จ: $e');
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _disconnect() async {
    await BleManager.instance.disconnect();

    if (!mounted) return;
    setState(() => _connectedDevice = null);

    AppConnection.instance.setBleConnected(false);
    _showSnack('ตัดการเชื่อมต่อแล้ว');
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
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

      _showSnack('เชื่อมต่อกับ $showName สำเร็จ');

      BleManager.instance.setDevice(d);

      final ok = await BleManager.instance.discoverServices();
      if (!ok) _showSnack("ไม่พบ UART RX/TX characteristic");
    } catch (e) {
      AppConnection.instance.setBleConnected(false);
      _showSnack('เชื่อมต่อไม่สำเร็จ: $e');
    }
  }

  Widget _buildBleStatusBar() {
    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,
      initialData: BleManager.instance.isConnected,
      builder: (context, snap) {
        final connected = snap.data ?? false;

        final name = connected
            ? (_connectedDevice?.platformName.isNotEmpty == true
                  ? _connectedDevice!.platformName
                  : _connectedDevice?.remoteId.str ?? "Unknown")
            : "Not Connected";

        final t = Theme.of(context).textTheme;
        final titleStyle =
            t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ) ??
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            );

        final grad = connected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0EA5E9).withOpacity(0.30), // BLE blue
                  const Color(0xFF22D3EE).withOpacity(0.18), // cyan
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

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: grad,
                border: Border.all(color: border, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 12,
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      connected ? "Connected: $name" : "Not Connected",
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  _smallAction(
                    icon: _scanning ? Icons.hourglass_top : Icons.refresh,
                    label: "Scan",
                    onTap: _scanning ? null : _startScan,
                  ),

                  const SizedBox(width: 8),

                  if (connected)
                    _smallAction(
                      icon: Icons.link_off,
                      label: "Disconnect",
                      onTap: _disconnect,
                      danger: true,
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: base.withOpacity(0.75), width: 1),
          boxShadow: [BoxShadow(blurRadius: 10, color: base.withOpacity(0.25))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
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
    final results = _results.where(isRobot).toList();

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
                    Color.fromARGB(
                      255,
                      158,
                      184,
                      247,
                    ), // ปรับสองค่านี้เป็นโทนที่อยากได้
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

      // 🔹 เพิ่ม body แสดงรายชื่ออุปกรณ์ที่เจอ (แก้เฉพาะส่วนนี้)
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
                    : r.device.remoteId.str;

                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    r.advertisementData.serviceUuids
                        .map((u) => u.str)
                        .join(', '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _connect(r),
                );
              },
            ),
    );
  }
}
