import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BlePairingRecord {
  const BlePairingRecord({required this.boardId, required this.secret});

  final String boardId;
  final List<int> secret;
}

/// Validates an 8–16 ASCII alphanumeric code and derives the board secret.
/// Pair codes remain case-insensitive; spaces and symbols are rejected.
List<int>? secretFromBlePairingCode(String value) {
  if (value.length < 8 ||
      value.length > 16 ||
      RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return null;
  }
  final code = value.toUpperCase();
  return sha256.convert(utf8.encode('PB2|PAIR|$code')).bytes;
}

abstract interface class BlePairingStore {
  Future<void> save(BlePairingRecord record);
  Future<List<int>?> readSecret(String boardId);
  Future<void> remove(String boardId);
}

class SecureBlePairingStore implements BlePairingStore {
  SecureBlePairingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'pb_ble_pairing_v1_';
  final FlutterSecureStorage _storage;

  @override
  Future<void> save(BlePairingRecord record) => _storage.write(
    key: '$_prefix${record.boardId}',
    value: base64UrlEncode(record.secret),
  );

  @override
  Future<List<int>?> readSecret(String boardId) async {
    final encoded = await _storage.read(key: '$_prefix$boardId');
    if (encoded == null) return null;
    try {
      final secret = base64Url.decode(base64Url.normalize(encoded));
      return secret.length == 32 ? secret : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> remove(String boardId) =>
      _storage.delete(key: '$_prefix$boardId');
}
