import 'package:flutter/material.dart';

import 'gamepad_components.dart';

class GamepadTutorialFloatingCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isThai;
  final bool isLast;
  final bool showBack;
  final Color surfaceColor;
  final Color ctaColor;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final double maxWidth;
  final double? minHeight;
  final bool roomyCompact;
  final bool compact;

  const GamepadTutorialFloatingCard({
    super.key,
    required this.title,
    required this.body,
    required this.isThai,
    required this.isLast,
    required this.showBack,
    required this.surfaceColor,
    required this.ctaColor,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
    this.maxWidth = 420,
    this.minHeight,
    this.roomyCompact = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GamepadTutorialCard(
      title: title,
      body: body,
      isThai: isThai,
      isLast: isLast,
      showBack: showBack,
      surfaceColor: surfaceColor,
      ctaColor: ctaColor,
      onSkip: onSkip,
      onBack: onBack,
      onNext: onNext,
      maxWidth: maxWidth,
      minHeight: minHeight,
      roomyCompact: roomyCompact,
      compact: compact,
    );
  }
}

class GamepadTutorialMaskPainter extends CustomPainter {
  const GamepadTutorialMaskPainter({
    required this.holeRect,
    required this.radius,
    required this.color,
  });

  final Rect? holeRect;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = color;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    if (holeRect != null) {
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      canvas.drawRRect(
        RRect.fromRectAndRadius(holeRect!, Radius.circular(radius)),
        clearPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamepadTutorialMaskPainter oldDelegate) {
    return oldDelegate.holeRect != holeRect ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

enum GamepadPointerDirection { up, down, right }

class GamepadTutorialPointer extends StatelessWidget {
  final double size;
  final Color color;
  final GamepadPointerDirection direction;

  const GamepadTutorialPointer({
    super.key,
    required this.size,
    required this.color,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GamepadTutorialPointerPainter(
          color: color,
          direction: direction,
        ),
      ),
    );
  }
}

class _GamepadTutorialPointerPainter extends CustomPainter {
  final Color color;
  final GamepadPointerDirection direction;

  const _GamepadTutorialPointerPainter({
    required this.color,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tailColor = color.withAlpha(40);
    final bodyColor = color.withAlpha(215);
    final haloColor = color.withAlpha(112);
    final coreColor = Colors.white.withAlpha(210);

    late Offset start;
    late Offset end;
    late Offset c1;
    late Offset c2;
    late List<Offset> head;
    const headSize = 9.5;

    switch (direction) {
      case GamepadPointerDirection.up:
        start = Offset(center.dx - 1, size.height - 14);
        end = Offset(center.dx, 17);
        c1 = Offset(center.dx - 9, size.height * 0.72);
        c2 = Offset(center.dx + 7, size.height * 0.33);
        head = [
          end,
          Offset(end.dx - headSize, end.dy + headSize + 1),
          Offset(end.dx + headSize, end.dy + headSize + 1),
        ];
        break;
      case GamepadPointerDirection.down:
        start = Offset(center.dx + 1, 14);
        end = Offset(center.dx, size.height - 17);
        c1 = Offset(center.dx + 9, size.height * 0.28);
        c2 = Offset(center.dx - 7, size.height * 0.67);
        head = [
          end,
          Offset(end.dx - headSize, end.dy - headSize - 1),
          Offset(end.dx + headSize, end.dy - headSize - 1),
        ];
        break;
      case GamepadPointerDirection.right:
        start = Offset(11, center.dy + 2);
        end = Offset(size.width - 17, center.dy);
        c1 = Offset(size.width * 0.30, center.dy - 8);
        c2 = Offset(size.width * 0.69, center.dy + 7);
        head = [
          end,
          Offset(end.dx - headSize - 1, end.dy - headSize),
          Offset(end.dx - headSize - 1, end.dy + headSize),
        ];
        break;
    }

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    final haloPaint = Paint()
      ..color = haloColor
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawPath(path, haloPaint);

    final bodyPaint = Paint()
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [tailColor, bodyColor],
      ).createShader(Rect.fromPoints(start, end));
    canvas.drawPath(path, bodyPaint);

    final corePaint = Paint()
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..color = coreColor.withAlpha(170);
    canvas.drawPath(path, corePaint);

    final headPath = Path()..addPolygon(head, true);
    canvas.drawShadow(headPath, bodyColor.withAlpha(160), 8, false);
    canvas.drawPath(
      headPath,
      Paint()
        ..shader = LinearGradient(
          colors: [bodyColor.withAlpha(210), coreColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromPoints(head[1], head[2])),
    );

    canvas.drawCircle(
      start,
      3.0,
      Paint()..color = tailColor.withAlpha(130),
    );
    canvas.drawCircle(
      end,
      3.4,
      Paint()
        ..color = haloColor.withAlpha(200)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _GamepadTutorialPointerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.direction != direction;
  }
}
