// lib/features/controller/controller_home_page.dart
import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/routes/app_routes.dart';
import '../../core/ui/language_controller.dart';
import '../../core/widgets/logo_corner.dart';
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

  Widget _homeIcon(String name, {double size = 24}) {
    return Image.asset(
      'assets/icons/Home/$name',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = _modeItems(isThai);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isThai ? 'โหมดการควบคุม' : 'Control Modes',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            centerTitle: false,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: _homeIcon('Guide-Manual.png', size: 22),
                tooltip: isThai ? 'คู่มือ' : 'Guide',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InfoPage()),
                ),
              ),
            ],
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint,
            scrolledUnderElevation: 2,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConnectionBar(context, isThai),
                    const SizedBox(height: 14),
                    _buildModeGrid(context, items),
                  ],
                ),
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
      },
    );
  }

  List<_ModeItem> _modeItems(bool isThai) {
    return [
      _ModeItem(
        title: isThai ? 'Gamepad Mode Edit' : 'Gamepad Mode Edit',
        subtitle: isThai
            ? 'ปุ่มกดมาตรฐาน 8 ทิศทาง (ปรับแต่งได้)'
            : 'Standard 8-direction buttons (customizable)',
        icon: Icons.tune,
        accent: const Color(0xFF8B5CF6),
        page: const GamepadModeEdit(),
      ),
      _ModeItem(
        title: isThai ? 'Gamepad (4 Buttons)' : 'Gamepad (4 Buttons)',
        subtitle: isThai
            ? 'ปุ่มกดมาตรฐาน 4 ทิศทาง'
            : 'Standard 4-direction buttons',
        icon: Icons.grid_on,
        accent: const Color(0xFF3B82F6),
        page: const Gamepad4ButtonPage(),
      ),
      _ModeItem(
        title: isThai ? 'Joystick Mode' : 'Joystick Mode',
        subtitle: isThai ? 'บังคับทิศทางอิสระ' : 'Free-form joystick control',
        icon: Icons.sports_esports,
        accent: const Color(0xFF6D28D9),
        page: const JoystickPage(),
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: connected ? scheme.onSurface : scheme.error,
                ),
              ),
            ),
            if (!connected)
              OutlinedButton(
                onPressed: () => BleManager.instance.autoConnectLastDevice(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: Text(isThai ? 'เชื่อมต่ออีกครั้ง' : 'Reconnect'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeGrid(BuildContext context, List<_ModeItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final width = constraints.maxWidth;
        final half = (width - spacing) / 2;
        final singleColumn = half < 160;

        return Column(
          children: [
            if (singleColumn) ...[
              SizedBox(
                width: width,
                child: _ModeCard(item: items[0], height: 170, wide: true),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: width,
                child: _ModeCard(item: items[1], height: 170, wide: true),
              ),
            ] else
              Row(
                children: [
                  SizedBox(
                    width: half,
                    child: _ModeCard(item: items[0], height: 180),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: half,
                    child: _ModeCard(item: items[1], height: 180),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: width,
              child: _ModeCard(item: items[2], height: 160, wide: true),
            ),
          ],
        );
      },
    );
  }
}

class _ModeItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget page;

  const _ModeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.page,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeItem item;
  final double height;
  final bool wide;

  const _ModeCard({
    required this.item,
    required this.height,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = item.accent;

    final gradient = LinearGradient(
      colors: [
        accent.withAlpha(28),
        accent.withAlpha(10),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Card(
      elevation: 3,
      shadowColor: accent.withAlpha(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.page),
        ),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(36),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, size: 28, color: accent),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Image.asset(
                        'assets/icons/Home/Chevron-Forward.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  maxLines: wide ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

