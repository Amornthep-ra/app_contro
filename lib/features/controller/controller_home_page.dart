// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/routes/app_routes.dart';
import '../../core/ui/language_controller.dart';

import '../gamepad/gamepad_mode_edit.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../joystick/joystick/presentation/joystick.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import '../info/info_page.dart';

class ControllerHomePage extends StatelessWidget {
  const ControllerHomePage({super.key});
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        actions: const [],
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
          ValueListenableBuilder<bool>(
            valueListenable: LanguageController.isThai,
            builder: (context, isThai, _) {
              final items = <_MenuItem>[
                _MenuItem(
                  'Gamepad Mode Edit',
                  Icons.tune,
                  const GamepadModeEdit(),
                  isThai ? 'ควบคุมสองฝั่ง 8 ปุ่ม' : 'Dual-side 8-button control',
                ),
                _MenuItem(
                  'Gamepad (4 Button)',
                  Icons.grid_on,
                  const Gamepad4ButtonPage(),
                  isThai ? 'ควบคุมสองฝั่ง 4 ปุ่ม' : 'Dual-side 4-button control',
                ),
                _MenuItem(
                  'Joystick',
                  Icons.sports_esports,
                  const JoystickPage(),
                  isThai ? 'ควบคุมแบบ Joystick' : 'Joystick control',
                ),
                _MenuItem(
                  'Bluetooth Low Energy (BLE)',
                  Icons.bluetooth,
                  const BluetoothBlePage(),
                  isThai ? 'สแกน/เชื่อมต่ออุปกรณ์ BLE' : 'Scan/connect BLE devices',
                ),
                _MenuItem(
                  'Guide',
                  Icons.info_outline,
                  const InfoPage(),
                  isThai ? 'ตัวอย่างและวิธีใช้งาน BLE' : 'Examples and BLE usage',
                ),
              ];
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, i) {
                  return Divider(
                    height: 1,
                    color: _opacity(Colors.black, 0.08),
                    indent: 72,
                    endIndent: 12,
                  );
                },
                itemBuilder: (ctx, i) {
                  final it = items[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: it.icon != null
                        ? Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              it.icon,
                              size: 26,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const SizedBox(width: 44),
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
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ),
                    minLeadingWidth: 52,
                    horizontalTitleGap: 14,
                    trailing: const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: Color(0xFFB5B5B9),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => it.page),
                    ),
                  );
                },
              );
            },
          ),
          const LogoCorner(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab_controller',
        mini: true,
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        ),
        child: const Icon(Icons.home),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class _MenuItem {
  final String title;
  final IconData? icon;
  final Widget page;
  final String subtitle;

  const _MenuItem(
    this.title,
    this.icon,
    this.page,
    this.subtitle,
  );
}

