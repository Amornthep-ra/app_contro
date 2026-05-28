// lib/features/home/home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/app_assets.dart';
import '../../core/ui/language_controller.dart';
import '../../core/ui/theme_controller.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import '../controller/controller_home_page.dart';
import '../info/info_page.dart';
import '../linesonic/linesonic_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<bool>? _connSub;
  Timer? _rssiTimer;
  Future<PackageInfo>? _infoFuture;

  bool _connected = false;
  bool _openingPage = false;
  int? _rssi;
  String? _lastDeviceId;
  String? _lastDeviceName;

  static const _prefsLastDeviceIdKey = 'ble_last_device_id';
  static const _prefsLastDeviceNameKey = 'ble_last_device_name';

  @override
  void initState() {
    super.initState();
    _connected = BleManager.instance.isConnected;
    _infoFuture = PackageInfo.fromPlatform();
    _loadLastDevice();
    _bindConnection();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _rssiTimer?.cancel();
    super.dispose();
  }

  void _bindConnection() {
    _connSub = BleManager.instance.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _connected = connected;
      });
      if (connected) {
        _startRssiPolling();
        _loadLastDevice();
      } else {
        _stopRssiPolling();
      }
    });

    if (_connected) {
      _startRssiPolling();
    }
  }

  Future<void> _loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsLastDeviceIdKey);
    final name = prefs.getString(_prefsLastDeviceNameKey);
    if (!mounted) return;
    setState(() {
      _lastDeviceId = id;
      _lastDeviceName = name;
    });
  }

  void _startRssiPolling() {
    _rssiTimer?.cancel();
    _pollRssi();
    _rssiTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollRssi();
    });
  }

  void _stopRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
    if (!mounted) return;
    setState(() => _rssi = null);
  }

  Future<void> _pollRssi() async {
    final value = await BleManager.instance.readRssi();
    if (!mounted) return;
    setState(() => _rssi = value);
  }

  Future<void> _openBlePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BluetoothBlePage()),
    );
    await _loadLastDevice();
  }

  Future<void> _openPage(Widget page) async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      );
    } finally {
      if (mounted) {
        setState(() => _openingPage = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _openBlePage();
  }

  Future<void> _connectLastDevice(bool isThai) async {
    if (_lastDeviceId == null || _lastDeviceId!.isEmpty) return;
    _showSnack(
      isThai ? 'กำลังเชื่อมต่ออุปกรณ์ล่าสุด...' : 'Reconnecting to the last device...',
    );
    await BleManager.instance.autoConnectLastDevice();
  }
  void _showSnack(String msg) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _connectedName() {
    final name = BleManager.instance.currentDeviceName;
    if (name != null && name.isNotEmpty) return name;
    final id = BleManager.instance.currentDeviceId;
    if (id != null && id.isNotEmpty) return id;
    if (_lastDeviceName != null && _lastDeviceName!.isNotEmpty) {
      return _lastDeviceName!;
    }
    return _lastDeviceId ?? 'Unknown';
  }

  Color _rssiColor(BuildContext context, int rssi) {
    if (rssi >= -65) return const Color(0xFF22C55E);
    if (rssi >= -80) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _homeIcon(String name, {double size = 24}) {
    return Image.asset(
      'assets/icons/HomeUnified/$name',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _rssiBars(BuildContext context, int rssi, {double size = 16}) {
    final level = rssi >= -55
        ? 4
        : rssi >= -65
            ? 3
            : rssi >= -75
                ? 2
                : rssi >= -85
                    ? 1
                    : 0;
    final active = _rssiColor(context, rssi);
    final inactive = active.withAlpha(60);
    final barWidth = (size / 6).clamp(2.0, 5.0).toDouble();
    final gap = (size / 10).clamp(2.0, 4.0).toDouble();
    final heights = <double>[
      size * 0.35,
      size * 0.55,
      size * 0.75,
      size * 0.95,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final color = i < level ? active : inactive;
        return Container(
          width: barWidth,
          height: heights[i],
          margin: EdgeInsets.only(right: i == 3 ? 0 : gap),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = _navItems(isThai);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'PB Controller',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            centerTitle: false,
            titleSpacing: 16,
            automaticallyImplyLeading: false,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withAlpha(132),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withAlpha(88),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      _homeIcon('Translate-Language.png', size: 28),
                      const SizedBox(width: 2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Center(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('EN')),
                              ButtonSegment(value: true, label: Text('TH')),
                            ],
                            selected: {isThai},
                            onSelectionChanged: (value) {
                              LanguageController.setIsThai(value.first);
                            },
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity:
                                  const VisualDensity(horizontal: -3, vertical: -3),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              minimumSize: const Size(0, 30),
                              side: BorderSide(
                                color: scheme.outlineVariant.withAlpha(88),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  icon: _homeIcon('Theme-Palette.png', size: 22),
                  onPressed: () => _showThemeSheet(context),
                  tooltip: isThai ? 'ธีม' : 'Theme',
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ),
            ],
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint,
            scrolledUnderElevation: 2,
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _handleRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: _buildConnectionCard(context, isThai),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: _buildNavGrid(context, items),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _buildRecentCard(context, isThai),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: _buildVersionInfo(context),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_NavItem> _navItems(bool isThai) {
    return [
      _NavItem(
        title: isThai ? 'โหมดควบคุม' : 'Controller',
        subtitle: isThai
            ? 'ควบคุมทิศทางและจอยสติ๊ก'
            : 'Direction control and joysticks in one place',
        iconAsset: 'Controller-Gamepad.png',
        accent: const Color(0xFF2563EB),
        page: const ControllerHomePage(),
      ),
      _NavItem(
        title: isThai ? 'LineSonic' : 'LineSonic',
        subtitle: isThai
            ? 'ปรับ PID และอ่านเซนเซอร์ผ่าน BLE'
            : 'Tune PID motion over BLE',
        iconAsset: 'LineSonic-PID Tuning.png',
        accent: const Color(0xFF16A34A),
        page: const LineSonicPage(),
      ),
      _NavItem(
        title: isThai ? 'คู่มือการใช้งาน' : 'Guide',
        subtitle: isThai
            ? 'คู่มือและตัวอย่างโค้ด'
            : 'How to use the app and starter code',
        iconAsset: 'Guide-Manual.png',
        accent: const Color(0xFFF59E0B),
        page: const InfoPage(),
      ),
    ];
  }
  Widget _buildConnectionCard(BuildContext context, bool isThai) {
    final scheme = Theme.of(context).colorScheme;
    final connected = _connected;
    final name = _connectedName();
    final rssi = _rssi;
    final rssiText = rssi != null ? '$rssi dBm' : '-- dBm';

    final gradient = connected
        ? LinearGradient(
            colors: [
              scheme.primaryContainer.withAlpha(220),
              scheme.primaryContainer.withAlpha(120),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              scheme.surfaceContainerHighest.withAlpha(200),
              scheme.surfaceContainerHighest.withAlpha(120),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: connected
                        ? scheme.primary.withAlpha(32)
                        : scheme.outlineVariant.withAlpha(40),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: connected
                      ? _homeIcon('Bluetooth Connected.png', size: 24)
                      : _homeIcon('Bluetooth Disabled.png', size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isThai ? 'สถานะ BLE' : 'BLE Connection',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: isThai ? 15 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        connected
                            ? name
                            : (isThai ? 'ยังไม่เชื่อมต่อ' : 'No device'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (connected)
                        Row(
                          children: [
                            _rssiBars(context, rssi ?? -100, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              rssiText,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (!connected)
                  FilledButton.icon(
                    onPressed: _openBlePage,
                    icon: _homeIcon('Search-Scan.png', size: 21),
                    label: Text(isThai ? 'ค้นหา' : 'Scan devices'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  Column(
                    children: [
                      _rssiBars(context, rssi ?? -100, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        isThai ? 'สัญญาณ' : 'RSSI',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavGrid(BuildContext context, List<_NavItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final width = constraints.maxWidth;
        final half = (width - spacing) / 2;
        final singleColumn = half < 140;

        return Column(
          children: [
            if (singleColumn) ...[
              SizedBox(
                width: width,
                child: _NavCard(
                  item: items[0],
                  height: 160,
                  wide: true,
                  enabled: !_openingPage,
                  onTap: () => _openPage(items[0].page),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: width,
                child: _NavCard(
                  item: items[1],
                  height: 160,
                  wide: true,
                  enabled: !_openingPage,
                  onTap: () => _openPage(items[1].page),
                ),
              ),
            ] else
              Row(
                children: [
                  SizedBox(
                    width: half,
                    child: _NavCard(
                      item: items[0],
                      height: 170,
                      enabled: !_openingPage,
                      onTap: () => _openPage(items[0].page),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: half,
                    child: _NavCard(
                      item: items[1],
                      height: 170,
                      enabled: !_openingPage,
                      onTap: () => _openPage(items[1].page),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: width,
              child: _NavCard(
                item: items[2],
                height: 120,
                wide: true,
                enabled: !_openingPage,
                onTap: () => _openPage(items[2].page),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentCard(BuildContext context, bool isThai) {
    final scheme = Theme.of(context).colorScheme;
    final hasLast = _lastDeviceId != null && _lastDeviceId!.isNotEmpty;

    if (!hasLast) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              _homeIcon('Recent Activity-History.png', size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThai ? 'ยังไม่มีอุปกรณ์ล่าสุด' : 'No recent device yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _homeIcon('Recent Activity-History.png', size: 20),
                const SizedBox(width: 8),
                Text(
                  isThai ? 'อุปกรณ์ที่เชื่อมต่อล่าสุด' : 'Recent Activity',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasLast)
              Text(
                isThai
                    ? 'ยังไม่มีประวัติการเชื่อมต่อ'
                    : 'No recent device yet',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastDeviceName ?? _lastDeviceId ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastDeviceId ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _connectLastDevice(isThai),
                        child: Text(isThai ? 'เชื่อมต่ออีกครั้ง' : 'Reconnect'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openBlePage,
                        icon: _homeIcon('Search-Scan.png', size: 36),
                        label: Text(isThai ? 'ค้นหา' : 'Scan'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildVersionInfo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FutureBuilder<PackageInfo>(
        future: _infoFuture,
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '2.0.4';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.28,
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.cornerLogo,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'v$version',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem {
  final String title;
  final String subtitle;
  final String iconAsset;
  final Color accent;
  final Widget page;

  const _NavItem({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.accent,
    required this.page,
  });
}

class _NavCard extends StatefulWidget {
  final _NavItem item;
  final double height;
  final bool wide;
  final bool enabled;
  final VoidCallback onTap;

  const _NavCard({
    required this.item,
    required this.height,
    required this.enabled,
    required this.onTap,
    this.wide = false,
  });

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard> {
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

    final gradient = LinearGradient(
      colors: [
        accent.withAlpha(32),
        accent.withAlpha(14),
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
          elevation: 3,
          shadowColor: accent.withAlpha(60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.enabled ? widget.onTap : null,
            onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: Ink(
              height: widget.height,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 150 || constraints.maxHeight < 150;
                  final compactWide = widget.wide && constraints.maxHeight < 150;
                  final padding = compact
                      ? (compactWide
                          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                          : const EdgeInsets.fromLTRB(6, 6, 6, 6))
                      : const EdgeInsets.fromLTRB(16, 14, 16, 14);
                  final iconBox = compact
                      ? (compactWide ? 36.0 : 30.0)
                      : 44.0;
                  final iconSize = compact
                      ? (compactWide ? 24.0 : 18.0)
                      : 28.0;
                  final gapTop = compact
                      ? (compactWide ? 6.0 : 2.0)
                      : 12.0;
                  final gapMid = compact
                      ? (compactWide ? 2.0 : 0.0)
                      : 6.0;
                  final defaultTitleSize = 16.0;
                  final defaultSubtitleSize = 12.0;
                  final titleSize = defaultTitleSize;
                  final subtitleSize = defaultSubtitleSize;
                  final subtitleLines = compact ? 1 : (widget.wide ? 2 : 3);

                  return Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: iconBox,
                              height: iconBox,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(40),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.asset(
                                  'assets/icons/HomeUnified/${widget.item.iconAsset}',
                                  width: iconSize,
                                  height: iconSize,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: compact ? 18 : 22,
                              color: accent.withAlpha(isDark ? 130 : 100),
                            ),
                          ],
                        ),
                        SizedBox(height: gapTop),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: gapMid),
                        Text(
                          widget.item.subtitle,
                          maxLines: subtitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            height: compact ? 1.05 : 1.2,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showThemeSheet(BuildContext context) {
  final isThai = LanguageController.isThai.value;
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return CupertinoActionSheet(
        title: Text(isThai ? 'ธีม' : 'Theme'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.light);
              Navigator.of(context).pop();
            },
            child: Text(isThai ? 'สว่าง' : 'Light'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.dark);
              Navigator.of(context).pop();
            },
            child: Text(isThai ? 'มืด' : 'Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
        ),
      );
    },
  );
}
