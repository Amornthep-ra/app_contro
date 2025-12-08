// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import '../../core/ui/app_assets.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/ble/ble_manager.dart';

import '../gamepad/gamepad_8_button_page.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../joystick/joystick/presentation/mode1_dual_joystick.dart';
import '../bluetooth/bluetooth_ble_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem(
        'Gamepad(8 Button)',
        null,
        const Gamepad_8_Botton(),
        'ควบคุมสองฝั่ง 8 ปุ่ม',
        asset: AppAssets.menuGamepad8,
      ),
      _MenuItem(
        'Gamepad(4 Button)',
        null,
        const Gamepad_4_Botton(),
        'ควบคุมสองฝั่ง 4 ปุ่ม',
        asset: AppAssets.menuGamepad4,
      ),
      _MenuItem(
        'Joystick',
        Icons.gamepad,
        const Mode1DualJoystickPage(),
        'ควบคุมแบบจอย',
        asset: AppAssets.menuJoystick,
      ),
      _MenuItem(
        'Bluetooth (BLE)',
        Icons.bluetooth,
        const BluetoothBlePage(),
        'สแกน/เชื่อมต่ออุปกรณ์ BLE',
        asset: AppAssets.menuBluetooth,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PB Controller',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 5,
        shadowColor: Colors.black54,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0083FF), Color(0xFF0051A8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final it = items[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: it.asset != null
                    ? Image.asset(it.asset!, width: 44, height: 44)
                    : (it.icon != null
                          ? Icon(it.icon, size: 40)
                          : const SizedBox(width: 44)),
                title: Text(
                  it.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    it.subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
                minLeadingWidth: 52,
                horizontalTitleGap: 14,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => it.page),
                ),
              );
            },
          ),
          const LogoCorner(),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData? icon;
  final Widget page;
  final String subtitle;
  final String? asset;

  const _MenuItem(
    this.title,
    this.icon,
    this.page,
    this.subtitle, {
    this.asset,
  });
}

