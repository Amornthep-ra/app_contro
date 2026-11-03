// lib/features/linesonic/linesonic_sensor_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ui/language_controller.dart';
import '../../core/ui/lavender_glass.dart';
import 'widgets/linesonic_controls.dart';
import 'widgets/linesonic_scaffold.dart';

class LineSonicSensorPage extends StatefulWidget {
  const LineSonicSensorPage({super.key, this.debugReceivedLines});

  /// Lines handled as if received from the board after the first frame
  /// (tests and previews only).
  @visibleForTesting
  final List<String>? debugReceivedLines;

  @override
  State<LineSonicSensorPage> createState() => _LineSonicSensorPageState();
}

class _LineSonicSensorPageState extends State<LineSonicSensorPage> {
  final List<int> _values = [];
  int? _sum;
  String _rxBuffer = '';
  int _intervalMs = 200;
  bool _auto = false;
  Timer? _autoTimer;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<bool>? _connSub;
  DateTime _lastWarn = DateTime.fromMillisecondsSinceEpoch(0);
  final List<String> _logs = [];
  DateTime _lastRead = DateTime.fromMillisecondsSinceEpoch(0);
  bool _pendingForceRead = false;
  int? _bleTrafficOwner;

  @override
  void initState() {
    super.initState();
    _bleTrafficOwner = BleManager.instance.claimTrafficMode(
      BleTrafficMode.textCommand,
      ownerName: 'linesonic_sensor',
    );
    _bindDataStream();
    _connSub = BleManager.instance.connectionStream.listen((_) {
      _bindDataStream();
    });
    final debugLines = widget.debugReceivedLines;
    if (debugLines != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final line in debugLines) {
          _handleData('$line\n'.codeUnits);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _dataSub?.cancel();
    _connSub?.cancel();
    final trafficOwner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (trafficOwner != null) {
      BleManager.instance.releaseTrafficMode(trafficOwner);
    }
    super.dispose();
  }

  void _bindDataStream() {
    _dataSub?.cancel();
    final owner = _bleTrafficOwner;
    if (owner == null) return;
    final stream = BleManager.instance.onData(owner: owner);
    if (stream == null) return;
    _dataSub = stream.listen(_handleData);
  }

  void _showBleBusy() {
    final now = DateTime.now();
    if (!mounted) return;
    if (now.difference(_lastWarn) <= const Duration(seconds: 2)) return;
    _lastWarn = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('BLE is busy in control mode')),
    );
  }

  void _handleData(List<int> data) {
    if (data.isEmpty) return;
    _rxBuffer += String.fromCharCodes(data);

    int idx;
    while ((idx = _rxBuffer.indexOf('\n')) != -1) {
      final line = _rxBuffer.substring(0, idx).trim();
      _rxBuffer = _rxBuffer.substring(idx + 1);
      _parseLine(line);
    }
  }

  void _parseLine(String line) {
    _addLog('RX: $line');
    if (!line.startsWith('SENS=')) return;
    final raw = line.substring(5);
    final parts = raw.split(',');
    final next = <int>[];
    int? nextSum;
    for (final p in parts) {
      final part = p.trim();
      if (part.toUpperCase().startsWith('SUM=')) {
        final s = part.substring(4);
        final v = int.tryParse(s);
        if (v != null) nextSum = v;
        continue;
      }
      final v = int.tryParse(part);
      if (v != null) next.add(v);
    }
    if (next.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _values
        ..clear()
        ..addAll(next);
      _sum = nextSum;
    });
  }

  Future<void> _sendRead() async {
    if (!BleManager.instance.isConnected) {
      if (_auto) _setAuto(false);
      final now = DateTime.now();
      if (!mounted) return;
      if (now.difference(_lastWarn) > const Duration(seconds: 2)) {
        _lastWarn = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageController.isThai.value
                  ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d BLE'
                  : 'BLE not connected',
            ),
          ),
        );
      }
      return;
    }

    final owner = _bleTrafficOwner;
    if (owner == null) {
      if (_auto) _setAuto(false);
      _showBleBusy();
      return;
    }
    _addLog('TX: SENS=1');
    final result = await BleManager.instance.send('SENS=1', owner: owner);
    if (result != BleWriteResult.sent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Command not sent: ${result.name}')),
        );
      }
      return;
    }

    if (_pendingForceRead) return;
    _pendingForceRead = true;
    Future.delayed(const Duration(milliseconds: 250), () async {
      _pendingForceRead = false;
      await _forceReadTx();
    });
  }

  Future<void> _forceReadTx() async {
    if (!BleManager.instance.isConnected) {
      final now = DateTime.now();
      if (!mounted) return;
      if (now.difference(_lastWarn) > const Duration(seconds: 2)) {
        _lastWarn = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageController.isThai.value
                  ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d BLE'
                  : 'BLE not connected',
            ),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastRead) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastRead = now;

    try {
      final owner = _bleTrafficOwner;
      if (owner == null) {
        _showBleBusy();
        return;
      }
      final data = await BleManager.instance.readTx(owner: owner);
      if (data.isEmpty) {
        _addLog('READ: (empty)');
        return;
      }
      final text = String.fromCharCodes(data).trim();
      _addLog('READ: $text');
      _parseLine(text);
    } catch (e) {
      _addLog('READ error: $e');
    }
  }

  void _setAuto(bool on) {
    _autoTimer?.cancel();
    _auto = on;
    if (on) {
      _autoTimer = Timer.periodic(
        Duration(milliseconds: _intervalMs),
        (_) => _sendRead(),
      );
      _addLog('Auto ON (${_intervalMs}ms)');
    } else {
      _addLog('Auto OFF');
    }
    if (mounted) setState(() {});
  }

  void _addLog(String msg) {
    final line = '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg';
    if (!mounted) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > 50) {
        _logs.removeRange(0, _logs.length - 50);
      }
    });
  }

  void _clearLog() {
    setState(_logs.clear);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LavenderPalette.violet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: LavenderPalette.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: LavenderPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: LavenderPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return GlassPanel(
      radius: 24,
      shadowStrength: 0.7,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GradientActionButton(
                  label: 'Read Now',
                  icon: Icons.download_rounded,
                  height: 48,
                  onPressed: _sendRead,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassActionButton(
                  label: _auto ? 'Auto On' : 'Auto Off',
                  icon: _auto ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  height: 48,
                  accent: _auto
                      ? LavenderPalette.success
                      : LavenderPalette.violet,
                  onPressed: () => _setAuto(!_auto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const LineSonicCaption('Auto Interval (ms)'),
          LineSonicSegments<int>(
            accent: LavenderPalette.violetDeep,
            selected: _intervalMs,
            options: const [
              (100, '100'),
              (200, '200'),
              (500, '500'),
              (1000, '1000'),
            ],
            onSelected: (val) {
              setState(() => _intervalMs = val);
              if (_auto) _setAuto(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildValues() {
    final sum = _sum;
    return GlassPanel(
      radius: 24,
      shadowStrength: 0.7,
      tint: LavenderPalette.success,
      tintStrength: 0.08,
      padding: const EdgeInsets.all(12),
      child: _values.isEmpty
          ? _buildEmptyState(
              icon: Icons.sensors_rounded,
              title: 'No data yet',
              hint: 'Tap Read Now to fetch sensor values',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final columns = (constraints.maxWidth / 84).floor().clamp(3, 8);
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < _values.length; i++)
                          SizedBox(
                            width: tileWidth,
                            child: _SensorValueTile(
                              label: 'S${i + 1}',
                              value: '${_values[i]}',
                            ),
                          ),
                      ],
                    ),
                    if (sum != null) ...[
                      const SizedBox(height: gap),
                      _SensorValueTile(
                        label: 'SUM',
                        value: '$sum',
                        icon: Icons.functions_rounded,
                        wide: true,
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLog() {
    return GlassPanel(
      radius: 24,
      shadowStrength: 0.7,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TX / RX',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LavenderPalette.inkSoft,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _forceReadTx,
                  style: TextButton.styleFrom(
                    foregroundColor: LavenderPalette.violetDeep,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.read_more_rounded, size: 20),
                  label: const Text(
                    'Read (force)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _logs.isEmpty ? null : _clearLog,
                  style: TextButton.styleFrom(
                    foregroundColor: LavenderPalette.violetDeep,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _logs.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No logs yet',
                      hint: 'TX/RX logs appear after reading values',
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        _logs.join('\n'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                          color: LavenderPalette.ink,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LineSonicScaffold(
      title: 'Read Sensor',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          LineSonicScaffold.pagePadding,
          LineSonicScaffold.contentTop(context) + 4,
          LineSonicScaffold.pagePadding,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildControls(),
          const SizedBox(height: 20),
          const LineSonicCaption('Sensor Values'),
          _buildValues(),
          const SizedBox(height: 20),
          const LineSonicCaption('Log'),
          _buildLog(),
        ],
      ),
    );
  }
}

class _SensorValueTile extends StatelessWidget {
  const _SensorValueTile({
    required this.label,
    required this.value,
    this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: LavenderPalette.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: LavenderPalette.inkSoft,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LavenderPalette.ink.withValues(alpha: 0.08)),
      ),
      child: wide
          ? Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: LavenderPalette.violet),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 2),
                Text(label, style: labelStyle),
                const Spacer(),
                Text(value, style: valueStyle),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: valueStyle),
                ),
              ],
            ),
    );
  }
}
