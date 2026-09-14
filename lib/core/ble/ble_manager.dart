//lib/core/ble/ble_manager.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_secure_protocol.dart';
import 'ble_permissions.dart';
import 'joystick_packet.dart';

enum BleTrafficMode { textCommand, controlBinary }

enum BleReconnectMode { disabled, controlActive }

typedef BleControlFrameWriter =
    Future<void> Function(List<int> bytes, {required bool withoutResponse});

class BleManagementLease {
  BleManagementLease._(this._manager, this._id);

  final BleManager _manager;
  final int _id;
  bool _released = false;

  bool get isActive => !_released;

  void release() {
    if (_released) return;
    _released = true;
    _manager._releaseManagementLease(_id);
  }

  void _invalidate() => _released = true;
}

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  discovering,
  subscribing,
  connected,
  reconnecting,
  reconnectFailed,
  disconnecting,
}

bool isBleStatusConnected(BleConnectionStatus status) {
  return status == BleConnectionStatus.connected;
}

bool isBleStatusBusy(BleConnectionStatus status) {
  return status == BleConnectionStatus.scanning ||
      status == BleConnectionStatus.connecting ||
      status == BleConnectionStatus.discovering ||
      status == BleConnectionStatus.subscribing ||
      status == BleConnectionStatus.reconnecting ||
      status == BleConnectionStatus.disconnecting;
}

bool isBleStatusFailed(BleConnectionStatus status) {
  return status == BleConnectionStatus.reconnectFailed;
}

@visibleForTesting
bool shouldMarkBleScanning(BleConnectionStatus currentStatus) {
  return currentStatus == BleConnectionStatus.disconnected ||
      currentStatus == BleConnectionStatus.reconnectFailed ||
      currentStatus == BleConnectionStatus.scanning;
}

@visibleForTesting
BleConnectionStatus? statusAfterBleScanStopped(
  BleConnectionStatus currentStatus,
) {
  return currentStatus == BleConnectionStatus.scanning
      ? BleConnectionStatus.disconnected
      : null;
}

@visibleForTesting
BleConnectionStatus? statusAfterBleConnectionAttemptFailed({
  required BleConnectionStatus currentStatus,
  required bool reconnectActive,
}) {
  switch (currentStatus) {
    case BleConnectionStatus.connecting:
    case BleConnectionStatus.discovering:
    case BleConnectionStatus.subscribing:
      return reconnectActive
          ? BleConnectionStatus.reconnecting
          : BleConnectionStatus.disconnected;
    case BleConnectionStatus.disconnected:
    case BleConnectionStatus.scanning:
    case BleConnectionStatus.connected:
    case BleConnectionStatus.reconnecting:
    case BleConnectionStatus.reconnectFailed:
    case BleConnectionStatus.disconnecting:
      return null;
  }
}

@visibleForTesting
bool shouldSuspendBleControlForLifecycle(AppLifecycleState state) {
  return state == AppLifecycleState.inactive ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached;
}

@visibleForTesting
bool shouldRequireExplicitControlResume({
  required bool controlWasSuspended,
  required AppLifecycleState state,
}) {
  return controlWasSuspended && state == AppLifecycleState.resumed;
}

@visibleForTesting
String bleDiscoveryTimeoutReason(BleConnectionStatus status) {
  return status == BleConnectionStatus.discovering
      ? 'service_discovery_timeout'
      : 'notification_subscribe_timeout';
}

enum BleWriteIntentKind { text, joystick, stop }

enum BleWriteResult { sent, dropped, blocked, notConnected, failed }

class BleAutoConnectRequest {
  BleAutoConnectRequest({
    required this.timeout,
    required this.source,
    required this.owner,
  });

  final Duration timeout;
  final String source;
  final int? owner;
  final Completer<bool> _result = Completer<bool>();

  Future<bool> get result => _result.future;

  void complete(bool connected) {
    if (!_result.isCompleted) _result.complete(connected);
  }
}

@visibleForTesting
BleWriteResult combineBleWriteResults(Iterable<BleWriteResult> results) {
  if (results.contains(BleWriteResult.failed)) return BleWriteResult.failed;
  if (results.contains(BleWriteResult.dropped)) return BleWriteResult.dropped;
  return BleWriteResult.sent;
}

enum BleNotificationMode { none, notify, indicate }

enum BleDisconnectReason {
  manual,
  transportFailure,
  remoteDisconnected,
  permissionDenied,
  bluetoothOff,
  locationServiceOff,
}

@immutable
class BleDiagnosticsSnapshot {
  const BleDiagnosticsSnapshot({
    required this.deviceName,
    required this.deviceId,
    required this.connectionStatus,
    required this.trafficMode,
    required this.trafficOwnerName,
    required this.mtu,
    required this.payloadSize,
    required this.writeCharacteristic,
    required this.readCharacteristic,
    required this.notificationMode,
    required this.lastTxAge,
    required this.lastRxAge,
    required this.reconnectAttempt,
    required this.lastFailureReason,
    required this.lastFailureAge,
    required this.lastDisconnectReason,
    required this.lastDisconnectAge,
    required this.lastScanPermissionResult,
    this.autoConnectTargetId,
    this.autoConnectOperationAge,
    this.lastAutoConnectOutcome,
  });

  final String? deviceName;
  final String? deviceId;
  final BleConnectionStatus connectionStatus;
  final BleTrafficMode trafficMode;
  final String trafficOwnerName;
  final int? mtu;
  final int payloadSize;
  final BleCharacteristicSpec? writeCharacteristic;
  final BleCharacteristicSpec? readCharacteristic;
  final BleNotificationMode notificationMode;
  final Duration? lastTxAge;
  final Duration? lastRxAge;
  final int reconnectAttempt;
  final String? lastFailureReason;
  final Duration? lastFailureAge;
  final BleDisconnectReason? lastDisconnectReason;
  final Duration? lastDisconnectAge;
  final BleScanPermissionResult? lastScanPermissionResult;
  final String? autoConnectTargetId;
  final Duration? autoConnectOperationAge;
  final String? lastAutoConnectOutcome;
}

String formatBleDiagnostics(BleDiagnosticsSnapshot value) {
  String spec(BleCharacteristicSpec? item) =>
      item == null ? '-' : '${item.uuid} (${item.propertySummary})';
  return [
    'BLE diagnostics',
    'device=${value.deviceName ?? '-'} id=${value.deviceId ?? '-'}',
    'status=${value.connectionStatus.name}',
    'traffic=${value.trafficMode.name} owner=${value.trafficOwnerName}',
    'mtu=${value.mtu ?? '-'} payload=${value.payloadSize}',
    'write=${spec(value.writeCharacteristic)}',
    'read=${spec(value.readCharacteristic)} notification=${value.notificationMode.name}',
    'reconnectAttempt=${value.reconnectAttempt}',
    'lastFailure=${value.lastFailureReason ?? '-'}',
    'lastDisconnect=${value.lastDisconnectReason?.name ?? '-'}',
    'lastScanPermission=${value.lastScanPermissionResult?.name ?? '-'}',
    'autoConnectTarget=${value.autoConnectTargetId ?? '-'}',
    'autoConnectAge=${value.autoConnectOperationAge?.inMilliseconds ?? '-'}ms',
    'lastAutoConnect=${value.lastAutoConnectOutcome ?? '-'}',
  ].join('\n');
}

@visibleForTesting
List<BleWriteIntentKind> applyBleWriteQueuePolicy(
  List<BleWriteIntentKind> intents,
) {
  final text = <BleWriteIntentKind>[];
  final stops = <BleWriteIntentKind>[];
  var joystickPending = false;

  for (final intent in intents) {
    switch (intent) {
      case BleWriteIntentKind.text:
        text.add(intent);
      case BleWriteIntentKind.stop:
        text.clear();
        joystickPending = false;
        stops.add(intent);
      case BleWriteIntentKind.joystick:
        joystickPending = true;
    }
  }

  final output = <BleWriteIntentKind>[...stops, ...text];
  if (joystickPending) {
    output.add(BleWriteIntentKind.joystick);
  }
  return output;
}

@visibleForTesting
bool shouldSendControlStopOnDisconnect({
  required BleTrafficMode mode,
  required bool connected,
}) {
  return connected && mode == BleTrafficMode.controlBinary;
}

@visibleForTesting
bool shouldSuppressReconnectDuringDisconnect(String source) {
  return source == 'manual_disconnect' || source.endsWith('_replace');
}

@visibleForTesting
bool shouldRefreshHeartbeatOnModeRelease({
  required BleTrafficMode previousMode,
  required BleTrafficMode fallback,
  required bool connected,
}) {
  return connected &&
      previousMode == BleTrafficMode.controlBinary &&
      fallback == BleTrafficMode.textCommand;
}

@visibleForTesting
bool shouldBlockTrafficModeClaim({
  required BleTrafficMode currentMode,
  required BleTrafficMode requestedMode,
  bool controlSuspendedForLifecycle = false,
}) {
  return currentMode == BleTrafficMode.controlBinary ||
      (controlSuspendedForLifecycle &&
          requestedMode == BleTrafficMode.controlBinary);
}

@visibleForTesting
bool canManageBleConnectionRequest({
  required BleTrafficMode trafficMode,
  required int? requestOwner,
  required int activeOwner,
}) {
  return trafficMode != BleTrafficMode.controlBinary ||
      (requestOwner != null && requestOwner == activeOwner);
}

@visibleForTesting
Future<void> runEmergencyStopOperation({
  required bool isOwnerActive,
  required bool isConnected,
  required bool controlSuspendedForLifecycle,
  required Future<void> Function(int repeats) sendZeroFrames,
  required VoidCallback disableReconnect,
  required VoidCallback releaseOwner,
  int repeats = BleManager.emergencyStopRepeats,
}) async {
  if (!isOwnerActive) return;

  disableReconnect();
  try {
    if (isConnected && !controlSuspendedForLifecycle) {
      await sendZeroFrames(repeats);
    }
  } finally {
    releaseOwner();
  }
}

/// Sends the zero-valued binary control frame through an injected transport.
///
/// Keeping this small seam outside [BleManager] makes the emergency packet
/// sequence verifiable without a Bluetooth radio while production still uses
/// the characteristic writer below.
Future<int> writeControlStopFrames({
  required BleControlFrameWriter writeFrame,
  required List<int> Function(int repeat) buildBytes,
  required int repeats,
  required Duration timeout,
  bool supportsWrite = true,
  bool supportsWriteWithoutResponse = true,
  Duration repeatDelay = const Duration(milliseconds: 20),
  void Function(int repeat, bool acknowledged)? onFrameSent,
  Future<void> Function(int repeat, Object error)? onFrameFailed,
  void Function(int repeat, Object error)? onAcknowledgedWriteFailed,
}) async {
  if (!supportsWrite && !supportsWriteWithoutResponse) {
    throw ArgumentError('The characteristic does not support writes');
  }
  final count = repeats.clamp(1, 5);
  var sent = 0;
  for (var index = 0; index < count; index++) {
    final repeat = index + 1;
    final bytes = buildBytes(repeat);
    try {
      await writeFrame(bytes, withoutResponse: !supportsWrite).timeout(timeout);
      sent++;
      onFrameSent?.call(repeat, supportsWrite);
    } catch (error) {
      if (!supportsWrite || !supportsWriteWithoutResponse) {
        await onFrameFailed?.call(repeat, error);
      } else {
        onAcknowledgedWriteFailed?.call(repeat, error);
        try {
          // A timed-out acknowledged write may still have reached the board.
          // Build a fresh secure frame so the fallback cannot replay its sequence.
          final fallbackBytes = buildBytes(repeat);
          await writeFrame(
            fallbackBytes,
            withoutResponse: true,
          ).timeout(timeout);
          sent++;
          onFrameSent?.call(repeat, false);
        } catch (fallbackError) {
          await onFrameFailed?.call(repeat, fallbackError);
        }
      }
    }
    if (index < count - 1 && repeatDelay > Duration.zero) {
      await Future<void>.delayed(repeatDelay);
    }
  }
  return sent;
}

List<int> buildZeroControlPacket() {
  return JoystickPacket(
    lx: 0,
    ly: 0,
    rx: 0,
    ry: 0,
  ).toBinaryPacket(const <int>{});
}

@visibleForTesting
bool shouldTriggerWriteTransportFailure({
  required int consecutiveFailures,
  int threshold = 2,
}) {
  return consecutiveFailures >= threshold;
}

@visibleForTesting
bool shouldMonitorHeartbeatRx(
  BleTrafficMode mode, {
  bool isSecureControlReady = false,
}) {
  // The control protocol is write-only; a quiet notification stream is normal.
  // Authenticated PB2 also stays quiet before Start and after Stop.
  return !isSecureControlReady && mode == BleTrafficMode.textCommand;
}

@visibleForTesting
bool shouldStopControlReconnectForScanPermission(
  BleScanPermissionResult? result,
) {
  return result != null && result != BleScanPermissionResult.granted;
}

@visibleForTesting
BleDisconnectReason? disconnectReasonForScanPermission(
  BleScanPermissionResult? result,
) {
  switch (result) {
    case BleScanPermissionResult.permissionDenied:
      return BleDisconnectReason.permissionDenied;
    case BleScanPermissionResult.bluetoothOff:
      return BleDisconnectReason.bluetoothOff;
    case BleScanPermissionResult.locationServiceOff:
      return BleDisconnectReason.locationServiceOff;
    case BleScanPermissionResult.granted:
    case null:
      return null;
  }
}

@visibleForTesting
bool shouldReconnectAfterTransportFailure({
  required BleTrafficMode trafficMode,
  required BleReconnectMode reconnectMode,
  required bool reconnectOwnerActive,
  required bool manualDisconnectInProgress,
}) {
  return trafficMode == BleTrafficMode.controlBinary &&
      reconnectMode == BleReconnectMode.controlActive &&
      reconnectOwnerActive &&
      !manualDisconnectInProgress;
}

@visibleForTesting
int blePayloadSizeFromMtu(int? mtu, {int fallback = 20}) {
  if (mtu == null) return fallback;
  final payloadSize = mtu - 3;
  return payloadSize > 0 ? payloadSize : fallback;
}

@visibleForTesting
List<List<int>> chunkBleTextPayload(String data, {required int payloadSize}) {
  final safePayloadSize = payloadSize > 0 ? payloadSize : 20;
  final bytes = '$data\n'.codeUnits;
  final chunks = <List<int>>[];

  for (var start = 0; start < bytes.length; start += safePayloadSize) {
    final end = start + safePayloadSize;
    chunks.add(bytes.sublist(start, end > bytes.length ? bytes.length : end));
  }

  return chunks;
}

@visibleForTesting
class BleCharacteristicSpec {
  const BleCharacteristicSpec({
    required this.uuid,
    this.read = false,
    this.write = false,
    this.writeWithoutResponse = false,
    this.notify = false,
    this.indicate = false,
  });

  final String uuid;
  final bool read;
  final bool write;
  final bool writeWithoutResponse;
  final bool notify;
  final bool indicate;

  bool get canWrite => write || writeWithoutResponse;

  bool useWithoutResponse({bool preferAcknowledged = false}) {
    if (!canWrite) {
      throw StateError('The characteristic does not support writes');
    }
    return writeWithoutResponse && (!preferAcknowledged || !write);
  }

  bool get canReceive => notify || indicate;

  String get normalizedUuid => uuid.toLowerCase();

  String get propertySummary {
    final props = <String>[];
    if (read) props.add('read');
    if (write) props.add('write');
    if (writeWithoutResponse) props.add('writeWithoutResponse');
    if (notify) props.add('notify');
    if (indicate) props.add('indicate');
    return props.isEmpty ? 'none' : props.join(',');
  }
}

@visibleForTesting
class BleUartCharacteristicSelection {
  const BleUartCharacteristicSelection({
    this.write,
    this.read,
    this.failureReason,
  });

  final BleCharacteristicSpec? write;
  final BleCharacteristicSpec? read;
  final String? failureReason;

  bool get isValid => write != null && read != null && failureReason == null;
}

@visibleForTesting
BleUartCharacteristicSelection selectUartCharacteristics(
  List<BleCharacteristicSpec> characteristics, {
  String writeUuidPrefix = BleManager.uartRxPrefix,
  String readUuidPrefix = BleManager.uartTxPrefix,
}) {
  final write = _selectUartCharacteristic(
    characteristics,
    preferredUuidPrefix: writeUuidPrefix,
    canUse: (c) => c.canWrite,
    role: 'write',
  );
  if (write.failureReason != null) {
    return BleUartCharacteristicSelection(failureReason: write.failureReason);
  }

  final read = _selectUartCharacteristic(
    characteristics,
    preferredUuidPrefix: readUuidPrefix,
    canUse: (c) => c.canReceive,
    role: 'read',
  );
  if (read.failureReason != null) {
    return BleUartCharacteristicSelection(failureReason: read.failureReason);
  }

  return BleUartCharacteristicSelection(write: write.spec, read: read.spec);
}

_BleCharacteristicPick _selectUartCharacteristic(
  List<BleCharacteristicSpec> characteristics, {
  required String preferredUuidPrefix,
  required bool Function(BleCharacteristicSpec characteristic) canUse,
  required String role,
}) {
  final candidates = characteristics.where(canUse).toList(growable: false);
  final preferred = candidates
      .where((c) => c.normalizedUuid.startsWith(preferredUuidPrefix))
      .toList(growable: false);

  if (preferred.length == 1) {
    return _BleCharacteristicPick(spec: preferred.single);
  }
  if (preferred.length > 1) {
    return _BleCharacteristicPick(
      failureReason: 'ambiguous_${role}_preferred_uuid',
    );
  }
  if (candidates.length == 1) {
    return _BleCharacteristicPick(spec: candidates.single);
  }
  if (candidates.isEmpty) {
    return _BleCharacteristicPick(failureReason: '${role}_not_found');
  }
  return _BleCharacteristicPick(failureReason: 'ambiguous_${role}_fallback');
}

class _BleCharacteristicPick {
  const _BleCharacteristicPick({this.spec, this.failureReason});

  final BleCharacteristicSpec? spec;
  final String? failureReason;
}

class _BleQueuedWrite {
  _BleQueuedWrite({required this.kind, required this.task});

  final BleWriteIntentKind kind;
  final Future<BleWriteResult> Function() task;
  final Completer<BleWriteResult> completer = Completer<BleWriteResult>();
}

class BleManager {
  /// Number of zero-value control frames sent for a user-triggered emergency
  /// stop. Repeating the frame improves delivery reliability over BLE.
  static const int emergencyStopRepeats = 3;

  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<BleConnectionStatus> _statusController =
      StreamController<BleConnectionStatus>.broadcast();
  final StreamController<BleDiagnosticsSnapshot> _diagnosticsController =
      StreamController<BleDiagnosticsSnapshot>.broadcast();
  final StreamController<String> _protocolLineController =
      StreamController<String>.broadcast();
  final StringBuffer _protocolLineBuffer = StringBuffer();
  BleSecureControlSession? _secureControlSession;

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;
  Stream<BleDiagnosticsSnapshot> get diagnosticsStream =>
      _diagnosticsController.stream;
  Stream<String> get protocolLines => _protocolLineController.stream;
  bool get isSecureControlReady => _secureControlSession != null;
  bool _securePairingPending = false;

  void setSecurePairingPending(bool pending) {
    if (_securePairingPending == pending) return;
    _securePairingPending = pending;
    _lastRxTime = DateTime.now();
  }

  void setSecureControlSession(BleSecureControlSession session) {
    _clearSecureControlSession();
    _secureControlSession = session;
    _log('secure_control_ready', 'board=${session.boardId}');
  }

  void clearSecureControlSession() => _clearSecureControlSession();

  void _clearSecureControlSession() {
    _securePairingPending = false;
    _secureControlSession?.dispose();
    _secureControlSession = null;
  }

  void _recordProtocolBytes(List<int> data) {
    if (data.any((byte) => byte != 10 && (byte < 32 || byte > 126))) return;
    final text = String.fromCharCodes(data);
    _protocolLineBuffer.write(text);
    final buffered = _protocolLineBuffer.toString();
    final lines = buffered.split('\n');
    _protocolLineBuffer
      ..clear()
      ..write(lines.removeLast());
    for (final line in lines) {
      if (line.isNotEmpty && !_protocolLineController.isClosed) {
        _protocolLineController.add(line.trim());
      }
    }
  }

  bool get isConnected => _device != null && _tx != null && _rx != null;

  String? get currentDeviceName => _device?.platformName;
  String? get currentDeviceId => _device?.remoteId.str;
  BleTrafficMode get trafficMode => _trafficMode;
  bool get isControlSessionActive =>
      _trafficMode == BleTrafficMode.controlBinary;
  BleConnectionStatus get connectionStatus => _connectionStatus;
  BleDiagnosticsSnapshot get diagnostics {
    final now = DateTime.now();
    return BleDiagnosticsSnapshot(
      deviceName: currentDeviceName,
      deviceId: currentDeviceId,
      connectionStatus: _connectionStatus,
      trafficMode: _trafficMode,
      trafficOwnerName: _trafficModeOwnerName,
      mtu: _mtu,
      payloadSize: _payloadSize,
      writeCharacteristic: _writeCharacteristicSpec,
      readCharacteristic: _readCharacteristicSpec,
      notificationMode: _notificationMode,
      lastTxAge: _lastTxTime == null ? null : now.difference(_lastTxTime!),
      lastRxAge: _lastRxTime == null ? null : now.difference(_lastRxTime!),
      reconnectAttempt: _reconnectAttempt,
      lastFailureReason: _lastFailureReason,
      lastFailureAge: _lastFailureAt == null
          ? null
          : now.difference(_lastFailureAt!),
      lastDisconnectReason: _lastDisconnectReason,
      lastDisconnectAge: _lastDisconnectAt == null
          ? null
          : now.difference(_lastDisconnectAt!),
      lastScanPermissionResult: _lastScanPermissionResult,
      autoConnectTargetId: _autoConnectTargetId,
      autoConnectOperationAge: _autoConnectStartedAt == null
          ? null
          : now.difference(_autoConnectStartedAt!),
      lastAutoConnectOutcome: _lastAutoConnectOutcome,
    );
  }

  static const uartServicePrefix = "6e400001";
  static const uartRxPrefix = "6e400002";
  static const uartTxPrefix = "6e400003";

  Timer? _heartbeatTimer;
  DateTime? _lastRxTime;
  DateTime? _lastTxTime;
  StreamSubscription<List<int>>? _txSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _reconnectTimer;
  final _autoConnectRequestController =
      StreamController<BleAutoConnectRequest>.broadcast();
  bool _manualDisconnectInProgress = false;
  int _nextManagementLeaseId = 0;
  int? _managementLeaseId;
  Completer<void>? _managementLeaseReleased;
  BleManagementLease? _activeManagementLease;
  Timer? _managementLeaseTimer;
  BleTrafficMode _trafficMode = BleTrafficMode.textCommand;
  int _trafficModeOwner = 0;
  String _trafficModeOwnerName = 'none';
  BleReconnectMode _reconnectMode = BleReconnectMode.disabled;
  int? _reconnectOwner;
  int _reconnectAttempt = 0;
  DateTime? _reconnectDeadline;
  BleConnectionStatus _connectionStatus = BleConnectionStatus.disconnected;
  int? _mtu;
  BleCharacteristicSpec? _writeCharacteristicSpec;
  BleCharacteristicSpec? _readCharacteristicSpec;
  BleNotificationMode _notificationMode = BleNotificationMode.none;
  String? _lastFailureReason;
  DateTime? _lastFailureAt;
  BleDisconnectReason? _lastDisconnectReason;
  DateTime? _lastDisconnectAt;
  BleScanPermissionResult? _lastScanPermissionResult;
  String? _autoConnectTargetId;
  DateTime? _autoConnectStartedAt;
  String? _lastAutoConnectOutcome;

  static const Duration _heartbeatInterval = Duration(seconds: 2);
  static const Duration _heartbeatTimeout = Duration(seconds: 5);
  static const Duration _stopFrameTimeout = Duration(milliseconds: 200);
  static const Duration _textWriteTimeout = Duration(milliseconds: 500);
  static const Duration _binaryWriteTimeout = Duration(milliseconds: 200);
  static const Duration _serviceDiscoveryTimeout = Duration(seconds: 10);
  static const Duration _notificationSubscribeTimeout = Duration(seconds: 5);
  static const int _writeFailureThreshold = 2;

  final Queue<_BleQueuedWrite> _textWriteQueue = Queue<_BleQueuedWrite>();
  final Queue<_BleQueuedWrite> _stopWriteQueue = Queue<_BleQueuedWrite>();
  _BleQueuedWrite? _pendingJoystickWrite;
  bool _writePumpRunning = false;
  int _payloadSize = 20;

  DateTime _lastJoySend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRateLimitLog = DateTime.fromMillisecondsSinceEpoch(0);
  int _writeFailureCount = 0;
  bool _transportFailureHandling = false;
  bool _controlSuspendedForLifecycle = false;
  final ValueNotifier<bool> _controlSuspendedController = ValueNotifier(false);

  bool get controlSuspendedForLifecycle => _controlSuspendedForLifecycle;
  ValueListenable<bool> get controlSuspendedListenable =>
      _controlSuspendedController;
  Stream<BleAutoConnectRequest> get autoConnectRequests =>
      _autoConnectRequestController.stream;

  Future<bool> _requestAutoConnect({
    Duration timeout = const Duration(seconds: 8),
    required String source,
    int? owner,
  }) {
    if (!_autoConnectRequestController.hasListener) {
      _log('auto_connect_unavailable', 'source=$source');
      return Future.value(false);
    }
    final request = BleAutoConnectRequest(
      timeout: timeout,
      source: source,
      owner: owner,
    );
    _autoConnectRequestController.add(request);
    return request.result;
  }

  @visibleForTesting
  Future<bool> requestAutoConnectForTesting({
    Duration timeout = const Duration(seconds: 8),
    String source = 'test',
    int? owner,
  }) => _requestAutoConnect(timeout: timeout, source: source, owner: owner);

  void _setControlSuspended(bool value) {
    _controlSuspendedForLifecycle = value;
    _controlSuspendedController.value = value;
    _emitDiagnostics();
  }

  void _emitDiagnostics() {
    if (!_diagnosticsController.isClosed) {
      _diagnosticsController.add(diagnostics);
    }
  }

  void recordScanPermissionResult(BleScanPermissionResult result) {
    _lastScanPermissionResult = result;
    _emitDiagnostics();
  }

  void recordAutoConnectStarted(String targetId) {
    _autoConnectTargetId = targetId;
    _autoConnectStartedAt = DateTime.now();
    _lastAutoConnectOutcome = null;
    _emitDiagnostics();
  }

  void recordAutoConnectCompleted(String outcome) {
    _lastAutoConnectOutcome = outcome;
    _autoConnectStartedAt = null;
    _emitDiagnostics();
  }

  void _recordFailure(String reason, {BleDisconnectReason? disconnectReason}) {
    _lastFailureReason = reason;
    _lastFailureAt = DateTime.now();
    if (disconnectReason != null) {
      _lastDisconnectReason = disconnectReason;
      _lastDisconnectAt = _lastFailureAt;
    }
    _emitDiagnostics();
  }

  void _recordDisconnect(BleDisconnectReason reason) {
    _lastDisconnectReason = reason;
    _lastDisconnectAt = DateTime.now();
    _emitDiagnostics();
  }

  void _clearFailureAfterReady() {
    _lastFailureReason = null;
    _lastFailureAt = null;
    _emitDiagnostics();
  }

  void _recordRxActivity() {
    _lastRxTime = DateTime.now();
    _emitDiagnostics();
  }

  void _recordTxActivity() {
    _lastTxTime = DateTime.now();
    _emitDiagnostics();
  }

  void setTrafficMode(BleTrafficMode mode, {String ownerName = 'legacy'}) {
    if (shouldBlockTrafficModeClaim(
      currentMode: _trafficMode,
      requestedMode: mode,
      controlSuspendedForLifecycle: _controlSuspendedForLifecycle,
    )) {
      _log(
        'mode_change_blocked',
        'ownerName=$ownerName requested=${mode.name}',
      );
      return;
    }
    _trafficModeOwner++;
    _trafficModeOwnerName = ownerName;
    _trafficMode = mode;
    _emitDiagnostics();
    _log('mode_changed', _ownerDetail(_trafficModeOwner));
  }

  int? claimTrafficMode(BleTrafficMode mode, {String ownerName = 'unknown'}) {
    return _claimTrafficMode(mode, ownerName: ownerName);
  }

  Future<int?> claimControlTrafficModeAfterManagement({
    required String ownerName,
  }) async {
    while (_managementLeaseReleased != null) {
      await _managementLeaseReleased!.future;
    }
    return _claimTrafficMode(
      BleTrafficMode.controlBinary,
      ownerName: ownerName,
    );
  }

  Future<BleManagementLease?> acquireManagementLease({
    int? owner,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    while (_managementLeaseReleased != null) {
      await _managementLeaseReleased!.future;
    }
    if (!canManageBleConnection(owner: owner)) {
      _log('management_lease_blocked', _ownerDetail(owner));
      return null;
    }
    final id = ++_nextManagementLeaseId;
    final lease = BleManagementLease._(this, id);
    _managementLeaseId = id;
    _activeManagementLease = lease;
    _managementLeaseReleased = Completer<void>();
    _managementLeaseTimer?.cancel();
    _managementLeaseTimer = Timer(
      timeout,
      () => _releaseManagementLease(id, reason: 'management_timeout'),
    );
    _log('management_lease_acquired', 'lease=$id');
    return lease;
  }

  void _releaseManagementLease(int id, {String? reason}) {
    if (_managementLeaseId != id) return;
    _managementLeaseTimer?.cancel();
    _managementLeaseTimer = null;
    _activeManagementLease?._invalidate();
    _activeManagementLease = null;
    _managementLeaseId = null;
    final released = _managementLeaseReleased;
    _managementLeaseReleased = null;
    if (released != null && !released.isCompleted) released.complete();
    if (reason != null) _recordFailure(reason);
    _log(
      'management_lease_released',
      'lease=$id reason=${reason ?? 'completed'}',
    );
  }

  int? _claimTrafficMode(
    BleTrafficMode mode, {
    required String ownerName,
    bool allowSuspendedControl = false,
  }) {
    if (shouldBlockTrafficModeClaim(
      currentMode: _trafficMode,
      requestedMode: mode,
      controlSuspendedForLifecycle:
          _controlSuspendedForLifecycle && !allowSuspendedControl,
    )) {
      _log('mode_claim_blocked', 'ownerName=$ownerName requested=${mode.name}');
      return null;
    }
    if (mode == BleTrafficMode.controlBinary) {
      _discardQueuedWrites(
        reason: 'control_mode_claimed',
        discardText: true,
        discardJoystick: true,
      );
    }
    _trafficModeOwner++;
    _trafficModeOwnerName = ownerName;
    _trafficMode = mode;
    _emitDiagnostics();
    _log('mode_claimed', _ownerDetail(_trafficModeOwner));
    return _trafficModeOwner;
  }

  void releaseTrafficMode(
    int owner, {
    BleTrafficMode fallback = BleTrafficMode.textCommand,
    bool refreshHeartbeat = true,
  }) {
    if (owner != _trafficModeOwner) {
      _log(
        'mode_release_ignored',
        'owner=$owner currentOwner=$_trafficModeOwner',
      );
      return;
    }

    final previousMode = _trafficMode;
    if (_reconnectOwner == owner) {
      _cancelControlReconnect(reason: 'mode_released', disableMode: true);
    }

    _trafficModeOwner++;
    _trafficModeOwnerName = 'none';
    _trafficMode = fallback;
    _emitDiagnostics();
    _log(
      'mode_released',
      'owner=$owner nextOwner=$_trafficModeOwner ownerName=$_trafficModeOwnerName',
    );
    if (refreshHeartbeat &&
        shouldRefreshHeartbeatOnModeRelease(
          previousMode: previousMode,
          fallback: fallback,
          connected: isConnected,
        )) {
      _recordRxActivity();
      _log('mode_release_heartbeat_refresh');
      unawaited(sendSystemText('PING', source: 'mode_release'));
    }
  }

  void enableControlReconnect({
    required int owner,
    String ownerName = 'control',
  }) {
    if (!_isActiveOwner(owner) ||
        _trafficMode != BleTrafficMode.controlBinary) {
      _log(
        'reconnect_enable_ignored',
        _ownerDetail(owner, 'ownerName=$ownerName'),
      );
      return;
    }

    _reconnectMode = BleReconnectMode.controlActive;
    _reconnectOwner = owner;
    _reconnectAttempt = 0;
    _reconnectDeadline = null;
    _log('reconnect_enabled', _ownerDetail(owner, 'ownerName=$ownerName'));
  }

  void disableControlReconnect(int owner) {
    if (_reconnectOwner != owner) {
      _log(
        'reconnect_disable_ignored',
        _ownerDetail(owner, 'reconnectOwner=$_reconnectOwner'),
      );
      return;
    }
    _cancelControlReconnect(reason: 'owner_disabled', disableMode: true);
  }

  Future<void> stopAndReleaseControl({
    required int owner,
    String source = 'control_navigation',
  }) async {
    if (!_isActiveOwner(owner) ||
        _trafficMode != BleTrafficMode.controlBinary) {
      _log('control_release_ignored', _ownerDetail(owner, 'source=$source'));
      return;
    }

    disableControlReconnect(owner);
    if (isConnected && !_controlSuspendedForLifecycle) {
      await sendControlStop(owner: owner, repeats: 1);
    }
    if (_isActiveOwner(owner)) {
      releaseTrafficMode(owner);
    }
  }

  /// Immediately stops an active control session and releases its BLE traffic
  /// ownership. A stale page cannot affect a newer session because ownership
  /// is verified before any stop frame is sent.
  Future<void> emergencyStopAndReleaseControl({
    required int owner,
    String source = 'control_emergency_stop',
  }) async {
    final isOwnerActive =
        _isActiveOwner(owner) && _trafficMode == BleTrafficMode.controlBinary;
    if (!isOwnerActive) {
      _log(
        'control_emergency_stop_ignored',
        _ownerDetail(owner, 'source=$source'),
      );
      return;
    }

    await runEmergencyStopOperation(
      isOwnerActive: isOwnerActive,
      isConnected: isConnected,
      controlSuspendedForLifecycle: _controlSuspendedForLifecycle,
      sendZeroFrames: (repeats) =>
          sendEmergencyStop(repeats: repeats, source: source),
      disableReconnect: () => disableControlReconnect(owner),
      releaseOwner: () {
        if (_isActiveOwner(owner)) releaseTrafficMode(owner);
      },
    );
  }

  /// Hands control to another on-screen control mode without waiting for the
  /// stop-frame acknowledgement. The priority stop is queued before the owner
  /// is released, so the next mode's binary write cannot overtake it.
  void handoffControlForModeSwitch({
    required int owner,
    String source = 'control_mode_switch',
  }) {
    if (!_isActiveOwner(owner) ||
        _trafficMode != BleTrafficMode.controlBinary) {
      _log('control_handoff_ignored', _ownerDetail(owner, 'source=$source'));
      return;
    }

    disableControlReconnect(owner);
    if (isConnected && !_controlSuspendedForLifecycle) {
      unawaited(sendControlStop(owner: owner, repeats: 1));
    }
    if (_isActiveOwner(owner)) {
      releaseTrafficMode(owner, refreshHeartbeat: false);
    }
    _log('control_handoff_queued', _ownerDetail(owner, 'source=$source'));
  }

  bool _isActiveOwner(int owner) => owner == _trafficModeOwner;

  Future<int?> resumeControl({required String ownerName}) async {
    if (!_controlSuspendedForLifecycle) return null;

    // A stale page may have claimed control while the previous app version was
    // suspended. Invalidate it before issuing the explicit resume owner.
    if (_trafficMode == BleTrafficMode.controlBinary) {
      _cancelControlReconnect(
        reason: 'resume_replaces_stale_owner',
        disableMode: true,
      );
      _trafficModeOwner++;
      _trafficModeOwnerName = 'none';
      _trafficMode = BleTrafficMode.textCommand;
      _emitDiagnostics();
    }

    final owner = _claimTrafficMode(
      BleTrafficMode.controlBinary,
      ownerName: ownerName,
      allowSuspendedControl: true,
    );
    if (owner == null) return null;
    _setControlSuspended(false);
    enableControlReconnect(owner: owner, ownerName: ownerName);
    if (!isConnected) {
      final connected = await _requestAutoConnect(
        source: 'control_resume',
        owner: owner,
      );
      if (!connected || !_isActiveOwner(owner)) {
        if (_isActiveOwner(owner)) {
          _cancelControlReconnect(
            reason: 'control_resume_not_connected',
            disableMode: true,
          );
          _trafficModeOwner++;
          _trafficModeOwnerName = 'none';
          _trafficMode = BleTrafficMode.textCommand;
          _emitDiagnostics();
        }
        _setControlSuspended(true);
        return null;
      }
    }
    if (isConnected && _isActiveOwner(owner)) {
      await sendControlStop(owner: owner, repeats: 1);
    }
    return owner;
  }

  void _setConnectionStatus(BleConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    _statusController.add(status);
    _emitDiagnostics();
  }

  void markScanning({String source = 'scan'}) {
    _log('status_scanning', 'source=$source');
    if (shouldMarkBleScanning(_connectionStatus)) {
      _setConnectionStatus(BleConnectionStatus.scanning);
    }
  }

  void markScanStopped({String source = 'scan'}) {
    final nextStatus = statusAfterBleScanStopped(_connectionStatus);
    if (nextStatus == null) return;
    _log('status_scan_stopped', 'source=$source');
    _setConnectionStatus(nextStatus);
  }

  void markConnectionAttemptFailed({String source = 'connect'}) {
    final owner = _reconnectOwner;
    final reconnectActive = owner != null && _canControlReconnect(owner);
    final nextStatus = statusAfterBleConnectionAttemptFailed(
      currentStatus: _connectionStatus,
      reconnectActive: reconnectActive,
    );
    if (nextStatus == null) return;
    _log('status_connect_failed', 'source=$source next=${nextStatus.name}');
    _setConnectionStatus(nextStatus);
  }

  void markConnecting({String source = 'connect'}) {
    _log('status_connecting', 'source=$source');
    _setConnectionStatus(BleConnectionStatus.connecting);
  }

  String _ownerDetail(int? owner, [String extra = '']) {
    final base =
        'owner=${owner ?? 'none'} activeOwner=$_trafficModeOwner ownerName=$_trafficModeOwnerName';
    return extra.isEmpty ? base : '$base $extra';
  }

  bool _allowTextWrite(int? owner, {bool system = false, String source = ''}) {
    if (_trafficMode == BleTrafficMode.controlBinary) {
      _log(
        'text_blocked_by_mode',
        _ownerDetail(owner, 'source=$source system=$system'),
      );
      return false;
    }
    if (!system && (owner == null || !_isActiveOwner(owner))) {
      _log('text_blocked_by_owner', _ownerDetail(owner, 'source=$source'));
      return false;
    }
    return true;
  }

  bool _allowBinaryWrite(int owner, {String source = ''}) {
    if (_controlSuspendedForLifecycle) {
      _log('binary_blocked_by_lifecycle', 'source=$source');
      return false;
    }
    if (_trafficMode != BleTrafficMode.controlBinary) {
      _log('binary_blocked_by_mode', _ownerDetail(owner, 'source=$source'));
      return false;
    }
    if (!_isActiveOwner(owner)) {
      _log('binary_blocked_by_owner', _ownerDetail(owner, 'source=$source'));
      return false;
    }
    return true;
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (!shouldSuspendBleControlForLifecycle(state)) {
      return;
    }
    if (_controlSuspendedForLifecycle ||
        _trafficMode != BleTrafficMode.controlBinary) {
      return;
    }

    _setControlSuspended(true);
    _log('control_suspended_for_lifecycle', 'state=${state.name}');
    await sendEmergencyStop(source: 'lifecycle:${state.name}');
    _cancelControlReconnect(
      reason: 'lifecycle:${state.name}',
      disableMode: true,
    );
    _trafficModeOwner++;
    _trafficModeOwnerName = 'none';
    _trafficMode = BleTrafficMode.textCommand;
  }

  String _age(DateTime? t) {
    if (t == null) return 'none';
    return '${DateTime.now().difference(t).inMilliseconds}ms';
  }

  void _log(String event, [String detail = '']) {
    final deviceName = currentDeviceName;
    final deviceId = currentDeviceId;
    final device = deviceName == null && deviceId == null
        ? 'none'
        : '${deviceName ?? 'unknown'}(${deviceId ?? 'no-id'})';
    final suffix = detail.isEmpty ? '' : ' $detail';
    debugPrint(
      '[BLE] $event mode=${_trafficMode.name} device=$device '
      'reconnect=${_reconnectMode.name} status=${_connectionStatus.name} '
      'lastTx=${_age(_lastTxTime)} lastRx=${_age(_lastRxTime)}$suffix',
    );
  }

  void _logRateLimitDrop() {
    final now = DateTime.now();
    if (now.difference(_lastRateLimitLog) < const Duration(seconds: 1)) {
      return;
    }
    _lastRateLimitLog = now;
    _log('dropped_by_rate_limit');
  }

  bool _canControlReconnect(int owner) {
    return shouldReconnectAfterTransportFailure(
      trafficMode: _trafficMode,
      reconnectMode: _reconnectMode,
      reconnectOwnerActive: _reconnectOwner == owner && _isActiveOwner(owner),
      manualDisconnectInProgress: _manualDisconnectInProgress,
    );
  }

  bool canAutoConnectForOwner(int? owner) {
    if (!canManageBleConnection(owner: owner)) return false;
    return owner == null || _canControlReconnect(owner);
  }

  bool canManageBleConnection({int? owner}) {
    return canManageBleConnectionRequest(
      trafficMode: _trafficMode,
      requestOwner: owner,
      activeOwner: _trafficModeOwner,
    );
  }

  void _resetTransportHealth() {
    _writeFailureCount = 0;
    _emitDiagnostics();
  }

  void _recordWriteSuccess() {
    if (_writeFailureCount == 0) return;
    _writeFailureCount = 0;
    _emitDiagnostics();
    _log('write_failure_count_reset');
  }

  Future<void> _recordWriteFailure({
    required String source,
    int? owner,
    Object? error,
  }) async {
    _writeFailureCount++;
    _recordFailure('write_failed:$source');
    _log(
      'write_failure_count',
      _ownerDetail(
        owner,
        'source=$source count=$_writeFailureCount threshold=$_writeFailureThreshold error=$error',
      ),
    );

    if (shouldTriggerWriteTransportFailure(
      consecutiveFailures: _writeFailureCount,
      threshold: _writeFailureThreshold,
    )) {
      await _handleTransportFailure(
        source: 'write_failed:$source',
        owner: owner,
      );
    }
  }

  Future<void> _handleTransportFailure({
    required String source,
    int? owner,
  }) async {
    if (_transportFailureHandling) {
      _log(
        'transport_failure_ignored',
        'source=$source reason=already_handling',
      );
      return;
    }

    _transportFailureHandling = true;
    _recordFailure(
      source,
      disconnectReason: BleDisconnectReason.transportFailure,
    );
    final reconnectOwner = owner ?? _reconnectOwner ?? _trafficModeOwner;
    final device = _device;

    _log(
      'transport_failure',
      _ownerDetail(
        reconnectOwner,
        'source=$source '
        'writeFailures=$_writeFailureCount',
      ),
    );

    try {
      _endControlSessionForLinkLoss(source: source);
      _stopHeartbeat();
      try {
        await _txSub?.cancel();
      } catch (e) {
        _log('tx_subscription_cancel_failed', 'source=$source error=$e');
      }
      _txSub = null;

      try {
        await _connSub?.cancel();
      } catch (e) {
        _log('conn_subscription_cancel_failed', 'source=$source error=$e');
      }
      _connSub = null;

      _device = null;
      _tx = null;
      _rx = null;
      _payloadSize = 20;
      _mtu = null;
      _writeCharacteristicSpec = null;
      _readCharacteristicSpec = null;
      _notificationMode = BleNotificationMode.none;
      _discardQueuedWrites(reason: 'transport_failure');
      _resetTransportHealth();

      _connectionController.add(false);
      _setConnectionStatus(BleConnectionStatus.disconnected);

      try {
        await device?.disconnect().timeout(_stopFrameTimeout);
      } catch (e) {
        _log('transport_disconnect_failed', 'source=$source error=$e');
      }
    } finally {
      _transportFailureHandling = false;
    }
  }

  void _endControlSessionForLinkLoss({required String source}) {
    if (_trafficMode != BleTrafficMode.controlBinary) return;
    final owner = _trafficModeOwner;
    _cancelControlReconnect(reason: 'link_lost:$source', disableMode: true);
    _discardQueuedWrites(reason: 'link_lost:$source');
    _trafficModeOwner++;
    _trafficModeOwnerName = 'none';
    _trafficMode = BleTrafficMode.textCommand;
    _emitDiagnostics();
    _log('control_session_ended_for_link_loss', 'owner=$owner source=$source');
  }

  Duration _nextReconnectDelay() {
    switch (_reconnectAttempt) {
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

  void _cancelControlReconnect({
    required String reason,
    bool disableMode = false,
  }) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _reconnectDeadline = null;
    if (disableMode) {
      _reconnectMode = BleReconnectMode.disabled;
      _reconnectOwner = null;
    }
    _log('reconnect_cancelled', 'reason=$reason');
    _emitDiagnostics();
  }

  void _scheduleControlReconnect(int owner) {
    if (!_canControlReconnect(owner)) {
      _cancelControlReconnect(reason: 'inactive_owner');
      return;
    }

    final deadline = _reconnectDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _recordFailure('reconnect_timeout');
      _setConnectionStatus(BleConnectionStatus.reconnectFailed);
      _log('reconnect_timeout', _ownerDetail(owner));
      _cancelControlReconnect(reason: 'timeout');
      return;
    }

    final delay = _nextReconnectDelay();
    _log(
      'reconnect_scheduled',
      _ownerDetail(owner, 'delayMs=${delay.inMilliseconds}'),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      unawaited(_runControlReconnect(owner));
    });
  }

  Future<void> _runControlReconnect(int owner) async {
    if (!_canControlReconnect(owner)) {
      _cancelControlReconnect(reason: 'inactive_owner');
      return;
    }
    if (isConnected) {
      _setConnectionStatus(BleConnectionStatus.connected);
      _cancelControlReconnect(reason: 'already_connected');
      return;
    }

    final attempt = ++_reconnectAttempt;
    _emitDiagnostics();
    _setConnectionStatus(BleConnectionStatus.reconnecting);
    _log('reconnect_scan_started', _ownerDetail(owner, 'attempt=$attempt'));

    final connected = await _requestAutoConnect(
      timeout: const Duration(seconds: 8),
      source: 'reconnect',
      owner: owner,
    );
    if (connected) {
      _setConnectionStatus(BleConnectionStatus.connected);
      _cancelControlReconnect(reason: 'connected');
      return;
    }

    final scanPermission = _lastScanPermissionResult;
    if (shouldStopControlReconnectForScanPermission(scanPermission)) {
      final reason = 'scan_unavailable:${scanPermission!.name}';
      _recordFailure(
        reason,
        disconnectReason: disconnectReasonForScanPermission(scanPermission),
      );
      _setConnectionStatus(BleConnectionStatus.reconnectFailed);
      _cancelControlReconnect(reason: reason);
      return;
    }

    if (!_canControlReconnect(owner)) {
      _cancelControlReconnect(reason: 'inactive_after_scan');
      return;
    }
    _scheduleControlReconnect(owner);
  }

  Future<BleWriteResult> _enqueueTextWrite(
    Future<BleWriteResult> Function() task,
  ) {
    final write = _BleQueuedWrite(kind: BleWriteIntentKind.text, task: task);
    _textWriteQueue.add(write);
    _pumpWrites();
    return write.completer.future;
  }

  Future<BleWriteResult> _enqueueStopWrite(
    Future<BleWriteResult> Function() task,
  ) {
    _discardQueuedWrites(
      reason: 'stop_requested',
      discardText: true,
      discardJoystick: true,
    );
    final write = _BleQueuedWrite(kind: BleWriteIntentKind.stop, task: task);
    _stopWriteQueue.add(write);
    _pumpWrites();
    return write.completer.future;
  }

  Future<BleWriteResult> _enqueueJoystickLatest(
    Future<BleWriteResult> Function() task,
  ) {
    _completeDroppedWrite(_pendingJoystickWrite);
    final write = _BleQueuedWrite(
      kind: BleWriteIntentKind.joystick,
      task: task,
    );
    _pendingJoystickWrite = write;
    _pumpWrites();
    return write.completer.future;
  }

  void _discardQueuedWrites({
    required String reason,
    bool discardText = true,
    bool discardJoystick = true,
    bool discardStops = true,
  }) {
    var dropped = 0;
    if (discardText) {
      while (_textWriteQueue.isNotEmpty) {
        _completeDroppedWrite(_textWriteQueue.removeFirst());
        dropped++;
      }
    }
    if (discardJoystick && _pendingJoystickWrite != null) {
      _completeDroppedWrite(_pendingJoystickWrite);
      _pendingJoystickWrite = null;
      dropped++;
    }
    if (discardStops) {
      while (_stopWriteQueue.isNotEmpty) {
        _completeDroppedWrite(_stopWriteQueue.removeFirst());
        dropped++;
      }
    }
    if (dropped > 0) {
      _log('write_queue_dropped', 'reason=$reason count=$dropped');
    }
  }

  void _completeDroppedWrite(_BleQueuedWrite? write) {
    if (write != null && !write.completer.isCompleted) {
      write.completer.complete(BleWriteResult.dropped);
    }
  }

  void _pumpWrites() {
    if (_writePumpRunning) return;
    _writePumpRunning = true;
    unawaited(_runWritePump());
  }

  Future<void> _runWritePump() async {
    try {
      while (true) {
        _BleQueuedWrite? write;
        if (_stopWriteQueue.isNotEmpty) {
          write = _stopWriteQueue.removeFirst();
        } else if (_textWriteQueue.isNotEmpty) {
          write = _textWriteQueue.removeFirst();
        } else if (_pendingJoystickWrite != null) {
          write = _pendingJoystickWrite;
          _pendingJoystickWrite = null;
        }
        if (write == null) return;

        try {
          final result = await write.task();
          if (!write.completer.isCompleted) write.completer.complete(result);
        } catch (e) {
          _log('write_queue_task_failed', 'kind=${write.kind.name} error=$e');
        } finally {
          _completeDroppedWrite(write);
        }
      }
    } finally {
      _writePumpRunning = false;
      if (_stopWriteQueue.isNotEmpty ||
          _textWriteQueue.isNotEmpty ||
          _pendingJoystickWrite != null) {
        _pumpWrites();
      }
    }
  }

  void _startHeartbeat() {
    _lastRxTime = DateTime.now();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!isConnected) {
        _stopHeartbeat();
        return;
      }

      await checkHeartbeatTick(
        rxAge: _lastRxTime == null
            ? null
            : DateTime.now().difference(_lastRxTime!),
        sendPing: () async {
          await sendSystemText("PING", source: 'heartbeat');
        },
        onTimeout: () async {
          _log(
            'heartbeat_timeout',
            'timeout=${_heartbeatTimeout.inMilliseconds}ms',
          );
          _stopHeartbeat();
          await disconnect(source: 'heartbeat_timeout');
        },
      );
    });
  }

  // Shared by the live timer and deterministic heartbeat regression tests.
  @visibleForTesting
  Future<void> checkHeartbeatTick({
    required Duration? rxAge,
    required Future<void> Function() sendPing,
    required Future<void> Function() onTimeout,
  }) async {
    if (_securePairingPending) return;
    if (!shouldMonitorHeartbeatRx(
      _trafficMode,
      isSecureControlReady: isSecureControlReady,
    )) {
      return;
    }
    if (rxAge != null && rxAge > _heartbeatTimeout) {
      await onTimeout();
      return;
    }
    await sendPing();
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void setDevice(BluetoothDevice device) {
    _clearSecureControlSession();
    _protocolLineBuffer.clear();
    _device = device;
    _emitDiagnostics();
    _log('device_set');

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      _log('connection_state', 'state=$state');

      if (state == BluetoothConnectionState.disconnected) {
        _clearSecureControlSession();
        _protocolLineBuffer.clear();
        _log('os_disconnected');
        _endControlSessionForLinkLoss(source: 'os_disconnected');

        _stopHeartbeat();
        await _txSub?.cancel();
        _txSub = null;

        _device = null;
        _tx = null;
        _rx = null;
        _payloadSize = 20;
        _mtu = null;
        _writeCharacteristicSpec = null;
        _readCharacteristicSpec = null;
        _notificationMode = BleNotificationMode.none;
        if (!_manualDisconnectInProgress) {
          _recordFailure(
            'os_disconnected',
            disconnectReason: BleDisconnectReason.remoteDisconnected,
          );
        }
        _connectionController.add(false);
        _setConnectionStatus(BleConnectionStatus.disconnected);
      }
    });
  }

  BleCharacteristicSpec _toCharacteristicSpec(BluetoothCharacteristic c) {
    final properties = c.properties;
    return BleCharacteristicSpec(
      uuid: c.uuid.str,
      read: properties.read,
      write: properties.write,
      writeWithoutResponse: properties.writeWithoutResponse,
      notify: properties.notify,
      indicate: properties.indicate,
    );
  }

  String _characteristicLogDetail(BleCharacteristicSpec spec) {
    return 'uuid=${spec.uuid} properties=${spec.propertySummary}';
  }

  Future<bool> discoverServices() async {
    if (_device == null) return false;

    try {
      _setConnectionStatus(BleConnectionStatus.discovering);
      final services = await _device!.discoverServices().timeout(
        _serviceDiscoveryTimeout,
      );
      BluetoothService? uartService;

      for (var s in services) {
        final suuid = s.uuid.str.toLowerCase();

        if (suuid.startsWith(uartServicePrefix)) {
          uartService = s;
          break;
        }
      }

      if (uartService == null) {
        _log('services_missing', 'reason=uart_service_not_found');
        _recordFailure('uart_service_not_found');
        return false;
      }

      final characteristics = uartService.characteristics;
      final specByUuid = <String, BluetoothCharacteristic>{};
      final specs = <BleCharacteristicSpec>[];
      for (final c in characteristics) {
        final spec = _toCharacteristicSpec(c);
        specs.add(spec);
        specByUuid[spec.normalizedUuid] = c;
      }

      final selection = selectUartCharacteristics(specs);
      if (!selection.isValid) {
        _log(
          'services_missing',
          'reason=${selection.failureReason} candidates=${specs.map(_characteristicLogDetail).join(';')}',
        );
        _recordFailure(
          selection.failureReason ?? 'characteristic_selection_failed',
        );
        return false;
      }

      final writeSpec = selection.write!;
      final readSpec = selection.read!;
      _rx = specByUuid[writeSpec.normalizedUuid];
      _tx = specByUuid[readSpec.normalizedUuid];

      if (_tx == null || _rx == null) {
        _log('services_missing', 'reason=selected_characteristic_not_found');
        _recordFailure('selected_characteristic_not_found');
        return false;
      }

      _writeCharacteristicSpec = writeSpec;
      _readCharacteristicSpec = readSpec;

      _log('uart_write_selected', _characteristicLogDetail(writeSpec));
      _log('uart_read_selected', _characteristicLogDetail(readSpec));

      _mtu = _device!.mtuNow;
      _payloadSize = blePayloadSizeFromMtu(_mtu);
      _log('mtu_ready', 'mtu=$_mtu payloadSize=$_payloadSize');
      _emitDiagnostics();

      _setConnectionStatus(BleConnectionStatus.subscribing);
      final txProperties = _tx!.properties;
      if (txProperties.notify) {
        await _tx!.setNotifyValue(true).timeout(_notificationSubscribeTimeout);
        _notificationMode = BleNotificationMode.notify;
      } else if (txProperties.indicate) {
        await _tx!
            .setNotifyValue(true, forceIndications: true)
            .timeout(_notificationSubscribeTimeout);
        _notificationMode = BleNotificationMode.indicate;
      } else {
        _log('services_missing', 'reason=tx_notify_or_indicate_not_supported');
        _recordFailure('tx_notify_or_indicate_not_supported');
        return false;
      }
      _emitDiagnostics();

      _txSub?.cancel();
      _txSub = _tx!.lastValueStream.listen(
        (data) {
          if (data.isNotEmpty) {
            _recordRxActivity();
            _recordProtocolBytes(data);
          }
        },
        onError: (e) {
          _log('tx_notify_error', 'error=$e');
          _recordFailure('tx_notify_error:$e');
        },
      );

      _log('services_ready');
      _resetTransportHealth();
      _startHeartbeat();
      _clearFailureAfterReady();
      _setConnectionStatus(BleConnectionStatus.connected);
      _connectionController.add(true);
      _cancelControlReconnect(reason: 'services_ready');
      return true;
    } on TimeoutException catch (e) {
      final phase = bleDiscoveryTimeoutReason(_connectionStatus);
      _log('discover_services_timeout', 'phase=$phase error=$e');
      await _handleTransportFailure(source: phase, owner: _reconnectOwner);
      return false;
    } catch (e) {
      _log('discover_services_failed', 'error=$e');
      _recordFailure('discover_services_failed:$e');
      return false;
    }
  }

  Future<BleWriteResult> send(String data, {required int owner}) {
    return _sendText(data, owner: owner, source: 'public');
  }

  Future<BleWriteResult> sendSystemText(
    String data, {
    String source = 'system',
  }) {
    return _sendText(data, system: true, source: source);
  }

  Future<BleWriteResult> _sendText(
    String data, {
    int? owner,
    bool system = false,
    String source = '',
  }) async {
    if (!_allowTextWrite(owner, system: system, source: source)) {
      return BleWriteResult.blocked;
    }
    if (!isConnected) {
      _log('write_failed', 'kind=text reason=not_ready len=${data.length}');
      return BleWriteResult.notConnected;
    }

    final rx = _rx!;
    final chunks = chunkBleTextPayload(data, payloadSize: _payloadSize);
    final withoutResponse = _writeCharacteristicSpec!.useWithoutResponse(
      preferAcknowledged: data == '0',
    );
    var failed = false;
    final writes = <Future<BleWriteResult>>[];
    for (final chunk in chunks) {
      writes.add(
        _enqueueTextWrite(() async {
          if (failed) return BleWriteResult.dropped;
          try {
            await rx
                .write(chunk, withoutResponse: withoutResponse)
                .timeout(_textWriteTimeout);
            _recordTxActivity();
            _recordWriteSuccess();
            return BleWriteResult.sent;
          } catch (e) {
            failed = true;
            _log(
              'write_failed',
              'kind=text error=$e timeoutMs=${_textWriteTimeout.inMilliseconds} len=${data.length} chunks=${chunks.length} payloadSize=$_payloadSize',
            );
            await _recordWriteFailure(
              source: 'text:$source',
              owner: owner,
              error: e,
            );
            return BleWriteResult.failed;
          }
        }),
      );
    }
    final results = await Future.wait(writes);
    return combineBleWriteResults(results);
  }

  Future<List<int>> readTx({required int owner}) async {
    if (!_isActiveOwner(owner)) {
      _log('rx_blocked_by_owner', _ownerDetail(owner, 'source=readTx'));
      return [];
    }
    if (_tx == null) return [];
    try {
      return await _tx!.read();
    } catch (e) {
      _log('read_tx_failed', 'error=$e');
      return [];
    }
  }

  Future<void> sendJoystick(JoystickPacket packet, {required int owner}) async {
    await send(packet.toBleString(), owner: owner);
  }

  Future<void> sendJoystickBinary({
    required JoystickPacket packet,
    required Set<int> pressedButtons,
    required int owner,
    bool force = false,
  }) async {
    if (!_allowBinaryWrite(owner, source: 'sendJoystickBinary')) {
      return;
    }
    if (!isConnected) {
      _log('write_failed', 'kind=binary reason=not_ready');
      return;
    }

    final rx = _rx!;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastJoySend) < const Duration(milliseconds: 20)) {
      _logRateLimitDrop();
      return;
    }
    _lastJoySend = now;

    final session = _secureControlSession;
    if (session == null) {
      _log('write_blocked', 'kind=binary reason=secure_session_required');
      return;
    }
    final bytes = BleSecureProtocol.buildJoystickPacket(
      session: session,
      sequence: session.nextSequence(),
      payload: packet.toControlPayload(pressedButtons),
    );

    final withoutResponse = _writeCharacteristicSpec!.useWithoutResponse();

    await _enqueueJoystickLatest(() async {
      try {
        await rx
            .write(bytes, withoutResponse: withoutResponse)
            .timeout(_binaryWriteTimeout);
        _recordTxActivity();
        _recordWriteSuccess();
        return BleWriteResult.sent;
      } catch (e) {
        _log(
          'write_failed',
          'kind=binary error=$e timeoutMs=${_binaryWriteTimeout.inMilliseconds}',
        );
        await _recordWriteFailure(
          source: 'binary:sendJoystickBinary',
          owner: owner,
          error: e,
        );
        return BleWriteResult.failed;
      }
    });
  }

  Future<void> sendStopFrame({required int owner}) async {
    await sendControlStop(owner: owner, repeats: 1);
  }

  Future<void> sendControlStop({required int owner, int repeats = 3}) async {
    if (!_allowBinaryWrite(owner, source: 'sendControlStop')) {
      return;
    }
    await _enqueueStopWrite(() async {
      await _sendControlStopNow(
        repeats: repeats,
        owner: owner,
        source: 'sendControlStop',
      );
      return BleWriteResult.sent;
    });
  }

  Future<void> sendEmergencyStop({
    int repeats = 3,
    String source = 'emergency',
  }) async {
    _log('emergency_stop', 'source=$source');
    await _enqueueStopWrite(() async {
      await _sendControlStopNow(repeats: repeats, source: source);
      return BleWriteResult.sent;
    });
  }

  Future<void> _sendControlStopNow({
    int repeats = 3,
    int? owner,
    String source = 'stop_frame',
  }) async {
    final rx = _rx;
    if (rx == null) {
      _log('stop_frame_failed', 'reason=no_rx');
      return;
    }

    final session = _secureControlSession;
    if (session == null) {
      _log('stop_frame_failed', 'reason=secure_session_required');
      return;
    }
    final count = repeats.clamp(1, 5);
    await writeControlStopFrames(
      supportsWrite: _writeCharacteristicSpec!.write,
      supportsWriteWithoutResponse:
          _writeCharacteristicSpec!.writeWithoutResponse,
      writeFrame: (packet, {required withoutResponse}) =>
          rx.write(packet, withoutResponse: withoutResponse),
      buildBytes: (_) => BleSecureProtocol.buildStopPacket(
        session: session,
        sequence: session.nextSequence(),
      ),
      repeats: repeats,
      timeout: _stopFrameTimeout,
      onFrameSent: (repeat, acknowledged) {
        final now = DateTime.now();
        _lastTxTime = now;
        _emitDiagnostics();
        _lastJoySend = now;
        _recordWriteSuccess();
        _log(
          'stop_frame_sent',
          acknowledged
              ? 'repeat=$repeat/$count ack=true'
              : 'repeat=$repeat/$count ack=false fallback=true',
        );
      },
      onAcknowledgedWriteFailed: (repeat, error) {
        _log(
          'stop_frame_failed',
          'repeat=$repeat/$count ack=true error=$error',
        );
      },
      onFrameFailed: (repeat, error) async {
        _log(
          'stop_frame_failed',
          'repeat=$repeat/$count ack=false error=$error',
        );
        await _recordWriteFailure(
          source: 'stop_frame:$source',
          owner: owner,
          error: error,
        );
      },
    );
  }

  Stream<List<int>>? onData({required int owner}) {
    final stream = _tx?.lastValueStream;
    if (stream == null) return null;
    return stream.where((data) {
      if (_isActiveOwner(owner)) return true;
      _log('rx_blocked_by_owner', _ownerDetail(owner, 'source=onData'));
      return false;
    });
  }

  Future<int?> readRssi() async {
    final device = _device;
    if (device == null) return null;
    try {
      return await device.readRssi();
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect({String source = 'manual_disconnect'}) async {
    _log(source);
    final manual = source == 'manual_disconnect';
    final suppressReconnect = shouldSuppressReconnectDuringDisconnect(source);
    if (!suppressReconnect) {
      _setConnectionStatus(BleConnectionStatus.disconnecting);
    }
    if (manual) {
      _recordDisconnect(BleDisconnectReason.manual);
      _cancelControlReconnect(reason: source, disableMode: true);
    }

    if (suppressReconnect) {
      _manualDisconnectInProgress = true;
      _log('disconnect_suppress_reconnect', 'source=$source');
    }

    try {
      final connected = isConnected;
      if (shouldSendControlStopOnDisconnect(
        mode: _trafficMode,
        connected: connected,
      )) {
        await sendEmergencyStop(source: 'disconnect:$source');
      } else if (connected) {
        _log('emergency_stop_skipped', 'reason=text_mode source=$source');
      }

      final rssi = await readRssi().timeout(
        _stopFrameTimeout,
        onTimeout: () => null,
      );
      _log(
        'disconnect_rssi',
        'source=$source rssi=${rssi == null ? 'unknown' : rssi.toString()}',
      );

      try {
        await _device?.disconnect();
      } catch (e) {
        _log('device_disconnect_failed', 'source=$source error=$e');
      }
    } catch (e) {
      _log('disconnect_failed', 'source=$source error=$e');
    } finally {
      _clearSecureControlSession();
      _protocolLineBuffer.clear();
      _device = null;
      _tx = null;
      _rx = null;
      _payloadSize = 20;
      _mtu = null;
      _writeCharacteristicSpec = null;
      _readCharacteristicSpec = null;
      _notificationMode = BleNotificationMode.none;
      _discardQueuedWrites(reason: 'disconnect_cleanup');
      _emitDiagnostics();

      _stopHeartbeat();
      try {
        await _txSub?.cancel();
      } catch (e) {
        _log('tx_subscription_cancel_failed', 'source=$source error=$e');
      }
      _txSub = null;

      try {
        await _connSub?.cancel();
      } catch (e) {
        _log('conn_subscription_cancel_failed', 'source=$source error=$e');
      }
      _connSub = null;

      _connectionController.add(false);
      if (!suppressReconnect) {
        _setConnectionStatus(BleConnectionStatus.disconnected);
      }

      _log('disconnected');
      if (suppressReconnect) {
        _manualDisconnectInProgress = false;
        _log('disconnect_suppress_reconnect_cleared', 'source=$source');
      }
    }
  }
}
