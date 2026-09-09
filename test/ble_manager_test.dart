import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_permissions.dart';

void main() {
  group('BleConnectionStatus helpers', () {
    test('classifies connected status', () {
      expect(isBleStatusConnected(BleConnectionStatus.connected), isTrue);
      expect(isBleStatusBusy(BleConnectionStatus.connected), isFalse);
      expect(isBleStatusFailed(BleConnectionStatus.connected), isFalse);
    });

    test('classifies transitional statuses as busy', () {
      for (final status in const [
        BleConnectionStatus.scanning,
        BleConnectionStatus.connecting,
        BleConnectionStatus.discovering,
        BleConnectionStatus.subscribing,
        BleConnectionStatus.reconnecting,
        BleConnectionStatus.disconnecting,
      ]) {
        expect(isBleStatusBusy(status), isTrue, reason: status.name);
        expect(isBleStatusConnected(status), isFalse, reason: status.name);
        expect(isBleStatusFailed(status), isFalse, reason: status.name);
      }
    });

    test('classifies reconnect failure separately', () {
      expect(isBleStatusFailed(BleConnectionStatus.reconnectFailed), isTrue);
      expect(isBleStatusBusy(BleConnectionStatus.reconnectFailed), isFalse);
      expect(
        isBleStatusConnected(BleConnectionStatus.reconnectFailed),
        isFalse,
      );
    });

    test('classifies disconnected as idle', () {
      expect(isBleStatusConnected(BleConnectionStatus.disconnected), isFalse);
      expect(isBleStatusBusy(BleConnectionStatus.disconnected), isFalse);
      expect(isBleStatusFailed(BleConnectionStatus.disconnected), isFalse);
    });

    test('marks only idle scan flows as scanning', () {
      expect(shouldMarkBleScanning(BleConnectionStatus.disconnected), isTrue);
      expect(
        shouldMarkBleScanning(BleConnectionStatus.reconnectFailed),
        isTrue,
      );
      expect(shouldMarkBleScanning(BleConnectionStatus.reconnecting), isFalse);
      expect(shouldMarkBleScanning(BleConnectionStatus.connected), isFalse);
    });

    test('returns disconnected only when a scan status stops', () {
      expect(
        statusAfterBleScanStopped(BleConnectionStatus.scanning),
        BleConnectionStatus.disconnected,
      );
      for (final status in const [
        BleConnectionStatus.reconnecting,
        BleConnectionStatus.connecting,
        BleConnectionStatus.discovering,
        BleConnectionStatus.subscribing,
        BleConnectionStatus.connected,
        BleConnectionStatus.reconnectFailed,
      ]) {
        expect(statusAfterBleScanStopped(status), isNull, reason: status.name);
      }
    });

    test('finishes a failed connection as disconnected or reconnecting', () {
      for (final status in const [
        BleConnectionStatus.connecting,
        BleConnectionStatus.discovering,
        BleConnectionStatus.subscribing,
      ]) {
        expect(
          statusAfterBleConnectionAttemptFailed(
            currentStatus: status,
            reconnectActive: false,
          ),
          BleConnectionStatus.disconnected,
          reason: status.name,
        );
        expect(
          statusAfterBleConnectionAttemptFailed(
            currentStatus: status,
            reconnectActive: true,
          ),
          BleConnectionStatus.reconnecting,
          reason: status.name,
        );
      }
      expect(
        statusAfterBleConnectionAttemptFailed(
          currentStatus: BleConnectionStatus.connected,
          reconnectActive: false,
        ),
        isNull,
      );
    });
  });

  group('BLE lifecycle safety', () {
    test('suspends control for inactive background lifecycle states', () {
      expect(
        shouldSuspendBleControlForLifecycle(AppLifecycleState.inactive),
        isTrue,
      );
      expect(
        shouldSuspendBleControlForLifecycle(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        shouldSuspendBleControlForLifecycle(AppLifecycleState.detached),
        isTrue,
      );
    });

    test('does not suspend control for resumed lifecycle state', () {
      expect(
        shouldSuspendBleControlForLifecycle(AppLifecycleState.resumed),
        isFalse,
      );
    });

    test('requires an explicit control resume after returning foreground', () {
      expect(
        shouldRequireExplicitControlResume(
          controlWasSuspended: true,
          state: AppLifecycleState.resumed,
        ),
        isTrue,
      );
      expect(
        shouldRequireExplicitControlResume(
          controlWasSuspended: false,
          state: AppLifecycleState.resumed,
        ),
        isFalse,
      );
    });

    test('maps discovery and subscribe timeouts distinctly', () {
      expect(
        bleDiscoveryTimeoutReason(BleConnectionStatus.discovering),
        'service_discovery_timeout',
      );
      expect(
        bleDiscoveryTimeoutReason(BleConnectionStatus.subscribing),
        'notification_subscribe_timeout',
      );
    });
  });

  group('BLE management access policy', () {
    test('blocks management without the active owner during control', () {
      expect(
        canManageBleConnectionRequest(
          trafficMode: BleTrafficMode.controlBinary,
          requestOwner: null,
          activeOwner: 7,
        ),
        isFalse,
      );
      expect(
        canManageBleConnectionRequest(
          trafficMode: BleTrafficMode.controlBinary,
          requestOwner: 6,
          activeOwner: 7,
        ),
        isFalse,
      );
      expect(
        canManageBleConnectionRequest(
          trafficMode: BleTrafficMode.controlBinary,
          requestOwner: 7,
          activeOwner: 7,
        ),
        isTrue,
      );
      expect(
        canManageBleConnectionRequest(
          trafficMode: BleTrafficMode.textCommand,
          requestOwner: null,
          activeOwner: 7,
        ),
        isTrue,
      );
    });
  });

  group('Emergency stop operation', () {
    for (final supportsAck in [false, true]) {
      test('stop uses the only supported mode: ack=$supportsAck', () async {
        final modes = <bool>[];
        final sent = await writeControlStopFrames(
          supportsWrite: supportsAck,
          supportsWriteWithoutResponse: !supportsAck,
          writeFrame: (_, {required withoutResponse}) async {
            modes.add(withoutResponse);
          },
          buildBytes: (_) => [1],
          repeats: 1,
          timeout: const Duration(seconds: 1),
        );
        expect(sent, 1);
        expect(modes, [!supportsAck]);
      });
      test(
        'stop does not fall back to unsupported mode: ack=$supportsAck',
        () async {
          final modes = <bool>[];
          var failures = 0;
          final sent = await writeControlStopFrames(
            supportsWrite: supportsAck,
            supportsWriteWithoutResponse: !supportsAck,
            writeFrame: (_, {required withoutResponse}) async {
              modes.add(withoutResponse);
              throw StateError('write failed');
            },
            buildBytes: (_) => [1],
            repeats: 1,
            timeout: const Duration(seconds: 1),
            onFrameFailed: (_, _) async {
              failures++;
            },
          );
          expect(sent, 0);
          expect(failures, 1);
          expect(modes, [!supportsAck]);
        },
      );
    }

    test('write mode selection respects characteristic capabilities', () {
      for (final ack in [false, true]) {
        for (final noAck in [false, true]) {
          final spec = BleCharacteristicSpec(
            uuid: 'test',
            write: ack,
            writeWithoutResponse: noAck,
          );
          if (!ack && !noAck) {
            expect(spec.useWithoutResponse, throwsStateError);
          } else {
            expect(spec.useWithoutResponse(), noAck);
            expect(spec.useWithoutResponse(preferAcknowledged: true), !ack);
          }
        }
      }
    });

    test('stop rejects a characteristic without write support', () async {
      await expectLater(
        writeControlStopFrames(
          supportsWrite: false,
          supportsWriteWithoutResponse: false,
          writeFrame: (_, {required withoutResponse}) async {
            fail('unexpected write');
          },
          buildBytes: (_) => [1],
          repeats: 1,
          timeout: const Duration(seconds: 1),
        ),
        throwsArgumentError,
      );
    });
    test('builds a distinct stop frame for every repeated write', () async {
      final writes = <({List<int> bytes, bool withoutResponse})>[];
      final builtRepeats = <int>[];
      final sent = await writeControlStopFrames(
        writeFrame: (bytes, {required withoutResponse}) async {
          writes.add((
            bytes: List<int>.from(bytes),
            withoutResponse: withoutResponse,
          ));
        },
        buildBytes: (repeat) {
          builtRepeats.add(repeat);
          return [0xAA, 0x55, 0x02, repeat];
        },
        repeats: 3,
        timeout: const Duration(milliseconds: 1),
        repeatDelay: Duration.zero,
      );

      expect(sent, 3);
      expect(writes, hasLength(3));
      expect(writes.every((write) => !write.withoutResponse), isTrue);
      expect(builtRepeats, [1, 2, 3]);
      expect(writes.map((write) => write.bytes[3]), [1, 2, 3]);
    });

    test('builds a fresh frame for the unacknowledged fallback', () async {
      final attempts = <({bool withoutResponse, List<int> bytes})>[];
      var builds = 0;

      final sent = await writeControlStopFrames(
        writeFrame: (bytes, {required withoutResponse}) async {
          attempts.add((
            withoutResponse: withoutResponse,
            bytes: List<int>.from(bytes),
          ));
          if (!withoutResponse) throw StateError('ack write failed');
        },
        buildBytes: (_) => [++builds],
        repeats: 1,
        timeout: const Duration(milliseconds: 1),
        repeatDelay: Duration.zero,
      );

      expect(sent, 1);
      expect(attempts.map((attempt) => attempt.withoutResponse), [false, true]);
      expect(attempts.map((attempt) => attempt.bytes), [
        [1],
        [2],
      ]);
    });

    test(
      'sends three zero frames before releasing an active session',
      () async {
        final events = <String>[];

        await runEmergencyStopOperation(
          isOwnerActive: true,
          isConnected: true,
          controlSuspendedForLifecycle: false,
          disableReconnect: () => events.add('disable_reconnect'),
          sendZeroFrames: (repeats) async => events.add('zero:$repeats'),
          releaseOwner: () => events.add('release_owner'),
        );

        expect(events, ['disable_reconnect', 'zero:3', 'release_owner']);
      },
    );

    test(
      'does not affect a stale owner or write after connection loss',
      () async {
        final staleEvents = <String>[];
        await runEmergencyStopOperation(
          isOwnerActive: false,
          isConnected: true,
          controlSuspendedForLifecycle: false,
          disableReconnect: () => staleEvents.add('disable_reconnect'),
          sendZeroFrames: (repeats) async => staleEvents.add('zero:$repeats'),
          releaseOwner: () => staleEvents.add('release_owner'),
        );
        expect(staleEvents, isEmpty);

        final disconnectedEvents = <String>[];
        await runEmergencyStopOperation(
          isOwnerActive: true,
          isConnected: false,
          controlSuspendedForLifecycle: false,
          disableReconnect: () => disconnectedEvents.add('disable_reconnect'),
          sendZeroFrames: (repeats) async =>
              disconnectedEvents.add('zero:$repeats'),
          releaseOwner: () => disconnectedEvents.add('release_owner'),
        );
        expect(disconnectedEvents, ['disable_reconnect', 'release_owner']);

        final suspendedEvents = <String>[];
        await runEmergencyStopOperation(
          isOwnerActive: true,
          isConnected: true,
          controlSuspendedForLifecycle: true,
          disableReconnect: () => suspendedEvents.add('disable_reconnect'),
          sendZeroFrames: (repeats) async =>
              suspendedEvents.add('zero:$repeats'),
          releaseOwner: () => suspendedEvents.add('release_owner'),
        );
        expect(suspendedEvents, ['disable_reconnect', 'release_owner']);
      },
    );
  });

  group('BLE management lease', () {
    test(
      'makes Control wait until an active management operation releases',
      () async {
        final manager = BleManager.instance;
        final lease = await manager.acquireManagementLease();
        expect(lease, isNotNull);

        var claimed = false;
        final controlOwner = manager
            .claimControlTrafficModeAfterManagement(ownerName: 'lease_test')
            .then((owner) {
              claimed = true;
              return owner;
            });
        await Future<void>.delayed(Duration.zero);
        expect(claimed, isFalse);

        lease!.release();
        final owner = await controlOwner;
        expect(owner, isNotNull);
        manager.releaseTrafficMode(owner!);
      },
    );

    test(
      'expires a stale lease and releases a waiting Control claim',
      () async {
        final manager = BleManager.instance;
        final lease = await manager.acquireManagementLease(
          timeout: const Duration(milliseconds: 1),
        );
        expect(lease, isNotNull);

        final owner = manager.claimControlTrafficModeAfterManagement(
          ownerName: 'lease_timeout_test',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(lease!.isActive, isFalse);
        final resolvedOwner = await owner;
        expect(resolvedOwner, isNotNull);
        lease.release(); // A stale callback must not release the newer owner.
        manager.releaseTrafficMode(resolvedOwner!);
      },
    );
  });

  group('BleWriteResult', () {
    test('prefers failed over dropped command chunks', () {
      expect(
        combineBleWriteResults(const [
          BleWriteResult.sent,
          BleWriteResult.dropped,
          BleWriteResult.failed,
        ]),
        BleWriteResult.failed,
      );
    });

    test('reports dropped when no chunk fails', () {
      expect(
        combineBleWriteResults(const [
          BleWriteResult.sent,
          BleWriteResult.dropped,
        ]),
        BleWriteResult.dropped,
      );
    });
  });

  group('formatBleDiagnostics', () {
    test('includes transport and failure details in plain text', () {
      const snapshot = BleDiagnosticsSnapshot(
        deviceName: 'PrinceBot',
        deviceId: 'id',
        connectionStatus: BleConnectionStatus.connected,
        trafficMode: BleTrafficMode.textCommand,
        trafficOwnerName: 'line',
        mtu: 23,
        payloadSize: 20,
        writeCharacteristic: null,
        readCharacteristic: null,
        notificationMode: BleNotificationMode.notify,
        lastTxAge: null,
        lastRxAge: null,
        reconnectAttempt: 1,
        lastFailureReason: 'write_failed',
        lastFailureAge: null,
        lastDisconnectReason: BleDisconnectReason.transportFailure,
        lastDisconnectAge: null,
        lastScanPermissionResult: BleScanPermissionResult.granted,
      );
      final text = formatBleDiagnostics(snapshot);
      expect(text, contains('device=PrinceBot id=id'));
      expect(text, contains('lastFailure=write_failed'));
      expect(text, contains('lastDisconnect=transportFailure'));
      expect(text, contains('lastAutoConnect=-'));
    });
  });

  group('BleDiagnosticsSnapshot', () {
    test('keeps selected BLE transport details together', () {
      const write = BleCharacteristicSpec(
        uuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        writeWithoutResponse: true,
      );
      const read = BleCharacteristicSpec(
        uuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
        notify: true,
      );
      const diagnostics = BleDiagnosticsSnapshot(
        deviceName: 'PrinceBot',
        deviceId: '01:02:03:04:05:06',
        connectionStatus: BleConnectionStatus.connected,
        trafficMode: BleTrafficMode.controlBinary,
        trafficOwnerName: 'joystick',
        mtu: 247,
        payloadSize: 244,
        writeCharacteristic: write,
        readCharacteristic: read,
        notificationMode: BleNotificationMode.notify,
        lastTxAge: Duration(milliseconds: 120),
        lastRxAge: Duration(milliseconds: 80),
        reconnectAttempt: 2,
        lastFailureReason: 'write_failed:text:linesonic',
        lastFailureAge: Duration(seconds: 2),
        lastDisconnectReason: BleDisconnectReason.transportFailure,
        lastDisconnectAge: Duration(seconds: 2),
        lastScanPermissionResult: BleScanPermissionResult.granted,
      );

      expect(diagnostics.deviceName, 'PrinceBot');
      expect(diagnostics.payloadSize, 244);
      expect(diagnostics.writeCharacteristic?.canWrite, isTrue);
      expect(diagnostics.readCharacteristic?.canReceive, isTrue);
      expect(diagnostics.notificationMode, BleNotificationMode.notify);
      expect(
        diagnostics.lastDisconnectReason,
        BleDisconnectReason.transportFailure,
      );
      expect(
        diagnostics.lastScanPermissionResult,
        BleScanPermissionResult.granted,
      );
    });
  });

  group('applyBleWriteQueuePolicy', () {
    test('keeps text commands in FIFO order', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.text,
          BleWriteIntentKind.text,
          BleWriteIntentKind.text,
        ]),
        const [
          BleWriteIntentKind.text,
          BleWriteIntentKind.text,
          BleWriteIntentKind.text,
        ],
      );
    });

    test('coalesces consecutive joystick writes to latest intent', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.joystick,
        ]),
        const [BleWriteIntentKind.joystick],
      );
    });

    test('keeps reliable text ahead of a pending joystick write', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.text,
        ]),
        const [BleWriteIntentKind.text, BleWriteIntentKind.joystick],
      );
    });

    test('gives stop priority over pending joystick writes', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.stop,
        ]),
        const [BleWriteIntentKind.stop],
      );
    });

    test('drops queued text writes when stop is requested', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.text,
          BleWriteIntentKind.text,
          BleWriteIntentKind.stop,
        ]),
        const [BleWriteIntentKind.stop],
      );
    });

    test('continues coalescing joystick writes after stop frame', () {
      expect(
        applyBleWriteQueuePolicy(const [
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.stop,
          BleWriteIntentKind.joystick,
          BleWriteIntentKind.joystick,
        ]),
        const [BleWriteIntentKind.stop, BleWriteIntentKind.joystick],
      );
    });
  });

  group('shouldSendControlStopOnDisconnect', () {
    test('returns true for connected control binary mode', () {
      expect(
        shouldSendControlStopOnDisconnect(
          mode: BleTrafficMode.controlBinary,
          connected: true,
        ),
        isTrue,
      );
    });

    test('returns false for connected text command mode', () {
      expect(
        shouldSendControlStopOnDisconnect(
          mode: BleTrafficMode.textCommand,
          connected: true,
        ),
        isFalse,
      );
    });

    test('returns false for disconnected control binary mode', () {
      expect(
        shouldSendControlStopOnDisconnect(
          mode: BleTrafficMode.controlBinary,
          connected: false,
        ),
        isFalse,
      );
    });

    test('returns false for disconnected text command mode', () {
      expect(
        shouldSendControlStopOnDisconnect(
          mode: BleTrafficMode.textCommand,
          connected: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldSuppressReconnectDuringDisconnect', () {
    test('returns true for manual disconnect', () {
      expect(
        shouldSuppressReconnectDuringDisconnect('manual_disconnect'),
        isTrue,
      );
    });

    test('returns true for replace disconnect sources', () {
      expect(
        shouldSuppressReconnectDuringDisconnect('manual_connect_replace'),
        isTrue,
      );
      expect(
        shouldSuppressReconnectDuringDisconnect('reconnect_replace'),
        isTrue,
      );
      expect(
        shouldSuppressReconnectDuringDisconnect('control_initial_replace'),
        isTrue,
      );
    });

    test('returns false for non-intentional disconnect sources', () {
      expect(
        shouldSuppressReconnectDuringDisconnect('heartbeat_timeout'),
        isFalse,
      );
      expect(shouldSuppressReconnectDuringDisconnect('adapter_off'), isFalse);
      expect(shouldSuppressReconnectDuringDisconnect('unknown'), isFalse);
    });
  });

  group('shouldRefreshHeartbeatOnModeRelease', () {
    test('returns true when connected control mode returns to text mode', () {
      expect(
        shouldRefreshHeartbeatOnModeRelease(
          previousMode: BleTrafficMode.controlBinary,
          fallback: BleTrafficMode.textCommand,
          connected: true,
        ),
        isTrue,
      );
    });

    test('returns false when previous mode was already text mode', () {
      expect(
        shouldRefreshHeartbeatOnModeRelease(
          previousMode: BleTrafficMode.textCommand,
          fallback: BleTrafficMode.textCommand,
          connected: true,
        ),
        isFalse,
      );
    });

    test('returns false when fallback stays in control mode', () {
      expect(
        shouldRefreshHeartbeatOnModeRelease(
          previousMode: BleTrafficMode.controlBinary,
          fallback: BleTrafficMode.controlBinary,
          connected: true,
        ),
        isFalse,
      );
    });

    test('returns false when disconnected', () {
      expect(
        shouldRefreshHeartbeatOnModeRelease(
          previousMode: BleTrafficMode.controlBinary,
          fallback: BleTrafficMode.textCommand,
          connected: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldBlockTrafficModeClaim', () {
    test('returns true when text mode tries to claim during control mode', () {
      expect(
        shouldBlockTrafficModeClaim(
          currentMode: BleTrafficMode.controlBinary,
          requestedMode: BleTrafficMode.textCommand,
        ),
        isTrue,
      );
    });

    test(
      'returns true when another control mode tries to claim during control mode',
      () {
        expect(
          shouldBlockTrafficModeClaim(
            currentMode: BleTrafficMode.controlBinary,
            requestedMode: BleTrafficMode.controlBinary,
          ),
          isTrue,
        );
      },
    );

    test('returns false when control mode claims during text mode', () {
      expect(
        shouldBlockTrafficModeClaim(
          currentMode: BleTrafficMode.textCommand,
          requestedMode: BleTrafficMode.controlBinary,
        ),
        isFalse,
      );
    });

    test('returns false when text mode claims during text mode', () {
      expect(
        shouldBlockTrafficModeClaim(
          currentMode: BleTrafficMode.textCommand,
          requestedMode: BleTrafficMode.textCommand,
        ),
        isFalse,
      );
    });

    test('blocks a new control owner while lifecycle suspension is active', () {
      expect(
        shouldBlockTrafficModeClaim(
          currentMode: BleTrafficMode.textCommand,
          requestedMode: BleTrafficMode.controlBinary,
          controlSuspendedForLifecycle: true,
        ),
        isTrue,
      );
    });

    test('allows text traffic while lifecycle suspension is active', () {
      expect(
        shouldBlockTrafficModeClaim(
          currentMode: BleTrafficMode.textCommand,
          requestedMode: BleTrafficMode.textCommand,
          controlSuspendedForLifecycle: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldTriggerWriteTransportFailure', () {
    test('returns false before the failure threshold', () {
      expect(
        shouldTriggerWriteTransportFailure(
          consecutiveFailures: 1,
          threshold: 2,
        ),
        isFalse,
      );
    });

    test('returns true at and after the failure threshold', () {
      expect(
        shouldTriggerWriteTransportFailure(
          consecutiveFailures: 2,
          threshold: 2,
        ),
        isTrue,
      );
      expect(
        shouldTriggerWriteTransportFailure(
          consecutiveFailures: 3,
          threshold: 2,
        ),
        isTrue,
      );
    });
  });

  group('shouldMonitorHeartbeatRx', () {
    test('uses notification heartbeat for text commands', () {
      expect(shouldMonitorHeartbeatRx(BleTrafficMode.textCommand), isTrue);
    });

    test('does not treat quiet control notifications as a lost transport', () {
      expect(shouldMonitorHeartbeatRx(BleTrafficMode.controlBinary), isFalse);
    });
  });

  group('shouldStopControlReconnectForScanPermission', () {
    test('continues reconnect only when scan prerequisites are granted', () {
      expect(
        shouldStopControlReconnectForScanPermission(
          BleScanPermissionResult.granted,
        ),
        isFalse,
      );
      expect(shouldStopControlReconnectForScanPermission(null), isFalse);
    });

    test('stops reconnect when user action is required', () {
      for (final result in const [
        BleScanPermissionResult.permissionDenied,
        BleScanPermissionResult.bluetoothOff,
        BleScanPermissionResult.locationServiceOff,
      ]) {
        expect(shouldStopControlReconnectForScanPermission(result), isTrue);
      }
    });
  });

  group('disconnectReasonForScanPermission', () {
    test('maps user-action scan failures to diagnostics reasons', () {
      expect(
        disconnectReasonForScanPermission(
          BleScanPermissionResult.permissionDenied,
        ),
        BleDisconnectReason.permissionDenied,
      );
      expect(
        disconnectReasonForScanPermission(BleScanPermissionResult.bluetoothOff),
        BleDisconnectReason.bluetoothOff,
      );
      expect(
        disconnectReasonForScanPermission(
          BleScanPermissionResult.locationServiceOff,
        ),
        BleDisconnectReason.locationServiceOff,
      );
    });

    test('does not classify granted permission as a disconnect reason', () {
      expect(
        disconnectReasonForScanPermission(BleScanPermissionResult.granted),
        isNull,
      );
    });
  });

  group('shouldReconnectAfterTransportFailure', () {
    test('returns true only for active control reconnect ownership', () {
      expect(
        shouldReconnectAfterTransportFailure(
          trafficMode: BleTrafficMode.controlBinary,
          reconnectMode: BleReconnectMode.controlActive,
          reconnectOwnerActive: true,
          manualDisconnectInProgress: false,
        ),
        isTrue,
      );
    });

    test(
      'returns false for text mode, inactive owner, or manual disconnect',
      () {
        expect(
          shouldReconnectAfterTransportFailure(
            trafficMode: BleTrafficMode.textCommand,
            reconnectMode: BleReconnectMode.controlActive,
            reconnectOwnerActive: true,
            manualDisconnectInProgress: false,
          ),
          isFalse,
        );
        expect(
          shouldReconnectAfterTransportFailure(
            trafficMode: BleTrafficMode.controlBinary,
            reconnectMode: BleReconnectMode.controlActive,
            reconnectOwnerActive: false,
            manualDisconnectInProgress: false,
          ),
          isFalse,
        );
        expect(
          shouldReconnectAfterTransportFailure(
            trafficMode: BleTrafficMode.controlBinary,
            reconnectMode: BleReconnectMode.controlActive,
            reconnectOwnerActive: true,
            manualDisconnectInProgress: true,
          ),
          isFalse,
        );
        expect(
          shouldReconnectAfterTransportFailure(
            trafficMode: BleTrafficMode.controlBinary,
            reconnectMode: BleReconnectMode.disabled,
            reconnectOwnerActive: true,
            manualDisconnectInProgress: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('blePayloadSizeFromMtu', () {
    test('uses ATT payload size from negotiated MTU', () {
      expect(blePayloadSizeFromMtu(23), 20);
      expect(blePayloadSizeFromMtu(185), 182);
    });

    test('falls back when MTU is null or invalid', () {
      expect(blePayloadSizeFromMtu(null), 20);
      expect(blePayloadSizeFromMtu(3), 20);
      expect(blePayloadSizeFromMtu(0), 20);
    });
  });

  group('chunkBleTextPayload', () {
    test('keeps an exact MTU-sized payload in one chunk', () {
      final chunks = chunkBleTextPayload('ABCD', payloadSize: 5);

      expect(chunks, ['ABCD\n'.codeUnits]);
    });

    test('splits payloads larger than MTU in order', () {
      final chunks = chunkBleTextPayload('ABCDE', payloadSize: 3);

      expect(chunks, ['ABC'.codeUnits, 'DE\n'.codeUnits]);
    });

    test('appends newline before chunking', () {
      final chunks = chunkBleTextPayload('ABC', payloadSize: 2);

      expect(chunks, ['AB'.codeUnits, 'C\n'.codeUnits]);
    });

    test('uses fallback payload size when input size is invalid', () {
      final chunks = chunkBleTextPayload('ABCD', payloadSize: 0);

      expect(chunks, ['ABCD\n'.codeUnits]);
    });
  });

  group('selectUartCharacteristics', () {
    test('prefers Nordic UART UUIDs when properties match', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(
          uuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
          writeWithoutResponse: true,
        ),
        BleCharacteristicSpec(
          uuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
          notify: true,
        ),
        BleCharacteristicSpec(uuid: '0000abcd', write: true),
      ]);

      expect(selection.isValid, isTrue);
      expect(selection.write?.uuid, startsWith('6e400002'));
      expect(selection.read?.uuid, startsWith('6e400003'));
    });

    test('falls back to single property-compatible variant', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '0000write', write: true),
        BleCharacteristicSpec(uuid: '0000read', indicate: true),
      ]);

      expect(selection.isValid, isTrue);
      expect(selection.write?.uuid, '0000write');
      expect(selection.read?.uuid, '0000read');
    });

    test('fails when fallback write characteristic is ambiguous', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '0000write1', write: true),
        BleCharacteristicSpec(uuid: '0000write2', writeWithoutResponse: true),
        BleCharacteristicSpec(uuid: '0000read', notify: true),
      ]);

      expect(selection.isValid, isFalse);
      expect(selection.failureReason, 'ambiguous_write_fallback');
    });

    test('fails when fallback read characteristic is ambiguous', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '0000write', write: true),
        BleCharacteristicSpec(uuid: '0000read1', notify: true),
        BleCharacteristicSpec(uuid: '0000read2', indicate: true),
      ]);

      expect(selection.isValid, isFalse);
      expect(selection.failureReason, 'ambiguous_read_fallback');
    });

    test('does not select preferred UUIDs when properties are wrong', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '6e400002-bad', notify: true),
        BleCharacteristicSpec(uuid: '6e400003-bad', write: true),
      ]);

      expect(selection.isValid, isTrue);
      expect(selection.write?.uuid, '6e400003-bad');
      expect(selection.read?.uuid, '6e400002-bad');
    });

    test('does not select read-only characteristic for UART stream', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '6e400002-good', write: true),
        BleCharacteristicSpec(uuid: '6e400003-read-only', read: true),
      ]);

      expect(selection.isValid, isFalse);
      expect(selection.failureReason, 'read_not_found');
    });

    test(
      'falls back from read-only preferred UUID to notify characteristic',
      () {
        final selection = selectUartCharacteristics(const [
          BleCharacteristicSpec(uuid: '6e400002-good', write: true),
          BleCharacteristicSpec(uuid: '6e400003-read-only', read: true),
          BleCharacteristicSpec(uuid: '0000notify', notify: true),
        ]);

        expect(selection.isValid, isTrue);
        expect(selection.read?.uuid, '0000notify');
      },
    );

    test('reports missing write characteristic clearly', () {
      final selection = selectUartCharacteristics(const [
        BleCharacteristicSpec(uuid: '6e400003-good', notify: true),
      ]);

      expect(selection.isValid, isFalse);
      expect(selection.failureReason, 'write_not_found');
    });
  });
}
