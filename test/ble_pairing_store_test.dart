import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_pairing_store.dart';

/// Secure storage whose read fails, as for a code restored from another
/// phone whose Keystore key is not on this one.
class _UnreadableStorage extends FlutterSecureStorage {
  _UnreadableStorage();

  final deleted = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'Failed to unwrap key');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => deleted.add(key);
}

void main() {
  test('an unreadable saved code reads as missing and is dropped', () async {
    final storage = _UnreadableStorage();
    final store = SecureBlePairingStore(storage: storage);

    expect(await store.readSecret('board-1'), isNull);
    expect(storage.deleted, ['pb_ble_pairing_v1_board-1']);
  });
}
