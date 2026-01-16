// lib/core/widgets/connection_status_badge.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_manager.dart';
import '../connection/app_connection.dart';

class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({super.key});

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge> {
  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ConnectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,
      initialData: BleManager.instance.isConnected,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;

        final bgColor = connected
            ? Colors.green.withOpacity(0.16)
            : theme.colorScheme.surfaceVariant.withOpacity(0.8);

        final borderColor =
            connected ? Colors.green : theme.colorScheme.outlineVariant;

        final icon =
            connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled;

        final text = connected ? 'BT On' : 'BT Off';
        final dotColor = connected ? Colors.green : Colors.redAccent;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
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
}

class _BleEntry {
  final ScanResult result;
  final DateTime lastSeen;

  const _BleEntry(this.result, this.lastSeen);

  _BleEntry copyWith({ScanResult? result, DateTime? lastSeen}) {
    return _BleEntry(result ?? this.result, lastSeen ?? this.lastSeen);
  }
}

class _ConnectionSheet extends StatefulWidget {
  const _ConnectionSheet();

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  bool _scanning = false;
  bool _connecting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _cleanupTimer;
  final Map<String, _BleEntry> _deviceMap = {};

  @override
  void initState() {
    super.initState();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pruneOldDevices(),
    );
    _startScan();
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

  Future<void> _startScan() async {
    if (_scanning || _connecting) return;

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth is off')),
        );
      }
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

  Future<void> _connect(ScanResult r) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      await FlutterBluePlus.stopScan();
      await BleManager.instance.disconnect();
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
        AppConnection.instance.setBleConnected(true);
        BleManager.instance.send("HELLO_APP");
        if (mounted) Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final connected = BleManager.instance.isConnected;
    final devices = _deviceMap.values.map((e) => e.result).toList();
    final maxH = MediaQuery.of(context).size.height * 0.6;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connected
                          ? 'Connected: ${BleManager.instance.currentDeviceName ?? BleManager.instance.currentDeviceId ?? "Unknown"}'
                          : 'Not connected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text(
                        'Disconnect',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _scanning ? null : _startScan,
                      child: Text(
                        _scanning ? 'Scanning...' : 'Scan',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!connected)
                Expanded(
                  child: devices.isEmpty
                      ? const Center(
                          child: Text(
                            'No devices found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final r = devices[index];
                            final name = r.device.platformName.isNotEmpty
                                ? r.device.platformName
                                : r.device.remoteId.str;
                            return ListTile(
                              dense: true,
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'RSSI: ${r.rssi} dBm',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: _connecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white70,
                                    ),
                              onTap: _connecting ? null : () => _connect(r),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
