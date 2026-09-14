// lib/core/widgets/connection_status_badge.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'gamepad_control_toolbar.dart';
import 'package:flutter/services.dart';
import '../ui/language_controller.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_presentation_state.dart';
import '../../features/bluetooth/widgets/pairing_code_dialog.dart';
import 'ble_presentation_icon.dart';
import 'cat_glass_popup.dart';
import 'gamepad_app_bar.dart';

String _t(bool isThai, String th, String en) => isThai ? th : en;

class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({
    super.key,
    this.appBarMetrics,
    this.iconAsset,
    this.subdued = false,
    this.onManagementBlocked,
    this.isControlSessionActive,
    this.coordinator,
    this.isBleConnected,
    this.pairingPromptLauncher = promptForBlePairingCode,
    this.pairingTransitionDelay = const Duration(milliseconds: 200),
    this.enableBlePlatformBindings = true,
    this.presentationState,
    this.autoPromptPairing = false,
    this.pairingPromptEnabled = true,
  });

  final GamepadAppBarMetrics? appBarMetrics;
  final String? iconAsset;
  final bool subdued;
  final bool autoPromptPairing;
  final bool pairingPromptEnabled;
  final VoidCallback? onManagementBlocked;
  final bool Function()? isControlSessionActive;
  final BleConnectionCoordinator? coordinator;
  final bool Function()? isBleConnected;
  final BlePairingPromptLauncher pairingPromptLauncher;
  final Duration pairingTransitionDelay;

  /// Test seam that leaves production BLE subscriptions and initialization off.
  @visibleForTesting
  final bool enableBlePlatformBindings;
  final ValueListenable<BlePresentationState>? presentationState;

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge>
    with WidgetsBindingObserver {
  StreamSubscription<BleConnectionCoordinatorState>? _pairingSubscription;
  bool _promptScheduled = false;
  bool _pairingTransitionPending = false;
  ({BleConnectionCoordinator coordinator, int generation, bool automatic})?
  _pendingPairing;

  void _bindPairing() {
    _pairingSubscription?.cancel();
    _pairingSubscription = _bleCoordinator.stream.listen(
      (_) => _schedulePairing(),
    );
    _schedulePairing();
  }

  void _schedulePairing() {
    if (!mounted ||
        _promptScheduled ||
        (!widget.autoPromptPairing && _pendingPairing == null)) {
      return;
    }
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptScheduled = false;
      if (!mounted) return;
      final pending = _pendingPairing;
      if (pending != null &&
          (pending.coordinator != _bleCoordinator ||
              pending.generation !=
                  _bleCoordinator.pairingConnectionGeneration ||
              !_isBleConnected ||
              !requiresBlePairingCode(_bleCoordinator.state.securityState))) {
        _pendingPairing = null;
      }
      if (_pendingPairing == null && widget.autoPromptPairing) {
        _pendingPairing = (
          coordinator: _bleCoordinator,
          generation: _bleCoordinator.pairingConnectionGeneration,
          automatic: true,
        );
      }
      unawaited(_showPairingCode());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedulePairing();
  }

  bool _sheetOpen = false;
  bool _pairingDialogOpen = false;
  Offset? _sheetAnchor;
  ValueListenable<BlePresentationState>? _presentationState;
  ChangeNotifier? _ownedPresentationState;
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
  BleConnectionCoordinator get _bleCoordinator =>
      widget.coordinator ?? BleConnectionCoordinator.instance;
  bool get _isBleConnected =>
      widget.isBleConnected?.call() ?? BleManager.instance.isConnected;

  @override
  void initState() {
    super.initState();
    _bindPresentationState();
    WidgetsBinding.instance.addObserver(this);
    _bindPairing();
  }

  @override
  void didUpdateWidget(ConnectionStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.autoPromptPairing != widget.autoPromptPairing ||
        oldWidget.pairingPromptEnabled != widget.pairingPromptEnabled) {
      _bindPairing();
    }
    if (oldWidget.presentationState != widget.presentationState ||
        oldWidget.enableBlePlatformBindings !=
            widget.enableBlePlatformBindings) {
      _bindPresentationState();
    }
  }

  void _bindPresentationState() {
    _ownedPresentationState?.dispose();
    _ownedPresentationState = null;
    final injected = widget.presentationState;
    if (injected != null) {
      _presentationState = injected;
      return;
    }
    if (!widget.enableBlePlatformBindings) {
      final fallback = ValueNotifier(
        resolveBlePresentationState(
          adapterState: BleAdapterPresentationState.unknown,
          connectionStatus: BleManager.instance.connectionStatus,
        ),
      );
      _ownedPresentationState = fallback;
      _presentationState = fallback;
      return;
    }
    final controller = BlePresentationStateController.production();
    _ownedPresentationState = controller;
    _presentationState = controller;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pairingSubscription?.cancel();
    _ownedPresentationState?.dispose();
    super.dispose();
  }

  Future<void> _requestSheetPairing(bool automatic) async {
    if (!mounted) return;
    final request = (
      coordinator: _bleCoordinator,
      generation: _bleCoordinator.pairingConnectionGeneration,
      automatic: automatic,
    );
    _pendingPairing = request;
    _pairingTransitionPending = true;
    await Future<void>.delayed(widget.pairingTransitionDelay);
    if (!mounted) return;
    _pairingTransitionPending = false;
    _schedulePairing();
  }

  Future<void> _showPairingCode() async {
    final request = _pendingPairing;
    if (request == null ||
        !mounted ||
        _pairingDialogOpen ||
        _sheetOpen ||
        _pairingTransitionPending ||
        !widget.pairingPromptEnabled ||
        ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    if (request.coordinator != _bleCoordinator ||
        request.generation != _bleCoordinator.pairingConnectionGeneration) {
      return;
    }
    if (!_isBleConnected) return;
    if (!requiresBlePairingCode(_bleCoordinator.state.securityState)) return;
    _pendingPairing = null;
    if (request.automatic) {
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
        coordinator: request.coordinator,
      );
    } catch (error, stackTrace) {
      if (request.automatic &&
          mounted &&
          request.coordinator == _bleCoordinator &&
          request.generation == _bleCoordinator.pairingConnectionGeneration) {
        request.coordinator.releaseAutomaticPairingPrompt();
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'BLE pairing prompt',
          context: ErrorDescription('while opening the BLE pairing prompt'),
        ),
      );
    } finally {
      _pairingDialogOpen = false;
      _schedulePairing();
    }
  }

  void _openSheet() {
    final controlSessionActive =
        widget.isControlSessionActive?.call() ??
        BleManager.instance.isControlSessionActive;
    if (controlSessionActive) {
      widget.onManagementBlocked?.call();
      return;
    }
    if (Platform.isIOS) {
      _openSheetIOS();
      return;
    }
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black87,
      builder: (context) => _ConnectionSheet(
        onPairingRequested: _requestSheetPairing,
        coordinator: _bleCoordinator,
        isBleConnected: () => _isBleConnected,
        enableBlePlatformBindings: widget.enableBlePlatformBindings,
      ),
    ).whenComplete(() {
      _sheetOpen = false;
      _schedulePairing();
    });
  }

  Future<void> _openSheetIOS() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final allowDismiss = ValueNotifier<bool>(false);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (allowDismiss.value) return;
      allowDismiss.value = true;
    });
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      anchorPoint: _sheetAnchor,
      builder: (context) {
        return SizedBox.expand(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: allowDismiss,
                builder: (context, armed, child) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: armed ? () => Navigator.pop(context) : null,
                    child: const SizedBox.expand(),
                  );
                },
              ),
              SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: _ConnectionSheet(
                    onPairingRequested: _requestSheetPairing,
                    coordinator: _bleCoordinator,
                    isBleConnected: () => _isBleConnected,
                    enableBlePlatformBindings: widget.enableBlePlatformBindings,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _sheetOpen = false;
    _schedulePairing();
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) == true) _schedulePairing();
    final theme = Theme.of(context);
    return ValueListenableBuilder<BlePresentationState>(
      valueListenable: _presentationState!,
      builder: (context, presentation, _) {
        final connected = presentation.isConnected;
        final tone = presentation.tone;
        final metrics = widget.appBarMetrics;
        final isDark = theme.brightness == Brightness.dark;
        final statusColor = switch (presentation.kind) {
          BlePresentationKind.notConnected => const Color(0xFFF87171),
          BlePresentationKind.connected => const Color(0xFF34D399),
          BlePresentationKind.scanning => const Color(0xFFF59E0B),
          _ => null,
        };
        final accentColor =
            statusColor ??
            switch (tone) {
              BlePresentationTone.connected => const Color(0xFF34D399),
              BlePresentationTone.busy => const Color(0xFFF59E0B),
              BlePresentationTone.failure => const Color(0xFFF87171),
              BlePresentationTone.neutral => const Color(0xFF60A5FA),
            };

        final bgColor =
            statusColor ??
            _opacity(
              Color.lerp(
                    isDark
                        ? const Color(0xFF101827)
                        : theme.colorScheme.surface,
                    isDark ? Colors.white : Colors.black,
                    isDark ? 0.04 : 0.02,
                  ) ??
                  theme.colorScheme.surface,
              isDark ? 0.92 : 0.97,
            );
        final borderColor = _opacity(
          statusColor ?? theme.colorScheme.outline,
          isDark ? 0.45 : 0.22,
        );

        final foregroundColor = statusColor == null
            ? accentColor
            : Colors.black87;
        final icon = materialIconForBlePresentation(presentation.icon);

        final text = presentation.label;
        final dotColor = statusColor == null
            ? switch (tone) {
                BlePresentationTone.connected => Colors.green,
                BlePresentationTone.busy => const Color(0xFFF59E0B),
                BlePresentationTone.failure => Colors.redAccent,
                BlePresentationTone.neutral => const Color(0xFF60A5FA),
              }
            : Colors.black54;
        if (GamepadControlScope.of(context) != null) {
          return Semantics(
            liveRegion: true,
            child: GamepadControlPill(
              accent: accentColor,
              backgroundColor: statusColor,
              color: statusColor == null ? null : Colors.black87,
              label: text,
              semanticLabel: presentation.semanticLabel,
              onTap: _openSheet,
              onTapDown: (details) => _sheetAnchor = details.globalPosition,
              icon: SizedBox(
                width: 16,
                height: 16,
                child: widget.iconAsset != null && connected
                    ? Image.asset(
                        widget.iconAsset!,
                        color: statusColor == null ? null : foregroundColor,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, size: 16, color: foregroundColor),
                      )
                    : Icon(icon, size: 16, color: foregroundColor),
              ),
            ),
          );
        }
        final iconGap = metrics?.labelIconGap ?? 4.0;
        final borderRadius = metrics?.borderRadius ?? BorderRadius.circular(20);
        final padding =
            metrics?.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
        final textStyle = (theme.textTheme.bodySmall ?? const TextStyle())
            .copyWith(
              fontSize:
                  (metrics == null ? null : 12) ??
                  theme.textTheme.bodySmall?.fontSize,
              fontWeight: FontWeight.w800,
              color:
                  (statusColor == null ? null : Colors.black87) ??
                  Color.lerp(
                    accentColor,
                    isDark ? Colors.white : theme.colorScheme.onSurface,
                    isDark ? 0.46 : 0.68,
                  ) ??
                  theme.colorScheme.onSurface,
            );

        return Semantics(
          container: true,
          liveRegion: true,
          button: true,
          label: presentation.semanticLabel,
          onTap: _openSheet,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTapDown: (d) => _sheetAnchor = d.globalPosition,
              onTap: _openSheet,
              child: ConstrainedBox(
                constraints: metrics != null
                    ? BoxConstraints(
                        minWidth: metrics.labelButtonWidth,
                        maxWidth: metrics.labelButtonWidth,
                        minHeight: metrics.tapTargetExtent,
                      )
                    : const BoxConstraints(),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    key: const ValueKey('gamepad-visual-control-surface'),
                    width: metrics?.labelButtonWidth,
                    constraints: metrics == null
                        ? null
                        : BoxConstraints(minHeight: metrics.controlHeight),
                    alignment: Alignment.center,
                    margin: metrics == null
                        ? const EdgeInsets.only(right: 6, top: 4, bottom: 4)
                        : EdgeInsets.zero,
                    padding: padding,
                    decoration: BoxDecoration(
                      color: _opacity(bgColor, widget.subdued ? 0.76 : 1),
                      borderRadius: borderRadius,
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: _opacity(
                            Colors.black,
                            widget.subdued ? 0.035 : (isDark ? 0.12 : 0.04),
                          ),
                          blurRadius: widget.subdued ? 5 : 8,
                          offset: Offset(0, widget.subdued ? 2 : 4),
                        ),
                        BoxShadow(
                          color: _opacity(Colors.white, isDark ? 0.06 : 0.16),
                          blurRadius: 10,
                          spreadRadius: 0.4,
                          blurStyle: BlurStyle.inner,
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: metrics?.iconSize ?? 16,
                            height: metrics?.iconSize ?? 16,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: widget.iconAsset == null || !connected
                                      ? Icon(icon, color: foregroundColor)
                                      : Image.asset(
                                          widget.iconAsset!,
                                          color: statusColor == null
                                              ? null
                                              : foregroundColor,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    icon,
                                                    color: foregroundColor,
                                                  ),
                                        ),
                                ),
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: bgColor,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: iconGap),
                          Text(
                            text,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: textStyle.copyWith(height: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
  const _ConnectionSheet({
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
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
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
