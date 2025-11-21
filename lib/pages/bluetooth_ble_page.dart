// lib/pages/bluetooth_ble_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../app_connection.dart';
import '../ble/ble_manager.dart';

class BluetoothBlePage extends StatefulWidget {
  const BluetoothBlePage({super.key});

  @override
  State<BluetoothBlePage> createState() => _BluetoothBlePageState();
}

class _BluetoothBlePageState extends State<BluetoothBlePage> {
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = const [];

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

    setState(() {
      _scanning = true;
      _results = [];
    });

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (mounted) setState(() => _results = list);
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    if (mounted) setState(() => _scanning = false);
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

      AppConnection.instance.setBleConnected(true);
      _showSnack(
        'เชื่อมต่อกับ ${d.platformName.isEmpty ? d.remoteId.str : d.platformName} สำเร็จ',
      );

      BleManager.instance.setDevice(d);

      final ok = await BleManager.instance.discoverServices();
      if (!ok) _showSnack("ไม่พบ UART RX/TX characteristic");

    } catch (e) {
      AppConnection.instance.setBleConnected(false);
      _showSnack('เชื่อมต่อไม่สำเร็จ: $e');
    }
  }

  // ===========================================================
  // ⭐ GLASSMORPHISM STATUS BAR (Premium)
  // ===========================================================
  Widget _buildBleStatusBar() {
    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,
      initialData: BleManager.instance.isConnected,
      builder: (context, snap) {
        final connected = snap.data ?? false;

        final name = connected
            ? (BleManager.instance.currentDeviceName ??
                BleManager.instance.currentDeviceId ??
                "Unknown")
            : "Unknown";

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: connected
                    ? Colors.greenAccent.withOpacity(0.22)
                    : Colors.redAccent.withOpacity(0.22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    connected ? "Connected: $name" : "Not Connected",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: Colors.black54,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================

  @override
  Widget build(BuildContext context) {
    final results = _results.where(isRobot).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth (BLE)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildBleStatusBar(),
        ),
        elevation: 0,
      ),

      body: results.isEmpty
          ? const Center(
              child: Text(
                'กำลังค้นหาอุปกรณ์ BLE…',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = results[i];
                final d = r.device;

                final name = d.platformName.isNotEmpty
                    ? d.platformName
                    : d.remoteId.str;

                return ListTile(
                  leading: const Icon(Icons.bluetooth, color: Colors.blue),
                  title: Text(name),
                  subtitle: Text("RSSI: ${r.rssi} • ${d.remoteId.str}"),
                  onTap: () => _connect(r),
                );
              },
            ),
    );
  }
}
