// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/ui/theme_controller.dart';
import '../../core/ui/language_controller.dart';

import '../gamepad/gamepad_mode_edit.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../joystick/joystick/presentation/joystick.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import '../info/info_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  Color _opacity(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());

  @override
  Widget build(BuildContext context) {
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
        leadingWidth: 96,
        leading: ValueListenableBuilder<bool>(
          valueListenable: LanguageController.isThai,
          builder: (context, isThai, _) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ToggleButtons(
                isSelected: [!isThai, isThai],
                onPressed: (index) {
                  LanguageController.setIsThai(index == 1);
                },
                borderRadius: BorderRadius.circular(8),
                color: Colors.white70,
                selectedColor: Colors.white,
                fillColor: Colors.white24,
                constraints:
                    const BoxConstraints(minHeight: 24, minWidth: 32),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('EN',
                        style:
                            TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('TH',
                        style:
                            TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens_outlined, color: Colors.white),
            onPressed: () => _showThemeSheet(context),
            tooltip: 'Theme',
          ),
        ],
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
                  isThai ? 'Gamepad Mode Edit' : 'Gamepad Mode Edit',
                  Icons.tune,
                  const GamepadModeEdit(),
                  isThai ? 'ควบคุมสองฝั่ง 8 ปุ่ม' : 'Dual-side 8-button control',
                ),
                _MenuItem(
                  isThai ? 'Gamepad(4 Button)' : 'Gamepad (4 Button)',
                  Icons.grid_on,
                  const Gamepad4ButtonPage(),
                  isThai ? 'ควบคุมสองฝั่ง 4 ปุ่ม' : 'Dual-side 4-button control',
                ),
                _MenuItem(
                  isThai ? 'Joystick' : 'Joystick',
                  Icons.sports_esports,
                  const JoystickPage(),
                  isThai ? 'ควบคุมแบบจอย' : 'Joystick control',
                ),
                _MenuItem(
                  isThai ? 'Bluetooth Low Energy (BLE)' : 'Bluetooth Low Energy (BLE)',
                  Icons.bluetooth,
                  const BluetoothBlePage(),
                  isThai ? 'สแกน/เชื่อมต่ออุปกรณ์ BLE' : 'Scan/connect BLE devices',
                ),
                _MenuItem(
                  isThai ? 'Guide' : 'Guide',
                  Icons.info_outline,
                  const InfoPage(),
                  isThai
                      ? 'ตัวอย่างโค้ดและวิธีใช้งาน BLE'
                      : 'Examples and BLE usage',
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

void _showThemeSheet(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return CupertinoActionSheet(
        title: const Text('Theme'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.light);
              Navigator.of(context).pop();
            },
            child: const Text('Light'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.dark);
              Navigator.of(context).pop();
            },
            child: const Text('Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      );
    },
  );
}
