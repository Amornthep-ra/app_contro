// lib/core/ui/custom_appbars.dart
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 4,
      backgroundColor: Colors.deepPurple.shade600,
      shadowColor: Colors.black38,
      title: const Text(
        'PrinceBot Controller',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }
}

class BleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  static const double _barHeight = 48;

  const BleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _barHeight,
      elevation: 0,
      backgroundColor: Colors.transparent,
      actions: actions,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      bottom: bottom,
      flexibleSpace: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E2A78), Color(0xFF243B94), Color(0xFF4263EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class JoystickAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  static const double _barHeight = 40;

  const JoystickAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _barHeight,
      elevation: 3,
      backgroundColor: Colors.blueGrey.shade800,
      leading: leading,
      actions: actions,
      centerTitle: true,
      title: titleWidget ??
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class GamepadAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  static const double _barHeight = 32;

  const GamepadAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _barHeight,
      elevation: 4,
      centerTitle: centerTitle,
      backgroundColor: Colors.teal.shade700,
      leading: leading,
      actions: actions,
      bottom: bottom,
      title: titleWidget ??
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color.fromARGB(255, 177, 97, 252), const Color.fromARGB(255, 232, 157, 255)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;

  static const double _barHeight = 48;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _barHeight,
      elevation: 0,
      backgroundColor: Colors.grey.shade900,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
      title: titleWidget ??
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
    );
  }
}
