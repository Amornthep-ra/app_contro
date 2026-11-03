// lib/features/bluetooth/bluetooth_ble_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/connection/app_connection.dart';
import '../../core/ble/ble_adapter_observation.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ble/ble_connection_coordinator.dart';
import '../../core/ble/ble_presentation_state.dart';
import '../../core/ui/language_controller.dart';
import '../../core/ui/lavender_glass.dart';
import '../../core/widgets/ble_status_orb.dart';
import '../../core/widgets/cat_back_button.dart';
import '../../core/widgets/portrait_background.dart';
import 'widgets/ble_connection_status.dart';
import 'widgets/ble_device_row.dart';
import 'widgets/pairing_code_dialog.dart';

export 'widgets/ble_connection_status.dart' show resolveBleConnectedDeviceName;
export 'widgets/ble_device_row.dart' show bleScanResultName, sortBleScanResults;

@visibleForTesting
bool isCurrentBleDeviceId({
  required String candidateDeviceId,
  String? currentDeviceId,
}) => candidateDeviceId == currentDeviceId;

const double _kToolbarHeight = 56;
const double _kPagePadding = 20;
const double _kContentMaxWidth = 560;

class BluetoothBlePage extends StatefulWidget {
  const BluetoothBlePage({
    super.key,
    this.coordinator,
    this.isBleConnected,
    this.pairingPromptLauncher = promptForBlePairingCode,
    this.enableBlePlatformBindings = true,
  });

  final BleConnectionCoordinator? coordinator;
  final bool Function()? isBleConnected;
  final BlePairingPromptLauncher pairingPromptLauncher;

  /// Test seam that leaves production BLE subscriptions and initialization off.
  @visibleForTesting
  final bool enableBlePlatformBindings;

  @override
  State<BluetoothBlePage> createState() => _BluetoothBlePageState();
}

class _BluetoothBlePageState extends State<BluetoothBlePage>
    with WidgetsBindingObserver {
  bool _pairingCheckScheduled = false;

  void _schedulePairingCheck() {
    if (!mounted || _pairingCheckScheduled) return;
    _pairingCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pairingCheckScheduled = false;
      if (mounted) unawaited(_enterPairingCode(automatic: true));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedulePairingCheck();
  }

  static const _bluetoothSettingsChannel = MethodChannel(
    'com.pbcontroller.app/bluetooth_settings',
  );

  bool _scanning = false;
  bool _connecting = false;
  bool _scrolled = false;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  bool _scanRequestedWhileBluetoothOff = false;
  bool _bluetoothOffDialogOpen = false;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<bool>? _connStateSub;

  List<ScanResult> _devices = const [];

  static const int _scanTimeoutSeconds = 10;
  int _scanSecondsLeft = 0;
  int? _bleTrafficOwner;

  String? _lastDeviceId;
  String? _lastDeviceNamePersisted;
  bool _pendingConnectLast = false;
  bool _pairingDialogOpen = false;

  /// Row the user tapped, so its spinner shows while connecting.
  String? _connectingDeviceId;
  BleControlSecurityState _securityState = BleControlSecurityState.disconnected;
  BleConnectionCoordinator get _bleCoordinator =>
      widget.coordinator ?? BleConnectionCoordinator.instance;
  bool get _isBleConnected =>
      widget.isBleConnected?.call() ?? BleManager.instance.isConnected;

  StreamSubscription<BleConnectionCoordinatorState>? _bleCoordinatorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleCoordinatorSub = _bleCoordinator.stream.listen(_applyCoordinatorState);
    if (widget.enableBlePlatformBindings) {
      _bleCoordinator.acquire();
      _bleTrafficOwner = BleManager.instance.claimTrafficMode(
        BleTrafficMode.textCommand,
        ownerName: 'bluetooth_page',
      );
      _bindConnectionGuard();
      _bindAdapterState();
      _initializeCoordinator();
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
      _lastDeviceNamePersisted = state.lastDeviceName?.isEmpty == true
          ? null
          : state.lastDeviceName;
      _devices = state.devices;
    });
    if (requiresBlePairingCode(state.securityState) && _isBleConnected) {
      _schedulePairingCheck();
    }
  }

  void _queueAutoConnectLast() {
    if (_lastDeviceId == null) return;
    if (_connecting || BleManager.instance.isConnected) return;
    if (_pendingConnectLast) return;
    _pendingConnectLast = true;
    unawaited(_connectRememberedDevice('bluetooth_page_initial'));
  }

  Future<void> _connectRememberedDevice(
    String source, {
    bool userInitiated = false,
  }) async {
    try {
      await _bleCoordinator.autoConnectLastDevice(
        timeout: const Duration(seconds: _scanTimeoutSeconds),
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

  void _bindConnectionGuard() {
    _connStateSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;

      if (!connected) {
        AppConnection.instance.setBleConnected(false);
        setState(() {
          _connecting = false;
          _connectingDeviceId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adapterStateSub?.cancel();
    _isScanningSub?.cancel();
    _connStateSub?.cancel();
    _bleCoordinatorSub?.cancel();
    if (widget.enableBlePlatformBindings) {
      unawaited(_bleCoordinator.release());
    }
    final trafficOwner = _bleTrafficOwner;
    _bleTrafficOwner = null;
    if (trafficOwner != null) {
      BleManager.instance.releaseTrafficMode(trafficOwner);
    }

    super.dispose();
  }

  Future<void> _startScan() async {
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _scanRequestedWhileBluetoothOff = true;
      await _showBluetoothOffDialog();
      return;
    }
    await _bleCoordinator.startScan(
      timeout: const Duration(seconds: _scanTimeoutSeconds),
    );
  }

  void _bindAdapterState() {
    _adapterStateSub = FlutterBluePlus.adapterState.listen((adapterState) {
      BleAdapterObservationBoundary.instance.recordAlreadyObserved(
        adapterState,
      );
      if (!mounted ||
          adapterState != BluetoothAdapterState.on ||
          !_scanRequestedWhileBluetoothOff) {
        return;
      }

      _scanRequestedWhileBluetoothOff = false;
      unawaited(
        _bleCoordinator.startScan(
          timeout: const Duration(seconds: _scanTimeoutSeconds),
        ),
      );
    });
  }

  Future<void> _showBluetoothOffDialog() async {
    if (!mounted || _bluetoothOffDialogOpen) return;
    _bluetoothOffDialogOpen = true;
    try {
      final openSettings = await showLavenderConfirmDialog(
        context: context,
        icon: Icons.bluetooth_disabled_rounded,
        title: 'Bluetooth is off',
        message: 'Turn on Bluetooth to scan for and connect to your robot.',
        confirmLabel: 'Open settings',
      );
      if (openSettings) {
        await _openBluetoothSettings();
      } else {
        _scanRequestedWhileBluetoothOff = false;
      }
    } finally {
      _bluetoothOffDialogOpen = false;
    }
  }

  Future<void> _openBluetoothSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _bluetoothSettingsChannel.invokeMethod<bool>(
          'openBluetoothSettings',
        );
        if (opened == true) return;
      } on PlatformException {
        // Fall through to the app settings page when the device cannot open
        // the system Bluetooth panel.
      }
    }

    await openAppSettings();
  }

  Future<void> _stopScan() => _bleCoordinator.stopScan();

  Future<void> _disconnect() async {
    await _bleCoordinator.disconnect();
  }

  Future<void> _confirmForgetLastDevice(String name, bool connected) async {
    final confirmed = await showLavenderConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Forget $name?',
      message: connected
          ? 'This disconnects the robot and removes it from quick reconnect. '
                'You can pair it again any time.'
          : 'It will be removed from quick reconnect. '
                'You can pair it again any time.',
      confirmLabel: 'Forget',
      destructive: true,
    );
    if (confirmed) await _bleCoordinator.forgetLastDevice();
  }

  void _connectLastDevice() {
    if (_pendingConnectLast) return;
    setState(() {
      _pendingConnectLast = true;
      _connectingDeviceId = _lastDeviceId;
    });
    unawaited(
      _connectRememberedDevice('bluetooth_page_manual', userInitiated: true),
    );
  }

  Future<void> _connect(ScanResult result) async {
    final id = result.device.remoteId.str;
    setState(() => _connectingDeviceId = id);
    try {
      await _bleCoordinator.connect(result, source: 'bluetooth_page');
    } finally {
      if (mounted && _connectingDeviceId == id) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  Future<void> _enterPairingCode({bool automatic = false}) async {
    if (_pairingDialogOpen || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    if (!_isBleConnected) {
      if (automatic) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a board before entering a pairing code.'),
        ),
      );
      return;
    }
    if (!requiresBlePairingCode(_securityState)) return;
    if (automatic) {
      if (!_bleCoordinator.claimAutomaticPairingPrompt(connected: true)) {
        return;
      }
    } else {
      _bleCoordinator.markPairingPromptPresented();
    }
    _pairingDialogOpen = true;
    try {
      await widget.pairingPromptLauncher(
        context: context,
        isThai: LanguageController.isThai.value,
        coordinator: _bleCoordinator,
      );
    } catch (error, stackTrace) {
      if (automatic) {
        _bleCoordinator.releaseAutomaticPairingPrompt();
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'BLE pairing prompt',
          context: ErrorDescription(
            'while opening the BLE Connection pairing prompt',
          ),
        ),
      );
    } finally {
      _pairingDialogOpen = false;
      _schedulePairingCheck();
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final scrolled = notification.metrics.pixels > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  String? _resolveLastDeviceName(String? deviceId) {
    if (deviceId == null) return _lastDeviceNamePersisted;
    for (final candidate in _devices) {
      if (candidate.device.remoteId.str == deviceId) {
        final name = bleScanResultName(candidate);
        return name.isNotEmpty ? name : deviceId;
      }
    }
    return _lastDeviceNamePersisted ?? deviceId;
  }

  String _connectedName() => resolveBleConnectedDeviceName(
    currentName: BleManager.instance.currentDeviceName,
    currentId: BleManager.instance.currentDeviceId,
    lastDeviceName: _lastDeviceNamePersisted,
    unknownName: 'Unknown device',
  );

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) == true) _schedulePairingCheck();
    final media = MediaQuery.of(context);
    final connectedDeviceId = BleManager.instance.currentDeviceId;
    final results = sortBleScanResults(
      _devices.where(
        (result) => !isCurrentBleDeviceId(
          candidateDeviceId: result.device.remoteId.str,
          currentDeviceId: connectedDeviceId,
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: LavenderPalette.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: _kToolbarHeight,
        leadingWidth: CatBackButton.leadingWidthFor(_kPagePadding),
        leading: Navigator.of(context).canPop()
            ? CatBackButton.leading()
            : null,
        centerTitle: true,
        title: const Text(
          'BLE Connection',
          style: TextStyle(
            fontFamily: LavenderPalette.displayFont,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: LavenderPalette.ink,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: FrostedBarBackground(visible: _scrolled),
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: PortraitBackground(
        child: StreamBuilder<bool>(
          stream: BleManager.instance.connectionStream,
          initialData: BleManager.instance.isConnected,
          builder: (context, snap) {
            final connected = widget.isBleConnected != null
                ? _isBleConnected
                : snap.data ?? false;
            return BackdropGroup(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScroll,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    _kPagePadding,
                    media.padding.top + _kToolbarHeight + 12,
                    _kPagePadding,
                    24 + media.padding.bottom,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kContentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatusCard(connected),
                            if (_lastDeviceId != null) ...[
                              const SizedBox(height: 14),
                              _buildLastDeviceCard(
                                connected: connected,
                                connectedDeviceId: connectedDeviceId,
                              ),
                            ],
                            const SizedBox(height: 24),
                            _buildDevicesHeader(results.length),
                            const SizedBox(height: 10),
                            _buildDevicesPanel(results),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status card
  // ---------------------------------------------------------------------------

  BlePresentationState _presentation(bool connected) {
    if (connected) {
      return const BlePresentationState(BlePresentationKind.connected);
    }
    if (_connecting || _connectingDeviceId != null) {
      return const BlePresentationState(BlePresentationKind.connecting);
    }
    if (_scanning) {
      return const BlePresentationState(BlePresentationKind.scanning);
    }
    return const BlePresentationState(BlePresentationKind.notConnected);
  }

  String? get _connectingTargetName {
    final id =
        _connectingDeviceId ?? (_pendingConnectLast ? _lastDeviceId : null);
    if (id == null) return null;
    for (final result in _devices) {
      if (result.device.remoteId.str == id) return bleScanResultName(result);
    }
    return _resolveLastDeviceName(id);
  }

  Widget _buildStatusCard(bool connected) {
    final presentation = _presentation(connected);
    final connecting = !connected && presentation.isBusy && !_scanning;
    final title = connected
        ? _connectedName()
        : connecting
        ? 'Connecting…'
        : _scanning
        ? 'Scanning…'
        : 'Not connected';

    final Widget detail;
    if (connected) {
      detail = BleSecurityLine(state: _securityState);
    } else {
      final target = _connectingTargetName;
      final hint = connecting
          ? (target != null ? 'Connecting to $target' : 'Connecting to robot')
          : _scanning
          ? 'Looking for nearby robots…'
          : 'Power on your robot, then tap Scan.';
      detail = Text(
        hint,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: LavenderPalette.inkSoft,
          fontSize: 13,
          height: 1.3,
        ),
      );
    }

    return GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      tint: LavenderPalette.violetBright,
      tintStrength: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            label: connected
                ? 'Bluetooth connection: Connected, $title'
                : 'Bluetooth connection: $title',
            excludeSemantics: true,
            child: Row(
              children: [
                BleStatusOrb(
                  presentation: presentation,
                  animate:
                      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    // Keep text left-aligned next to the orb while it
                    // cross-fades (the default centres the child).
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Column(
                      key: ValueKey('$title/$connected/$_securityState'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: LavenderPalette.displayFont,
                            fontSize: 21,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: LavenderPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        detail,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildStatusActions(connected, connecting),
        ],
      ),
    );
  }

  Widget _buildStatusActions(bool connected, bool connecting) {
    if (connected) {
      final disconnect = GlassActionButton(
        label: 'Disconnect',
        icon: Icons.link_off_rounded,
        accent: LavenderPalette.coral,
        onPressed: _disconnect,
      );
      if (requiresBlePairingCode(_securityState)) {
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: GradientActionButton(
                label: 'Pair code',
                icon: Icons.password_rounded,
                onPressed: () => _enterPairingCode(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: disconnect),
          ],
        );
      }
      return Row(
        children: [
          if (_securityState == BleControlSecurityState.ready)
            const LavenderChip(
              label: 'Paired',
              icon: Icons.verified_rounded,
              color: LavenderPalette.success,
            ),
          const Spacer(),
          SizedBox(width: 168, child: disconnect),
        ],
      );
    }

    if (_scanning) {
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: GlassActionButton(
              label: _scanSecondsLeft > 0
                  ? 'Scanning ${_scanSecondsLeft}s'
                  : 'Scanning',
              icon: Icons.search_rounded,
              busy: true,
              onPressed: null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: GlassActionButton(
              label: 'Stop',
              icon: Icons.stop_rounded,
              accent: LavenderPalette.coral,
              onPressed: _stopScan,
            ),
          ),
        ],
      );
    }

    return GradientActionButton(
      label: connecting ? 'Connecting' : 'Scan devices',
      icon: Icons.search_rounded,
      busy: connecting,
      onPressed: connecting ? null : _startScan,
    );
  }

  // ---------------------------------------------------------------------------
  // Last device
  // ---------------------------------------------------------------------------

  Widget _buildLastDeviceCard({
    required bool connected,
    required String? connectedDeviceId,
  }) {
    final lastId = _lastDeviceId!;
    final name = _resolveLastDeviceName(lastId) ?? lastId;
    final isCurrent =
        connected && (connectedDeviceId == null || connectedDeviceId == lastId);
    final busy = _pendingConnectLast || _connectingDeviceId == lastId;

    Widget trailing({required bool stacked}) {
      if (isCurrent) {
        return const LavenderChip(
          label: 'Connected',
          icon: Icons.check_rounded,
          color: LavenderPalette.success,
        );
      }
      return SizedBox(
        width: stacked ? 200 : 124,
        child: GlassActionButton(
          label: busy ? 'Connecting' : 'Connect',
          icon: Icons.link_rounded,
          height: 44,
          busy: busy,
          onPressed:
              (busy || _connecting || _scanning || _connectingDeviceId != null)
              ? null
              : _connectLastDevice,
        ),
      );
    }

    final menu = PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded, color: LavenderPalette.inkSoft),
      color: const Color(0xFFFBF8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'forget') {
          unawaited(_confirmForgetLastDevice(name, isCurrent));
        }
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
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Last device',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LavenderPalette.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: LavenderPalette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          lastId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: LavenderPalette.inkMuted,
            fontSize: 11.5,
          ),
        ),
      ],
    );

    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      shadowStrength: 0.8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Put the action under the name when a single row would squeeze
          // the device name (small phones or large text).
          final stacked =
              constraints.maxWidth <
              340 * MediaQuery.textScalerOf(context).scale(1);
          final header = Row(
            children: [
              const BleRoundIcon(icon: Icons.history_rounded),
              const SizedBox(width: 12),
              Expanded(child: info),
              if (!stacked) ...[
                const SizedBox(width: 8),
                trailing(stacked: false),
              ],
              menu,
            ],
          );
          if (!stacked) return header;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: trailing(stacked: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Discovered devices
  // ---------------------------------------------------------------------------

  Widget _buildDevicesHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          const Flexible(
            child: Text(
              'Discovered devices',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: LavenderPalette.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            LavenderChip(label: '$count'),
          ],
        ],
      ),
    );
  }

  Widget _buildDevicesPanel(List<ScanResult> results) {
    if (results.isEmpty) {
      return GlassPanel(
        radius: 24,
        shadowStrength: 0.75,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BleRoundIcon(
              icon: _scanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.smart_toy_outlined,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              _scanning ? 'Looking for robots…' : 'No robots found yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LavenderPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _scanning
                  ? 'Keep your robot powered on and close to this phone.'
                  : 'Make sure your robot is on and nearby, then tap Scan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LavenderPalette.inkSoft,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

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
    return GlassPanel(
      radius: 24,
      shadowStrength: 0.75,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
