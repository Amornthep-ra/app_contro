import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Wire contract for PB Control Protocol v2.
/// Firmware must frame setup messages with `\n`, validate every HMAC, and
/// stop outputs after [watchdogTimeout] without a valid control packet.
class BleSecureProtocol {
  static const version = 2;
  static const watchdogTimeout = Duration(milliseconds: 400);
  static const _controlHeader = <int>[0xAA, 0x55, version];
  static const _joystickType = 0x01;
  static const _stopType = 0x02;
  static const _tagLength = 8;

  static String createNonce() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hello(String appNonce) => 'PB2:HELLO:$appNonce\n';

  static String? parseError(String line) {
    final match = RegExp(r'^PB2:ERROR:([A-Z_]+)$').firstMatch(line.trim());
    return match?.group(1);
  }

  static String auth({
    required List<int> secret,
    required BleBoardCapabilities capabilities,
    required String appNonce,
  }) {
    final value = _hmacHex(
      secret,
      'PB2|AUTH|${capabilities.boardId}|$appNonce|${capabilities.boardNonce}',
    );
    return 'PB2:AUTH:$value\n';
  }

  static bool verifiesBoard({
    required List<int> secret,
    required BleBoardCapabilities capabilities,
    required String appNonce,
  }) {
    final expected = _hmacHex(
      secret,
      'PB2|CAPS|${capabilities.boardId}|${capabilities.boardModel}|'
      '${capabilities.firmwareVersion}|$appNonce|${capabilities.boardNonce}',
    );
    return _constantTimeEquals(expected, capabilities.boardTag);
  }

  static BleSecureControlSession createSession({
    required List<int> secret,
    required BleBoardCapabilities capabilities,
    required String appNonce,
    required String sessionId,
  }) {
    final key = Hmac(sha256, secret)
        .convert(
          utf8.encode(
            'PB2|SESSION|${capabilities.boardId}|$appNonce|'
            '${capabilities.boardNonce}|$sessionId',
          ),
        )
        .bytes;
    return BleSecureControlSession(
      boardId: capabilities.boardId,
      boardModel: capabilities.boardModel,
      sessionId: sessionId,
      key: Uint8List.fromList(key),
    );
  }

  static Uint8List buildJoystickPacket({
    required BleSecureControlSession session,
    required int sequence,
    required List<int> payload,
  }) => _buildPacket(
    session: session,
    sequence: sequence,
    type: _joystickType,
    payload: payload,
  );

  static Uint8List buildStopPacket({
    required BleSecureControlSession session,
    required int sequence,
  }) => _buildPacket(
    session: session,
    sequence: sequence,
    type: _stopType,
    payload: const <int>[],
  );

  static Uint8List _buildPacket({
    required BleSecureControlSession session,
    required int sequence,
    required int type,
    required List<int> payload,
  }) {
    if (payload.length > 255) throw ArgumentError.value(payload, 'payload');
    final bytes = BytesBuilder(copy: false)
      ..add(_controlHeader)
      ..addByte(type)
      ..addByte((sequence >> 24) & 0xFF)
      ..addByte((sequence >> 16) & 0xFF)
      ..addByte((sequence >> 8) & 0xFF)
      ..addByte(sequence & 0xFF)
      ..addByte(payload.length)
      ..add(payload);
    final unsigned = bytes.toBytes();
    final tag = Hmac(sha256, session.key).convert(unsigned).bytes;
    return Uint8List.fromList([...unsigned, ...tag.take(_tagLength)]);
  }

  static BleBoardCapabilities? parseCapabilities(String line) {
    final parts = line.trim().split(':');
    if (parts.length != 8 || parts[0] != 'PB2' || parts[1] != 'CAPS') {
      return null;
    }
    final protocolVersion = int.tryParse(parts[2]);
    if (protocolVersion == null || protocolVersion != version) return null;
    if (parts.any((part) => part.isEmpty)) {
      return null;
    }
    return BleBoardCapabilities(
      protocolVersion: protocolVersion,
      boardId: parts[3],
      boardModel: parts[4],
      firmwareVersion: parts[5],
      boardNonce: parts[6],
      boardTag: parts[7],
    );
  }

  static BleAuthenticationAck? parseAuthenticated(String line) {
    final parts = line.trim().split(':');
    if (parts.length != 4 || parts[0] != 'PB2' || parts[1] != 'OK') return null;
    if (parts[2].isEmpty || parts[3].isEmpty) return null;
    return BleAuthenticationAck(sessionId: parts[2], boardTag: parts[3]);
  }

  static bool verifiesAuthenticated({
    required List<int> secret,
    required BleBoardCapabilities capabilities,
    required String appNonce,
    required BleAuthenticationAck acknowledgement,
  }) {
    final expected = _hmacHex(
      secret,
      'PB2|OK|${capabilities.boardId}|$appNonce|${capabilities.boardNonce}|'
      '${acknowledgement.sessionId}',
    );
    return _constantTimeEquals(expected, acknowledgement.boardTag);
  }

  static String _hmacHex(List<int> secret, String value) =>
      Hmac(sha256, secret).convert(utf8.encode(value)).toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var different = 0;
    for (var index = 0; index < a.length; index++) {
      different |= a.codeUnitAt(index) ^ b.codeUnitAt(index);
    }
    return different == 0;
  }
}

class BleBoardCapabilities {
  const BleBoardCapabilities({
    required this.protocolVersion,
    required this.boardId,
    required this.boardModel,
    required this.firmwareVersion,
    required this.boardNonce,
    required this.boardTag,
  });

  final int protocolVersion;
  final String boardId;
  final String boardModel;
  final String firmwareVersion;
  final String boardNonce;
  final String boardTag;
}

class BleSecureControlSession {
  BleSecureControlSession({
    required this.boardId,
    required this.boardModel,
    required this.sessionId,
    required Uint8List key,
  }) : _key = Uint8List.fromList(key);

  final String boardId;
  final String boardModel;
  final String sessionId;
  final Uint8List _key;
  int _nextSequence = 0;

  Uint8List get key => Uint8List.fromList(_key);
  int nextSequence() => ++_nextSequence;
  void dispose() => _key.fillRange(0, _key.length, 0);
}

class BleAuthenticationAck {
  const BleAuthenticationAck({required this.sessionId, required this.boardTag});

  final String sessionId;
  final String boardTag;
}
