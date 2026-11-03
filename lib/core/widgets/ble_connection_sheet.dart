// lib/core/widgets/ble_connection_sheet.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../features/bluetooth/widgets/ble_connection_status.dart';
import '../../features/bluetooth/widgets/ble_device_row.dart';
import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_presentation_state.dart';
import '../ui/ambient_motion.dart';
import '../ui/lavender_glass.dart';
import 'ble_status_orb.dart';
import 'cat_glass_popup.dart';

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

  /// Row the user tapped (or the last device for `Connect <name>`), so only
  /// that one shows a spinner while connecting.
  String? _connectingDeviceId;
  bool _pairingRequestPending = false;
  BleControlSecurityState _securityState = BleControlSecurityState.disconnected;
  BleConnectionCoordinator get _bleCoordinator => widget.coordinator;

  StreamSubscription<BleConnectionCoordinatorState>? _bleCoordinatorSub;
  final ScrollController _scrollController = ScrollController();
  bool _showDiagnostics = false;
  bool _diagnosticsCopied = false;
  Timer? _copiedTimer;

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
      if (!state.connecting) _connectingDeviceId = null;
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
    _copiedTimer?.cancel();
    _scrollController.dispose();
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
      if (mounted) {
        setState(() {
          if (_connectingDeviceId == _lastDeviceId) _connectingDeviceId = null;
        });
      }
    }
  }

  Future<void> _confirmForgetLastDevice() async {
    final id = _lastDeviceId;
    if (id == null) return;
    final name = _deviceName(id) ?? id;
    final currentId = BleManager.instance.currentDeviceId;
    final connectedToIt =
        widget.isBleConnected() && (currentId == null || currentId == id);
    final confirmed = await showLavenderConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Forget $name?',
      message: connectedToIt
          ? 'This disconnects the robot and removes it from quick reconnect. '
                'You can pair it again any time.'
          : 'It will be removed from quick reconnect. '
                'You can pair it again any time.',
      confirmLabel: 'Forget',
      destructive: true,
    );
    if (confirmed) await _bleCoordinator.forgetLastDevice();
  }

  void _toggleDiagnostics() {
    setState(() => _showDiagnostics = !_showDiagnostics);
    // The panel opens at the top of the list: bring it into view.
    if (_showDiagnostics && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _startScan() => _bleCoordinator.startScan();

  Future<void> _stopScan() => _bleCoordinator.stopScan();

  Future<void> _disconnect() => _bleCoordinator.disconnect();

  Future<void> _openPairingCode() => _requestPairingCode(automatic: false);

  Future<void> _connect(ScanResult result) async {
    final id = result.device.remoteId.str;
    setState(() => _connectingDeviceId = id);
    try {
      await _bleCoordinator.connect(result, source: 'connection_status_badge');
    } finally {
      if (mounted && _connectingDeviceId == id) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  Future<void> _connectLast() async {
    if (_lastDeviceId == null || _pendingConnectLast) return;
    setState(() {
      _pendingConnectLast = true;
      _connectingDeviceId = _lastDeviceId;
    });
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
    // A snack bar would sit behind this sheet's barrier: confirm on the
    // button instead.
    setState(() => _diagnosticsCopied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _diagnosticsCopied = false);
    });
  }

  Widget _buildDiagnosticsPanel(BleDiagnosticsSnapshot diagnostics) {
    final write = diagnostics.writeCharacteristic;
    final read = diagnostics.readCharacteristic;
    final rows = <(String, String)>[
      ('Status', diagnostics.connectionStatus.name),
      ('Device', diagnostics.deviceName ?? diagnostics.deviceId ?? '-'),
      ('Device ID', diagnostics.deviceId ?? '-'),
      (
        'Mode / owner',
        '${diagnostics.trafficMode.name} / ${diagnostics.trafficOwnerName}',
      ),
      (
        'MTU / payload',
        '${diagnostics.mtu?.toString() ?? '-'} / ${diagnostics.payloadSize}',
      ),
      (
        'Write characteristic',
        write == null ? '-' : '${write.uuid} (${write.propertySummary})',
      ),
      (
        'Receive characteristic',
        read == null ? '-' : '${read.uuid} (${read.propertySummary})',
      ),
      ('Notification', diagnostics.notificationMode.name),
      ('Last TX', _diagnosticAge(diagnostics.lastTxAge)),
      ('Last RX', _diagnosticAge(diagnostics.lastRxAge)),
      ('Reconnect attempts', diagnostics.reconnectAttempt.toString()),
      ('Auto-connect target', diagnostics.autoConnectTargetId ?? '-'),
      ('Auto-connect age', _diagnosticAge(diagnostics.autoConnectOperationAge)),
      ('Last auto-connect', diagnostics.lastAutoConnectOutcome ?? '-'),
      ('Last failure', diagnostics.lastFailureReason ?? '-'),
      ('Last failure age', _diagnosticAge(diagnostics.lastFailureAge)),
      ('Last disconnect', diagnostics.lastDisconnectReason?.name ?? '-'),
      ('Last disconnect age', _diagnosticAge(diagnostics.lastDisconnectAge)),
      (
        'Last scan permission',
        diagnostics.lastScanPermissionResult?.name ?? '-',
      ),
    ];

    final radius = BorderRadius.circular(20);
    return Container(
      key: const ValueKey('ble-sheet-diagnostics'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BLE diagnostics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LavenderPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copyDiagnostics(diagnostics),
                style: _footerButtonStyle,
                icon: Icon(
                  _diagnosticsCopied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 18,
                ),
                label: Text(
                  _diagnosticsCopied ? 'Copied' : 'Copy',
                  style: _footerLabelStyle,
                ),
              ),
            ],
          ),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: LavenderPalette.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      value,
                      style: const TextStyle(
                        color: LavenderPalette.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Text buttons in the footer and diagnostics panel: violet, 48 px tall.
  /// (Labels set their own size so they keep the app font.)
  static final ButtonStyle _footerButtonStyle = TextButton.styleFrom(
    foregroundColor: LavenderPalette.violetDeep,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: const StadiumBorder(),
  );

  static const TextStyle _footerLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  BlePresentationState _presentation(
    BlePresentationState badge,
    bool connected,
  ) => resolveBleSheetPresentation(
    badge: badge,
    connected: connected,
    connecting: _connecting,
    scanning: _scanning,
  );

  /// Display name for a device id: from the scan list, else the remembered
  /// last-device name.
  String? _deviceName(String? id) {
    if (id == null) return null;
    final entry = _deviceMap[id];
    if (entry != null) return bleScanResultName(entry.result);
    return id == _lastDeviceId ? _lastDeviceName : null;
  }

  String _connectedName() => resolveBleConnectedDeviceName(
    currentName: BleManager.instance.currentDeviceName,
    currentId: BleManager.instance.currentDeviceId,
    lastDeviceName: _lastDeviceName,
    unknownName: 'Unknown device',
  );

  Widget _buildHeader(BlePresentationState presentation, bool connected) {
    final title = connected ? _connectedName() : presentation.label;
    final target = _deviceName(
      _connectingDeviceId ?? (_pendingConnectLast ? _lastDeviceId : null),
    );
    final hint =
        presentation.kind == BlePresentationKind.connecting && target != null
        ? 'Connecting to $target'
        : _bleSheetHint(presentation.kind);
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
                    hint,
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
        final scale = MediaQuery.textScalerOf(context).scale(1);
        // "Connect <name>" plus "Scan devices" beside the title would cut
        // the title ("Not conn…") on a phone, so they need a wider sheet.
        final connectAndScan =
            !connected && !_scanning && _lastDeviceId != null;
        final wide =
            constraints.maxWidth >= (connectAndScan ? 680 : 520) * scale;
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
    // On narrow sheets, only this button stretches; the others keep their
    // natural width. Null: all share the row.
    Widget? stretch;
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
      final inProgress =
          _connecting || _pendingConnectLast || _connectingDeviceId != null;
      // The spinner goes on the button the user pressed.
      final lastBusy =
          _lastDeviceId != null && _connectingDeviceId == _lastDeviceId;
      final connectLast = _lastDeviceId == null
          ? null
          : GlassActionButton(
              label: lastBusy
                  ? 'Connecting'
                  : 'Connect ${_deviceName(_lastDeviceId) ?? 'last robot'}',
              icon: Icons.link_rounded,
              height: 48,
              busy: lastBusy,
              onPressed: inProgress ? null : _connectLast,
            );
      // Next to "Connect <name>" on a narrow sheet, "Scan" leaves the name
      // room to stay readable.
      final scanBusy = _connecting && !lastBusy;
      buttons = [
        ?connectLast,
        GradientActionButton(
          label: scanBusy
              ? 'Connecting'
              : (connectLast != null && !wide ? 'Scan' : 'Scan devices'),
          icon: Icons.search_rounded,
          height: 48,
          busy: scanBusy,
          onPressed: inProgress ? null : _startScan,
        ),
      ];
      stretch = connectLast;
    }

    final children = <Widget>[?leading];
    for (final button in buttons) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(
        wide || (stretch != null && button != stretch)
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
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
          BleRoundIcon(
            icon: _scanning
                ? Icons.bluetooth_searching_rounded
                : Icons.smart_toy_outlined,
            size: 44,
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

  Widget _buildDeviceList(List<ScanResult> results) {
    final rows = <Widget>[];
    for (var i = 0; i < results.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 70,
            endIndent: 16,
            color: LavenderPalette.ink.withValues(alpha: 0.07),
          ),
        );
      }
      final result = results[i];
      final id = result.device.remoteId.str;
      rows.add(
        BleDeviceRow(
          name: bleScanResultName(result),
          rssi: result.rssi,
          lastUsed: id == _lastDeviceId,
          connecting: _connectingDeviceId == id,
          enabled: !_connecting && _connectingDeviceId == null,
          onTap: () => _connect(result),
        ),
      );
    }
    final radius = BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.isBleConnected();
    final devices = sortBleScanResults(_deviceMap.values.map((e) => e.result));
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
        // Diagnostics are for troubleshooting: closed until asked for, and
        // shown first when opened so they appear right under the header.
        if (_showDiagnostics)
          StreamBuilder<BleDiagnosticsSnapshot>(
            stream: BleManager.instance.diagnosticsStream,
            initialData: BleManager.instance.diagnostics,
            builder: (context, snapshot) => _buildDiagnosticsPanel(
              snapshot.data ?? BleManager.instance.diagnostics,
            ),
          ),
        if (!connected)
          devices.isEmpty ? _buildEmptyState() : _buildDeviceList(devices),
      ],
    );

    final footer = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _toggleDiagnostics,
                style: _footerButtonStyle,
                icon: Icon(
                  _showDiagnostics
                      ? Icons.expand_less_rounded
                      : Icons.monitor_heart_outlined,
                  size: 20,
                ),
                label: Text(
                  _showDiagnostics ? 'Hide diagnostics' : 'Diagnostics',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _footerLabelStyle,
                ),
              ),
            ),
          ),
          if (_lastDeviceId != null)
            PopupMenuButton<String>(
              tooltip: 'More options',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: LavenderPalette.inkSoft,
              ),
              color: const Color(0xFFFBF8FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'forget') unawaited(_confirmForgetLastDevice());
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'forget',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: LavenderPalette.coral,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Forget device',
                        style: TextStyle(
                          color: LavenderPalette.coral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      controller: _scrollController,
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
