// lib/features/linesonic/widgets/linesonic_scaffold.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/lavender_glass.dart';
import '../../../core/widgets/cat_back_button.dart';
import '../../../core/widgets/connection_status_badge.dart';
import '../../../core/widgets/gamepad_control_toolbar.dart';
import '../../../core/widgets/portrait_background.dart';

/// Shared page frame for the LineSonic pages (hub, PID Tuning, Read Sensor).
///
/// Cat Back on the left, a Kanit title that scales down instead of being cut
/// off, the Bluetooth badge on the right, and a frosted strip that fades in
/// once content scrolls under the header. An optional [bottomBar] sits below
/// the scrolling body and hides while the keyboard is up.
class LineSonicScaffold extends StatefulWidget {
  const LineSonicScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.badge,
  });

  static const double toolbarHeight = 56;
  static const double pagePadding = 16;

  /// Top padding for scrolling content so it starts under the header.
  static double contentTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top + toolbarHeight + 8;

  final String title;
  final Widget body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Replaces the default [LineSonicBleBadge] (tests).
  final Widget? badge;

  @override
  State<LineSonicScaffold> createState() => _LineSonicScaffoldState();
}

class _LineSonicScaffoldState extends State<LineSonicScaffold> {
  bool _scrolled = false;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final scrolled = notification.metrics.pixels > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomBar = widget.bottomBar;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: LavenderPalette.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: LineSonicScaffold.toolbarHeight,
        leadingWidth: CatBackButton.leadingWidthFor(
          LineSonicScaffold.pagePadding,
        ),
        leading: Navigator.of(context).canPop()
            ? CatBackButton.leading()
            : null,
        centerTitle: true,
        titleSpacing: 8,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.title,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: LavenderPalette.displayFont,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: LavenderPalette.ink,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: LineSonicScaffold.pagePadding,
            ),
            child: Center(child: widget.badge ?? const LineSonicBleBadge()),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: LavenderPalette.ink,
        flexibleSpace: FrostedBarBackground(visible: _scrolled),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: PortraitBackground(
        child: BackdropGroup(
          child: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScroll,
                  child: widget.body,
                ),
              ),
              if (bottomBar != null && !keyboardUp) bottomBar,
            ],
          ),
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

/// The shared Bluetooth badge (opens the BLE status sheet) drawn as the
/// controller toolbar's pill, with short labels so the title keeps its room.
class LineSonicBleBadge extends StatelessWidget {
  const LineSonicBleBadge({super.key, this.badge});

  /// Replaces the [ConnectionStatusBadge] inside the pill frame (tests).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final visualHeight = math.max(30.0, scaler.scale(12) + 12);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = math.max(96.0, math.min(200.0, screenWidth * 0.46));
    return GamepadControlScope(
      layout: GamepadControlLayout(
        const [0],
        const [
          [0],
        ],
        math.max(48, visualHeight),
        visualHeight,
        GamepadControlLayout.edgeActionGap,
        compactBle: true,
      ),
      child: SizedBox(
        height: 48,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 48, maxWidth: maxWidth),
          child: IntrinsicWidth(child: badge ?? const ConnectionStatusBadge()),
        ),
      ),
    );
  }
}
