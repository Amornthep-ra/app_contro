import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_permissions.dart';

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
}
