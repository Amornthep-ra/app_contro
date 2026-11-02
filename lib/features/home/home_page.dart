// lib/features/home/home_page.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ble/ble_connection_coordinator.dart';
import '../../core/ble/ble_manager.dart';
import '../../core/ble/ble_presentation_state.dart';
import '../../core/ui/app_assets.dart';
import '../../core/ui/control_mode_preference.dart';
import '../../core/utils/orientation_utils.dart';
import '../../core/widgets/ble_status_orb.dart';
import '../../core/widgets/signal_bars.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import '../gamepad/gamepad_4_button_page.dart';
import '../gamepad/gamepad_mode_edit.dart';
import '../joystick/joystick/presentation/joystick.dart';
import '../linesonic/linesonic_page.dart';
import 'widgets/home_backdrop.dart';
import '../../core/ui/lavender_glass.dart';

const double _kToolbarHeight = 68;
const double _kPagePadding = 20;
const double _kContentMaxWidth = 560;
const double _kSectionGap = 16;

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.blePageBuilder,
    this.blePresentationState,
    this.animateBackground,
    this.backgroundFrameTime,
  });

  final WidgetBuilder? blePageBuilder;
  final ValueListenable<BlePresentationState>? blePresentationState;

  /// Ambient background motion. Null follows
  /// [HomeBackdrop.motionEnabledByDefault].
  final bool? animateBackground;

  /// Renders one fixed background frame (for previews/screenshots).
  final Duration? backgroundFrameTime;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<bool>? _connSub;
  Timer? _rssiTimer;
  Future<PackageInfo>? _infoFuture;
  late ValueListenable<BlePresentationState> _blePresentationState;
  BlePresentationStateController? _ownedBlePresentationState;
  late final AnimationController _entrance;
  late final List<CurvedAnimation> _reveals;
  bool _entranceStarted = false;

  bool _openingPage = false;
  bool _scrolled = false;
  int? _rssi;
  String? _lastDeviceId;
  String? _lastDeviceName;

  static const _prefsLastDeviceIdKey = 'ble_last_device_id';
  static const _prefsLastDeviceNameKey = 'ble_last_device_name';
  static final _facebookPageUri = Uri.parse(
    'https://www.facebook.com/PrinceBotAndElectronics',
  );
  static final _arduinoLibraryUri = Uri.parse(
    'https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower.git',
  );

  @override
  void initState() {
    super.initState();
    unawaited(OrientationUtils.request(AppOrientation.portrait));
    _infoFuture = PackageInfo.fromPlatform();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _reveals = List<CurvedAnimation>.generate(4, (index) {
      final start = index * 0.12;
      return CurvedAnimation(
        parent: _entrance,
        curve: Interval(start, start + 0.6, curve: Curves.easeOutCubic),
      );
    });
    _bindBlePresentationState();
    _loadLastDevice();
    _bindConnection();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (_motionEnabled) {
      _entrance.forward();
    } else {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _rssiTimer?.cancel();
    _blePresentationState.removeListener(_onBlePresentationChanged);
    _ownedBlePresentationState?.dispose();
    for (final reveal in _reveals) {
      reveal.dispose();
    }
    _entrance.dispose();
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

  bool get _motionEnabled =>
      widget.backgroundFrameTime == null &&
      (widget.animateBackground ?? HomeBackdrop.motionEnabledByDefault) &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

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
      if (connected) {
        _startRssiPolling();
        _loadLastDevice();
      } else {
        _stopRssiPolling();
      }
    });

    if (BleManager.instance.isConnected) {
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

  Future<void> _connectLastDevice() async {
    if (!_hasLastDevice) return;
    _showSnack('Reconnecting to ${_lastDeviceLabel ?? 'the last device'}…');
    await BleConnectionCoordinator.instance.autoConnectLastDevice(
      timeout: const Duration(seconds: 8),
      source: 'home_reconnect',
      userInitiated: true,
    );
  }

  Future<void> _openExternal(Uri uri, String failureMessage) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showSnack(failureMessage);
    } catch (_) {
      _showSnack(failureMessage);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: LavenderPalette.ink.withValues(alpha: 0.92),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  bool get _hasLastDevice => _lastDeviceId != null && _lastDeviceId!.isNotEmpty;

  String? get _lastDeviceLabel {
    final name = _lastDeviceName;
    if (name != null && name.isNotEmpty) return name;
    return _hasLastDevice ? _lastDeviceId : null;
  }

  String _connectedName() {
    final name = BleManager.instance.currentDeviceName;
    if (name != null && name.isNotEmpty) return name;
    final id = BleManager.instance.currentDeviceId;
    if (id != null && id.isNotEmpty) return id;
    return _lastDeviceLabel ?? 'Unknown device';
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final scrolled = notification.metrics.pixels > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + _kToolbarHeight + 6;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: LavenderPalette.background,
      appBar: AppBar(
        toolbarHeight: _kToolbarHeight,
        title: const _BrandHeader(),
        centerTitle: false,
        titleSpacing: _kPagePadding,
        automaticallyImplyLeading: false,
        actions: const [],
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: _FrostedBar(visible: _scrolled),
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          HomeBackdrop(
            animate: widget.animateBackground,
            frameTime: widget.backgroundFrameTime,
          ),
          BackdropGroup(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      _kPagePadding,
                      topInset,
                      _kPagePadding,
                      24 + media.padding.bottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kContentMaxWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Reveal(
                                animation: _reveals[0],
                                child: _buildConnectionCard(),
                              ),
                              const SizedBox(height: _kSectionGap),
                              _Reveal(
                                animation: _reveals[1],
                                child: _buildDestinations(),
                              ),
                              const SizedBox(height: _kSectionGap + 8),
                              _Reveal(
                                animation: _reveals[2],
                                child: _buildResources(),
                              ),
                              const SizedBox(height: _kSectionGap + 4),
                              _Reveal(
                                animation: _reveals[3],
                                child: _buildVersionInfo(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BLE connection hero card
  // ---------------------------------------------------------------------------

  String? _connectionHint(BlePresentationState presentation) {
    final last = _lastDeviceLabel;
    return switch (presentation.kind) {
      BlePresentationKind.notConnected =>
        last != null
            ? 'Last device · $last'
            : 'Power on your robot, then scan to pair.',
      BlePresentationKind.bluetoothOff =>
        'Turn on Bluetooth to find your robot.',
      BlePresentationKind.permissionNeeded =>
        'Allow Bluetooth access to continue.',
      BlePresentationKind.unavailable =>
        'Bluetooth LE is not available on this phone.',
      BlePresentationKind.reconnectFailed =>
        last != null ? 'Could not reach $last.' : 'Try scanning again.',
      BlePresentationKind.scanning => 'Looking for nearby robots…',
      BlePresentationKind.connecting ||
      BlePresentationKind.reconnecting => last,
      _ => null,
    };
  }

  Widget _buildConnectionCard() {
    final presentation = _blePresentationState.value;
    final connected = presentation.isConnected;
    final failure = presentation.tone == BlePresentationTone.failure;
    final name = connected ? _connectedName() : null;
    final hint = connected ? null : _connectionHint(presentation);
    final canReconnect =
        !connected &&
        _hasLastDevice &&
        (presentation.kind == BlePresentationKind.notConnected ||
            presentation.kind == BlePresentationKind.reconnectFailed);

    final status = Semantics(
      container: true,
      liveRegion: true,
      label: connected
          ? '${presentation.semanticLabel}, $name'
          : presentation.semanticLabel,
      excludeSemantics: true,
      child: Row(
        children: [
          BleStatusOrb(presentation: presentation, animate: _motionEnabled),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BLE Connection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: LavenderPalette.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected ? name! : presentation.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: LavenderPalette.displayFont,
                    fontSize: 21,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: failure
                        ? LavenderPalette.coral
                        : LavenderPalette.ink,
                  ),
                ),
                if (connected) ...[
                  const SizedBox(height: 4),
                  _ConnectedLine(rssi: _rssi),
                ] else if (hint != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LavenderPalette.inkSoft,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      tint: LavenderPalette.violetBright,
      tintStrength: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (connected)
            Row(
              children: [
                Expanded(child: status),
                const SizedBox(width: 8),
                _RoundGlassIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Manage connection',
                  onPressed: _openBlePage,
                ),
              ],
            )
          else ...[
            status,
            const SizedBox(height: 18),
            if (canReconnect)
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: GlassActionButton(
                      label: 'Reconnect',
                      icon: Icons.refresh_rounded,
                      onPressed: _connectLastDevice,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: GradientActionButton(
                      label: 'Scan devices',
                      icon: Icons.search_rounded,
                      onPressed: _openBlePage,
                    ),
                  ),
                ],
              )
            else
              GradientActionButton(
                label: 'Scan devices',
                icon: Icons.search_rounded,
                onPressed: _openBlePage,
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main destinations
  // ---------------------------------------------------------------------------

  Widget _buildDestinations() {
    _DestinationTile controller({bool wide = false}) => _DestinationTile(
      title: 'Controller',
      subtitle: 'Gamepad · Joystick',
      iconAsset: 'Controller-Gamepad.png',
      tint: LavenderPalette.violetBright,
      accentInk: LavenderPalette.violet,
      enabled: !_openingPage,
      onTap: _openLastControl,
      wide: wide,
    );
    _DestinationTile lineSonic({bool wide = false}) => _DestinationTile(
      title: 'LineSonic',
      subtitle: 'PID tuning · Sensors',
      iconAsset: 'LineSonic-PID Tuning.png',
      tint: LavenderPalette.cyan,
      tintStrength: 0.15,
      accentInk: LavenderPalette.cyanDeep,
      enabled: !_openingPage,
      onTap: () => _openPage(const LineSonicPage()),
      wide: wide,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final singleColumn = (constraints.maxWidth - gap) / 2 < 150;
        if (singleColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controller(wide: true),
              const SizedBox(height: gap),
              lineSonic(wide: true),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: controller()),
              const SizedBox(width: gap),
              Expanded(child: lineSonic()),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Resources (external links)
  // ---------------------------------------------------------------------------

  Widget _buildResources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 10),
          child: Text(
            'Resources',
            style: TextStyle(
              color: LavenderPalette.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        GlassPanel(
          radius: 24,
          shadowStrength: 0.75,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LinkRow(
                actionKey: const ValueKey('home-contact-action'),
                icon: Icons.facebook_rounded,
                title: 'Contact',
                subtitle: 'Follow us on Facebook',
                enabled: !_openingPage,
                onTap: () =>
                    _openExternal(_facebookPageUri, 'Unable to open Facebook.'),
              ),
              Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                endIndent: 18,
                color: LavenderPalette.ink.withValues(alpha: 0.07),
              ),
              _LinkRow(
                actionKey: const ValueKey('home-arduino-library-action'),
                icon: Icons.download_rounded,
                title: 'Arduino IDE Library',
                subtitle: 'Download from GitHub',
                enabled: !_openingPage,
                onTap: () => _openExternal(
                  _arduinoLibraryUri,
                  'Unable to open the library link.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return FutureBuilder<PackageInfo>(
      future: _infoFuture,
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return SizedBox(
          height: 20,
          child: version == null
              ? null
              : Center(
                  child: Text(
                    'PB Controller  ·  v$version',
                    style: const TextStyle(
                      color: LavenderPalette.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------------

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    const logoSize = 40.0;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: LavenderPalette.violetDeep.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              AppAssets.cornerLogo,
              fit: BoxFit.cover,
              // The source is 2048 px; decode only what is displayed.
              cacheWidth: (logoSize * dpr).round(),
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PB Controller',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: LavenderPalette.displayFont,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: LavenderPalette.ink,
                ),
              ),
              Text(
                'Robot remote by PrinceBot',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: LavenderPalette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Frosted strip behind the header, shown only once content scrolls under it.
class _FrostedBar extends StatelessWidget {
  const _FrostedBar({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      LavenderPalette.background.withValues(alpha: 0.88),
                      LavenderPalette.background.withValues(alpha: 0.70),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Connection pieces
// -----------------------------------------------------------------------------

class _ConnectedLine extends StatelessWidget {
  const _ConnectedLine({required this.rssi});

  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final value = rssi;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: LavenderPalette.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: LavenderPalette.success.withValues(alpha: 0.55),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Connected',
          style: TextStyle(
            color: LavenderPalette.success,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        SignalBars(rssi: value),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value != null ? '$value dBm' : '-- dBm',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LavenderPalette.inkSoft,
              fontSize: 12.5,
              fontFeatures: [ui.FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundGlassIconButton extends StatelessWidget {
  const _RoundGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.7),
        shape: CircleBorder(
          side: BorderSide(
            color: LavenderPalette.violet.withValues(alpha: 0.18),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 21, color: LavenderPalette.violet),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Destination tiles
// -----------------------------------------------------------------------------

class _DestinationTile extends StatefulWidget {
  const _DestinationTile({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.tint,
    required this.accentInk,
    required this.enabled,
    required this.onTap,
    this.tintStrength = 0.20,
    this.wide = false,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final Color tint;
  final Color accentInk;
  final double tintStrength;
  final bool enabled;
  final Future<void> Function() onTap;
  final bool wide;

  @override
  State<_DestinationTile> createState() => _DestinationTileState();
}

class _DestinationTileState extends State<_DestinationTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final icon = Image.asset(
      'assets/icons/HomeUnified/${widget.iconAsset}',
      width: 54,
      height: 54,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final arrow = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 17,
        color: widget.accentInk,
      ),
    );
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: LavenderPalette.displayFont,
            fontSize: 19,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: LavenderPalette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.3,
            color: LavenderPalette.inkSoft,
          ),
        ),
      ],
    );

    final content = widget.wide
        ? Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: texts),
              const SizedBox(width: 8),
              arrow,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [icon, const Spacer(), arrow],
              ),
              const SizedBox(height: 22),
              texts,
            ],
          );

    final radius = BorderRadius.circular(26);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GlassPanel(
        radius: 26,
        tint: widget.tint,
        tintStrength: widget.tintStrength,
        shadowColor: Color.lerp(widget.tint, LavenderPalette.violetDeep, 0.5)!,
        child: Stack(
          // Fill the stretched grid cell so the whole tile is tappable.
          fit: StackFit.passthrough,
          children: [
            // Soft colored light in the corner for depth.
            Positioned(
              right: -46,
              bottom: -56,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.tint.withValues(
                          alpha: widget.tintStrength * 1.4,
                        ),
                        widget.tint.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                splashColor: widget.tint.withValues(alpha: 0.16),
                highlightColor: widget.tint.withValues(alpha: 0.08),
                onTap: widget.enabled ? widget.onTap : null,
                onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: widget.wide ? 92 : 158,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Resource rows
// -----------------------------------------------------------------------------

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: actionKey,
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          splashColor: LavenderPalette.violet.withValues(alpha: 0.10),
          highlightColor: LavenderPalette.violet.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 18, 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        LavenderPalette.violetBright.withValues(alpha: 0.18),
                        LavenderPalette.cyan.withValues(alpha: 0.14),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Icon(icon, size: 22, color: LavenderPalette.violet),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: LavenderPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: LavenderPalette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: LavenderPalette.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
