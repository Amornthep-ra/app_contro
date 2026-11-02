// lib/core/widgets/ble_connection_sheet.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../features/bluetooth/widgets/ble_connection_status.dart';
import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_presentation_state.dart';
import '../ui/ambient_motion.dart';
import '../ui/language_controller.dart';
import '../ui/lavender_glass.dart';
import 'ble_status_orb.dart';
import 'cat_glass_popup.dart';

String _t(bool isThai, String th, String en) => isThai ? th : en;

/// What the sheet header shows.
///
/// Follows the toolbar badge ([badge]) so both always agree. The sheet's own
/// scan/connect state only fills in while the badge is idle ("Not
/// connected", "Checking…") or still says "Scanning…" after a scan ended.
@visibleForTesting
BlePresentationState resolveBleSheetPresentation({
  required BlePresentationState badge,
  required bool connected,
  required bool connecting,
  required bool scanning,
}) {
  if (connected) {
    return const BlePresentationState(BlePresentationKind.connected);
  }
  final badgeIdle = switch (badge.kind) {
    BlePresentationKind.notConnected ||
    BlePresentationKind.checking ||
    BlePresentationKind.scanning ||
    // The badge can lag a disconnect by a frame.
    BlePresentationKind.connected => true,
    _ => false,
  };
  if (!badgeIdle) return badge;
  if (connecting) {
    return const BlePresentationState(BlePresentationKind.connecting);
  }
  if (scanning) {
    return const BlePresentationState(BlePresentationKind.scanning);
  }
  if (badge.kind == BlePresentationKind.checking) return badge;
  return const BlePresentationState(BlePresentationKind.notConnected);
}

/// Hint under the sheet title while not connected.
String _bleSheetHint(BlePresentationKind kind) => switch (kind) {
  BlePresentationKind.scanning => 'Looking for nearby robots…',
  BlePresentationKind.connecting => 'Connecting to your robot…',
  BlePresentationKind.reconnecting => 'Trying to reach your robot again…',
  BlePresentationKind.bluetoothOff => 'Turn on Bluetooth to find your robot.',
  BlePresentationKind.permissionNeeded =>
    'Allow Bluetooth access for this app in Settings.',
  BlePresentationKind.unavailable => 'This phone cannot use Bluetooth.',
  BlePresentationKind.reconnectFailed =>
    'Make sure your robot is on, then tap Scan.',
  BlePresentationKind.checking ||
  BlePresentationKind.turningOn ||
  BlePresentationKind.turningOff ||
  BlePresentationKind.disconnecting => 'One moment…',
  BlePresentationKind.notConnected ||
  BlePresentationKind.connected => 'Power on your robot, then tap Scan.',
};

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
    this.presentationState,
  });

  final Future<void> Function(bool automatic) onPairingRequested;
  final BleConnectionCoordinator coordinator;
  final bool Function() isBleConnected;
  final bool enableBlePlatformBindings;

  /// The toolbar badge's state, so the sheet header says the same thing.
  final ValueListenable<BlePresentationState>? presentationState;

  @override
  State<BleConnectionSheet> createState() => _BleConnectionSheetState();
}

class _BleConnectionSheetState extends State<BleConnectionSheet> {
  bool _scanning = false;
  bool _connecting = false;
  int _scanSecondsLeft = 0;
  Timer? _cleanupTimer;
  final Map<String, _BleEntry> _deviceMap = {};
  String? _lastDeviceId;
  String? _lastDeviceName;
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
      _scanSecondsLeft = state.scanSecondsLeft;
      _securityState = state.securityState;
      _lastDeviceId = state.lastDeviceId?.isEmpty == true
          ? null
          : state.lastDeviceId;
      _lastDeviceName = state.lastDeviceName?.isEmpty == true
          ? null
          : state.lastDeviceName;
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

  Future<void> _stopScan() => _bleCoordinator.stopScan();

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

  BlePresentationState _presentation(
    BlePresentationState badge,
    bool connected,
  ) => resolveBleSheetPresentation(
    badge: badge,
    connected: connected,
    connecting: _connecting,
    scanning: _scanning,
  );

  String _connectedName() => resolveBleConnectedDeviceName(
    currentName: BleManager.instance.currentDeviceName,
    currentId: BleManager.instance.currentDeviceId,
    lastDeviceName: _lastDeviceName,
    unknownName: 'Unknown device',
  );

  Widget _buildHeader(BlePresentationState presentation, bool connected) {
    final title = connected ? _connectedName() : presentation.label;
    final status = Semantics(
      container: true,
      liveRegion: true,
      label: connected
          ? 'Bluetooth connection: Connected, $title'
          : presentation.semanticLabel,
      excludeSemantics: true,
      child: Row(
        children: [
          BleStatusOrb(
            presentation: presentation,
            size: 44,
            animate: AmbientMotion.enabledFor(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: LavenderPalette.displayFont,
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: LavenderPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                if (connected)
                  BleSecurityLine(state: _securityState)
                else
                  Text(
                    _bleSheetHint(presentation.kind),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LavenderPalette.inkSoft,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Actions sit beside the title when there is room (landscape) and
        // move under it on narrow sheets or with large text.
        final wide =
            constraints.maxWidth >=
            520 * MediaQuery.textScalerOf(context).scale(1);
        final actions = _buildActions(connected, wide: wide);
        if (wide) {
          return Row(
            children: [
              Expanded(child: status),
              const SizedBox(width: 12),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [status, const SizedBox(height: 10), actions],
        );
      },
    );
  }

  Widget _buildActions(bool connected, {required bool wide}) {
    Widget? leading;
    final List<Widget> buttons;
    if (connected) {
      final needsCode = requiresBlePairingCode(_securityState);
      leading = IconButton(
        tooltip: _securityState == BleControlSecurityState.ready
            ? 'Paired'
            : 'Pair code',
        onPressed: needsCode ? _openPairingCode : null,
        icon: Icon(
          Icons.password_rounded,
          color: needsCode
              ? LavenderPalette.violet
              : LavenderPalette.ink.withValues(alpha: 0.28),
        ),
      );
      buttons = [
        GlassActionButton(
          label: 'Disconnect',
          icon: Icons.link_off_rounded,
          accent: LavenderPalette.coral,
          height: 48,
          onPressed: _disconnect,
        ),
      ];
    } else if (_scanning) {
      buttons = [
        GlassActionButton(
          label: _scanSecondsLeft > 0
              ? 'Scanning ${_scanSecondsLeft}s'
              : 'Scanning',
          icon: Icons.search_rounded,
          height: 48,
          busy: true,
          onPressed: null,
        ),
        GlassActionButton(
          label: 'Stop',
          icon: Icons.stop_rounded,
          accent: LavenderPalette.coral,
          height: 48,
          onPressed: _stopScan,
        ),
      ];
    } else {
      buttons = [
        if (_lastDeviceId != null)
          GlassActionButton(
            label: 'Connect last',
            icon: Icons.link_rounded,
            height: 48,
            onPressed: _connecting ? null : _connectLast,
          ),
        GradientActionButton(
          label: _connecting ? 'Connecting' : 'Scan devices',
          icon: Icons.search_rounded,
          height: 48,
          busy: _connecting,
          onPressed: _connecting ? null : _startScan,
        ),
      ];
    }

    final children = <Widget>[?leading];
    for (final button in buttons) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(
        wide
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: IntrinsicWidth(child: button),
              )
            : Expanded(child: button),
      );
    }
    return Row(
      mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Icon(
              _scanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.smart_toy_outlined,
              size: 26,
              color: LavenderPalette.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _scanning ? 'Looking for robots…' : 'No robots found yet',
                  style: const TextStyle(
                    color: LavenderPalette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _scanning
                      ? 'Keep your robot powered on and close to this phone.'
                      : 'Make sure your robot is on and nearby, then tap Scan.',
                  style: const TextStyle(
                    color: LavenderPalette.inkSoft,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    final connected = widget.isBleConnected();
    const titleColor = LavenderPalette.ink;
    const bodyColor = LavenderPalette.inkSoft;
    final tileColor = Colors.white.withValues(alpha: 0.5);
    final tileBorder = LavenderPalette.ink.withValues(alpha: 0.1);
    final devices = _deviceMap.values.map((e) => e.result).toList();
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    // The header and footer stay put and only the middle scrolls, so Close
    // is always visible. Landscape screens are short: use most of them.
    final maxHeight = math.max(
      0.0,
      math.min(
        media.size.height * (landscape ? 0.85 : 0.6),
        media.size.height - media.padding.vertical - 48,
      ),
    );

    final presentationState = widget.presentationState;
    final header = presentationState == null
        ? _buildHeader(
            _presentation(
              const BlePresentationState(BlePresentationKind.notConnected),
              connected,
            ),
            connected,
          )
        : ValueListenableBuilder<BlePresentationState>(
            valueListenable: presentationState,
            builder: (context, badge, _) =>
                _buildHeader(_presentation(badge, connected), connected),
          );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!connected)
          devices.isEmpty
              ? _buildEmptyState()
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
              diagnostics: snapshot.data ?? BleManager.instance.diagnostics,
              isThai: isThai,
              titleColor: titleColor,
              bodyColor: bodyColor,
              tileColor: tileColor,
              tileBorder: tileBorder,
            );
          },
        ),
      ],
    );

    final footer = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Spacer(),
          if (_lastDeviceId != null)
            TextButton(
              onPressed: _forgetLastDevice,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                backgroundColor: _opacity(Colors.redAccent, 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: _opacity(Colors.redAccent, 0.28)),
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
          const SizedBox(width: 8),
          GlassActionButton(
            label: 'Close',
            icon: Icons.close_rounded,
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CatGlassModalSurface(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: LavenderPalette.violet.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  header,
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      // Own ink layer, so row highlights scroll and clip
                      // with the list instead of painting under the footer.
                      child: Material(
                        type: MaterialType.transparency,
                        child: body,
                      ),
                    ),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
