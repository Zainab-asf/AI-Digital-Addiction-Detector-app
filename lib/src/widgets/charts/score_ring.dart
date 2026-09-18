import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Animated circular 0–100 score with a rounded progress arc and the value
/// centred inside.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 92,
    this.strokeWidth = 9,
    this.label,
    this.caption,
  });

  /// 0..100.
  final int score;
  final Color color;
  final double size;
  final double strokeWidth;

  /// Small text above the number.
  final String? label;

  /// Small text below the number.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final clamped = score.clamp(0, 100);
    final track = Color.alphaBlend(
      color.withValues(alpha: c.isDark ? 0.18 : 0.14),
      c.surface,
    );

    return Semantics(
      label: '${label ?? 'Score'} $clamped out of 100',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: clamped / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder:
                  (context, value, _) => CustomPaint(
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
                if (label != null)
                  Text(label!, style: theme.textTheme.labelSmall),
                Text(
                  '$clamped',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: size * 0.27,
                    height: 1.1,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
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
    final ringRect = (Offset.zero & size).deflate(strokeWidth / 2);

    final track =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = trackColor;
    canvas.drawArc(ringRect, 0, 2 * pi, false, track);

    if (progress <= 0) return;
    final arc =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color;
    canvas.drawArc(ringRect, -pi / 2, 2 * pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
