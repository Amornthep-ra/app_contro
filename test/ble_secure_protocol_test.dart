import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_pairing_store.dart';
import 'package:pb_controller/core/ble/ble_secure_protocol.dart';

String _hmac(List<int> key, String value) =>
    Hmac(sha256, key).convert(utf8.encode(value)).toString();

void main() {
  const boardId = 'PB-01';
  const model = 'ESP32-C3';
  const firmware = '2.0.0';
  const appNonce = 'a1';
  const boardNonce = 'b2';
  final secret = List<int>.generate(32, (index) => index);

  BleBoardCapabilities capabilities() => BleBoardCapabilities(
    protocolVersion: 2,
    boardId: boardId,
    boardModel: model,
    firmwareVersion: firmware,
    boardNonce: boardNonce,
    boardTag: _hmac(
      secret,
      'PB2|CAPS|$boardId|$model|$firmware|$appNonce|$boardNonce',
    ),
  );

  test('parses only protocol-v2 capability lines', () {
    final caps = capabilities();
    final line =
        'PB2:CAPS:2:$boardId:$model:$firmware:$boardNonce:${caps.boardTag}';
    expect(BleSecureProtocol.parseCapabilities(line)?.boardId, boardId);
    expect(BleSecureProtocol.parseCapabilities('PB2:CAPS:1:x:y:z:n:t'), isNull);
  });

  test('verifies board and authenticated acknowledgement', () {
    final caps = capabilities();
    expect(
      BleSecureProtocol.verifiesBoard(
        secret: secret,
        capabilities: caps,
        appNonce: appNonce,
      ),
      isTrue,
    );
    const sessionId = 's1';
    final acknowledgement = BleAuthenticationAck(
      sessionId: sessionId,
      boardTag: _hmac(
        secret,
        'PB2|OK|$boardId|$appNonce|$boardNonce|$sessionId',
      ),
    );
    expect(
      BleSecureProtocol.verifiesAuthenticated(
        secret: secret,
        capabilities: caps,
        appNonce: appNonce,
        acknowledgement: acknowledgement,
      ),
      isTrue,
    );
  });

  test(
    'creates authenticated joystick and stop packets with unique sequence',
    () {
      final session = BleSecureProtocol.createSession(
        secret: secret,
        capabilities: capabilities(),
        appNonce: appNonce,
        sessionId: 'session',
      );
      final joystick = BleSecureProtocol.buildJoystickPacket(
        session: session,
        sequence: session.nextSequence(),
        payload: const [0, 0, 0, 0, 0, 0],
      );
      final stop = BleSecureProtocol.buildStopPacket(
        session: session,
        sequence: session.nextSequence(),
      );
      expect(joystick.sublist(0, 4), [0xAA, 0x55, 0x02, 0x01]);
      expect(stop.sublist(0, 4), [0xAA, 0x55, 0x02, 0x02]);
      expect(joystick[7], 1);
      expect(stop[7], 2);
      expect(stop.length, 17);
    },
  );

  test('accepts only 8-16 ASCII alphanumeric pairing characters', () {
    // Public synthetic fixtures only.
    final compact = secretFromBlePairingCode('iLoU1234');
    expect(compact, sha256.convert(utf8.encode('PB2|PAIR|ILOU1234')).bytes);
    expect(compact, secretFromBlePairingCode('ILOU1234'));
    expect(secretFromBlePairingCode('abcdefghijklmnop'), hasLength(32));
    expect(secretFromBlePairingCode('01234567'), hasLength(32));
    for (final invalid in [
      '',
      '1234567',
      '12345678901234567',
      'abcd-efgh',
      'abcd efgh',
      'abcdefgh_',
      'abcdefgh!',
      'abcdefgh\n',
      'abcdefgh\t',
      'abcdefghé',
      'abcdefghไทย',
      'abcdefghı',
    ]) {
      expect(secretFromBlePairingCode(invalid), isNull);
    }
  });

  test('parses PB2 board errors without treating them as a timeout', () {
    expect(
      BleSecureProtocol.parseError('PB2:ERROR:AUTH_FAILED'),
      'AUTH_FAILED',
    );
    expect(BleSecureProtocol.parseError('PB2:OK:session:tag'), isNull);
  });
}
