// lib/pages/home_page.dart
import 'package:flutter/material.dart';

import '../../core/ui/app_assets.dart';
import '../../widgets/logo_corner.dart';
import '../../core/ble/ble_manager.dart';

// import pages
import '../gamepad/gamepad_8Botton_page.dart';
import '../gamepad/gamepad_4Botton_page.dart';
import '../joystick/mode1_dual_joystick.dart';
import '../bluetooth/bluetooth_ble_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem(
        'Gamepad(8 Button)',
        null,
        const Gamepad_8Botton(),
        'ควบคุมสองฝั่ง 8 ปุ่ม',
        asset: AppAssets.menuGamepad8,
      ),
      _MenuItem(
        'Gamepad(4 Button)',
        null,
        const Gamepad_4Botton(),
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
      _MenuItem('About', Icons.info, const AboutPage(), 'PrinceBot Controller'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PrinceBot Controller',
          style: TextStyle(
            fontSize: 24, // ✅ ปรับขนาดตรงนี้
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        /// ⭐ AppBar Style เฉพาะหน้า Home
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
          /// ------------------------
          ///      เมนูปกติ
          /// ------------------------
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
                    ? Image.asset(
                        it.asset!,
                        width: 44, // ✅ ไอคอน asset ใหญ่ขึ้น
                        height: 44,
                      )
                    : (it.icon != null
                          ? Icon(
                              it.icon,
                              size: 40, // ✅ icon ปกติใหญ่ขึ้น
                            )
                          : const SizedBox(width: 44)),

                title: Text(
                  it.title,
                  style: const TextStyle(
                    fontSize: 18, // ✅ ตัวหัวใหญ่ขึ้น
                    fontWeight: FontWeight.w600,
                  ),
                ),

                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    it.subtitle,
                    style: TextStyle(
                      fontSize: 14, // ✅ ตัวรองใหญ่ขึ้น
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                minLeadingWidth: 52, // ✅ กันแนวไอคอนชิดเกินไป
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

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),

        /// ⭐ AppBar Style หน้า About
        centerTitle: true,
        elevation: 5,
        shadowColor: Colors.black45,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00A1FF), Color(0xFF0064C8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),

      body: const Center(child: Text('PrinceBot Controller v1.0 — BLE Mode')),
    );
  }
}
