package com.pbcontroller.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.pbcontroller.app/bluetooth_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openBluetoothSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }
}
