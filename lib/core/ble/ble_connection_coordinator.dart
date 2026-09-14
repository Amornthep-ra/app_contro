import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../connection/app_connection.dart';
import 'ble_adapter_observation.dart';
import 'ble_manager.dart';
import 'ble_pairing_store.dart';
import 'ble_permissions.dart';
import 'ble_secure_protocol.dart';

abstract interface class BleConnectionPlatform {
  Stream<List<ScanResult>> get scanResults;

  Future<void> startScan({required Duration timeout});
  Future<void> stopScan();
  Future<void> connect(ScanResult result);
  Future<void> disconnect(ScanResult result);
}

class FlutterBluePlusConnectionPlatform implements BleConnectionPlatform {
  const FlutterBluePlusConnectionPlatform();

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Future<void> startScan({required Duration timeout}) {
    return FlutterBluePlus.startScan(timeout: timeout).whenComplete(
      BleAdapterObservationBoundary.instance.recordCachedStateIfAvailable,
    );
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  @override
  Future<void> connect(ScanResult result) {
    return result.device
        .connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        )
        .whenComplete(
          BleAdapterObservationBoundary.instance.recordCachedStateIfAvailable,
        );
  }

  @override
  Future<void> disconnect(ScanResult result) => result.device.disconnect();
}

typedef BleScanPermissionCheck = Future<BleScanPermissionResult> Function();
typedef BleConnectionManagementPolicy = bool Function({int? owner});

/// The small portion of the BLE manager used by the PB2 authentication flow.
/// Keeping it separate makes the on-wire handshake testable without a device.
abstract interface class BleSecureHandshakeTransport {
  bool get isConnected;
  Stream<String> get protocolLines;

  Future<BleWriteResult> sendSystemText(String data, {required String source});
  void setSecureControlSession(BleSecureControlSession session);
  void clearSecureControlSession();
}

class BleManagerSecureHandshakeTransport
    implements BleSecureHandshakeTransport {
  const BleManagerSecureHandshakeTransport();

  BleManager get _manager => BleManager.instance;

  @override
  bool get isConnected => _manager.isConnected;

  @override
  Stream<String> get protocolLines => _manager.protocolLines;

  @override
  Future<BleWriteResult> sendSystemText(
    String data, {
    required String source,
  }) => _manager.sendSystemText(data, source: source);

  @override
  void setSecureControlSession(BleSecureControlSession session) =>
      _manager.setSecureControlSession(session);

  @override
  void clearSecureControlSession() => _manager.clearSecureControlSession();
}

enum BleControlSecurityState {
  disconnected,
  authenticating,
  pairingRequired,
  ready,
  unsupportedFirmware,
  authenticationFailed,
}

enum BlePairingFailure {
  none,
  codeMissing,
  codeRejected,
  protocolError,
  timeout,
  storageError,
}

enum BleRecoveryOutcome {
  none,
  ready,
  transientTransport,
  unsupportedProtocol,
  pairingRequired,
  credentialMismatchSuspected,
  credentialRejected,
}

class BlePairingAttemptResult {
  const BlePairingAttemptResult({required this.ready, required this.failure});

  final bool ready;
  final BlePairingFailure failure;
}

class _BleBoardProtocolError implements Exception {
  const _BleBoardProtocolError(this.code);
  final String code;
}

/// User input is required only when this board has not been paired before.
bool requiresBlePairingCode(BleControlSecurityState state) =>
    state == BleControlSecurityState.pairingRequired;

@visibleForTesting
bool shouldPersistBlePairingSecret({
  required BleConnectionCoordinatorState state,
  required String boardId,
}) =>
    state.securityState == BleControlSecurityState.ready &&
    state.boardCapabilities?.boardId == boardId;

class _AutoConnectRequest {
  _AutoConnectRequest({
    required this.deviceId,
    required this.source,
    required this.owner,
  });

  final String deviceId;
  final String source;
  final int? owner;
  final Completer<bool> completer = Completer<bool>();
  bool connecting = false;
  Timer? timeout;
}

class _ScannedDeviceEntry {
  const _ScannedDeviceEntry({required this.result, required this.lastSeen});

  final ScanResult result;
  final DateTime lastSeen;
}

@immutable
class BleConnectionCoordinatorState {
  const BleConnectionCoordinatorState({
    this.scanning = false,
    this.connecting = false,
    this.scanSecondsLeft = 0,
    this.devices = const [],
    this.lastDeviceId,
    this.lastDeviceName,
    this.failureReason,
    this.securityState = BleControlSecurityState.disconnected,
    this.pairingFailure = BlePairingFailure.none,
    this.recoveryOutcome = BleRecoveryOutcome.none,
    this.boardCapabilities,
  });

  final bool scanning;
  final bool connecting;
  final int scanSecondsLeft;
  final List<ScanResult> devices;
  final String? lastDeviceId;
  final String? lastDeviceName;
  final String? failureReason;
  final BleControlSecurityState securityState;
  final BlePairingFailure pairingFailure;
  final BleRecoveryOutcome recoveryOutcome;
  final BleBoardCapabilities? boardCapabilities;
  bool get controlReady => securityState == BleControlSecurityState.ready;

  BleConnectionCoordinatorState copyWith({
    bool? scanning,
    bool? connecting,
    int? scanSecondsLeft,
    List<ScanResult>? devices,
    String? lastDeviceId,
    String? lastDeviceName,
    String? failureReason,
    BleControlSecurityState? securityState,
    BlePairingFailure? pairingFailure,
    BleRecoveryOutcome? recoveryOutcome,
    BleBoardCapabilities? boardCapabilities,
    bool clearBoardCapabilities = false,
    bool clearFailure = false,
  }) => BleConnectionCoordinatorState(
    scanning: scanning ?? this.scanning,
    connecting: connecting ?? this.connecting,
    scanSecondsLeft: scanSecondsLeft ?? this.scanSecondsLeft,
    devices: devices ?? this.devices,
    lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    lastDeviceName: lastDeviceName ?? this.lastDeviceName,
    failureReason: clearFailure ? null : failureReason ?? this.failureReason,
    securityState: securityState ?? this.securityState,
    pairingFailure: pairingFailure ?? this.pairingFailure,
    recoveryOutcome: recoveryOutcome ?? this.recoveryOutcome,
    boardCapabilities: clearBoardCapabilities
        ? null
        : boardCapabilities ?? this.boardCapabilities,
  );
}

class BleConnectionCoordinator {
  BleConnectionCoordinator({
    BleConnectionPlatform? platform,
    BleScanPermissionCheck? ensureScanPermissions,
    BleConnectionManagementPolicy? canManageConnection,
    BlePairingStore? pairingStore,
    BleSecureHandshakeTransport? secureHandshakeTransport,
    bool? enforceSecureProtocol,
    bool? listenToManagerAutoConnectRequests,
    Stream<bool>? managerConnectionStream,
    Duration deviceTtl = const Duration(seconds: 20),
    Duration secureHandshakeTimeout = const Duration(seconds: 3),
    DateTime Function()? now,
  }) : _platform = platform ?? const FlutterBluePlusConnectionPlatform(),
       _ensureScanPermissions =
           ensureScanPermissions ?? ensureBleScanPermissions,
       _canManageConnection =
           canManageConnection ?? BleManager.instance.canManageBleConnection,
       _pairingStore = pairingStore ?? SecureBlePairingStore(),
       _secureHandshakeTransport =
           secureHandshakeTransport ??
           const BleManagerSecureHandshakeTransport(),
       _enforceSecureProtocol = enforceSecureProtocol ?? platform == null,
       _deviceTtl = deviceTtl,
       _secureHandshakeTimeout = secureHandshakeTimeout,
       _now = now ?? DateTime.now {
    final listenToManager =
        listenToManagerAutoConnectRequests ?? platform == null;
    if (listenToManager) {
      _managerAutoConnectSub = BleManager.instance.autoConnectRequests.listen(
        (request) => unawaited(_handleManagerAutoConnect(request)),
      );
    }
    if (listenToManager || managerConnectionStream != null) {
      _managerConnectionSub =
          (managerConnectionStream ?? BleManager.instance.connectionStream)
              .listen(_handleManagerConnectionChanged);
    }
  }

  static final BleConnectionCoordinator instance = BleConnectionCoordinator();

  static const _lastDeviceIdKey = 'ble_last_device_id';
  static const _lastDeviceNameKey = 'ble_last_device_name';
  static const _lastBoardIdKey = 'ble_last_board_id';
  final Duration _deviceTtl;
  final DateTime Function() _now;
  final _controller =
      StreamController<BleConnectionCoordinatorState>.broadcast();
  final BleConnectionPlatform _platform;
  final BleScanPermissionCheck _ensureScanPermissions;
  final BleConnectionManagementPolicy _canManageConnection;
  final BlePairingStore _pairingStore;
  final BleSecureHandshakeTransport _secureHandshakeTransport;
  final bool _enforceSecureProtocol;
  final Map<String, _ScannedDeviceEntry> _devices = {};
  final Duration _secureHandshakeTimeout;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BleAutoConnectRequest>? _managerAutoConnectSub;
  StreamSubscription<bool>? _managerConnectionSub;
  Timer? _scanTimeout;
  Timer? _scanStateTimer;
  Timer? _linkLossReconnectTimer;
  DateTime? _scanDeadline;
  _AutoConnectRequest? _autoConnectRequest;
  BleManagementLease? _managementLease;
  BleConnectionCoordinatorState _state = const BleConnectionCoordinatorState();
  Future<void>? _initializeFuture;
  Future<void>? _authenticationFuture;
  int _authenticationGeneration = 0;
  int _consecutiveTransientHandshakeFailures = 0;
  int _consecutiveCapabilityMismatches = 0;
  static const _handshakeResetThreshold = 2;
  static const _capabilityMismatchThreshold = 2;
  int _consumerCount = 0;
  int _linkLossReconnectAttempt = 0;
  bool _linkLossReconnectInFlight = false;
  bool _manualDisconnectInProgress = false;
  bool _automaticReconnectSuppressed = false;
  bool _pairingPromptPresentedForConnection = false;
  bool _automaticPairingPromptClaimPending = false;
  bool _disposed = false;

  BleConnectionCoordinatorState get state => _state;
  Stream<BleConnectionCoordinatorState> get stream => _controller.stream;
  int get pairingConnectionGeneration => _authenticationGeneration;

  Future<void> cancelPairing(int generation) async {
    if (generation != _authenticationGeneration || _disposed) return;
    _authenticationGeneration++;
    _authenticationFuture = null;
    await disconnect();
  }

  void _emit(BleConnectionCoordinatorState state) {
    BleManager.instance.setSecurePairingPending(
      state.securityState == BleControlSecurityState.authenticating ||
          state.securityState == BleControlSecurityState.pairingRequired ||
          state.securityState == BleControlSecurityState.authenticationFailed ||
          state.securityState == BleControlSecurityState.unsupportedFirmware,
    );
    _state = state;
    _controller.add(state);
  }

  void _debug(String event, [String detail = '']) {
    // Pairing codes, authentication tags, nonces, and session keys must never
    // be included here. Board ID is intentionally included for field triage.
    debugPrint('[PB BLE] $event${detail.isEmpty ? '' : ' $detail'}');
  }

  void _handleManagerConnectionChanged(bool connected) {
    if (connected) {
      _linkLossReconnectTimer?.cancel();
      _linkLossReconnectTimer = null;
      _linkLossReconnectAttempt = 0;
      return;
    }
    _pairingPromptPresentedForConnection = false;
    _automaticPairingPromptClaimPending = false;

    _authenticationGeneration++;
    _authenticationFuture = null;
    AppConnection.instance.setBleConnected(false);
    _secureHandshakeTransport.clearSecureControlSession();
    if (_state.connecting ||
        _manualDisconnectInProgress ||
        _automaticReconnectSuppressed ||
        _disposed) {
      return;
    }

    _emit(
      _state.copyWith(
        securityState: BleControlSecurityState.disconnected,
        clearBoardCapabilities: true,
        failureReason: 'ble_link_lost',
        recoveryOutcome: BleRecoveryOutcome.none,
      ),
    );
    _debug('link_lost', 'lastDevice=${_state.lastDeviceId ?? '-'}');
    _scheduleLinkLossReconnect();
  }

  /// Claims the one automatic pairing prompt allowed for the active BLE link.
  ///
  /// Manual Pair code actions bypass the return value but still mark the prompt
  /// as presented through [markPairingPromptPresented].
  bool claimAutomaticPairingPrompt({required bool connected}) {
    if (!connected || !requiresBlePairingCode(_state.securityState)) {
      return false;
    }
    if (_pairingPromptPresentedForConnection) return false;
    _pairingPromptPresentedForConnection = true;
    _automaticPairingPromptClaimPending = true;
    return true;
  }

  /// Prevents another automatic prompt while keeping manual Pair code enabled.
  bool get pairingPromptPresentedForConnection =>
      _pairingPromptPresentedForConnection;

  void markPairingPromptPresented() {
    _pairingPromptPresentedForConnection = true;
    _automaticPairingPromptClaimPending = false;
  }

  /// Rolls back a claim when the UI was disposed or failed before presenting
  /// the automatic pairing prompt.
  void releaseAutomaticPairingPrompt() {
    if (_automaticPairingPromptClaimPending) {
      _pairingPromptPresentedForConnection = false;
      _automaticPairingPromptClaimPending = false;
    }
  }

  Duration _linkLossReconnectDelay() {
    switch (_linkLossReconnectAttempt) {
      case 0:
        return const Duration(milliseconds: 800);
      case 1:
        return const Duration(seconds: 2);
      case 2:
        return const Duration(seconds: 4);
      default:
        return const Duration(seconds: 5);
    }
  }

  void _scheduleLinkLossReconnect() {
    if (_disposed ||
        _manualDisconnectInProgress ||
        _automaticReconnectSuppressed ||
        _state.lastDeviceId == null ||
        _state.lastDeviceId!.isEmpty ||
        _linkLossReconnectTimer != null) {
      return;
    }
    final delay = _linkLossReconnectDelay();
    _debug(
      'link_loss_reconnect_scheduled',
      'attempt=${_linkLossReconnectAttempt + 1} delayMs=${delay.inMilliseconds}',
    );
    _linkLossReconnectTimer = Timer(delay, () {
      _linkLossReconnectTimer = null;
      unawaited(_runLinkLossReconnect());
    });
  }

  Future<void> _runLinkLossReconnect() async {
    if (_disposed ||
        _manualDisconnectInProgress ||
        _automaticReconnectSuppressed ||
        _linkLossReconnectInFlight) {
      return;
    }
    _linkLossReconnectInFlight = true;
    try {
      final attempt = ++_linkLossReconnectAttempt;
      _debug('link_loss_reconnect_started', 'attempt=$attempt');
      final connected = await autoConnectLastDevice(
        timeout: const Duration(seconds: 8),
        source: 'link_loss_reconnect',
      );
      if (connected) {
        _debug(
          'link_loss_reconnect_connected',
          'security=${_state.securityState.name} board=${_state.boardCapabilities?.boardId ?? '-'}',
        );
        return;
      }
      if (_state.recoveryOutcome != BleRecoveryOutcome.transientTransport &&
          _state.recoveryOutcome != BleRecoveryOutcome.none) {
        _debug(
          'link_loss_reconnect_stopped',
          'outcome=${_state.recoveryOutcome.name}',
        );
        return;
      }
      _debug('link_loss_reconnect_failed', 'attempt=$attempt');
      _scheduleLinkLossReconnect();
    } finally {
      _linkLossReconnectInFlight = false;
    }
  }

  Future<void> _handleManagerAutoConnect(BleAutoConnectRequest request) async {
    try {
      final connected = await autoConnectLastDevice(
        timeout: request.timeout,
        source: request.source,
        owner: request.owner,
      );
      request.complete(connected);
    } catch (_) {
      request.complete(false);
    }
  }

  Future<void> initialize() => _initializeFuture ??= _loadSavedDevice();

  void acquire() {
    _consumerCount++;
  }

  Future<void> release() async {
    if (_consumerCount > 0) _consumerCount--;
    if (_consumerCount == 0) await stopScan();
  }

  Future<void> _loadSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    _emit(
      _state.copyWith(
        lastDeviceId: prefs.getString(_lastDeviceIdKey),
        lastDeviceName: prefs.getString(_lastDeviceNameKey),
      ),
    );
  }

  Future<BlePairingAttemptResult> savePairingCode(String pairingCode) async {
    final capabilities = _state.boardCapabilities;
    final secret = secretFromBlePairingCode(pairingCode);
    if (capabilities == null || secret == null) {
      _emit(
        _state.copyWith(
          failureReason: 'invalid_pairing_code',
          pairingFailure: BlePairingFailure.codeMissing,
        ),
      );
      return BlePairingAttemptResult(
        ready: false,
        failure: _state.pairingFailure,
      );
    }
    if (!_secureHandshakeTransport.isConnected) {
      _emit(
        _state.copyWith(
          failureReason: 'pairing_requires_connection',
          pairingFailure: BlePairingFailure.protocolError,
        ),
      );
      return BlePairingAttemptResult(
        ready: false,
        failure: _state.pairingFailure,
      );
    }
    if (_enforceSecureProtocol) {
      await authenticateConnectedBoard(pairingSecret: secret);
      if (!shouldPersistBlePairingSecret(
        state: _state,
        boardId: capabilities.boardId,
      )) {
        return BlePairingAttemptResult(
          ready: false,
          failure: _state.pairingFailure,
        );
      }
    } else {
      // Test transports model an already trusted board; production always
      // uses the default platform and therefore enforces v2 authentication.
      _emit(_state.copyWith(securityState: BleControlSecurityState.ready));
    }
    try {
      await _pairingStore.save(
        BlePairingRecord(boardId: capabilities.boardId, secret: secret),
      );
      final savedSecret = await _pairingStore.readSecret(capabilities.boardId);
      if (savedSecret == null || !listEquals(savedSecret, secret)) {
        throw StateError('Pairing secret read-back verification failed');
      }
      _debug('pairing_secret_saved', 'board=${capabilities.boardId}');
    } catch (_) {
      _emit(
        _state.copyWith(
          securityState: BleControlSecurityState.pairingRequired,
          failureReason: 'pairing_storage_failed',
          pairingFailure: BlePairingFailure.storageError,
          recoveryOutcome: BleRecoveryOutcome.pairingRequired,
        ),
      );
      _debug('pairing_secret_save_failed', 'board=${capabilities.boardId}');
      return const BlePairingAttemptResult(
        ready: false,
        failure: BlePairingFailure.storageError,
      );
    }
    return BlePairingAttemptResult(
      ready: _state.controlReady,
      failure: _state.pairingFailure,
    );
  }

  Future<void> authenticateConnectedBoard({List<int>? pairingSecret}) {
    final active = _authenticationFuture;
    if (active != null) return active;

    late final Future<void> authentication;
    authentication = _authenticateConnectedBoard(
      pairingSecret: pairingSecret,
      generation: _authenticationGeneration,
    );
    _authenticationFuture = authentication;
    return authentication.whenComplete(() {
      if (identical(_authenticationFuture, authentication)) {
        _authenticationFuture = null;
      }
    });
  }

  Future<void> _authenticateConnectedBoard({
    List<int>? pairingSecret,
    required int generation,
  }) async {
    final transport = _secureHandshakeTransport;
    transport.clearSecureControlSession();
    if (!transport.isConnected) {
      _emit(
        _state.copyWith(securityState: BleControlSecurityState.disconnected),
      );
      return;
    }

    _emit(
      _state.copyWith(
        securityState: BleControlSecurityState.authenticating,
        clearFailure: true,
        pairingFailure: BlePairingFailure.none,
        recoveryOutcome: BleRecoveryOutcome.none,
      ),
    );
    final appNonce = BleSecureProtocol.createNonce();
    var usedStoredSecret = false;
    try {
      final capabilitiesLine = transport.protocolLines.firstWhere(
        (line) =>
            BleSecureProtocol.parseCapabilities(line) != null ||
            BleSecureProtocol.parseError(line) != null,
      );
      final write = await transport.sendSystemText(
        BleSecureProtocol.hello(appNonce),
        source: 'secure_hello',
      );
      if (write != BleWriteResult.sent) throw StateError('secure_hello_failed');
      final line = await capabilitiesLine.timeout(_secureHandshakeTimeout);
      if (generation != _authenticationGeneration) return;
      final boardError = BleSecureProtocol.parseError(line);
      if (boardError != null) throw _BleBoardProtocolError(boardError);
      final capabilities = BleSecureProtocol.parseCapabilities(line)!;
      _emit(_state.copyWith(boardCapabilities: capabilities));
      final secret =
          pairingSecret ?? await _pairingStore.readSecret(capabilities.boardId);
      if (generation != _authenticationGeneration) return;
      usedStoredSecret = pairingSecret == null && secret != null;
      if (secret == null) {
        _debug('pairing_secret_missing', 'board=${capabilities.boardId}');
        _emit(
          _state.copyWith(
            securityState: BleControlSecurityState.pairingRequired,
            boardCapabilities: capabilities,
            failureReason: 'pairing_required',
            pairingFailure: BlePairingFailure.codeMissing,
            recoveryOutcome: BleRecoveryOutcome.pairingRequired,
          ),
        );
        return;
      }
      if (!BleSecureProtocol.verifiesBoard(
        secret: secret,
        capabilities: capabilities,
        appNonce: appNonce,
      )) {
        if (usedStoredSecret) {
          _consecutiveCapabilityMismatches++;
          if (_consecutiveCapabilityMismatches >=
              _capabilityMismatchThreshold) {
            _emit(
              _state.copyWith(
                securityState: BleControlSecurityState.pairingRequired,
                failureReason: 'stored_pairing_code_mismatch_suspected',
                pairingFailure: BlePairingFailure.codeRejected,
                recoveryOutcome: BleRecoveryOutcome.credentialMismatchSuspected,
              ),
            );
          } else {
            await _recordTransientHandshakeFailure(
              reason: 'capabilities_authentication_failed',
              forceTransportReset: true,
            );
          }
        } else {
          _emit(
            _state.copyWith(
              securityState: BleControlSecurityState.pairingRequired,
              failureReason: 'pairing_code_rejected',
              pairingFailure: BlePairingFailure.codeRejected,
              recoveryOutcome: BleRecoveryOutcome.credentialRejected,
            ),
          );
        }
        return;
      }

      final acknowledgementLine = transport.protocolLines.firstWhere(
        (line) =>
            BleSecureProtocol.parseAuthenticated(line) != null ||
            BleSecureProtocol.parseError(line) != null,
      );
      final authWrite = await transport.sendSystemText(
        BleSecureProtocol.auth(
          secret: secret,
          capabilities: capabilities,
          appNonce: appNonce,
        ),
        source: 'secure_auth',
      );
      if (authWrite != BleWriteResult.sent) {
        throw StateError('secure_auth_failed');
      }
      final acknowledgementText = await acknowledgementLine.timeout(
        _secureHandshakeTimeout,
      );
      if (generation != _authenticationGeneration) return;
      final acknowledgementError = BleSecureProtocol.parseError(
        acknowledgementText,
      );
      if (acknowledgementError != null) {
        throw _BleBoardProtocolError(acknowledgementError);
      }
      final acknowledgement = BleSecureProtocol.parseAuthenticated(
        acknowledgementText,
      )!;
      if (!BleSecureProtocol.verifiesAuthenticated(
        secret: secret,
        capabilities: capabilities,
        appNonce: appNonce,
        acknowledgement: acknowledgement,
      )) {
        await _recordTransientHandshakeFailure(
          reason: 'acknowledgement_authentication_failed',
        );
        return;
      }
      transport.setSecureControlSession(
        BleSecureProtocol.createSession(
          secret: secret,
          capabilities: capabilities,
          appNonce: appNonce,
          sessionId: acknowledgement.sessionId,
        ),
      );
      _emit(
        _state.copyWith(
          securityState: BleControlSecurityState.ready,
          boardCapabilities: capabilities,
          clearFailure: true,
          pairingFailure: BlePairingFailure.none,
          recoveryOutcome: BleRecoveryOutcome.ready,
        ),
      );
      _consecutiveTransientHandshakeFailures = 0;
      _consecutiveCapabilityMismatches = 0;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastBoardIdKey, capabilities.boardId);
      } catch (_) {
        _debug('pairing_board_id_save_failed', 'board=${capabilities.boardId}');
      }
      _debug('secure_authentication_ready', 'board=${capabilities.boardId}');
    } on TimeoutException {
      if (generation != _authenticationGeneration) return;
      await _recordTransientHandshakeFailure(
        reason: 'secure_handshake_timeout',
      );
    } on _BleBoardProtocolError catch (error) {
      if (generation != _authenticationGeneration) return;
      transport.clearSecureControlSession();
      final rejected = error.code == 'AUTH_FAILED';
      _emit(
        _state.copyWith(
          securityState: rejected
              ? (usedStoredSecret
                    ? BleControlSecurityState.pairingRequired
                    : BleControlSecurityState.authenticationFailed)
              : BleControlSecurityState.unsupportedFirmware,
          failureReason: 'board_protocol_${error.code.toLowerCase()}',
          pairingFailure: rejected
              ? BlePairingFailure.codeRejected
              : BlePairingFailure.protocolError,
          recoveryOutcome: rejected
              ? BleRecoveryOutcome.credentialRejected
              : BleRecoveryOutcome.unsupportedProtocol,
        ),
      );
      _debug('board_protocol_error', 'code=${error.code}');
    } catch (error) {
      if (generation != _authenticationGeneration) return;
      transport.clearSecureControlSession();
      await _recordTransientHandshakeFailure(
        reason: 'secure_authentication_transient',
      );
      _debug(
        'secure_authentication_failed',
        'credential=${usedStoredSecret ? 'stored' : 'entered'} '
            'retryable=true error=${error.runtimeType}',
      );
    }
  }

  Future<void> _recordTransientHandshakeFailure({
    required String reason,
    bool forceTransportReset = false,
  }) async {
    _consecutiveTransientHandshakeFailures++;
    _emit(
      _state.copyWith(
        securityState: BleControlSecurityState.unsupportedFirmware,
        failureReason: reason,
        pairingFailure: BlePairingFailure.protocolError,
        recoveryOutcome: BleRecoveryOutcome.transientTransport,
      ),
    );
    if (!forceTransportReset &&
            _consecutiveTransientHandshakeFailures < _handshakeResetThreshold ||
        !BleManager.instance.isConnected) {
      return;
    }
    _debug('secure_handshake_transport_reset', 'reason=$reason');
    _consecutiveTransientHandshakeFailures = 0;
    await BleManager.instance.disconnect(source: 'secure_handshake_reset');
  }

  bool _isRobot(ScanResult result) => result.advertisementData.serviceUuids.any(
    (uuid) => uuid.str.toLowerCase().startsWith(BleManager.uartServicePrefix),
  );

  int _secondsRemaining(DateTime now) {
    final deadline = _scanDeadline;
    if (deadline == null) return 0;
    final milliseconds = deadline.difference(now).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  bool _pruneStaleDevices(DateTime now) {
    final before = _devices.length;
    _devices.removeWhere(
      (_, entry) => now.difference(entry.lastSeen) > _deviceTtl,
    );
    return _devices.length != before;
  }

  void _updateScanState() {
    if (!_state.scanning) return;
    final now = _now();
    final devicesChanged = _pruneStaleDevices(now);
    final secondsLeft = _secondsRemaining(now);
    if (devicesChanged || secondsLeft != _state.scanSecondsLeft) {
      _emit(
        _state.copyWith(
          devices: _devices.values
              .map((entry) => entry.result)
              .toList(growable: false),
          scanSecondsLeft: secondsLeft,
        ),
      );
    }
  }

  void _startScanStateTimer() {
    _scanStateTimer?.cancel();
    _scanStateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateScanState();
    });
  }

  void _clearScanStateTimer() {
    _scanStateTimer?.cancel();
    _scanStateTimer = null;
    _scanDeadline = null;
  }

  Future<void> _stopScanTransport({bool releaseManagementLease = true}) async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    _clearScanStateTimer();
    try {
      await _platform.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    if (_state.scanning || _state.scanSecondsLeft != 0) {
      _emit(_state.copyWith(scanning: false, scanSecondsLeft: 0));
    }
    BleManager.instance.markScanStopped(source: 'ble_coordinator');
    if (releaseManagementLease) _releaseManagementLease();
  }

  void _completeAutoConnect(
    _AutoConnectRequest request,
    bool connected, {
    String? failureReason,
  }) {
    if (!identical(_autoConnectRequest, request)) return;
    _autoConnectRequest = null;
    request.timeout?.cancel();
    BleManager.instance.recordAutoConnectCompleted(
      connected ? 'connected' : (failureReason ?? 'failed'),
    );
    if (failureReason != null) {
      _emit(_state.copyWith(failureReason: failureReason));
    }
    if (!request.completer.isCompleted) {
      request.completer.complete(connected);
    }
  }

  Future<void> _failAutoConnect({
    required String failureReason,
    bool stopScan = true,
  }) async {
    final request = _autoConnectRequest;
    if (request != null) {
      _completeAutoConnect(request, false, failureReason: failureReason);
    } else {
      _emit(_state.copyWith(failureReason: failureReason));
    }
    if (stopScan) await _stopScanTransport();
  }

  Future<void> _onScanTimeout() async {
    if (_autoConnectRequest != null) {
      await _failAutoConnect(failureReason: 'last_device_not_found');
      return;
    }
    await _stopScanTransport();
  }

  Future<void> _connectAutoResult(
    ScanResult result,
    _AutoConnectRequest request,
  ) async {
    if (!identical(_autoConnectRequest, request) || request.connecting) return;
    if (!BleManager.instance.canAutoConnectForOwner(request.owner)) {
      await _failAutoConnect(failureReason: 'auto_connect_owner_invalid');
      return;
    }

    request.connecting = true;
    await stopScan(cancelAutoConnect: false, releaseManagementLease: false);
    await connect(
      result,
      source: request.source,
      preserveAutoConnect: true,
      owner: request.owner,
    );
    _completeAutoConnect(
      request,
      _state.controlReady,
      failureReason: _state.controlReady
          ? null
          : (_state.failureReason ?? 'connect_failed'),
    );
  }

  void _onScanResults(List<ScanResult> results) {
    ScanResult? autoConnectMatch;
    final now = _now();
    _pruneStaleDevices(now);
    for (final result in results) {
      if (!_isRobot(result)) continue;
      final id = result.device.remoteId.str;
      _devices[id] = _ScannedDeviceEntry(result: result, lastSeen: now);
      if (id == _autoConnectRequest?.deviceId) autoConnectMatch = result;
    }
    _emit(
      _state.copyWith(
        devices: _devices.values
            .map((entry) => entry.result)
            .toList(growable: false),
        scanSecondsLeft: _secondsRemaining(now),
      ),
    );

    final request = _autoConnectRequest;
    if (request != null && autoConnectMatch != null) {
      unawaited(_connectAutoResult(autoConnectMatch, request));
    }
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    int? owner,
  }) async {
    await initialize();
    if (!_ensureCanManageConnection(owner: owner)) return;
    if (_state.scanning || _state.connecting) return;
    if (!await _ensureManagementLease(owner: owner)) return;
    final permission = await _ensureScanPermissions();
    BleManager.instance.recordScanPermissionResult(permission);
    if (permission != BleScanPermissionResult.granted) {
      _emit(
        _state.copyWith(failureReason: 'scan_unavailable:${permission.name}'),
      );
      BleManager.instance.markScanStopped(source: 'scan_unavailable');
      _releaseManagementLease();
      return;
    }
    if (!_ensureActiveManagementLease()) return;
    // Permission prompts can outlive a Control Start. Re-check before
    // touching the scanner so management cannot race an active session.
    if (!_ensureCanManageConnection(owner: owner)) {
      _releaseManagementLease();
      return;
    }
    _devices.clear();
    _scanDeadline = _now().add(timeout);
    _emit(
      _state.copyWith(
        scanning: true,
        scanSecondsLeft: _secondsRemaining(_now()),
        devices: const [],
        clearFailure: true,
      ),
    );
    BleManager.instance.markScanning(source: 'ble_coordinator');
    await _scanSub?.cancel();
    _scanSub = _platform.scanResults.listen(
      _onScanResults,
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_failAutoConnect(failureReason: 'scan_failed:$error'));
      },
    );
    try {
      await _platform
          .startScan(timeout: timeout)
          .timeout(const Duration(seconds: 25));
      if (!_ensureActiveManagementLease()) {
        await _stopScanTransport();
        return;
      }
      _scanTimeout = Timer(timeout, () => unawaited(_onScanTimeout()));
      _startScanStateTimer();
    } catch (error) {
      await _failAutoConnect(failureReason: 'scan_failed:$error');
    }
  }

  Future<void> stopScan({
    bool cancelAutoConnect = true,
    bool releaseManagementLease = true,
  }) async {
    if (cancelAutoConnect && _autoConnectRequest != null) {
      _completeAutoConnect(
        _autoConnectRequest!,
        false,
        failureReason: 'auto_connect_cancelled',
      );
    }
    await _stopScanTransport(releaseManagementLease: releaseManagementLease);
  }

  Future<void> connect(
    ScanResult result, {
    String source = 'ble_coordinator',
    bool preserveAutoConnect = false,
    int? owner,
    bool userInitiated = true,
  }) async {
    await initialize();
    if (userInitiated) {
      _automaticReconnectSuppressed = false;
      _linkLossReconnectTimer?.cancel();
      _linkLossReconnectTimer = null;
    }
    _pairingPromptPresentedForConnection = false;
    _automaticPairingPromptClaimPending = false;
    if (!_ensureCanManageConnection(owner: owner)) return;
    if (_state.connecting) return;
    if (!await _ensureManagementLease(owner: owner)) return;
    await stopScan(
      cancelAutoConnect: !preserveAutoConnect,
      releaseManagementLease: false,
    );
    // Stopping a scan is asynchronous. A Control session may have acquired
    // ownership while it was in flight, so do not disconnect/connect after it.
    if (!_ensureCanManageConnection(owner: owner) || _state.connecting) {
      _releaseManagementLease();
      return;
    }

    var connected = false;
    _emit(
      _state.copyWith(
        connecting: true,
        clearFailure: true,
        clearBoardCapabilities: true,
        securityState: BleControlSecurityState.disconnected,
        recoveryOutcome: BleRecoveryOutcome.none,
      ),
    );
    try {
      await BleManager.instance
          .disconnect(source: '${source}_replace')
          .timeout(const Duration(seconds: 25));
      if (!_ensureActiveManagementLease()) return;
      try {
        await _platform.disconnect(result).timeout(const Duration(seconds: 25));
      } catch (_) {}
      if (!_ensureCanManageConnection(owner: owner) ||
          !_ensureActiveManagementLease()) {
        return;
      }
      BleManager.instance.markConnecting(source: source);
      await _platform.connect(result).timeout(const Duration(seconds: 25));
      if (!_ensureActiveManagementLease()) {
        try {
          await _platform
              .disconnect(result)
              .timeout(const Duration(seconds: 25));
        } catch (_) {}
        return;
      }
      BleManager.instance.setDevice(result.device);
      final ready = await BleManager.instance.discoverServices();
      if (!_ensureActiveManagementLease()) return;
      if (!ready) {
        await BleManager.instance
            .disconnect(source: 'services_missing')
            .timeout(const Duration(seconds: 25));
        _emit(_state.copyWith(failureReason: 'service_discovery_failed'));
        return;
      }
      final name = result.device.platformName.isEmpty
          ? result.device.remoteId.str
          : result.device.platformName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceIdKey, result.device.remoteId.str);
      await prefs.setString(_lastDeviceNameKey, name);
      AppConnection.instance.setBleConnected(true);
      if (_enforceSecureProtocol) {
        await authenticateConnectedBoard();
      } else {
        _emit(_state.copyWith(securityState: BleControlSecurityState.ready));
      }
      connected = _state.controlReady;
      _emit(
        _state.copyWith(
          lastDeviceId: result.device.remoteId.str,
          lastDeviceName: name,
        ),
      );
    } catch (error) {
      AppConnection.instance.setBleConnected(false);
      _emit(_state.copyWith(failureReason: 'connect_failed:$error'));
    } finally {
      if (!connected) {
        BleManager.instance.markConnectionAttemptFailed(source: source);
      }
      _emit(_state.copyWith(connecting: false));
      _releaseManagementLease();
    }
  }

  Future<void> connectLast({String source = 'ble_coordinator'}) async {
    await initialize();
    final id = _state.lastDeviceId;
    final device = id == null ? null : _devices[id]?.result;
    if (device == null) {
      _emit(_state.copyWith(failureReason: 'last_device_not_found'));
      return;
    }
    await connect(device, source: source);
  }

  Future<bool> autoConnectLastDevice({
    required Duration timeout,
    required String source,
    int? owner,
    bool userInitiated = false,
  }) async {
    await initialize();
    if (userInitiated) {
      _automaticReconnectSuppressed = false;
      _linkLossReconnectTimer?.cancel();
      _linkLossReconnectTimer = null;
    } else if (_automaticReconnectSuppressed) {
      _emit(_state.copyWith(failureReason: 'manual_disconnect'));
      return false;
    }
    if (BleManager.instance.isConnected) {
      if (_state.controlReady) return true;
      if (_enforceSecureProtocol) await authenticateConnectedBoard();
      return _state.controlReady;
    }
    if (!_ensureCanManageConnection(owner: owner)) return false;
    if (!BleManager.instance.canAutoConnectForOwner(owner)) return false;

    final id = _state.lastDeviceId;
    if (id == null || id.isEmpty) {
      _emit(_state.copyWith(failureReason: 'last_device_not_saved'));
      return false;
    }

    final active = _autoConnectRequest;
    if (active != null) {
      if (active.deviceId == id) return active.completer.future;
      _emit(_state.copyWith(failureReason: 'auto_connect_busy'));
      return false;
    }

    if (_state.connecting) {
      _emit(_state.copyWith(failureReason: 'auto_connect_busy'));
      return false;
    }

    final request = _AutoConnectRequest(
      deviceId: id,
      source: source,
      owner: owner,
    );
    _autoConnectRequest = request;
    BleManager.instance.recordAutoConnectStarted(id);
    request.timeout = Timer(timeout, () {
      if (identical(_autoConnectRequest, request)) {
        unawaited(_failAutoConnect(failureReason: 'last_device_not_found'));
      }
    });

    _pruneStaleDevices(_now());
    final cached = _devices[id]?.result;
    if (cached != null) {
      unawaited(_connectAutoResult(cached, request));
      return request.completer.future;
    }

    await startScan(timeout: timeout, owner: owner);
    if (identical(_autoConnectRequest, request) && !_state.scanning) {
      _completeAutoConnect(
        request,
        false,
        failureReason: _state.failureReason ?? 'scan_failed',
      );
    }
    return request.completer.future;
  }

  /// Acquires the binary control channel only when the user explicitly starts
  /// controlling, then connects the remembered device when necessary.
  Future<int?> acquireControlForStart({
    required String ownerName,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final manager = BleManager.instance;
    if (manager.controlSuspendedForLifecycle) {
      return manager.resumeControl(ownerName: ownerName);
    }

    final owner = await manager.claimControlTrafficModeAfterManagement(
      ownerName: ownerName,
    );
    if (owner == null) return null;

    manager.enableControlReconnect(owner: owner, ownerName: ownerName);
    final connected =
        (manager.isConnected && _state.controlReady) ||
        await autoConnectLastDevice(
          timeout: timeout,
          source: 'control_start',
          owner: owner,
          userInitiated: true,
        );
    if (connected && manager.isConnected && _state.controlReady) {
      // Reconnect is only permitted while acquiring this Start request. Once
      // control is live, a link loss must end the session instead of resuming.
      manager.disableControlReconnect(owner);
      return owner;
    }

    await manager.stopAndReleaseControl(owner: owner, source: 'control_start');
    if (manager.isConnected && !_state.controlReady) {
      _emit(_state.copyWith(failureReason: 'secure_control_required'));
    }
    return null;
  }

  Future<void> disconnect({int? owner}) async {
    if (!_ensureCanManageConnection(owner: owner)) return;
    if (!await _ensureManagementLease(owner: owner)) return;
    _automaticReconnectSuppressed = true;
    _pairingPromptPresentedForConnection = false;
    _automaticPairingPromptClaimPending = false;
    _manualDisconnectInProgress = true;
    _linkLossReconnectTimer?.cancel();
    _linkLossReconnectTimer = null;
    _linkLossReconnectAttempt = 0;
    try {
      await stopScan(releaseManagementLease: false);
      if (!_ensureCanManageConnection(owner: owner)) return;
      await BleManager.instance.disconnect();
      AppConnection.instance.setBleConnected(false);
      _emit(
        _state.copyWith(
          securityState: BleControlSecurityState.disconnected,
          clearFailure: true,
          clearBoardCapabilities: true,
        ),
      );
    } finally {
      _manualDisconnectInProgress = false;
      _releaseManagementLease();
    }
  }

  bool _ensureCanManageConnection({int? owner}) {
    if (_canManageConnection(owner: owner)) return true;
    _emit(_state.copyWith(failureReason: 'ble_busy_in_control'));
    return false;
  }

  Future<bool> _ensureManagementLease({int? owner}) async {
    final current = _managementLease;
    if (current != null && current.isActive) return true;
    final lease = await BleManager.instance.acquireManagementLease(
      owner: owner,
    );
    if (lease == null) {
      _emit(_state.copyWith(failureReason: 'ble_busy_in_control'));
      return false;
    }
    _managementLease = lease;
    return true;
  }

  bool _ensureActiveManagementLease() {
    final lease = _managementLease;
    if (lease != null && lease.isActive) return true;
    _managementLease = null;
    _emit(_state.copyWith(failureReason: 'management_timeout'));
    return false;
  }

  void _releaseManagementLease() {
    _managementLease?.release();
    _managementLease = null;
  }

  Future<void> forgetLastDevice() async {
    _linkLossReconnectTimer?.cancel();
    _linkLossReconnectTimer = null;
    _automaticReconnectSuppressed = true;
    _pairingPromptPresentedForConnection = false;
    _automaticPairingPromptClaimPending = false;
    _linkLossReconnectAttempt = 0;
    _authenticationGeneration++;
    _consecutiveCapabilityMismatches = 0;
    _manualDisconnectInProgress = true;
    try {
      if (_autoConnectRequest != null) {
        _completeAutoConnect(
          _autoConnectRequest!,
          false,
          failureReason: 'device_forgotten',
        );
      }
      await stopScan(cancelAutoConnect: false);
      _secureHandshakeTransport.clearSecureControlSession();
      if (BleManager.instance.isConnected) {
        await BleManager.instance.disconnect(source: 'manual_disconnect');
      }

      final prefs = await SharedPreferences.getInstance();
      final boardId =
          _state.boardCapabilities?.boardId ?? prefs.getString(_lastBoardIdKey);
      if (boardId != null && boardId.isNotEmpty) {
        await _pairingStore.remove(boardId);
        _debug('pairing_secret_forgotten', 'board=$boardId');
      }
      await prefs.remove(_lastDeviceIdKey);
      await prefs.remove(_lastDeviceNameKey);
      await prefs.remove(_lastBoardIdKey);
      _emit(
        _state.copyWith(
          lastDeviceId: '',
          lastDeviceName: '',
          securityState: BleControlSecurityState.disconnected,
          clearBoardCapabilities: true,
          recoveryOutcome: BleRecoveryOutcome.none,
        ),
      );
    } finally {
      _manualDisconnectInProgress = false;
    }
  }

  @visibleForTesting
  void pruneStaleDevices() {
    _updateScanState();
  }

  @visibleForTesting
  void debugEmitForTesting(BleConnectionCoordinatorState state) => _emit(state);

  @visibleForTesting
  Future<void> dispose() async {
    _disposed = true;
    _authenticationGeneration++;
    BleManager.instance.setSecurePairingPending(false);
    _linkLossReconnectTimer?.cancel();
    await stopScan();
    await _managerAutoConnectSub?.cancel();
    await _managerConnectionSub?.cancel();
    await _controller.close();
  }
}
