import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../state/app_state.dart';
import '../../widgets/cards/insight_card.dart';
import '../../widgets/charts/score_ring.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/section_header.dart';
import '../coach/coach_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final prediction = state.prediction;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: () => state.refreshUsage(),
        child: prediction == null
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'No insights yet',
                  message: 'We need a day of data before we can spot patterns.',
                  actionLabel: 'Refresh',
                  onAction: () => state.refreshUsage(),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _WellnessHeader(prediction: prediction),
                  const SizedBox(height: 18),
                  _MetricsGrid(prediction: prediction),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'What we noticed today',
                    subtitle:
                        '${prediction.insights.length} insights · prioritised',
                  ),
                  const SizedBox(height: 12),
                  for (final insight in prediction.prioritisedInsights) ...[
                    InsightCard(insight: insight),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                  _TalkToCoachButton(),
                ],
              ),
      ),
    );
  }
}

class _WellnessHeader extends StatelessWidget {
  const _WellnessHeader({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = prediction.wellnessSeverity.color;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          ScoreRing(
            score: prediction.wellnessScore,
            color: color,
            size: 90,
            strokeWidth: 8,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall wellness',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  prediction.wellnessLabel,
                  style: theme.textTheme.titleLarge?.copyWith(color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  'A blended view of addiction, focus, sleep and burnout '
                  'signals from today.',
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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      prediction.addiction,
      prediction.focus,
      prediction.sleepImpact,
      prediction.burnoutRisk,
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: metrics.map((m) => _MetricTile(metric: m)).toList(),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final ScoreMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = metric.severity.color;
    final steady = metric.isSteady;
    final improving = metric.isImproving;
    final trendIcon = steady
        ? Icons.remove_rounded
        : metric.higherIsBetter
            ? (improving
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded)
            : (improving
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded);
    final trendColor =
        steady ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : (improving ? AppTheme.good : AppTheme.severe);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          ScoreRing(
            score: metric.score,
            color: color,
            size: 64,
            strokeWidth: 7,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  metric.severity.label,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(trendIcon, color: trendColor, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        steady
                            ? 'Steady'
                            : '${metric.delta > 0 ? '+' : ''}${metric.delta.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: trendColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TalkToCoachButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CoachScreen()),
      ),
      icon: const Icon(Icons.self_improvement_rounded),
      label: const Text('Talk to the wellness coach'),
    );
  }
}
