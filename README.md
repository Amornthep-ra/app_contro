# PB Controller

Flutter controller app for PrinceBot over Bluetooth Low Energy (BLE). Supported
release platforms are Android and iOS. Web, Windows, macOS, and Linux builds
are intentionally not supported.

## Android release signing

Release APK and App Bundle builds require a private Android keystore. The
keystore and its credentials must never be committed.

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Set `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` in the new
   file. `storeFile` may be absolute or relative to the `android/` directory.
3. Build the desired artifact:

   ```sh
   flutter build apk --release
   flutter build appbundle --release
   ```

The build stops with a setup error if the file, any required property, or the
keystore path is missing. In CI, create `android/key.properties` from secret
values before invoking either release build command.

## iOS release signing

Build and archive iOS releases on macOS with Xcode signing configured for the
target Apple Developer team. CI must provide the signing certificate,
provisioning profile, and App Store Connect credentials; none are stored in
this repository.
