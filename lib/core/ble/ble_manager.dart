//lib/core/ble/ble_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_permissions.dart';
import 'joystick_packet.dart';

enum BleTrafficMode { textCommand, controlBinary }

enum BleReconnectMode { disabled, controlActive }

enum BleConnectionStatus {
  disconnected,
  connected,
  reconnecting,
  reconnectFailed,
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
}) {
  return currentMode == BleTrafficMode.controlBinary &&
      requestedMode == BleTrafficMode.textCommand;
}

class BleManager {
  BleManager._();
  static final BleManager instance = BleManager._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _tx;
  BluetoothCharacteristic? _rx;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<BleConnectionStatus> _statusController =
      StreamController<BleConnectionStatus>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  bool get isConnected => _device != null && _tx != null && _rx != null;

  String? get currentDeviceName => _device?.platformName;
  String? get currentDeviceId => _device?.remoteId.str;
  BleTrafficMode get trafficMode => _trafficMode;
  BleConnectionStatus get connectionStatus => _connectionStatus;

  static const uartServicePrefix = "6e400001";
  static const uartRxPrefix = "6e400002";
  static const uartTxPrefix = "6e400003";
  static const int _blockedTrafficModeOwner = -1;

  Timer? _heartbeatTimer;
  DateTime? _lastRxTime;
  DateTime? _lastTxTime;
  StreamSubscription<List<int>>? _txSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<ScanResult>>? _autoScanSub;
  Timer? _reconnectTimer;
  bool _autoConnectRunning = false;
  Future<bool>? _autoConnectFuture;
  bool _manualDisconnectInProgress = false;
  BleTrafficMode _trafficMode = BleTrafficMode.textCommand;
  int _trafficModeOwner = 0;
  String _trafficModeOwnerName = 'none';
  BleReconnectMode _reconnectMode = BleReconnectMode.disabled;
  int? _reconnectOwner;
  int _reconnectAttempt = 0;
  DateTime? _reconnectDeadline;
  BleConnectionStatus _connectionStatus = BleConnectionStatus.disconnected;

  static const Duration _heartbeatInterval = Duration(seconds: 2);
  static const Duration _heartbeatTimeout = Duration(seconds: 5);
  static const Duration _stopFrameTimeout = Duration(milliseconds: 200);
  static const Duration _textWriteTimeout = Duration(milliseconds: 500);
  static const Duration _binaryWriteTimeout = Duration(milliseconds: 200);
  static const Duration _reconnectWindow = Duration(seconds: 60);

  Future<void> _sendLock = Future.value();

  DateTime _lastJoySend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRateLimitLog = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeartbeatStaleLog = DateTime.fromMillisecondsSinceEpoch(0);

  void setTrafficMode(BleTrafficMode mode, {String ownerName = 'legacy'}) {
    if (shouldBlockTrafficModeClaim(
      currentMode: _trafficMode,
      requestedMode: mode,
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
    _log('mode_changed', _ownerDetail(_trafficModeOwner));
  }

  int claimTrafficMode(BleTrafficMode mode, {String ownerName = 'unknown'}) {
    if (shouldBlockTrafficModeClaim(
      currentMode: _trafficMode,
      requestedMode: mode,
    )) {
      _log(
        'mode_claim_blocked',
        'ownerName=$ownerName requested=${mode.name}',
      );
      return _blockedTrafficModeOwner;
    }
    _trafficModeOwner++;
    _trafficModeOwnerName = ownerName;
    _trafficMode = mode;
    _log('mode_claimed', _ownerDetail(_trafficModeOwner));
    return _trafficModeOwner;
  }

  void releaseTrafficMode(
    int owner, {
    BleTrafficMode fallback = BleTrafficMode.textCommand,
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
    _log(
      'mode_released',
      'owner=$owner nextOwner=$_trafficModeOwner ownerName=$_trafficModeOwnerName',
    );
    if (shouldRefreshHeartbeatOnModeRelease(
      previousMode: previousMode,
      fallback: fallback,
      connected: isConnected,
    )) {
      _lastRxTime = DateTime.now();
      _log('mode_release_heartbeat_refresh');
      unawaited(sendSystemText('PING', source: 'mode_release'));
    }
  }

  void enableControlReconnect({
    required int owner,
    String ownerName = 'control',
  }) {
    if (!_isActiveOwner(owner) || _trafficMode != BleTrafficMode.controlBinary) {
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

  bool _isActiveOwner(int owner) => owner == _trafficModeOwner;

  void _setConnectionStatus(BleConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    _statusController.add(status);
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

  void _logHeartbeatStale() {
    final now = DateTime.now();
    if (now.difference(_lastHeartbeatStaleLog) <
        const Duration(seconds: 2)) {
      return;
    }
    _lastHeartbeatStaleLog = now;
    _log('heartbeat_stale', 'timeout=${_heartbeatTimeout.inMilliseconds}ms');
  }

  bool _canControlReconnect(int owner) {
    return _reconnectMode == BleReconnectMode.controlActive &&
        _reconnectOwner == owner &&
        _isActiveOwner(owner) &&
        _trafficMode == BleTrafficMode.controlBinary &&
        !_manualDisconnectInProgress;
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
    unawaited(_autoScanSub?.cancel() ?? Future<void>.value());
    _autoScanSub = null;
    _autoConnectRunning = false;
    _reconnectAttempt = 0;
    _reconnectDeadline = null;
    if (disableMode) {
      _reconnectMode = BleReconnectMode.disabled;
      _reconnectOwner = null;
    }
    _log('reconnect_cancelled', 'reason=$reason');
  }

  void _beginControlReconnect({required int owner, required String reason}) {
    if (!_canControlReconnect(owner)) {
      _log('reconnect_cancelled', _ownerDetail(owner, 'reason=inactive'));
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _reconnectDeadline = DateTime.now().add(_reconnectWindow);
    _setConnectionStatus(BleConnectionStatus.reconnecting);
    _log('reconnect_scheduled', _ownerDetail(owner, 'reason=$reason'));
    _scheduleControlReconnect(owner);
  }

  void _scheduleControlReconnect(int owner) {
    if (!_canControlReconnect(owner)) {
      _cancelControlReconnect(reason: 'inactive_owner');
      return;
    }

    final deadline = _reconnectDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
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

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _setConnectionStatus(BleConnectionStatus.disconnected);
      _cancelControlReconnect(reason: 'adapter_off');
      return;
    }

    final attempt = ++_reconnectAttempt;
    _setConnectionStatus(BleConnectionStatus.reconnecting);
    _log('reconnect_scan_started', _ownerDetail(owner, 'attempt=$attempt'));

    final ok = await autoConnectLastDevice(
      timeout: const Duration(seconds: 8),
      source: 'reconnect',
      owner: owner,
    );
    if (ok) {
      _setConnectionStatus(BleConnectionStatus.connected);
      _cancelControlReconnect(reason: 'connected');
      return;
    }

    if (!_canControlReconnect(owner)) {
      _cancelControlReconnect(reason: 'inactive_after_scan');
      return;
    }
    _scheduleControlReconnect(owner);
  }

  Future<void> _enqueueWrite(Future<void> Function() task) {
    _sendLock = _sendLock
        .then((_) async {
          await task();
        })
        .catchError((_) {});
    return _sendLock;
  }

  void _startHeartbeat() {
    _lastRxTime = DateTime.now();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!isConnected) {
        _stopHeartbeat();
        return;
      }

      final now = DateTime.now();
      if (_lastRxTime != null &&
          now.difference(_lastRxTime!) > _heartbeatTimeout) {
        if (_trafficMode == BleTrafficMode.controlBinary) {
          _logHeartbeatStale();
          return;
        }

        _log(
          'heartbeat_timeout',
          'timeout=${_heartbeatTimeout.inMilliseconds}ms',
        );
        _stopHeartbeat();
        await disconnect(source: 'heartbeat_timeout');
        return;
      }

      if (_trafficMode == BleTrafficMode.controlBinary) {
        return;
      }

      await sendSystemText("PING", source: 'heartbeat');
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void setDevice(BluetoothDevice device) {
    _device = device;
    _log('device_set');

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      _log('connection_state', 'state=$state');

      if (state == BluetoothConnectionState.disconnected) {
        _log('os_disconnected');
        final reconnectOwner = _trafficModeOwner;
        final shouldReconnect = _canControlReconnect(reconnectOwner);

        _stopHeartbeat();
        await _txSub?.cancel();
        _txSub = null;

        _device = null;
        _tx = null;
        _rx = null;

        _connectionController.add(false);
        _setConnectionStatus(BleConnectionStatus.disconnected);
        if (shouldReconnect) {
          _beginControlReconnect(
            owner: reconnectOwner,
            reason: 'os_disconnected',
          );
        }
      }
    });
  }

  Future<bool> discoverServices() async {
    if (_device == null) return false;

    try {
      final services = await _device!.discoverServices();

      for (var s in services) {
        final suuid = s.uuid.str.toLowerCase();

        if (suuid.startsWith(uartServicePrefix)) {
          for (var c in s.characteristics) {
            final cuuid = c.uuid.str.toLowerCase();

            if (cuuid.startsWith(uartTxPrefix)) {
              _tx = c;
            } else if (cuuid.startsWith(uartRxPrefix)) {
              _rx = c;
            }
          }
        }
      }

      if (_tx == null || _rx == null) {
        _log('services_missing', 'reason=tx_or_rx_not_found');
        return false;
      }

      if (_tx!.properties.notify) {
        await _tx!.setNotifyValue(true);

        _txSub?.cancel();
        _txSub = _tx!.lastValueStream.listen(
          (data) {
            if (data.isNotEmpty) {
              _lastRxTime = DateTime.now();
            }
          },
          onError: (e) {
            _log('tx_notify_error', 'error=$e');
          },
        );
      }

      _log('services_ready');
      _startHeartbeat();
      _setConnectionStatus(BleConnectionStatus.connected);
      _connectionController.add(true);
      _cancelControlReconnect(reason: 'services_ready');
      return true;
    } catch (e) {
      _log('discover_services_failed', 'error=$e');
      return false;
    }
  }

  Future<void> send(String data, {required int owner}) async {
    await _sendText(data, owner: owner, source: 'public');
  }

  Future<void> sendSystemText(String data, {String source = 'system'}) async {
    await _sendText(data, system: true, source: source);
  }

  Future<void> _sendText(
    String data, {
    int? owner,
    bool system = false,
    String source = '',
  }) async {
    if (!_allowTextWrite(owner, system: system, source: source)) {
      return;
    }
    if (!isConnected) {
      _log('write_failed', 'kind=text reason=not_ready len=${data.length}');
      return;
    }

    final rx = _rx!;
    final msg = "$data\n".codeUnits;
    final mustAck = data == '0';

    await _enqueueWrite(() async {
      try {
        await rx
            .write(msg, withoutResponse: !mustAck)
            .timeout(_textWriteTimeout);
        _lastTxTime = DateTime.now();
      } catch (e) {
        _log(
          'write_failed',
          'kind=text error=$e timeoutMs=${_textWriteTimeout.inMilliseconds} len=${data.length}',
        );
      }
    });
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

    final bytes = packet.toBinaryPacket(pressedButtons);

    await _enqueueWrite(() async {
      try {
        await rx
            .write(bytes, withoutResponse: true)
            .timeout(_binaryWriteTimeout);
        _lastTxTime = DateTime.now();
      } catch (e) {
        _log(
          'write_failed',
          'kind=binary error=$e timeoutMs=${_binaryWriteTimeout.inMilliseconds}',
        );
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
    await _enqueueWrite(() async {
      await _sendControlStopNow(repeats: repeats);
    });
  }

  Future<void> sendEmergencyStop({
    int repeats = 3,
    String source = 'emergency',
  }) async {
    _log('emergency_stop', 'source=$source');
    await _enqueueWrite(() async {
      await _sendControlStopNow(repeats: repeats);
    });
  }

  Future<void> _sendControlStopNow({int repeats = 3}) async {
    final rx = _rx;
    if (rx == null) {
      _log('stop_frame_failed', 'reason=no_rx');
      return;
    }

    final bytes = JoystickPacket(
      lx: 0,
      ly: 0,
      rx: 0,
      ry: 0,
    ).toBinaryPacket(const <int>{});

    final count = repeats < 1 ? 1 : (repeats > 5 ? 5 : repeats);
    for (var i = 0; i < count; i++) {
      try {
        await rx
            .write(bytes, withoutResponse: false)
            .timeout(_stopFrameTimeout);
        final now = DateTime.now();
        _lastTxTime = now;
        _lastJoySend = now;
        _log('stop_frame_sent', 'repeat=${i + 1}/$count ack=true');
      } catch (e) {
        _log('stop_frame_failed',
            'repeat=${i + 1}/$count ack=true error=$e');
        try {
          await rx
              .write(bytes, withoutResponse: true)
              .timeout(_stopFrameTimeout);
          final now = DateTime.now();
          _lastTxTime = now;
          _lastJoySend = now;
          _log(
            'stop_frame_sent',
            'repeat=${i + 1}/$count ack=false fallback=true',
          );
        } catch (fallbackError) {
          _log(
            'stop_frame_failed',
            'repeat=${i + 1}/$count ack=false error=$fallbackError',
          );
        }
      }

      if (i < count - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
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

  Future<bool> autoConnectLastDevice({
    Duration timeout = const Duration(seconds: 8),
    String source = 'auto_connect',
    int? owner,
  }) async {
    if (isConnected) return true;

    final runningFuture = _autoConnectFuture;
    if (runningFuture != null) {
      _log('auto_connect_joined', 'source=$source');
      return runningFuture;
    }

    late final Future<bool> future;
    future = _runAutoConnectLastDevice(
      timeout: timeout,
      source: source,
      owner: owner,
    ).whenComplete(() {
      if (identical(_autoConnectFuture, future)) {
        _autoConnectFuture = null;
      }
    });
    _autoConnectFuture = future;
    return future;
  }

  Future<bool> _runAutoConnectLastDevice({
    required Duration timeout,
    required String source,
    required int? owner,
  }) async {
    if (_autoConnectRunning || isConnected) return isConnected;

    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('ble_last_device_id');
    if (lastId == null || lastId.isEmpty) return false;

    final permissionsOk = await ensureBleScanPermissions();
    if (!permissionsOk) {
      _log('auto_connect_permission_denied', 'source=$source');
      return false;
    }

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) return false;

    _autoConnectRunning = true;
    final connected = Completer<bool>();
    Timer? timeoutTimer;

    try {
      await _autoScanSub?.cancel();
      _autoScanSub = FlutterBluePlus.scanResults.listen((list) async {
        if (!_autoConnectRunning || isConnected || connected.isCompleted) {
          return;
        }
        for (final r in list) {
          if (r.device.remoteId.str != lastId) continue;
          if (owner != null && !_canControlReconnect(owner)) {
            if (!connected.isCompleted) {
              connected.complete(false);
            }
            return;
          }

          _autoConnectRunning = false;
          await _autoScanSub?.cancel();
          _autoScanSub = null;

          try {
            await FlutterBluePlus.stopScan();
          } catch (_) {}

          if (source == 'reconnect') {
            _log('reconnect_device_found', 'id=$lastId');
          }

          await disconnect(source: '${source}_replace');
          try {
            await r.device.disconnect();
          } catch (_) {}

          try {
            await r.device.connect(
              license: License.free,
              timeout: const Duration(seconds: 10),
              autoConnect: false,
            );

            setDevice(r.device);
            final ok = await discoverServices();
            if (!ok) {
              await disconnect(source: 'services_missing');
            }
            if (ok && _trafficMode != BleTrafficMode.controlBinary) {
              await sendSystemText("HELLO_APP", source: source);
            }
            if (source == 'reconnect' && ok) {
              _log('reconnect_services_ready', 'id=$lastId');
            }
            if (!connected.isCompleted) {
              connected.complete(ok);
            }
          } catch (e) {
            _log('auto_connect_failed', 'source=$source error=$e');
            if (!connected.isCompleted) {
              connected.complete(false);
            }
          }
          return;
        }
      });

      timeoutTimer = Timer(timeout, () {
        if (!connected.isCompleted) {
          if (source == 'reconnect') {
            _log(
              'reconnect_timeout',
              'scanTimeoutMs=${timeout.inMilliseconds}',
            );
          }
          connected.complete(false);
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout);
      return await connected.future;
    } catch (e) {
      _log('auto_connect_failed', 'source=$source error=$e');
      return false;
    } finally {
      timeoutTimer?.cancel();
      await _autoScanSub?.cancel();
      _autoScanSub = null;
      _autoConnectRunning = false;
    }
  }

  Future<void> disconnect({String source = 'manual_disconnect'}) async {
    _log(source);
    final manual = source == 'manual_disconnect';
    final suppressReconnect = shouldSuppressReconnectDuringDisconnect(source);
    if (manual) {
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
      _device = null;
      _tx = null;
      _rx = null;

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
      _setConnectionStatus(BleConnectionStatus.disconnected);

      _log('disconnected');
      if (suppressReconnect) {
        _manualDisconnectInProgress = false;
        _log('disconnect_suppress_reconnect_cleared', 'source=$source');
      }
    }
  }
}
