// lib/features/home/widgets/home_backdrop.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ambient_motion.dart';
import '../../../core/ui/app_assets.dart';
import '../../../core/ui/lavender_glass.dart';

/// Home background: the original `BG_Portrait.png` artwork, unchanged, with
/// an optional ambient-motion layer painted on top of it.
///
/// The motion layer adds:
/// * soft aurora light that drifts slowly behind the glass cards,
/// * twinkles on the sparkles already painted in the artwork,
/// * a breathing glow on the cat's collar, the paw sign and the cat-house door,
/// * a few floating light motes.
///
/// It runs at ~30 fps and pauses automatically while another page covers
/// Home, while the app is in the background, and when the system "remove
/// animations" accessibility setting is on.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key, this.animate, this.frameTime});

  /// Whether to run the ambient motion. Null follows [motionEnabledByDefault].
  final bool? animate;

  /// Paints a single fixed frame at this time instead of animating.
  /// Used for previews and screenshots.
  final Duration? frameTime;

  /// Global default for [animate]. Off under `flutter test` so that
  /// `pumpAndSettle` can settle.
  static bool motionEnabledByDefault = AmbientMotion.enabledByDefault;

  /// Number of backdrops whose motion clock is currently running.
  @visibleForTesting
  static int get debugRunningClocks => _HomeBackdropState._runningClocks;

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> {
  static const _frameInterval = Duration(milliseconds: 33);
  static int _runningClocks = 0;

  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  final Stopwatch _stopwatch = Stopwatch();
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  double _baseSeconds = 0;
  bool _appResumed = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appResumed = state == AppLifecycleState.resumed;
        _syncClock();
      },
    );
    _applyFrameTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncClock();
  }

  @override
  void didUpdateWidget(HomeBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameTime != widget.frameTime) _applyFrameTime();
    _syncClock();
  }

  @override
  void dispose() {
    _stopClock();
    _lifecycle.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _applyFrameTime() {
    final frameTime = widget.frameTime;
    if (frameTime == null) return;
    _seconds.value = frameTime.inMicroseconds / Duration.microsecondsPerSecond;
  }

  bool get _shouldAnimate =>
      widget.frameTime == null &&
      (widget.animate ?? HomeBackdrop.motionEnabledByDefault) &&
      !_reduceMotion &&
      _tickerEnabled &&
      _appResumed;

  void _syncClock() {
    if (_shouldAnimate) {
      if (_timer != null) return;
      _stopwatch
        ..reset()
        ..start();
      _runningClocks += 1;
      _timer = Timer.periodic(_frameInterval, (_) {
        _seconds.value =
            _baseSeconds +
            _stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
      });
    } else {
      _stopClock();
    }
  }

  void _stopClock() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    _runningClocks -= 1;
    _stopwatch.stop();
    _baseSeconds = _seconds.value;
  }

  @override
  Widget build(BuildContext context) {
    final motionVisible =
        widget.frameTime != null ||
        (widget.animate ?? HomeBackdrop.motionEnabledByDefault);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LavenderPalette.background),
        Image.asset(
          AppAssets.controlBackgroundPortrait,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
        if (motionVisible)
          RepaintBoundary(
            child: CustomPaint(painter: _AmbientMotionPainter(_seconds)),
          ),
      ],
    );
  }
}

/// A painted sparkle in `BG_Portrait.png` (artwork pixel coordinates).
class _Star {
  const _Star(this.x, this.y, this.radius, this.period, this.phase);

  final double x;
  final double y;
  final double radius;
  final double period;
  final double phase;
}

class _Mote {
  const _Mote({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.sway,
    required this.period,
    required this.phase,
  });

  final double x;
  final double y;
  final double speed;
  final double radius;
  final double sway;
  final double period;
  final double phase;
}

class _AmbientMotionPainter extends CustomPainter {
  _AmbientMotionPainter(this.seconds) : super(repaint: seconds);

  final ValueListenable<double> seconds;

  static const _artSize = Size(1440, 3200);
  static const _tau = math.pi * 2;

  /// Sparkles detected in the artwork, so the existing stars twinkle.
  static const _stars = <_Star>[
    _Star(967, 107, 22, 5.2, 0.00),
    _Star(1199, 676, 18, 6.1, 0.35),
    _Star(1344, 1156, 12, 4.4, 0.62),
    _Star(183, 1428, 15, 5.6, 0.18),
    _Star(118, 1378, 9, 3.9, 0.80),
    _Star(1216, 1702, 20, 6.6, 0.47),
    _Star(1315, 2025, 8, 4.1, 0.12),
    _Star(1250, 2155, 8, 5.0, 0.71),
    _Star(1211, 2283, 8, 4.7, 0.29),
    _Star(117, 2317, 18, 5.9, 0.56),
    _Star(66, 2369, 11, 4.3, 0.91),
    _Star(1355, 2359, 7, 3.7, 0.40),
    _Star(1176, 2620, 14, 5.3, 0.05),
    _Star(1092, 183, 8, 4.6, 0.66),
    _Star(1251, 918, 7, 3.8, 0.22),
    _Star(88, 1547, 7, 4.9, 0.84),
    _Star(395, 333, 14, 6.3, 0.52),
  ];

  static final List<_Mote> _motes = _buildMotes();

  static List<_Mote> _buildMotes() {
    final random = math.Random(42);
    double between(double a, double b) => a + random.nextDouble() * (b - a);
    return List<_Mote>.generate(
      12,
      (_) => _Mote(
        x: between(0.06, 0.94),
        y: random.nextDouble(),
        speed: between(6, 13),
        radius: between(1.0, 2.1),
        sway: between(4, 12),
        period: between(5, 9),
        phase: random.nextDouble() * _tau,
      ),
    );
  }

  /// Smooth 0 → 1 → 0 cycle.
  static double _pulse(double t, double period, double phase) =>
      0.5 - 0.5 * math.cos(_tau * (t / period + phase));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = seconds.value;
    final scale = math.max(
      size.width / _artSize.width,
      size.height / _artSize.height,
    );
    final dx = (size.width - _artSize.width * scale) / 2;
    final dy = (size.height - _artSize.height * scale) / 2;
    Offset art(double x, double y) => Offset(dx + x * scale, dy + y * scale);

    _paintAurora(canvas, size, t);
    _paintArtworkGlows(canvas, art, scale, t);
    _paintMotes(canvas, size, t);
    _paintStars(canvas, art, scale, t);
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    if (alpha <= 0 || radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.42),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  void _paintAurora(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    _glow(
      canvas,
      Offset(
        w * (0.16 + 0.10 * math.sin(_tau * t / 26)),
        h * (0.20 + 0.05 * math.cos(_tau * t / 31)),
      ),
      w * 0.62,
      const Color(0xFFB59BFF),
      0.20 + 0.05 * math.sin(_tau * t / 17),
    );
    _glow(
      canvas,
      Offset(
        w * (0.88 + 0.08 * math.sin(_tau * t / 22 + 1.3)),
        h * (0.40 + 0.06 * math.sin(_tau * t / 29 + 0.4)),
      ),
      w * 0.56,
      const Color(0xFF86E4FF),
      0.17 + 0.05 * math.sin(_tau * t / 19 + 2.1),
    );
    _glow(
      canvas,
      Offset(
        w * (0.28 + 0.12 * math.cos(_tau * t / 34 + 2.0)),
        h * (0.60 + 0.05 * math.sin(_tau * t / 24 + 1.0)),
      ),
      w * 0.50,
      const Color(0xFFFFC4EE),
      0.15 + 0.04 * math.sin(_tau * t / 21 + 0.7),
    );
    _glow(
      canvas,
      Offset(
        w * (0.62 + 0.10 * math.sin(_tau * t / 30 + 3.0)),
        h * (0.07 + 0.03 * math.cos(_tau * t / 20)),
      ),
      w * 0.46,
      Colors.white,
      0.30,
    );
  }

  void _paintArtworkGlows(
    Canvas canvas,
    Offset Function(double, double) art,
    double scale,
    double t,
  ) {
    // Cat-house door: slow breathing light.
    final door = _pulse(t, 4.2, 0);
    _glow(
      canvas,
      art(1180, 3005),
      170 * scale,
      const Color(0xFFC6AAFF),
      0.18 + 0.24 * door,
    );
    _glow(
      canvas,
      art(1180, 3020),
      80 * scale,
      Colors.white,
      0.08 + 0.20 * door,
    );
    // Paw sign on the cat house.
    _glow(
      canvas,
      art(1182, 2832),
      62 * scale,
      Colors.white,
      0.04 + 0.22 * _pulse(t, 5.0, 0.6),
    );
    // Collar pendant: quicker cyan shimmer.
    _glow(
      canvas,
      art(233, 2806),
      72 * scale,
      const Color(0xFF9CEBFF),
      0.12 + 0.38 * _pulse(t, 2.8, 0.3),
    );
  }

  void _paintMotes(Canvas canvas, Size size, double t) {
    final travel = size.height + 40;
    final halo = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    final core = Paint();
    for (final mote in _motes) {
      final y = (mote.y * travel - t * mote.speed) % travel - 20;
      final x =
          mote.x * size.width +
          mote.sway * math.sin(_tau * t / mote.period + mote.phase);
      final edgeFade = (math.min(y, size.height - y) / 80).clamp(0.0, 1.0);
      final alpha =
          (0.40 +
              0.25 * math.sin(_tau * t / (mote.period * 0.7) + mote.phase)) *
          edgeFade;
      if (alpha <= 0.01) continue;
      final center = Offset(x, y);
      halo.color = Colors.white.withValues(alpha: alpha * 0.7);
      canvas.drawCircle(center, mote.radius * 2.2, halo);
      core.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, mote.radius, core);
    }
  }

  void _paintStars(
    Canvas canvas,
    Offset Function(double, double) art,
    double scale,
    double t,
  ) {
    final glow = Paint();
    final fill = Paint();
    for (final star in _stars) {
      final wave = math.sin(_tau * (t / star.period + star.phase));
      if (wave <= 0) continue;
      final o = wave * wave * wave;
      final center = art(star.x, star.y);
      final r = star.radius * scale;
      glow
        ..color = const Color(0xFFE9DEFF).withValues(alpha: 0.65 * o)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.5, r * 0.9),
        );
      canvas.drawCircle(center, r * (1.3 + 0.6 * o), glow);

      final arm = r * (1.0 + 0.55 * o);
      final waist = arm * 0.2;
      final path = Path()
        ..moveTo(center.dx, center.dy - arm)
        ..lineTo(center.dx + waist, center.dy - waist)
        ..lineTo(center.dx + arm, center.dy)
        ..lineTo(center.dx + waist, center.dy + waist)
        ..lineTo(center.dx, center.dy + arm)
        ..lineTo(center.dx - waist, center.dy + waist)
        ..lineTo(center.dx - arm, center.dy)
        ..lineTo(center.dx - waist, center.dy - waist)
        ..close();
      fill.color = Colors.white.withValues(alpha: 0.95 * o);
      canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(_AmbientMotionPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}
