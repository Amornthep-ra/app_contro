// lib/features/linesonic/linesonic_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ble/ble_manager.dart';
import '../../core/ui/language_controller.dart';
import '../../core/widgets/cat_back_button.dart';
import '../../core/widgets/portrait_background.dart';
import '../bluetooth/bluetooth_ble_page.dart';
import 'linesonic_pid_page.dart';
import 'linesonic_sensor_page.dart';

class _LineSonicPalette {
  static const deepPlum = Color(0xFF261B39);
  static const pidCyan = Color(0xFF37D8FF);
  static const sensorMint = Color(0xFF45D6A1);
  static const coral = Color(0xFFF05264);
  static const glass = Color(0xEAFDF9FF);
  static const glassBorder = Color(0xCCFFFFFF);
}

class LineSonicPage extends StatefulWidget {
  const LineSonicPage({super.key, this.blePageBuilder});

  final WidgetBuilder? blePageBuilder;

  @override
  State<LineSonicPage> createState() => _LineSonicPageState();
}

class _LineSonicPageState extends State<LineSonicPage> {
  bool _openingPage = false;
  bool _openingBlePage = false;

  String _t(bool isThai, String th, String en) => isThai ? th : en;

  Widget _lineSonicIcon(String name, {double size = 28}) {
    return Image.asset(
      'assets/icons/HomeUnified/$name',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Future<void> _openBlePage() async {
    if (_openingBlePage) return;
    _openingBlePage = true;
    HapticFeedback.selectionClick();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: widget.blePageBuilder ?? (_) => const BluetoothBlePage(),
        ),
      );
    } finally {
      _openingBlePage = false;
    }
  }

  Widget _buildBleBadge(bool isThai) {
    return StreamBuilder<BleConnectionStatus>(
      stream: BleManager.instance.statusStream,
      initialData: BleManager.instance.connectionStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? BleConnectionStatus.disconnected;
        final connected = isBleStatusConnected(status);
        final busy = isBleStatusBusy(status);
        final failed = isBleStatusFailed(status);
        final accent = connected
            ? const Color(0xFF16A34A)
            : busy
            ? const Color(0xFFF59E0B)
            : failed
            ? const Color(0xFFDC2626)
            : _LineSonicPalette.coral;
        final icon = connected
            ? Icons.bluetooth_connected_rounded
            : busy
            ? Icons.bluetooth_searching_rounded
            : Icons.bluetooth_disabled_rounded;
        final label = connected
            ? 'BLE On'
            : busy
            ? 'Reconnecting...'
            : failed
            ? 'Failed'
            : 'BLE Off';

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Tooltip(
            message: _t(isThai, 'Open BLE connection', 'Open BLE connection'),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _openBlePage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 32,
                  constraints: const BoxConstraints(maxWidth: 108),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color.lerp(_LineSonicPalette.glass, accent, 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          Color.lerp(
                            _LineSonicPalette.glassBorder,
                            accent,
                            0.52,
                          ) ??
                          _LineSonicPalette.glassBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            color:
                                Color.lerp(
                                  accent,
                                  _LineSonicPalette.deepPlum,
                                  0.45,
                                ) ??
                                _LineSonicPalette.deepPlum,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(90),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPage(Widget page) async {
    if (_openingPage) return;
    setState(() => _openingPage = true);
    HapticFeedback.selectionClick();
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } finally {
      if (mounted) {
        setState(() => _openingPage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = [
          _LineSonicItem(
            title: _t(isThai, 'PID Tuning', 'PID Tuning'),
            subtitle: _t(
              isThai,
              'Tune motion PID over BLE',
              'Tune motion PID over BLE',
            ),
            iconAsset: 'LineSonic-PID Tuning.png',
            accent: _LineSonicPalette.pidCyan,
            page: const LineSonicPidPage(),
          ),
          _LineSonicItem(
            title: _t(isThai, 'Read Sensor', 'Read Sensor'),
            subtitle: _t(
              isThai,
              'Read sensor values from board',
              'Read sensor values from board',
            ),
            iconAsset: 'LineSonic-Read Sensor.png',
            accent: _LineSonicPalette.sensorMint,
            page: const LineSonicSensorPage(),
          ),
        ];

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 44,
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            foregroundColor: _LineSonicPalette.deepPlum,
            leadingWidth: CatBackButton.leadingWidthFor(16),
            leading: Navigator.of(context).canPop()
                ? CatBackButton.leading()
                : null,
            centerTitle: true,
            title: Text(
              'LineSonic',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: _LineSonicPalette.deepPlum,
              ),
            ),
            actions: [_buildBleBadge(isThai)],
          ),
          body: PortraitBackground(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 44 + 16,
                16,
                24,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _LineSonicCard(
                  item: item,
                  enabled: !_openingPage,
                  iconBuilder: _lineSonicIcon,
                  onTap: () => _openPage(item.page),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LineSonicItem {
  final String title;
  final String subtitle;
  final String iconAsset;
  final Color accent;
  final Widget page;

  const _LineSonicItem({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.accent,
    required this.page,
  });
}

class _LineSonicCard extends StatefulWidget {
  final _LineSonicItem item;
  final bool enabled;
  final Widget Function(String name, {double size}) iconBuilder;
  final VoidCallback onTap;

  const _LineSonicCard({
    required this.item,
    required this.enabled,
    required this.iconBuilder,
    required this.onTap,
  });

  @override
  State<_LineSonicCard> createState() => _LineSonicCardState();
}

class _LineSonicCardState extends State<_LineSonicCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.item.accent;

    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1.0 : 0.62,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _LineSonicPalette.glass,
                Color.lerp(_LineSonicPalette.glass, accent, 0.13)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(_LineSonicPalette.glassBorder, accent, 0.40)!,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(_pressed && widget.enabled ? 52 : 28),
                blurRadius: _pressed && widget.enabled ? 16 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.enabled ? widget.onTap : null,
              onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
              onTapCancel: () => _setPressed(false),
              onTapUp: (_) => _setPressed(false),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withAlpha(45)),
                      ),
                      child: Center(
                        child: widget.iconBuilder(
                          widget.item.iconAsset,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _LineSonicPalette.deepPlum,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: _LineSonicPalette.deepPlum.withAlpha(185),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: accent.withAlpha(210),
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
