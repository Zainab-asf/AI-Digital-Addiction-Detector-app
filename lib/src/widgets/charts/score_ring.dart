import 'dart:math';

import 'package:flutter/material.dart';

/// Animated circular score indicator with a rounded progress arc.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 180,
    this.strokeWidth = 14,
    this.label,
    this.caption,
  });

  /// 0..100.
  final int score;
  final Color color;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = score.clamp(0, 100);
    final track = color.withValues(alpha: 0.16);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: value,
                color: color,
                trackColor: track,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                Text(
                  label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '$clamped',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: size * 0.30,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = strokeWidth / 2;
    final ringRect = rect.deflate(inset);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ringRect, 0, 2 * pi, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: 0.7), color],
      ).createShader(ringRect);
    canvas.drawArc(ringRect, -pi / 2, 2 * pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
