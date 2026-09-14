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
import '../../core/ui/app_assets.dart';
import '../../core/ui/language_controller.dart';
import '../../core/widgets/portrait_background.dart';
import 'widgets/pairing_code_dialog.dart';

@visibleForTesting
String resolveBleConnectedDeviceName({
  String? currentName,
  String? currentId,
  String? lastDeviceName,
  String unknownName = 'Unknown',
}) {
  final name = currentName?.trim();
  if (name != null && name.isNotEmpty) return name;

  final id = currentId?.trim();
  if (id != null && id.isNotEmpty) return id;

  final lastName = lastDeviceName?.trim();
  if (lastName != null && lastName.isNotEmpty) return lastName;

  return unknownName;
}

@visibleForTesting
bool isCurrentBleDeviceId({
  required String candidateDeviceId,
  String? currentDeviceId,
}) => candidateDeviceId == currentDeviceId;

class _BleCatPalette {
  static const purple = Color(0xFF7256B6);
  static const cyan = Color(0xFF37D8FF);
  static const coral = Color(0xFFF05264);
  static const deepPlum = Color(0xFF261B39);
  static const glass = Color(0xEAFDF9FF);
  static const glassBorder = Color(0xCCFFFFFF);
}

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
  BleControlSecurityState _securityState = BleControlSecurityState.disconnected;
  BleConnectionCoordinator get _bleCoordinator =>
      widget.coordinator ?? BleConnectionCoordinator.instance;
  bool get _isBleConnected =>
      widget.isBleConnected?.call() ?? BleManager.instance.isConnected;

  StreamSubscription<BleConnectionCoordinatorState>? _bleCoordinatorSub;

  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  ColorScheme _scheme(BuildContext context) => Theme.of(context).colorScheme;
  Color _textPrimary(BuildContext context) =>
      _isDark(context) ? _scheme(context).onSurface : _BleCatPalette.deepPlum;
  Color _textSecondary(BuildContext context) =>
      _scheme(context).onSurfaceVariant;
  Color _textTertiary(BuildContext context) =>
      _opacity(_scheme(context).onSurfaceVariant, 0.82);
  Color _panelBg(BuildContext context) => _isDark(context)
      ? _opacity(_scheme(context).surfaceContainerHighest, 0.55)
      : _BleCatPalette.glass;
  Color _panelBorder(BuildContext context) => _isDark(context)
      ? _opacity(_scheme(context).outlineVariant, 0.78)
      : _BleCatPalette.glassBorder;
  Color _pillBg(BuildContext context) => _isDark(context)
      ? _opacity(_scheme(context).primaryContainer, 0.56)
      : _opacity(_BleCatPalette.glass, 0.94);

  String _t(String th, String en) {
    if (en == 'Pair QR') {
      return LanguageController.isThai.value ? 'Pair code' : 'Pair code';
    }
    if (en == 'Pair QR before control') {
      return LanguageController.isThai.value
          ? 'Enter pairing code before control'
          : 'Enter pairing code before control';
    }
    return LanguageController.isThai.value ? th : en;
  }

  Widget _homeIcon(String name, {double size = 24}) {
    return Image.asset(
      'assets/icons/HomeUnified/$name',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPlainBackButton() {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: _t('Back', 'Back'),
        icon: Image.asset(
          AppAssets.controlBack,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.chevron_left_rounded, size: 24),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.maybePop(context);
        },
        padding: EdgeInsets.zero,
        splashRadius: 22,
      ),
    );
  }

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
      if (mounted) setState(() {});
    }
  }

  void _bindConnectionGuard() {
    _connStateSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;

      if (!connected) {
        AppConnection.instance.setBleConnected(false);
        setState(() {
          _connecting = false;
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
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Bluetooth is off'),
          content: const Text(
            'Turn on Bluetooth to scan for and connect to devices.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _scanRequestedWhileBluetoothOff = false;
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _openBluetoothSettings();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
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

  Future<void> _forgetLastDevice() async {
    await _bleCoordinator.forgetLastDevice();
  }

  Future<void> _connect(ScanResult result) =>
      _bleCoordinator.connect(result, source: 'bluetooth_page');

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
        SnackBar(
          content: Text(
            _t(
              'Connect to a board before entering a pairing code.',
              'Connect to a board before entering a pairing code.',
            ),
          ),
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

  String _signalLabel(int rssi) {
    if (rssi >= -55) return _t('Very strong', 'Very strong');
    if (rssi >= -65) return _t('Strong', 'Strong');
    if (rssi >= -75) return _t('Medium', 'Medium');
    if (rssi >= -85) return _t('Weak', 'Weak');
    return _t('Very weak', 'Very weak');
  }

  IconData _signalIcon(int rssi) {
    return Icons.bluetooth;
  }

  Color _signalColor(BuildContext context, int rssi) {
    if (rssi >= -65) {
      return const Color(0xFF22C55E);
    } else if (rssi >= -80) {
      return const Color(0xFFEAB308);
    } else {
      return const Color(0xFFEF4444);
    }
  }

  Widget _buildBleStatusBar() {
    return StreamBuilder<bool>(
      stream: BleManager.instance.connectionStream,
      initialData: BleManager.instance.isConnected,
      builder: (context, snap) {
        final connected = widget.isBleConnected != null
            ? _isBleConnected
            : snap.data ?? false;
        final scheme = _scheme(context);

        final name = connected
            ? resolveBleConnectedDeviceName(
                currentName: BleManager.instance.currentDeviceName,
                currentId: BleManager.instance.currentDeviceId,
                lastDeviceName: _lastDeviceNamePersisted,
                unknownName: _t('Unknown', 'Unknown'),
              )
            : _t('Not connected', 'Not connected');

        final titleColor = connected
            ? _textPrimary(context)
            : _BleCatPalette.coral;
        final subtitleColor = _textSecondary(context);
        final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor,
        );

        final grad = connected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _opacity(scheme.primaryContainer, 0.9),
                  _opacity(scheme.primaryContainer, 0.62),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_BleCatPalette.glass, Color(0xDDF6F0FF)],
              );

        final border = connected
            ? _opacity(scheme.primary, 0.55)
            : _BleCatPalette.coral.withAlpha(170);

        final actions = <Widget>[];
        if (!connected) {
          final icon = (_connecting || _scanning)
              ? Icons.hourglass_top
              : Icons.refresh;
          final label = _connecting
              ? _t('Connecting...', 'Connecting...')
              : (_scanning
                    ? (_scanSecondsLeft > 0
                          ? _t(
                              'Scanning (${_scanSecondsLeft}s)',
                              'Scanning (${_scanSecondsLeft}s)',
                            )
                          : _t('Scanning...', 'Scanning...'))
                    : _t('Scan', 'Scan'));

          actions.add(
            _smallAction(
              icon: icon,
              assetName: (!_connecting && !_scanning)
                  ? 'Search-Scan.png'
                  : null,
              label: label,
              onTap: (_scanning || _connecting) ? null : _startScan,
              primary: !_scanning && !_connecting,
            ),
          );
          if (_scanning) {
            actions.add(
              _smallAction(
                icon: Icons.stop_circle,
                label: _t('Stop', 'Stop'),
                onTap: _stopScan,
                danger: true,
              ),
            );
          }
        } else {
          final pairingRequired = requiresBlePairingCode(_securityState);
          actions.add(
            _smallAction(
              icon: Icons.password,
              label: pairingRequired
                  ? _t('Pair code', 'Pair code')
                  : _t('Paired', 'Paired'),
              onTap: pairingRequired ? () => _enterPairingCode() : null,
            ),
          );
          actions.add(
            _smallAction(
              icon: Icons.link_off,
              label: _t('Disconnect', 'Disconnect'),
              onTap: _disconnect,
              danger: true,
            ),
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: grad,
            border: Border.all(color: border, width: 1.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: connected
                          ? _opacity(scheme.primary, 0.14)
                          : _BleCatPalette.coral.withAlpha(44),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _homeIcon(
                          connected
                              ? 'Bluetooth Connected.png'
                              : 'Bluetooth Disabled.png',
                          size: 24,
                        ),
                        if (!connected)
                          Positioned(
                            top: 3,
                            right: 3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _BleCatPalette.coral,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(
                          connected ? "connected_$name" : "disconnected",
                        ),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            connected
                                ? _t('Connected', 'Connected')
                                : _t('Not connected', 'Not connected'),
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            connected
                                ? name
                                : _t('Tap scan to begin', 'Tap scan to begin'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (connected && !_bleCoordinator.state.controlReady)
                            Text(
                              _bleCoordinator.state.securityState ==
                                      BleControlSecurityState.pairingRequired
                                  ? _t(
                                      'Pair QR before control',
                                      'Pair QR before control',
                                    )
                                  : _t(
                                      'Secure firmware update required',
                                      'Secure firmware update required',
                                    ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _BleCatPalette.coral,
                                    fontWeight: FontWeight.w700,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _smallAction({
    required IconData icon,
    String? assetName,
    required String label,
    required VoidCallback? onTap,
    bool danger = false,
    bool primary = false,
  }) {
    final scheme = _scheme(context);
    final base = danger ? scheme.error : scheme.primary;
    final foreground = danger ? scheme.error : _textPrimary(context);

    final action = TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 32),
        foregroundColor: primary ? Colors.white : foreground,
        backgroundColor: primary ? Colors.transparent : _pillBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: _opacity(base, 0.72), width: 1),
        ),
      ),
      icon: assetName == null
          ? Icon(icon, size: 14)
          : _homeIcon(assetName, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
    if (!primary) return action;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_BleCatPalette.purple, _BleCatPalette.cyan],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _BleCatPalette.purple.withAlpha(88),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) == true) _schedulePairingCheck();
    final connectedDeviceId = BleManager.instance.currentDeviceId;
    final results = _devices
        .where(
          (result) => !isCurrentBleDeviceId(
            candidateDeviceId: result.device.remoteId.str,
            currentDeviceId: connectedDeviceId,
          ),
        )
        .toList();

    final lastId = _lastDeviceId;
    final lastName = _resolveLastDeviceName(lastId);

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        const toolbarHeight = 44.0;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: toolbarHeight,
            leading: Navigator.of(context).canPop()
                ? _buildPlainBackButton()
                : null,
            centerTitle: true,
            title: Text(
              _t('BLE Connection', 'BLE Connection'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
          ),
          body: PortraitBackground(
            child: Padding(
              padding: const EdgeInsets.only(top: toolbarHeight),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      _buildBleStatusBar(),
                      const SizedBox(height: 10),
                      _lastDeviceCard(
                        hasLastDevice: lastId != null,
                        name:
                            lastName ??
                            _t('No recent device', 'No recent device'),
                        id: lastId ?? '-',
                        onConnect: (lastId == null || _connecting || _scanning)
                            ? null
                            : () {
                                if (_pendingConnectLast) return;
                                _pendingConnectLast = true;
                                unawaited(
                                  _connectRememberedDevice(
                                    'bluetooth_page_manual',
                                    userInitiated: true,
                                  ),
                                );
                              },
                        onForget: lastId == null ? null : _forgetLastDevice,
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        fit: results.isEmpty && !_scanning
                            ? FlexFit.loose
                            : FlexFit.tight,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          decoration: BoxDecoration(
                            color: _panelBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _panelBorder(context)),
                            boxShadow: [
                              BoxShadow(
                                color: _BleCatPalette.purple.withAlpha(40),
                                blurRadius: 16,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: results.isEmpty && !_scanning
                                ? MainAxisSize.min
                                : MainAxisSize.max,
                            children: [
                              Row(
                                children: [
                                  _homeIcon('Search-Scan.png', size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t(
                                      'Discovered devices',
                                      'Discovered devices',
                                    ),
                                    style: TextStyle(
                                      color: _textPrimary(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                fit: results.isEmpty && !_scanning
                                    ? FlexFit.loose
                                    : FlexFit.tight,
                                child: results.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _homeIcon(
                                                _scanning
                                                    ? 'Search-Scan.png'
                                                    : 'Bluetooth Disabled.png',
                                                size: 42,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                _scanning
                                                    ? _t(
                                                        'Scanning for devices...',
                                                        'Scanning for devices...',
                                                      )
                                                    : _t(
                                                        'No devices found.\nTap Scan to try again.',
                                                        'No devices found.\nTap Scan to try again.',
                                                      ),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: _textSecondary(
                                                    context,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: results.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final r = results[index];
                                          final name =
                                              r.device.platformName.isNotEmpty
                                              ? r.device.platformName
                                              : (r
                                                        .advertisementData
                                                        .advName
                                                        .isNotEmpty
                                                    ? r
                                                          .advertisementData
                                                          .advName
                                                    : r.device.remoteId.str);

                                          final rssi = r.rssi;
                                          final signalText = _signalLabel(rssi);
                                          final signalColor = _signalColor(
                                            context,
                                            rssi,
                                          );
                                          final signalIcon = _signalIcon(rssi);

                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: _connecting
                                                  ? null
                                                  : () => _connect(r),
                                              child: Ink(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      12,
                                                      10,
                                                      8,
                                                      10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _panelBg(context),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: _panelBorder(
                                                      context,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: _opacity(
                                                          signalColor,
                                                          0.13,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        signalIcon,
                                                        color: signalColor,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 15,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            'RSSI: $rssi dBm | $signalText',
                                                            style: TextStyle(
                                                              color:
                                                                  _textSecondary(
                                                                    context,
                                                                  ),
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.chevron_right,
                                                      color: _opacity(
                                                        _textSecondary(context),
                                                        0.75,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _resolveLastDeviceName(String? deviceId) {
    if (deviceId == null) return _lastDeviceNamePersisted;
    ScanResult? result;
    for (final candidate in _devices) {
      if (candidate.device.remoteId.str == deviceId) {
        result = candidate;
        break;
      }
    }
    if (result != null) {
      final r = result;
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : (r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.remoteId.str);
      return name.isNotEmpty ? name : deviceId;
    }
    return _lastDeviceNamePersisted ?? deviceId;
  }

  Widget _lastDeviceCard({
    required bool hasLastDevice,
    required String name,
    required String id,
    required VoidCallback? onConnect,
    required VoidCallback? onForget,
  }) {
    final scheme = _scheme(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        hasLastDevice ? 12 : 10,
        12,
        hasLastDevice ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: _panelBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder(context)),
        boxShadow: [
          BoxShadow(
            color: _BleCatPalette.purple.withAlpha(28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _opacity(scheme.tertiaryContainer, 0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: _homeIcon('Recent Activity-History.png', size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLastDevice) ...[
                  Text(
                    _t('Last device', 'Last device'),
                    style: TextStyle(
                      color: _textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasLastDevice)
                  Text(
                    id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textTertiary(context),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (hasLastDevice) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: onConnect,
                  child: Text(_t('Connect', 'Connect')),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onForget,
                  style: TextButton.styleFrom(
                    foregroundColor: _BleCatPalette.coral,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_t('Forget', 'Forget')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
