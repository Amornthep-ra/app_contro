// lib/features/controller/controller_home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/language_controller.dart';
import '../../core/widgets/gamepad_app_bar.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../gamepad/gamepad_mode_edit.dart';
import '../info/info_page.dart';
import '../joystick/joystick/presentation/joystick.dart';

class ControllerHomePage extends StatefulWidget {
  const ControllerHomePage({super.key});

  @override
  State<ControllerHomePage> createState() => _ControllerHomePageState();
}

class _ControllerHomePageState extends State<ControllerHomePage> {
  StreamSubscription<bool>? _connSub;
  bool _connected = false;
  bool _openingMode = false;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _connected = BleManager.instance.isConnected;
    _connSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() => _connected = connected);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  String _connectedName() {
    final name = BleManager.instance.currentDeviceName;
    if (name != null && name.isNotEmpty) return name;
    final id = BleManager.instance.currentDeviceId;
    if (id != null && id.isNotEmpty) return id;
    return 'Unknown';
  }

  Future<void> _openMode(_ControlMenuItem item) async {
    if (_openingMode) return;
    setState(() => _openingMode = true);
    HapticFeedback.selectionClick();
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.page),
      );
    } finally {
      if (mounted) {
        setState(() => _openingMode = false);
      }
    }
  }

  Future<void> _reconnectLastDevice() async {
    if (_reconnecting || _connected) return;
    setState(() => _reconnecting = true);
    HapticFeedback.selectionClick();
    try {
      await BleManager.instance.autoConnectLastDevice(
        source: 'control_modes_reconnect',
      );
    } finally {
      if (mounted) {
        setState(() => _reconnecting = false);
      }
    }
  }

  Widget _buildReconnectChild(bool isThai) {
    final label = _reconnecting
        ? (isThai ? 'เชื่อมต่อ...' : 'Connecting...')
        : (isThai ? 'เชื่อมต่ออีกครั้ง' : 'Reconnect');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_reconnecting) ...[
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
        ],
        Text(label),
      ],
    );
  }

  Widget _buildPlainBackButton() {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.maybePop(context);
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 28,
                color: scheme.onSurface.withAlpha(216),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = _modeItems(isThai);
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: GamepadUnifiedAppBar(
            leading: _buildPlainBackButton(),
            title: isThai ? 'โหมดการควบคุม' : 'Control Modes',
            centerTitle: true,
            titleStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: scheme.onSurface,
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionBar(context, isThai),
                const SizedBox(height: 14),
                _buildModeGrid(context, items),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ControlMenuItem> _modeItems(bool isThai) {
    return [
      _ControlMenuItem(
        title: isThai ? 'Gamepad Mode Edit' : 'Gamepad Mode Edit',
        subtitle: isThai
            ? 'ควบคุม 8 ปุ่ม ปรับแต่งตำแหน่งได้'
            : '8-button layout with editable controls',
        iconBuilder: (_) => const _ControlModeAssetIcon(
          assetPath: 'assets/icons/control_mode_gamepad_8.png',
        ),
        accent: const Color(0xFF8B5CF6),
        page: const GamepadModeEdit(),
      ),
      _ControlMenuItem(
        title: isThai ? 'Gamepad (4 Buttons)' : 'Gamepad (4 Buttons)',
        subtitle: isThai
            ? 'ควบคุมทิศทางแบบ 4 ปุ่ม'
            : 'Simple 4-button directional control',
        iconBuilder: (_) => const _ControlModeAssetIcon(
          assetPath: 'assets/icons/control_mode_gamepad_4.png',
        ),
        accent: const Color(0xFF3B82F6),
        page: const Gamepad4ButtonPage(),
      ),
      _ControlMenuItem(
        title: isThai ? 'Joystick Mode' : 'Joystick Mode',
        subtitle:
            isThai ? 'ควบคุมด้วยสติ๊กอิสระ' : 'Free-form analog stick control',
        iconBuilder: (_) => const _ControlModeAssetIcon(
          assetPath: 'assets/icons/control_mode_joystick.png',
        ),
        accent: const Color(0xFF6D28D9),
        page: const JoystickPage(),
      ),
      _ControlMenuItem(
        title: isThai ? 'คู่มือ' : 'Guide',
        subtitle: isThai ? 'วิธีใช้งานและการตั้งค่า' : 'Usage and setup guide',
        iconBuilder: (_) => const _ControlModeAssetIcon(
          assetPath: 'assets/icons/control_mode_guide.png',
        ),
        accent: const Color(0xFF06B6D4),
        page: const InfoPage(),
      ),
    ];
  }

  Widget _buildConnectionBar(BuildContext context, bool isThai) {
    final scheme = Theme.of(context).colorScheme;
    final connected = _connected;
    final statusColor = connected ? const Color(0xFF22C55E) : scheme.error;
    final text = connected
        ? (isThai
            ? 'เชื่อมต่ออยู่กับ: ${_connectedName()}'
            : 'Connected to: ${_connectedName()}')
        : (isThai ? 'ยังไม่ได้เชื่อมต่อ' : 'Not connected');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: connected ? scheme.onSurface : scheme.error,
                  ),
                ),
              ),
            ),
            if (!connected)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: FilledButton.tonal(
                  key: ValueKey<bool>(_reconnecting),
                  onPressed: _reconnecting ? null : _reconnectLastDevice,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle:
                        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: _buildReconnectChild(isThai),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeGrid(BuildContext context, List<_ControlMenuItem> items) {
    const cardHeight = 108.0;
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          SizedBox(
            width: double.infinity,
            child: _ControlMenuCard(
              item: items[i],
              height: cardHeight,
              enabled: !_openingMode,
              onTap: () => _openMode(items[i]),
            ),
          ),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ControlMenuItem {
  final String title;
  final String subtitle;
  final Widget Function(Color accent) iconBuilder;
  final Color accent;
  final Widget page;

  const _ControlMenuItem({
    required this.title,
    required this.subtitle,
    required this.iconBuilder,
    required this.accent,
    required this.page,
  });
}

class _ControlMenuCard extends StatefulWidget {
  final _ControlMenuItem item;
  final double height;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlMenuCard({
    required this.item,
    required this.height,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ControlMenuCard> createState() => _ControlMenuCardState();
}

class _ControlMenuCardState extends State<_ControlMenuCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.item.accent;
    final glowColor = accent.withAlpha(isDark ? 74 : 44);
    final glowBlur = isDark ? 13.0 : 9.0;
    final glowSpread = isDark ? 1.0 : 0.0;

    final gradient = LinearGradient(
      colors: [
        accent.withAlpha(20),
        accent.withAlpha(7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1.0 : 0.62,
        duration: const Duration(milliseconds: 120),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shadowColor: accent.withAlpha(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.enabled ? widget.onTap : null,
            onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: Ink(
              height: widget.height,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withAlpha(80),
                  width: 0.8,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: glowColor,
                                      blurRadius: glowBlur,
                                      spreadRadius: glowSpread,
                                    ),
                                  ],
                                ),
                                child: const SizedBox(width: 24, height: 24),
                              ),
                              widget.item.iconBuilder(accent),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: accent.withAlpha(isDark ? 150 : 120),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: Text(
                        widget.item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlModeAssetIcon extends StatelessWidget {
  final String assetPath;

  const _ControlModeAssetIcon({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
    );
  }
}
