// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'pages/home_page.dart';               // ⭐ NEW
import 'pages/joystick_control_page.dart';
import 'pages/gamepad_8Botton_page.dart';
import 'pages/gamepad_4Botton_page.dart';
import 'pages/bluetooth_ble_page.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomePage(),   // ⭐ ใช้หน้าเมนูใหม่
    );
  }
}
