import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_connection_coordinator.dart';
import 'package:pb_controller/core/ble/ble_manager.dart';
import 'package:pb_controller/core/ble/ble_pairing_store.dart';
import 'package:pb_controller/core/ble/ble_secure_protocol.dart';

void main() {
  const code = '7K9M2PQT';
  final secret = secretFromBlePairingCode(code)!;

  BleConnectionCoordinator coordinatorFor(
    _HandshakeTransport transport, {
    BlePairingStore? pairingStore,
    Duration timeout = const Duration(milliseconds: 20),
  }) => BleConnectionCoordinator(
    secureHandshakeTransport: transport,
    pairingStore: pairingStore,
    secureHandshakeTimeout: timeout,
  );

  test(
    'completes PB2 HELLO, CAPS, AUTH, and OK before enabling control',
    () async {
      final transport = _HandshakeTransport(secret: secret);
      final coordinator = coordinatorFor(transport);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);

      expect(transport.authCount, 1);
      expect(coordinator.state.securityState, BleControlSecurityState.ready);
      expect(transport.helloCount, 1);
      expect(transport.authCount, 1);
      expect(transport.sessions, hasLength(1));
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test(
    'retries after a CAPS response whose authentication tag is invalid',
    () async {
      final transport = _HandshakeTransport(
        secret: secret,
        invalidCapsTag: true,
      );
      final coordinator = coordinatorFor(transport);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);

      expect(
        coordinator.state.securityState,
        BleControlSecurityState.unsupportedFirmware,
      );
      expect(transport.sessions, isEmpty);
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test(
    'retries after an OK response whose authentication tag is invalid',
    () async {
      final transport = _HandshakeTransport(
        secret: secret,
        invalidAckTag: true,
      );
      final coordinator = coordinatorFor(transport);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);

      expect(
        coordinator.state.securityState,
        BleControlSecurityState.unsupportedFirmware,
      );
      expect(transport.sessions, isEmpty);
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test(
    'marks pairing rejected only when the board sends AUTH_FAILED',
    () async {
      final transport = _HandshakeTransport(secret: secret, rejectAuth: true);
      final coordinator = coordinatorFor(transport);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);

      expect(
        coordinator.state.securityState,
        BleControlSecurityState.authenticationFailed,
      );
      expect(coordinator.state.failureReason, 'board_protocol_auth_failed');
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test('requires pairing when no saved secret exists for the board', () async {
    final transport = _HandshakeTransport(secret: secret);
    final coordinator = coordinatorFor(
      transport,
      pairingStore: _PairingStore(),
    );

    await coordinator.authenticateConnectedBoard();

    expect(
      coordinator.state.securityState,
      BleControlSecurityState.pairingRequired,
    );
    expect(transport.authCount, 0);
    await coordinator.dispose();
    await transport.dispose();
  });

  test('stops recovery when a saved secret cannot verify CAPS', () async {
    final store = _PairingStore();
    await store.save(
      BlePairingRecord(
        boardId: 'BOARD-A',
        secret: secretFromBlePairingCode('8K9M2PQT')!,
      ),
    );
    final transport = _HandshakeTransport(secret: secret);
    final coordinator = coordinatorFor(transport, pairingStore: store);

    await coordinator.authenticateConnectedBoard();
    await coordinator.authenticateConnectedBoard();

    expect(
      coordinator.state.recoveryOutcome,
      BleRecoveryOutcome.credentialMismatchSuspected,
    );
    expect(transport.authCount, 0);
    await coordinator.dispose();
    await transport.dispose();
  });

  test(
    'reports unsupported firmware when the board does not answer HELLO',
    () async {
      final transport = _HandshakeTransport(
        secret: secret,
        respondToHello: false,
      );
      final coordinator = coordinatorFor(transport, timeout: Duration.zero);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);

      expect(
        coordinator.state.securityState,
        BleControlSecurityState.unsupportedFirmware,
      );
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test('creates a fresh PB2 session for each authentication attempt', () async {
    final transport = _HandshakeTransport(secret: secret);
    final coordinator = coordinatorFor(transport);

    await coordinator.authenticateConnectedBoard(pairingSecret: secret);
    await coordinator.authenticateConnectedBoard(pairingSecret: secret);

    expect(transport.helloNonces.toSet(), hasLength(2));
    expect(
      transport.sessions.map((session) => session.sessionId).toSet(),
      hasLength(2),
    );
    await coordinator.dispose();
    await transport.dispose();
  });

  test('shares one in-flight handshake between concurrent callers', () async {
    final transport = _HandshakeTransport(secret: secret);
    final coordinator = coordinatorFor(transport);

    await Future.wait([
      coordinator.authenticateConnectedBoard(pairingSecret: secret),
      coordinator.authenticateConnectedBoard(pairingSecret: secret),
    ]);

    expect(transport.helloCount, 1);
    expect(transport.authCount, 1);
    expect(coordinator.state.securityState, BleControlSecurityState.ready);
    await coordinator.dispose();
    await transport.dispose();
  });

  test(
    'does not persist a pairing secret after failed authentication',
    () async {
      final store = _PairingStore();
      final transport = _HandshakeTransport(
        secret: secret,
        invalidCapsTag: true,
      );
      final coordinator = coordinatorFor(transport, pairingStore: store);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);
      await coordinator.savePairingCode(code);

      expect(store.saved, isEmpty);
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test('keeps pairing required when saving the secret fails', () async {
    final store = _PairingStore(throwOnSave: true);
    final transport = _HandshakeTransport(secret: secret);
    final coordinator = coordinatorFor(transport, pairingStore: store);

    await coordinator.authenticateConnectedBoard(pairingSecret: secret);
    final result = await coordinator.savePairingCode(code);

    expect(result.ready, isFalse);
    expect(result.failure, BlePairingFailure.storageError);
    expect(
      coordinator.state.securityState,
      BleControlSecurityState.pairingRequired,
    );
    await coordinator.dispose();
    await transport.dispose();
  });

  test(
    'keeps pairing required when the saved secret cannot be read back',
    () async {
      final store = _PairingStore(returnMismatchedSecret: true);
      final transport = _HandshakeTransport(secret: secret);
      final coordinator = coordinatorFor(transport, pairingStore: store);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);
      final result = await coordinator.savePairingCode(code);

      expect(result.ready, isFalse);
      expect(result.failure, BlePairingFailure.storageError);
      expect(
        coordinator.state.securityState,
        BleControlSecurityState.pairingRequired,
      );
      await coordinator.dispose();
      await transport.dispose();
    },
  );

  test(
    'reuses a saved pairing secret after a new secure session starts',
    () async {
      final store = _PairingStore();
      final transport = _HandshakeTransport(secret: secret);
      final coordinator = coordinatorFor(transport, pairingStore: store);

      await coordinator.authenticateConnectedBoard(pairingSecret: secret);
      await coordinator.savePairingCode(code);
      await coordinator.authenticateConnectedBoard();

      expect(store.saved, hasLength(1));
      expect(transport.authCount, 3);
      expect(coordinator.state.securityState, BleControlSecurityState.ready);
      await coordinator.dispose();
      await transport.dispose();
    },
  );
}

class _HandshakeTransport implements BleSecureHandshakeTransport {
  _HandshakeTransport({
    required this.secret,
    this.invalidCapsTag = false,
    this.invalidAckTag = false,
    this.rejectAuth = false,
    this.respondToHello = true,
  });

  final List<int> secret;
  final bool invalidCapsTag;
  final bool invalidAckTag;
  final bool rejectAuth;
  final bool respondToHello;
  final _lines = StreamController<String>.broadcast();
  final List<String> helloNonces = [];
  final List<BleSecureControlSession> sessions = [];
  int helloCount = 0;
  int authCount = 0;

  @override
  bool get isConnected => true;

  @override
  Stream<String> get protocolLines => _lines.stream;

  @override
  void clearSecureControlSession() {}

  @override
  Future<BleWriteResult> sendSystemText(
    String data, {
    required String source,
  }) async {
    if (data.startsWith('PB2:HELLO:')) {
      helloCount++;
      final nonce = data.trim().split(':').last;
      helloNonces.add(nonce);
      if (respondToHello) {
        final tag = _tag('PB2|CAPS|BOARD-A|PrinceBot|2.0|$nonce|BOARD-NONCE');
        await Future<void>.delayed(Duration.zero);
        _lines.add(
          'PB2:CAPS:2:BOARD-A:PrinceBot:2.0:BOARD-NONCE:'
          '${invalidCapsTag ? 'invalid' : tag}',
        );
      }
    } else if (data.startsWith('PB2:AUTH:')) {
      authCount++;
      if (rejectAuth) {
        await Future<void>.delayed(Duration.zero);
        _lines.add('PB2:ERROR:AUTH_FAILED');
        return BleWriteResult.sent;
      }
      final nonce = helloNonces.last;
      final sessionId = 'session-$authCount';
      final tag = invalidAckTag
          ? 'invalid'
          : _tag('PB2|OK|BOARD-A|$nonce|BOARD-NONCE|$sessionId');
      await Future<void>.delayed(Duration.zero);
      _lines.add('PB2:OK:$sessionId:$tag');
    }
    return BleWriteResult.sent;
  }

  String _tag(String value) =>
      Hmac(sha256, secret).convert(utf8.encode(value)).toString();

  @override
  void setSecureControlSession(BleSecureControlSession session) =>
      sessions.add(session);

  Future<void> dispose() => _lines.close();
}

class _PairingStore implements BlePairingStore {
  _PairingStore({
    this.throwOnSave = false,
    this.returnMismatchedSecret = false,
  });

  final bool throwOnSave;
  final bool returnMismatchedSecret;
  final List<BlePairingRecord> saved = [];

  @override
  Future<void> save(BlePairingRecord record) async {
    if (throwOnSave) throw StateError('save failed');
    saved.removeWhere((savedRecord) => savedRecord.boardId == record.boardId);
    saved.add(record);
  }

  @override
  Future<List<int>?> readSecret(String boardId) async {
    if (returnMismatchedSecret) return List<int>.filled(32, 0);
    for (final record in saved) {
      if (record.boardId == boardId) return record.secret;
    }
    return null;
  }

  @override
  Future<void> remove(String boardId) async {
    saved.removeWhere((record) => record.boardId == boardId);
  }
}
