// lib/features/linesonic/linesonic_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/lavender_glass.dart';
import 'linesonic_pid_page.dart';
import 'linesonic_sensor_page.dart';
import 'widgets/linesonic_scaffold.dart';

class LineSonicPage extends StatefulWidget {
  const LineSonicPage({super.key});

  @override
  State<LineSonicPage> createState() => _LineSonicPageState();
}

class _LineSonicPageState extends State<LineSonicPage> {
  bool _openingPage = false;

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
    final media = MediaQuery.of(context);
    return LineSonicScaffold(
      title: 'LineSonic',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          LineSonicScaffold.pagePadding,
          LineSonicScaffold.contentTop(context) + 4,
          LineSonicScaffold.pagePadding,
          24 + media.padding.bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LineSonicTile(
                    title: 'PID Tuning',
                    subtitle: 'Tune motion PID over BLE',
                    iconAsset: 'LineSonic-PID Tuning.png',
                    tint: LavenderPalette.cyan,
                    accentInk: LavenderPalette.cyanDeep,
                    enabled: !_openingPage,
                    onTap: () => _openPage(const LineSonicPidPage()),
                  ),
                  const SizedBox(height: 14),
                  _LineSonicTile(
                    title: 'Read Sensor',
                    subtitle: 'Read sensor values from board',
                    iconAsset: 'LineSonic-Read Sensor.png',
                    tint: LavenderPalette.success,
                    accentInk: _sensorInk,
                    enabled: !_openingPage,
                    onTap: () => _openPage(const LineSonicSensorPage()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deeper mint for text/icons on the Read Sensor tile (success is too light
/// for a 17 px arrow on glass).
const _sensorInk = Color(0xFF128A6C);

/// Glass destination tile, the wide variant of Home's tiles.
class _LineSonicTile extends StatefulWidget {
  const _LineSonicTile({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.tint,
    required this.accentInk,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final Color tint;
  final Color accentInk;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_LineSonicTile> createState() => _LineSonicTileState();
}

class _LineSonicTileState extends State<_LineSonicTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GlassPanel(
        radius: radius,
        tint: widget.tint,
        tintStrength: 0.16,
        shadowColor: Color.lerp(widget.tint, LavenderPalette.violetDeep, 0.5)!,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashColor: widget.tint.withValues(alpha: 0.16),
            highlightColor: widget.tint.withValues(alpha: 0.08),
            onTap: widget.enabled ? widget.onTap : null,
            onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 92),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/HomeUnified/${widget.iconAsset}',
                      width: 54,
                      height: 54,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
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
