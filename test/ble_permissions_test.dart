import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothAdapterState;
import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_permissions.dart';
import 'package:pb_controller/core/ble/control_timing.dart';

void main() {
  group('decideBleScanPermissionResult', () {
    test('returns permissionDenied before checking Bluetooth state', () {
      expect(
        decideBleScanPermissionResult(
          bluetoothOn: false,
          permissionsGranted: false,
          requiresLocationService: true,
          locationServiceEnabled: false,
        ),
        BleScanPermissionResult.permissionDenied,
      );
    });

    test('returns permissionDenied when required permissions are missing', () {
      expect(
        decideBleScanPermissionResult(
          bluetoothOn: true,
          permissionsGranted: false,
          requiresLocationService: true,
          locationServiceEnabled: false,
        ),
        BleScanPermissionResult.permissionDenied,
      );
    });

    test(
      'returns locationServiceOff for Android pre-31 location service off',
      () {
        expect(
          decideBleScanPermissionResult(
            bluetoothOn: true,
            permissionsGranted: true,
            requiresLocationService: true,
            locationServiceEnabled: false,
          ),
          BleScanPermissionResult.locationServiceOff,
        );
      },
    );

    test(
      'returns granted when permissions and required services are ready',
      () {
        expect(
          decideBleScanPermissionResult(
            bluetoothOn: true,
            permissionsGranted: true,
            requiresLocationService: true,
            locationServiceEnabled: true,
          ),
          BleScanPermissionResult.granted,
        );
        expect(
          decideBleScanPermissionResult(
            bluetoothOn: true,
            permissionsGranted: true,
            requiresLocationService: false,
            locationServiceEnabled: false,
          ),
          BleScanPermissionResult.granted,
        );
      },
    );

    test('returns bluetoothOff after permissions and services are ready', () {
      expect(
        decideBleScanPermissionResult(
          bluetoothOn: false,
          permissionsGranted: true,
          requiresLocationService: true,
          locationServiceEnabled: true,
        ),
        BleScanPermissionResult.bluetoothOff,
      );
    });
  });

  group('appleScanPermissionResult', () {
    test('reports only states that certainly block a scan', () {
      expect(
        appleScanPermissionResult(BluetoothAdapterState.off),
        BleScanPermissionResult.bluetoothOff,
      );
      expect(
        appleScanPermissionResult(BluetoothAdapterState.unauthorized),
        BleScanPermissionResult.permissionDenied,
      );
    });

    test('lets the scan run for every other state', () {
      for (final state in const [
        BluetoothAdapterState.on,
        BluetoothAdapterState.unknown,
        BluetoothAdapterState.unavailable,
        BluetoothAdapterState.turningOn,
        BluetoothAdapterState.turningOff,
      ]) {
        expect(
          appleScanPermissionResult(state),
          BleScanPermissionResult.granted,
          reason: state.name,
        );
      }
    });
  });

  group('isWithinBinaryMinGap', () {
    test('skips a tick right after a forced send', () {
      // Release forced at t=1000, stick moves on the tick at t=1005.
      expect(isWithinBinaryMinGap(nowMs: 1005, lastSendMs: 1000), isTrue);
    });

    test('never skips the regular 25 ms joystick tick', () {
      expect(isWithinBinaryMinGap(nowMs: 1025, lastSendMs: 1000), isFalse);
      expect(
        isWithinBinaryMinGap(nowMs: 1000 + kBinaryMinGapMs, lastSendMs: 1000),
        isFalse,
      );
    });
  });
}
