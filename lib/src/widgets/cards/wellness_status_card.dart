import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../utils/formatters.dart';
import '../charts/score_ring.dart';
import '../common/app_card.dart';
import '../common/status_badge.dart';

/// Dashboard card summarising today's overall wellness score, its risk band
/// and the addiction-risk trend behind it.
class WellnessStatusCard extends StatelessWidget {
  const WellnessStatusCard({
    super.key,
    required this.prediction,
    this.compact = false,
  });

  final Prediction prediction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final severity = prediction.wellnessSeverity;
    final addiction = prediction.addiction;

    final message =
        addiction.isSteady
            ? 'Addiction risk is holding steady versus your recent average.'
            : addiction.isImproving
            ? 'Addiction risk is trending down versus your recent average.'
            : 'Addiction risk is up versus your recent average — a couple of '
                'small swaps can help.';

    return AppCard(
      padding: EdgeInsets.all(compact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Wellness status',
            muted: true,
            trailing: Text(
              'Updated ${Formatters.time(prediction.generatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ScoreRing(
                score: prediction.wellnessScore,
                color: c.severity(severity).solid,
                size: compact ? 76 : 88,
                strokeWidth: compact ? 8 : 9,
                label: null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.wellnessLabel,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge.severity(
                      context,
                      severity,
                      label: '${severity.label} risk',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: c.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Addiction risk',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              Text(
                '${addiction.score}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              const SizedBox(width: 10),
              TrendLabel.metric(addiction),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
