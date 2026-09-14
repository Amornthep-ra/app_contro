// lib/features/home/home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ble/ble_connection_coordinator.dart';
import '../../core/ble/ble_presentation_state.dart';
import '../../core/ui/app_assets.dart';
import '../../core/ui/control_mode_preference.dart';
import '../../core/ui/language_controller.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/widgets/ble_presentation_icon.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../gamepad/gamepad_mode_edit.dart';
import '../joystick/joystick/presentation/joystick.dart';
import '../linesonic/linesonic_page.dart';

class _HomePalette {
  static const background = Color(0xFFF5F0FF);
  static const controller = Color(0xFF6F8FFF);
  static const lineSonic = Color(0xFF45D6A1);
  static const guide = Color(0xFFFFB56B);
  static const scanPurple = Color(0xFF7256B6);
  static const scanCyan = Color(0xFF37D8FF);
  static const deepPlum = Color(0xFF261B39);
  static const coral = Color(0xFFF05264);
  static const glass = Color(0xEAFDF9FF);
  static const glassBorder = Color(0xCCFFFFFF);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.blePageBuilder, this.blePresentationState});

  final WidgetBuilder? blePageBuilder;
  final ValueListenable<BlePresentationState>? blePresentationState;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<bool>? _connSub;
  Timer? _rssiTimer;
  Future<PackageInfo>? _infoFuture;
  late ValueListenable<BlePresentationState> _blePresentationState;
  BlePresentationStateController? _ownedBlePresentationState;

  bool _connected = false;
  bool _openingPage = false;
  int? _rssi;
  String? _lastDeviceId;
  String? _lastDeviceName;

  static const _prefsLastDeviceIdKey = 'ble_last_device_id';
  static const _prefsLastDeviceNameKey = 'ble_last_device_name';
  static final _facebookPageUri = Uri.parse(
    'https://www.facebook.com/PrinceBotAndElectronics',
  );

  @override
  void initState() {
    super.initState();
    unawaited(OrientationUtils.request(AppOrientation.portrait));
    _connected = BleManager.instance.isConnected;
    _infoFuture = PackageInfo.fromPlatform();
    _bindBlePresentationState();
    _loadLastDevice();
    _bindConnection();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _rssiTimer?.cancel();
    _blePresentationState.removeListener(_onBlePresentationChanged);
    _ownedBlePresentationState?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blePresentationState != widget.blePresentationState) {
      _blePresentationState.removeListener(_onBlePresentationChanged);
      _ownedBlePresentationState?.dispose();
      _bindBlePresentationState();
    }
  }

  void _bindBlePresentationState() {
    _ownedBlePresentationState = widget.blePresentationState == null
        ? BlePresentationStateController.production()
        : null;
    _blePresentationState =
        widget.blePresentationState ?? _ownedBlePresentationState!;
    _blePresentationState.addListener(_onBlePresentationChanged);
  }

  void _onBlePresentationChanged() {
    if (mounted) setState(() {});
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
      MaterialPageRoute(
        builder: widget.blePageBuilder ?? (_) => const BluetoothBlePage(),
      ),
    );
    await OrientationUtils.request(AppOrientation.portrait);
    await _loadLastDevice();
  }

  Future<void> _openPage(Widget page) async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } finally {
      await OrientationUtils.request(AppOrientation.portrait);
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
      isThai
          ? 'Reconnecting to the last device...'
          : 'Reconnecting to the last device...',
    );
    await BleConnectionCoordinator.instance.autoConnectLastDevice(
      timeout: const Duration(seconds: 8),
      source: 'home_reconnect',
      userInitiated: true,
    );
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

  Future<void> _openLastControl() async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    var modeSwitched = false;
    try {
      final mode = await ControlModePreference.load();
      if (!mounted) return;
      final page = switch (mode) {
        LastControlMode.fourButton => const Gamepad4ButtonPage(),
        LastControlMode.eightButton => const GamepadModeEdit(),
        LastControlMode.joystick => const JoystickPage(),
      };
      modeSwitched =
          await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => page)) ??
          false;
    } finally {
      if (!modeSwitched) {
        await OrientationUtils.request(AppOrientation.portrait);
      }
      if (mounted) {
        setState(() => _openingPage = false);
      }
    }
  }

  Future<void> _openNavItem(_NavItem item) =>
      item.onTap?.call() ?? _openPage(item.page!);

  Future<void> _openFacebookPage(bool isThai) async {
    try {
      final opened = await launchUrl(
        _facebookPageUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showSnack(
          isThai ? 'Unable to open Facebook.' : 'Unable to open Facebook.',
        );
      }
    } catch (_) {
      _showSnack(
        isThai ? 'Unable to open Facebook.' : 'Unable to open Facebook.',
      );
    }
  }

  Future<void> _openArduinoLibrary() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower.git'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showSnack('Unable to open the library link.');
    } catch (_) {
      _showSnack('Unable to open the library link.');
    }
  }

  Color _contentTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.onSurface
      : _HomePalette.deepPlum;

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
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = _navItems(isThai);
        final contentTopPadding =
            MediaQuery.paddingOf(context).top + kToolbarHeight + 16;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text(
              'PB Controller',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            centerTitle: false,
            titleSpacing: 16,
            automaticallyImplyLeading: false,
            actions: const [],
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: _HomePalette.background),
              Image.asset(
                AppAssets.controlBackgroundPortrait,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
              RefreshIndicator(
                onRefresh: _handleRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          contentTopPadding,
                          16,
                          12,
                        ),
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
        title: isThai ? 'Controller' : 'Controller',
        iconAsset: 'Controller-Gamepad.png',
        accent: _HomePalette.controller,
        onTap: _openLastControl,
      ),
      _NavItem(
        title: isThai ? 'LineSonic' : 'LineSonic',
        iconAsset: 'LineSonic-PID Tuning.png',
        accent: _HomePalette.lineSonic,
        page: const LineSonicPage(),
      ),
      _NavItem(
        title: isThai ? 'Contact' : 'Contact',
        subtitle: isThai ? 'Follow us on Facebook' : 'Follow us on Facebook',
        icon: Icons.facebook,
        accent: _HomePalette.guide,
        onTap: () => _openFacebookPage(isThai),
      ),
      _NavItem(
        title: 'Arduino IDE Library',
        subtitle: 'Download from GitHub',
        icon: Icons.download_rounded,
        accent: _HomePalette.guide,
        onTap: _openArduinoLibrary,
      ),
    ];
  }

  Widget _buildConnectionCard(BuildContext context, bool isThai) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presentation = _blePresentationState.value;
    final connected = presentation.isConnected;
    final tone = presentation.tone;
    final name = _connectedName();
    final rssi = _rssi;
    final rssiText = rssi != null ? '$rssi dBm' : '-- dBm';

    final gradient = isDark
        ? LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withAlpha(220),
              Theme.of(context).colorScheme.primaryContainer.withAlpha(120),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [_HomePalette.glass, Color(0xDDF6F0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Card(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Theme.of(context).colorScheme.outlineVariant
                : _HomePalette.glassBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _HomePalette.scanPurple.withAlpha(isDark ? 38 : 48),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
                  color: switch (tone) {
                    BlePresentationTone.connected =>
                      _HomePalette.scanCyan.withAlpha(isDark ? 48 : 60),
                    BlePresentationTone.busy =>
                      _HomePalette.scanPurple.withAlpha(isDark ? 44 : 36),
                    BlePresentationTone.failure => _HomePalette.coral.withAlpha(
                      isDark ? 44 : 36,
                    ),
                    BlePresentationTone.neutral =>
                      _HomePalette.scanPurple.withAlpha(isDark ? 44 : 36),
                  },
                  borderRadius: BorderRadius.circular(14),
                ),
                child: connected
                    ? _homeIcon('Bluetooth Connected.png', size: 24)
                    : presentation.kind == BlePresentationKind.bluetoothOff
                    ? _homeIcon('Bluetooth Disabled.png', size: 24)
                    : Icon(
                        materialIconForBlePresentation(presentation.icon),
                        size: 24,
                        color: tone == BlePresentationTone.failure
                            ? _HomePalette.coral
                            : _HomePalette.scanPurple,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: connected
                          ? '${presentation.semanticLabel}, $name'
                          : presentation.semanticLabel,
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai ? 'BLE Connection' : 'BLE Connection',
                            style: TextStyle(
                              color: isDark
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : _HomePalette.deepPlum.withAlpha(180),
                              fontSize: isThai ? 15 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            connected
                                ? '${presentation.label} · $name'
                                : presentation.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: connected
                                  ? _contentTextColor(context)
                                  : tone == BlePresentationTone.failure
                                  ? _HomePalette.coral
                                  : _HomePalette.deepPlum,
                            ),
                          ),
                        ],
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
                              color: isDark
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : _HomePalette.deepPlum.withAlpha(170),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!connected)
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _HomePalette.scanPurple,
                          _HomePalette.scanCyan,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _HomePalette.scanPurple.withAlpha(92),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _openBlePage,
                      icon: _homeIcon('Search-Scan.png', size: 21),
                      label: Text(
                        isThai ? 'Scan devices' : 'Scan devices',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    _rssiBars(context, rssi ?? -100, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      isThai ? 'RSSI' : 'RSSI',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : _HomePalette.deepPlum.withAlpha(170),
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
                  height: 104,
                  wide: true,
                  enabled: !_openingPage,
                  onTap: () => _openNavItem(items[0]),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: width,
                child: _NavCard(
                  item: items[1],
                  height: 104,
                  wide: true,
                  enabled: !_openingPage,
                  onTap: () => _openNavItem(items[1]),
                ),
              ),
            ] else
              Row(
                children: [
                  SizedBox(
                    width: half,
                    child: _NavCard(
                      item: items[0],
                      height: 112,
                      enabled: !_openingPage,
                      onTap: () => _openNavItem(items[0]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: half,
                    child: _NavCard(
                      item: items[1],
                      height: 112,
                      enabled: !_openingPage,
                      onTap: () => _openNavItem(items[1]),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: width > 420 ? 420 : width,
                child: _SecondaryNavAction(
                  item: items[2],
                  enabled: !_openingPage,
                  onTap: () => _openNavItem(items[2]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: width > 420 ? 420 : width,
                child: _SecondaryNavAction(
                  actionKey: const ValueKey('home-arduino-library-action'),
                  item: items[3],
                  enabled: !_openingPage,
                  onTap: () => _openNavItem(items[3]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentCard(BuildContext context, bool isThai) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLast = _lastDeviceId != null && _lastDeviceId!.isNotEmpty;

    if (!hasLast) {
      return Card(
        color: isDark ? null : _HomePalette.glass,
        surfaceTintColor: isDark ? null : Colors.transparent,
        elevation: isDark ? 1 : 0,
        shadowColor: _HomePalette.scanPurple.withAlpha(34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              _homeIcon('Recent Activity-History.png', size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThai ? 'No recent device yet' : 'No recent device yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      color: isDark ? null : _HomePalette.glass,
      surfaceTintColor: isDark ? null : Colors.transparent,
      elevation: isDark ? 2 : 0,
      shadowColor: _HomePalette.scanPurple.withAlpha(34),
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
                  isThai ? 'Recent Activity' : 'Recent Activity',
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
                isThai ? 'No recent device yet' : 'No recent device yet',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _connectLastDevice(isThai),
                        child: Text(isThai ? 'Reconnect' : 'Reconnect'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openBlePage,
                        icon: _homeIcon('Search-Scan.png', size: 36),
                        label: Text(isThai ? 'Scan' : 'Scan'),
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
    return Align(
      alignment: Alignment.centerRight,
      child: FutureBuilder<PackageInfo>(
        future: _infoFuture,
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '2.1.0';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.42,
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : _HomePalette.deepPlum.withAlpha(176),
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
  final String? subtitle;
  final String? iconAsset;
  final IconData? icon;
  final Color accent;
  final Widget? page;
  final Future<void> Function()? onTap;

  const _NavItem({
    required this.title,
    this.subtitle,
    this.iconAsset,
    this.icon,
    required this.accent,
    this.page,
    this.onTap,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.item.accent;

    final gradient = LinearGradient(
      colors: [
        accent.withAlpha(isDark ? 52 : 72),
        accent.withAlpha(isDark ? 24 : 32),
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
          color: isDark ? null : _HomePalette.glass,
          surfaceTintColor: isDark ? null : Colors.transparent,
          elevation: isDark ? 3 : 0,
          shadowColor: accent.withAlpha(isDark ? 60 : 92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                border: Border.all(
                  color: isDark
                      ? Theme.of(context).colorScheme.outlineVariant
                      : accent.withAlpha(88),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withAlpha(_pressed ? 100 : 58),
                    blurRadius: _pressed ? 18 : 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 150 || constraints.maxHeight < 150;
                  final compactWide =
                      widget.wide && constraints.maxHeight < 150;
                  final padding = compact
                      ? (compactWide
                            ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                            : const EdgeInsets.fromLTRB(6, 6, 6, 6))
                      : const EdgeInsets.fromLTRB(16, 14, 16, 14);
                  final iconBox = compact ? (compactWide ? 36.0 : 30.0) : 44.0;
                  final iconSize = compact ? (compactWide ? 24.0 : 18.0) : 28.0;
                  final gapTop = compact ? (compactWide ? 6.0 : 2.0) : 12.0;
                  final gapMid = compact ? (compactWide ? 2.0 : 0.0) : 6.0;
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
                                color: accent.withAlpha(isDark ? 52 : 74),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: widget.item.iconAsset != null
                                    ? Image.asset(
                                        'assets/icons/HomeUnified/${widget.item.iconAsset}',
                                        width: iconSize,
                                        height: iconSize,
                                        fit: BoxFit.contain,
                                      )
                                    : Icon(
                                        widget.item.icon!,
                                        size: iconSize,
                                        color: accent,
                                      ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: compact ? 18 : 22,
                              color: accent.withAlpha(isDark ? 176 : 196),
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
                            color: isDark
                                ? Theme.of(context).colorScheme.onSurface
                                : _HomePalette.deepPlum,
                          ),
                        ),
                        if (widget.item.subtitle != null) ...[
                          SizedBox(height: gapMid),
                          Text(
                            widget.item.subtitle!,
                            maxLines: subtitleLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              height: compact ? 1.05 : 1.2,
                              color: isDark
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : _HomePalette.deepPlum.withAlpha(182),
                            ),
                          ),
                        ],
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

class _SecondaryNavAction extends StatelessWidget {
  final Key actionKey;
  final _NavItem item;
  final bool enabled;
  final VoidCallback onTap;

  const _SecondaryNavAction({
    this.actionKey = const ValueKey('home-contact-action'),
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitle = item.subtitle;
    final label = subtitle == null ? item.title : '${item.title}. $subtitle';

    return Semantics(
      key: actionKey,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isDark
            ? item.accent.withAlpha(24)
            : _HomePalette.glass.withAlpha(190),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: item.accent.withAlpha(isDark ? 88 : 72)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.accent.withAlpha(isDark ? 44 : 48),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 22, color: item.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Theme.of(context).colorScheme.onSurface
                              : _HomePalette.deepPlum,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : _HomePalette.deepPlum.withAlpha(176),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: item.accent.withAlpha(isDark ? 184 : 204),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
