// lib/core/widgets/connection_status_badge.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'gamepad_control_toolbar.dart';
import '../ui/language_controller.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_connection_coordinator.dart';
import '../ble/ble_presentation_state.dart';
import '../../features/bluetooth/widgets/pairing_code_dialog.dart';
import 'ble_connection_sheet.dart';
import 'ble_presentation_icon.dart';
import 'gamepad_app_bar.dart';

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
      builder: (context) => BleConnectionSheet(
        onPairingRequested: _requestSheetPairing,
        coordinator: _bleCoordinator,
        isBleConnected: () => _isBleConnected,
        enableBlePlatformBindings: widget.enableBlePlatformBindings,
        presentationState: _presentationState,
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
                  child: BleConnectionSheet(
                    onPairingRequested: _requestSheetPairing,
                    coordinator: _bleCoordinator,
                    isBleConnected: () => _isBleConnected,
                    enableBlePlatformBindings: widget.enableBlePlatformBindings,
                    presentationState: _presentationState,
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
        final controlLayout = GamepadControlScope.of(context);
        if (controlLayout != null) {
          return Semantics(
            liveRegion: true,
            child: GamepadControlPill(
              accent: accentColor,
              backgroundColor: statusColor,
              color: statusColor == null ? null : Colors.black87,
              label: controlLayout.compactBle ? presentation.shortLabel : text,
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
