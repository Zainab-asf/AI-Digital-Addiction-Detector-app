import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../charts/score_ring.dart';

/// Hero dashboard card showing today's addiction risk score plus a wellness
/// caption and a trend chip.
class AddictionScoreCard extends StatelessWidget {
  const AddictionScoreCard({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addiction = prediction.addiction;
    final color = addiction.severity.color;
    final improving = addiction.isImproving;
    final steady = addiction.isSteady;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScoreRing(
            score: addiction.score,
            color: color,
            size: 152,
            strokeWidth: 12,
            label: 'ADDICTION RISK',
            caption: addiction.severity.label,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wellness',
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${prediction.wellnessScore} · ${prediction.wellnessLabel}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _TrendChip(
                  delta: addiction.delta,
                  steady: steady,
                  improving: improving,
                  higherIsBetter: false,
                ),
                const SizedBox(height: 12),
                Text(
                  steady
                      ? 'Holding steady versus your recent average.'
                      : improving
                          ? 'Trending in the right direction — keep it up.'
                          : 'Slight uptick — a couple of small swaps can help.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.delta,
    required this.steady,
    required this.improving,
    required this.higherIsBetter,
  });

  final double delta;
  final bool steady;
  final bool improving;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = steady
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : improving
            ? AppTheme.good
            : AppTheme.severe;
    final icon = steady
        ? Icons.remove_rounded
        : improving
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded;
    // For risk metrics (higherIsBetter=false), a falling delta is the
    // improving case — flip the icon so the arrow always matches intuition.
    final displayIcon = higherIsBetter
        ? (steady
            ? Icons.remove_rounded
            : improving
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded)
        : icon;
    final label = steady
        ? 'Steady'
        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)} pts';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(displayIcon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
