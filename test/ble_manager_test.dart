import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';

void main() {
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
  });
}
