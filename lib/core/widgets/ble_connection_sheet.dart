// lib/core/widgets/ble_connection_sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_manager.dart';
import '../ui/language_controller.dart';
import 'cat_glass_popup.dart';

String _t(bool isThai, String th, String en) => isThai ? th : en;

class _BleEntry {
  final ScanResult result;
  final DateTime lastSeen;

  const _BleEntry(this.result, this.lastSeen);

  _BleEntry copyWith({ScanResult? result, DateTime? lastSeen}) {
    return _BleEntry(result ?? this.result, lastSeen ?? this.lastSeen);
  }
}

class BleConnectionSheet extends StatefulWidget {
  const BleConnectionSheet({
    super.key,
    required this.onPairingRequested,
    required this.coordinator,
    required this.isBleConnected,
    required this.enableBlePlatformBindings,
  });

  final Future<void> Function(bool automatic) onPairingRequested;
  final BleConnectionCoordinator coordinator;
  final bool Function() isBleConnected;
  final bool enableBlePlatformBindings;

  @override
  State<BleConnectionSheet> createState() => _BleConnectionSheetState();
}

class _BleConnectionSheetState extends State<BleConnectionSheet> {
  bool _scanning = false;
  bool _connecting = false;
  Timer? _cleanupTimer;
  final Map<String, _BleEntry> _deviceMap = {};
  String? _lastDeviceId;
  bool _pendingConnectLast = false;
  bool _pairingRequestPending = false;
  BleControlSecurityState _securityState = BleControlSecurityState.disconnected;
  BleConnectionCoordinator get _bleCoordinator => widget.coordinator;

  StreamSubscription<BleConnectionCoordinatorState>? _bleCoordinatorSub;
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

  @override
  void initState() {
    super.initState();
    _bleCoordinatorSub = _bleCoordinator.stream.listen(_applyCoordinatorState);
    if (widget.enableBlePlatformBindings) {
      _bleCoordinator.acquire();
      _initializeCoordinator();
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _pruneOldDevices(),
      );
      _startScan();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyCoordinatorState(_bleCoordinator.state);
      });
    }
  }

  Future<void> _initializeCoordinator() async {
    await _bleCoordinator.initialize();
    _applyCoordinatorState(_bleCoordinator.state);
    _queueAutoConnectLast();
  }

  void _applyCoordinatorState(BleConnectionCoordinatorState state) {
    if (!mounted) return;
    setState(() {
      _scanning = state.scanning;
      _connecting = state.connecting;
      _securityState = state.securityState;
      _lastDeviceId = state.lastDeviceId?.isEmpty == true
          ? null
          : state.lastDeviceId;
      _deviceMap
        ..clear()
        ..addEntries(
          state.devices.map(
            (result) => MapEntry(
              result.device.remoteId.str,
              _BleEntry(result, DateTime.now()),
            ),
          ),
        );
    });
    if (!_pairingRequestPending &&
        !_bleCoordinator.pairingPromptPresentedForConnection &&
        requiresBlePairingCode(state.securityState) &&
        widget.isBleConnected()) {
      unawaited(_requestPairingCode(automatic: true));
    }
  }

  Future<void> _requestPairingCode({required bool automatic}) async {
    if (!mounted || _pairingRequestPending) return;
    if (!widget.isBleConnected() || !requiresBlePairingCode(_securityState)) {
      return;
    }
    _pairingRequestPending = true;
    final request = widget.onPairingRequested(automatic);
    Navigator.of(context).pop();
    await request;
  }

  @override
  void dispose() {
    _bleCoordinatorSub?.cancel();
    if (widget.enableBlePlatformBindings) {
      unawaited(_bleCoordinator.release());
    }
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _pruneOldDevices() {
    if (!_scanning) return;
    final now = DateTime.now();
    _deviceMap.removeWhere(
      (_, entry) =>
          now.difference(entry.lastSeen) > const Duration(seconds: 20),
    );
    if (mounted) setState(() {});
  }

  void _queueAutoConnectLast() {
    if (_lastDeviceId == null) return;
    if (_connecting || BleManager.instance.isConnected) return;
    if (_pendingConnectLast) return;
    _pendingConnectLast = true;
    unawaited(_connectRememberedDevice('connection_badge_initial'));
  }

  Future<void> _connectRememberedDevice(
    String source, {
    bool userInitiated = false,
  }) async {
    try {
      await _bleCoordinator.autoConnectLastDevice(
        timeout: const Duration(seconds: 10),
        source: source,
        userInitiated: userInitiated,
      );
    } finally {
      _pendingConnectLast = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _forgetLastDevice() async {
    await _bleCoordinator.forgetLastDevice();
  }

  Future<void> _startScan() => _bleCoordinator.startScan();

  Future<void> _disconnect() => _bleCoordinator.disconnect();

  Future<void> _openPairingCode() => _requestPairingCode(automatic: false);

  Future<void> _connect(ScanResult result) =>
      _bleCoordinator.connect(result, source: 'connection_status_badge');

  Future<void> _connectLast() async {
    if (_lastDeviceId == null || _pendingConnectLast) return;
    _pendingConnectLast = true;
    await _connectRememberedDevice(
      'connection_badge_manual',
      userInitiated: true,
    );
  }

  String _diagnosticAge(Duration? age) {
    if (age == null) return '-';
    if (age.inSeconds < 1) return '${age.inMilliseconds} ms';
    if (age.inMinutes < 1) return '${age.inSeconds} s';
    return '${age.inMinutes} min';
  }

  Future<void> _copyDiagnostics(BleDiagnosticsSnapshot diagnostics) async {
    await Clipboard.setData(
      ClipboardData(text: formatBleDiagnostics(diagnostics)),
    );
    if (!mounted) return;
    final isThai = LanguageController.isThai.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(isThai, 'Diagnostics copied', 'Diagnostics copied')),
      ),
    );
  }

  Widget _buildDiagnosticsPanel({
    required BleDiagnosticsSnapshot diagnostics,
    required bool isThai,
    required Color titleColor,
    required Color bodyColor,
    required Color tileColor,
    required Color tileBorder,
  }) {
    final write = diagnostics.writeCharacteristic;
    final read = diagnostics.readCharacteristic;
    final rows = <MapEntry<String, String>>[
      MapEntry(
        _t(isThai, 'Status', 'Status'),
        diagnostics.connectionStatus.name,
      ),
      MapEntry(
        _t(isThai, 'Device', 'Device'),
        diagnostics.deviceName ?? diagnostics.deviceId ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Device ID', 'Device ID'),
        diagnostics.deviceId ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Mode / owner', 'Mode / owner'),
        '${diagnostics.trafficMode.name} / ${diagnostics.trafficOwnerName}',
      ),
      MapEntry(
        _t(isThai, 'MTU / payload', 'MTU / payload'),
        '${diagnostics.mtu?.toString() ?? '-'} / ${diagnostics.payloadSize}',
      ),
      MapEntry(
        _t(isThai, 'Write characteristic', 'Write characteristic'),
        write == null ? '-' : '${write.uuid} (${write.propertySummary})',
      ),
      MapEntry(
        _t(isThai, 'Receive characteristic', 'Receive characteristic'),
        read == null ? '-' : '${read.uuid} (${read.propertySummary})',
      ),
      MapEntry(
        _t(isThai, 'Notification', 'Notification'),
        diagnostics.notificationMode.name,
      ),
      MapEntry(
        _t(isThai, 'Last TX', 'Last TX'),
        _diagnosticAge(diagnostics.lastTxAge),
      ),
      MapEntry(
        _t(isThai, 'Last RX', 'Last RX'),
        _diagnosticAge(diagnostics.lastRxAge),
      ),
      MapEntry(
        _t(isThai, 'Reconnect attempts', 'Reconnect attempts'),
        diagnostics.reconnectAttempt.toString(),
      ),
      MapEntry(
        _t(isThai, 'Auto-connect target', 'Auto-connect target'),
        diagnostics.autoConnectTargetId ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Auto-connect age', 'Auto-connect age'),
        _diagnosticAge(diagnostics.autoConnectOperationAge),
      ),
      MapEntry(
        _t(isThai, 'Last auto-connect', 'Last auto-connect'),
        diagnostics.lastAutoConnectOutcome ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Last failure', 'Last failure'),
        diagnostics.lastFailureReason ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Last failure age', 'Last failure age'),
        _diagnosticAge(diagnostics.lastFailureAge),
      ),
      MapEntry(
        _t(isThai, 'Last disconnect', 'Last disconnect'),
        diagnostics.lastDisconnectReason?.name ?? '-',
      ),
      MapEntry(
        _t(isThai, 'Last disconnect age', 'Last disconnect age'),
        _diagnosticAge(diagnostics.lastDisconnectAge),
      ),
      MapEntry(
        _t(isThai, 'Last scan permission', 'Last scan permission'),
        diagnostics.lastScanPermissionResult?.name ?? '-',
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tileBorder),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: IconButton(
            tooltip: _t(isThai, 'Copy diagnostics', 'Copy diagnostics'),
            icon: const Icon(Icons.copy_outlined),
            color: bodyColor,
            onPressed: () => _copyDiagnostics(diagnostics),
          ),
          iconColor: bodyColor,
          collapsedIconColor: bodyColor,
          title: Text(
            _t(isThai, 'BLE diagnostics', 'BLE diagnostics'),
            style: _sheetTextStyle(
              isThai,
              size: 13,
              weight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 132,
                      child: Text(
                        row.key,
                        style: _sheetTextStyle(
                          isThai,
                          size: 12,
                          weight: FontWeight.w600,
                          color: bodyColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        row.value,
                        style: _sheetTextStyle(
                          isThai,
                          size: 12,
                          weight: FontWeight.w400,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    final connected = widget.isBleConnected();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
    final accent = connected
        ? const Color(0xFF22C55E)
        : const Color(0xFF8063C2);
    final devices = _deviceMap.values.map((e) => e.result).toList();
    final maxH = MediaQuery.of(context).size.height * 0.6;
    final previewPanel = Padding(
      padding: const EdgeInsets.all(12),
      child: CatGlassModalSurface(
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
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
                              ? '${_t(isThai, 'Connected', 'Connected')}: ${BleManager.instance.currentDeviceName ?? BleManager.instance.currentDeviceId ?? _t(isThai, 'Unknown', 'Unknown')}'
                              : _t(isThai, 'Not connected', 'Not connected'),
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
                      if (connected) ...[
                        IconButton(
                          tooltip:
                              _securityState == BleControlSecurityState.ready
                              ? 'Paired'
                              : 'Pair code',
                          onPressed: requiresBlePairingCode(_securityState)
                              ? _openPairingCode
                              : null,
                          icon: Icon(
                            Icons.password_rounded,
                            color: requiresBlePairingCode(_securityState)
                                ? accent
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                        TextButton(
                          onPressed: _disconnect,
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
                            _t(isThai, 'Disconnect', 'Disconnect'),
                            style: _sheetTextStyle(
                              isThai,
                              size: 13,
                              weight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ] else ...[
                        if (_lastDeviceId != null)
                          TextButton(
                            onPressed: _connecting ? null : _connectLast,
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
                              _t(isThai, 'Connect last', 'Connect last'),
                              style: _sheetTextStyle(
                                isThai,
                                size: 13,
                                weight: FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                          ),
                        TextButton(
                          onPressed: _scanning ? null : _startScan,
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
                                ? _t(isThai, 'Scanning...', 'Scanning...')
                                : _t(isThai, 'Scan', 'Scan'),
                            style: _sheetTextStyle(
                              isThai,
                              size: 13,
                              weight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!connected)
                    devices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                _t(
                                  isThai,
                                  'No devices found',
                                  'No devices found',
                                ),
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
                                  'MAC: ${r.device.remoteId.str} | RSSI: ${r.rssi} dBm',
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
                                onTap: _connecting ? null : () => _connect(r),
                              );
                            },
                          ),
                  StreamBuilder<BleDiagnosticsSnapshot>(
                    stream: BleManager.instance.diagnosticsStream,
                    initialData: BleManager.instance.diagnostics,
                    builder: (context, snapshot) {
                      return _buildDiagnosticsPanel(
                        diagnostics:
                            snapshot.data ?? BleManager.instance.diagnostics,
                        isThai: isThai,
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                        tileColor: tileColor,
                        tileBorder: tileBorder,
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
                              _t(isThai, 'Forget', 'Forget'),
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
                              side: BorderSide(
                                color: _opacity(titleColor, 0.18),
                              ),
                            ),
                          ),
                          child: Text(
                            _t(isThai, 'Cancel', 'Cancel'),
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
        ),
      ),
    );

    return SafeArea(child: previewPanel);
  }
}
