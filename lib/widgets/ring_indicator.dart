import 'dart:math';
import 'package:flutter/material.dart';

/// HSL ring progress indicator (matches the JSX prototype)
class RingIndicator extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final double strokeWidth;

  const RingIndicator({
    super.key,
    required this.value,
    this.size = 72,
    this.strokeWidth = 5,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    // HSL: 0% → hue 0 (red), 100% → hue 120 (green)
    final hue = pct * 120;
    final color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.55).toColor();
    final textColor = HSLColor.fromAHSL(1.0, hue, 0.8, 0.65).toColor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: pct,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: size > 60 ? 13 : 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Small circular progress (for category cards)
class CategoryRing extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color color;
  final double size;

  const CategoryRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _SmallRingPainter(progress: pct, color: color),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: size > 40 ? 10 : 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SmallRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 3.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SmallRingPainter old) =>
      old.progress != progress || old.color != color;
}
