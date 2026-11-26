// lib/features/linesonic/linesonic_sensor_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ble/ble_protocol_line_assembler.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/widgets/portrait_background.dart';
import 'linesonic_protocol.dart';

class LineSonicSensorPage extends StatefulWidget {
  const LineSonicSensorPage({super.key});

  @override
  State<LineSonicSensorPage> createState() => _LineSonicSensorPageState();
}

class _LineSonicSensorPageState extends State<LineSonicSensorPage> {
  final List<int> _values = [];
  int? _sum;
  final _rxLines = BleProtocolLineAssembler();
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
    // A line cut off by a disconnect must not prefix the next one.
    _rxLines.reset();
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
    for (final line in _rxLines.add(data)) {
      _parseLine(line);
    }
  }

  void _parseLine(String line) {
    _addLog('RX: $line');
    final reading = LineSonicProtocol.parseSensorLine(line);
    if (reading == null || !mounted) return;
    setState(() {
      _values
        ..clear()
        ..addAll(reading.values);
      _sum = reading.sum;
    });
  }

  Future<void> _sendRead() async {
    if (!BleManager.instance.isConnected) {
      if (_auto) _setAuto(false);
      final now = DateTime.now();
      if (!mounted) return;
      if (now.difference(_lastWarn) > const Duration(seconds: 2)) {
        _lastWarn = now;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE not connected')));
      }
      return;
    }

    final owner = _bleTrafficOwner;
    if (owner == null) {
      if (_auto) _setAuto(false);
      _showBleBusy();
      return;
    }
    _addLog('TX: ${LineSonicProtocol.sensorRead}');
    final result = await BleManager.instance.send(
      LineSonicProtocol.sensorRead,
      owner: owner,
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE not connected')));
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

  Widget _buildPlainBackButton() {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.chevron_left_rounded, size: 30),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.maybePop(context);
        },
        padding: EdgeInsets.zero,
        splashRadius: 22,
      ),
    );
  }

  Widget _buildEmptyPanel({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String hint,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withAlpha(150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(170),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValues(ThemeData theme) {
    if (_values.isEmpty) {
      return _buildEmptyPanel(
        theme: theme,
        icon: Icons.sensors_rounded,
        title: 'No data yet',
        hint: 'Tap Read Now to fetch sensor values',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        _values.length,
        (i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(160),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(
            'S${i + 1}: ${_values[i]}',
            style: theme.textTheme.labelLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildLog(ThemeData theme) {
    if (_logs.isEmpty) {
      return _buildEmptyPanel(
        theme: theme,
        icon: Icons.receipt_long_rounded,
        title: 'No logs yet',
        hint: 'TX/RX logs appear after reading values',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        _logs.join('\n'),
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 44,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        leading: Navigator.of(context).canPop()
            ? _buildPlainBackButton()
            : null,
        centerTitle: true,
        title: Text(
          'Read Sensor',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ConnectionStatusBadge(),
          ),
        ],
      ),
      body: PortraitBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 44 + 16,
            16,
            24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendRead,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Read Now'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      elevation: 1,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _setAuto(!_auto),
                  icon: Icon(
                    _auto ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_auto ? 'Auto On' : 'Auto Off'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(118, 44),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _forceReadTx,
                icon: const Icon(Icons.read_more_rounded, size: 18),
                label: const Text('Read (force)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: scheme.onSurfaceVariant,
                  side: BorderSide(color: scheme.outlineVariant),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _intervalMs,
              decoration: const InputDecoration(
                label: Text('Auto Interval (ms)'),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 100, child: Text('100')),
                DropdownMenuItem(value: 200, child: Text('200')),
                DropdownMenuItem(value: 500, child: Text('500')),
                DropdownMenuItem(value: 1000, child: Text('1000')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => _intervalMs = val);
                if (_auto) _setAuto(true);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Sensor Values',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildValues(theme),
            const SizedBox(height: 12),
            if (_sum != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    140,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.functions, size: 18),
                    const SizedBox(width: 8),
                    Text('SUM: $_sum', style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Log',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildLog(theme),
          ],
        ),
      ),
    );
  }
}
