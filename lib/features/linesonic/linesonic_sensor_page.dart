// lib/features/linesonic/linesonic_sensor_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../../core/ui/language_controller.dart';

class LineSonicSensorPage extends StatefulWidget {
  const LineSonicSensorPage({super.key});

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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _bindDataStream() {
    _dataSub?.cancel();
    final stream = BleManager.instance.onData();
    if (stream == null) return;
    _dataSub = stream.listen(_handleData);
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
              LanguageController.isThai.value ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d BLE' : 'BLE not connected',
            ),
          ),
        );
      }
      return;
    }

    _addLog('TX: SENS=1');
    await BleManager.instance.send('SENS=1');

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
              LanguageController.isThai.value ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d BLE' : 'BLE not connected',
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
      final data = await BleManager.instance.readTx();
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

  void _showTutorial(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isThai ? '\u0e27\u0e34\u0e18\u0e35\u0e43\u0e0a\u0e49' : 'Tutorial'),
          content: SingleChildScrollView(
            child: Text(
              isThai
                  ? '\u0031\u0029\u0020\u0e01\u0e14\u0020\u0e2d\u0e48\u0e32\u0e19\u0e15\u0e2d\u0e19\u0e19\u0e35\u0e49\u0020\u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e14\u0e36\u0e07\u0e04\u0e48\u0e32\u0020SENS\n\u0032\u0029\u0020Auto\u0020\u0e08\u0e30\u0e2d\u0e48\u0e32\u0e19\u0e0b\u0e49\u0e33\u0e15\u0e32\u0e21\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\n\u0033\u0029\u0020\u0e2d\u0e48\u0e32\u0e19\u0020(\u0e1a\u0e31\u0e07\u0e04\u0e31\u0e1a)\u0020\u0e43\u0e0a\u0e49\u0e14\u0e36\u0e07\u0e04\u0e48\u0e32\u0e08\u0e32\u0e01\u0020TX\u0020\u0e40\u0e21\u0e37\u0e48\u0e2d\u0e44\u0e21\u0e48\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15\n\u0034\u0029\u0020S1..\u0020\u0e04\u0e37\u0e2d\u0e04\u0e48\u0e32\u0e14\u0e34\u0e1a,\u0020SUM\u0020\u0e04\u0e37\u0e2d\u0e1c\u0e25\u0e23\u0e27\u0e21\n\u0035\u0029\u0020\u0e14\u0e39\u0020Log\u0020\u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e40\u0e0a\u0e47\u0e04\u0020TX/RX'
                  : '1) Tap Read Now to request SENS over BLE\n2) Auto reads repeatedly by interval\n3) Read (force) pulls from TX when not updating\n4) S1.. are raw values, SUM is total\n5) Check Log for TX/RX',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isThai ? '\u0e1b\u0e34\u0e14' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValues(ThemeData theme) {
    if (_values.isEmpty) {
      return Text(
        LanguageController.isThai.value ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25' : 'No data yet',
        style: theme.textTheme.bodySmall,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThai = LanguageController.isThai.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Sensor'),
        actions: [
          IconButton(
            tooltip: isThai ? '\u0e27\u0e34\u0e18\u0e35\u0e43\u0e0a\u0e49' : 'Tutorial',
            onPressed: () => _showTutorial(context),
            icon: const Icon(Icons.help_outline),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ConnectionStatusBadge(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sendRead,
                  icon: const Icon(Icons.download),
                  label: Text(
                    isThai ? '\u0e2d\u0e48\u0e32\u0e19\u0e15\u0e2d\u0e19\u0e19\u0e35\u0e49' : 'Read Now',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _setAuto(!_auto),
                icon: Icon(_auto ? Icons.pause : Icons.play_arrow),
                label: Text(
                  _auto
                      ? (isThai ? '\u0e40\u0e1b\u0e34\u0e14\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34' : 'Auto On')
                      : (isThai ? '\u0e1b\u0e34\u0e14\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34' : 'Auto Off'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _forceReadTx,
            icon: const Icon(Icons.read_more),
            label: Text(isThai ? '\u0e2d\u0e48\u0e32\u0e19 (\u0e1a\u0e31\u0e07\u0e04\u0e31\u0e1a)' : 'Read (force)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _intervalMs,
            decoration: InputDecoration(
              labelText: isThai ? '\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34 (ms)' : 'Auto Interval (ms)',
              border: const OutlineInputBorder(),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: _logs.isEmpty
                ? Text(
                    isThai ? '\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35 Log' : 'No logs yet',
                    style: theme.textTheme.bodySmall,
                  )
                : Text(
                    _logs.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab_linesonic_sensor',
        mini: true,
        onPressed: () => Navigator.popUntil(
          context,
          (route) => route.settings.name == AppRoutes.home || route.isFirst,
        ),
        child: const Icon(Icons.home),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
