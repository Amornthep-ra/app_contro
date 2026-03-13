// lib/core/ui/custom_appbars.dart
import 'dart:ui';

import 'package:flutter/material.dart';

Color _appBarOpacity(Color color, double opacity) =>
    color.withAlpha((opacity * 255).round());

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
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'PrinceBot Controller',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
  final Widget? toolbarContent;
  final List<Widget>? actions;
  final Widget? leading;
  final double? leadingWidth;
  final PreferredSizeWidget? bottom;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry toolbarPadding;

  static const double _barHeight = 48;

  const JoystickAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.toolbarContent,
    this.actions,
    this.leading,
    this.leadingWidth,
    this.bottom,
    this.gradientColors,
    this.toolbarPadding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(_barHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        isDark
            ? _appBarOpacity(const Color(0xFF111827), 0.94)
            : _appBarOpacity(
                Color.lerp(const Color(0xFFF8FAFC), cs.surface, 0.55) ??
                    cs.surface,
                0.97,
              );
    final border = _appBarOpacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      isDark ? 0.28 : 0.16,
    );
    final topLine = _appBarOpacity(Colors.white, isDark ? 0.1 : 0.45);
    final bottomLine = _appBarOpacity(
      isDark ? const Color(0xFF38BDF8) : cs.outline,
      isDark ? 0.32 : 0.18,
    );
    final content = toolbarContent;
    return AppBar(
      toolbarHeight: _barHeight,
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      iconTheme: IconThemeData(color: cs.onSurface),
      actionsIconTheme: IconThemeData(color: cs.onSurface),
      leading: content == null ? leading : null,
      leadingWidth: content == null ? leadingWidth : null,
      actions: content == null ? actions : null,
      centerTitle: content == null,
      bottom: bottom,
      titleSpacing: content == null ? NavigationToolbar.kMiddleSpacing : 0,
      title: content != null
          ? Padding(padding: toolbarPadding, child: content)
          : titleWidget ??
               Text(
                 title,
                 style: TextStyle(
                   fontSize: 16,
                   fontWeight: FontWeight.w700,
                   color: cs.onSurface,
                 ),
               ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              border: Border(
                top: BorderSide(color: topLine, width: 0.8),
                bottom: BorderSide(color: border, width: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: _appBarOpacity(Colors.black, isDark ? 0.24 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(height: 1, color: bottomLine),
            ),
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
  final List<Color>? gradientColors;

  static const double _barHeight = 48;

  const GamepadAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.gradientColors,
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
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      leading: leading,
      actions: actions,
      bottom: bottom,
      title: titleWidget ??
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors ??
                [
                  const Color.fromARGB(255, 177, 97, 252),
                  const Color.fromARGB(255, 232, 157, 255),
                ],
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
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final List<Color>? gradientColors;

  static const double _barHeight = 48;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.gradientColors,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _barHeight,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      leading: leading,
      leadingWidth: leadingWidth,
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
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors ??
                [Colors.grey.shade900, Colors.grey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}


