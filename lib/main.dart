// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'gamepad_8Botton_page.dart';
import 'gamepad_4Botton_page.dart';
import 'bluetooth_ble_page.dart';

import 'widgets/logo_corner.dart';
import 'UI/app_assets.dart';   // ใช้ Asset จากไฟล์ที่คุณให้มา

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);

    return MaterialApp(
      title: 'PrinceBot Controller',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const MenuPage(),
        '/Gamepad_8Botton': (_) => const Gamepad_8Botton(),
        '/Gamepad_4Botton': (_) => const Gamepad_4Botton(),
        '/bluetooth': (_) => const BluetoothBlePage(),
      },
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem(
        'Gamepad(8 Button)',
        null,
        '/Gamepad_8Botton',
        'ควบคุมสองฝั่ง 8 ปุ่ม',
        asset: AppAssets.menuGamepad8,
      ),
      _MenuItem(
        'Gamepad(4 Button)',
        null,
        '/Gamepad_4Botton',
        'ควบคุมสองฝั่ง 4 ปุ่ม',
        asset: AppAssets.menuGamepad4,
      ),

      // ใช้ BLE สำหรับทุก Platform
      _MenuItem(
        'Bluetooth (BLE)',
        Icons.bluetooth,
        '/bluetooth',
        'สแกน/เชื่อมต่ออุปกรณ์ BLE',
        asset: AppAssets.menuBluetooth,
      ),

      _MenuItem('About', Icons.info, '/about', 'PrinceBot Controller'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('PrinceBot Controller')),
      body: Stack(
        children: [
          ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final it = items[i];
              return ListTile(
                leading: it.asset != null
                    ? Image.asset(it.asset!, width: 32, height: 32)
                    : (it.icon != null
                        ? Icon(it.icon)
                        : const SizedBox(width: 32)),
                title: Text(it.title),
                subtitle: Text(it.subtitle),
                onTap: () {
                  if (it.route == '/about') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  } else {
                    Navigator.pushNamed(context, it.route);
                  }
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
  final String title, route, subtitle;
  final IconData? icon;
  final String? asset;
  const _MenuItem(
    this.title,
    this.icon,
    this.route,
    this.subtitle, {
    this.asset,
  });
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(
        child: Text('PrinceBot Controller v1.0 — BLE Mode'),
      ),
    );
  }
}
