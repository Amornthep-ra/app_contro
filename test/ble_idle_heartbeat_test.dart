import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_secure_protocol.dart';

void main() {
  final manager = BleManager.instance;
  late List<String> events;

  void authenticate() {
    // Synthetic fixture; never a device credential.
    manager.setSecureControlSession(
      BleSecureControlSession(
        boardId: 'fixture',
        boardModel: 'ESP32',
        sessionId: 'fixture',
        key: Uint8List(32),
      ),
    );
  }

  Future<void> tick(int seconds) => manager.checkHeartbeatTick(
    rxAge: Duration(seconds: seconds),
    sendPing: () async {
      events.add('PING');
    },
    onTimeout: () async {
      events.add('disconnect');
    },
  );

  setUp(() {
    events = [];
    manager.clearSecureControlSession();
    manager.setTrafficMode(BleTrafficMode.textCommand);
  });
  tearDown(() {
    manager.clearSecureControlSession();
    manager.setTrafficMode(BleTrafficMode.textCommand);
  });

  test('pending pairing ignores legacy RX timeout', () async {
    manager.setSecurePairingPending(true);
    for (var seconds = 2; seconds <= 60; seconds += 2) {
      await tick(seconds);
    }
    expect(events, isEmpty);
  });

  test(
    'PB2 idle before Start never pings or disconnects for 60 seconds',
    () async {
      authenticate();
      for (var seconds = 2; seconds <= 60; seconds += 2) {
        await tick(seconds);
      }
      expect(events, isEmpty);
    },
  );

  test('PB2 Start then Stop stays connected with a quiet RX stream', () async {
    authenticate();
    final owner = manager.claimTrafficMode(BleTrafficMode.controlBinary)!;
    await tick(6);
    expect(events, isEmpty);
    manager.releaseTrafficMode(owner);
    expect(manager.trafficMode, BleTrafficMode.textCommand);
    for (var seconds = 2; seconds <= 60; seconds += 2) {
      await tick(seconds);
    }
    expect(events, isEmpty);
  });

  test(
    'tick reads new authentication and cleared session without stale state',
    () async {
      await tick(2);
      expect(events, ['PING']);
      events.clear();
      authenticate();
      await tick(6);
      expect(events, isEmpty);
      manager.clearSecureControlSession();
      await tick(2);
      await tick(6);
      expect(events, ['PING', 'disconnect']);
    },
  );

  test('legacy heartbeat keeps the original five second timeout', () async {
    await tick(2);
    await tick(5);
    await tick(6);
    expect(events, ['PING', 'PING', 'disconnect']);
  });

  test(
    'binary traffic without session still skips notification heartbeat',
    () async {
      final owner = manager.claimTrafficMode(BleTrafficMode.controlBinary)!;
      try {
        await tick(6);
        expect(events, isEmpty);
      } finally {
        manager.releaseTrafficMode(owner);
      }
    },
  );
}
