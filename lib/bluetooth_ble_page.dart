// lib/bluetooth_ble_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'app_connection.dart';
import 'ble_manager.dart';

class BluetoothBlePage extends StatefulWidget {
  const BluetoothBlePage({super.key});

  @override
  State<BluetoothBlePage> createState() => _BluetoothBlePageState();
}

class _BluetoothBlePageState extends State<BluetoothBlePage> {
  bool _scanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _results = const [];

  /// ---------------------------
  /// ✅ ฟังก์ชันกรองเฉพาะอุปกรณ์หุ่นยนต์ (UART Service)
  /// ---------------------------
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

  Future<void> _ensurePermissions() async {}

  Future<void> _prepareAndScan() async {
    await _ensurePermissions();

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
      if (mounted) {
        setState(() => _results = list);
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 6),
    );

    if (mounted) setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    AppConnection.instance.setBleConnected(false);
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
          'เชื่อมต่อกับ ${d.platformName.isEmpty ? d.remoteId.str : d.platformName} สำเร็จ');

      BleManager.instance.setDevice(d);

      final ok = await BleManager.instance.discoverServices();
      if (!ok) {
        _showSnack("ไม่พบ UART RX/TX characteristic");
      }

    } catch (e) {
      AppConnection.instance.setBleConnected(false);
      _showSnack('เชื่อมต่อไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 กรองเฉพาะอุปกรณ์หุ่นยนต์
    final results = _results.where(isRobot).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth (BLE)'),
        actions: [
          IconButton(
            tooltip: 'สแกนใหม่',
            icon: Icon(_scanning ? Icons.hourglass_top : Icons.refresh),
            onPressed: _scanning
                ? null
                : () async {
                    await FlutterBluePlus.stopScan();
                    _startScan();
                  },
          ),
        ],
      ),
      body: results.isEmpty
          ? const Center(child: Text('กำลังค้นหาอุปกรณ์ BLE…'))
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
                  leading: const Icon(Icons.bluetooth),
                  title: Text(name),
                  subtitle: Text('RSSI: ${r.rssi} • ${d.remoteId.str}'),
                  onTap: () => _connect(r),
                );
              },
            ),
    );
  }
}
