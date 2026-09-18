import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/cards/insight_card.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../widgets/charts/score_ring.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_badge.dart';
import '../coach/coach_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static void _openCoach(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CoachScreen()));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final prediction = state.prediction;

    return PageScaffold(
      title: 'Insights',
      subtitle:
          prediction == null
              ? 'Patterns detected on-device from your usage'
              : 'Patterns detected on-device from today\'s usage · updated '
                  '${Formatters.time(prediction.generatedAt)}',
      onRefresh: () => state.refreshUsage(),
      actions:
          (layout) => [
            if (prediction != null && !layout.compact)
              OutlinedButton.icon(
                onPressed: () => _openCoach(context),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Ask the coach'),
              ),
          ],
      builder: (context, layout) {
        if (prediction == null) {
          return [
            const SizedBox(height: 48),
            EmptyState(
              icon: Icons.lightbulb_outline_rounded,
              title: state.loadingData ? 'Analysing usage…' : 'No insights yet',
              message:
                  'Insights appear once there is a day of usage data to '
                  'look at.',
              actionLabel: state.loadingData ? null : 'Refresh',
              onAction: state.loadingData ? null : () => state.refreshUsage(),
            ),
          ];
        }

        final gap = layout.gap;
        final ordered = prediction.prioritisedInsights;
        final attention = ordered.where((i) => !i.positive).toList();
        final positive = ordered.where((i) => i.positive).toList();
        final twoUp = layout.width >= 900;

        final metrics = [
          for (final m in [
            prediction.addiction,
            prediction.focus,
            prediction.sleepImpact,
            prediction.burnoutRisk,
          ])
            _MetricCard(metric: m),
        ];

        final overview =
            layout.width >= 1100
                ? ResponsiveGrid(
                  columns: 5,
                  flex: const [6, 4, 4, 4, 4],
                  spacing: gap,
                  children: [_WellnessCard(prediction: prediction), ...metrics],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WellnessCard(prediction: prediction),
                    SizedBox(height: gap),
                    ResponsiveGrid(
                      columns:
                          layout.width >= 720
                              ? 4
                              : (layout.width >= 320 ? 2 : 1),
                      spacing: gap,
                      children: metrics,
                    ),
                  ],
                );

        return [
          overview,
          SizedBox(height: layout.compact ? 24 : 32),
          SectionHeader(
            title: 'Needs attention',
            count: attention.length,
            subtitle: attention.length < 2 ? null : 'Highest priority first',
          ),
          const SizedBox(height: 12),
          if (attention.isEmpty)
            const _AllClear()
          else
            ResponsiveGrid(
              columns: twoUp && attention.length > 1 ? 2 : 1,
              spacing: gap,
              children: [
                for (final insight in attention)
                  InsightCard(
                    insight: insight,
                    // Side-by-side labels need roughly 520px of card width.
                    sideLabels:
                        (!layout.compact && !twoUp) || layout.width >= 1100,
                  ),
              ],
            ),
          if (positive.isNotEmpty) ...[
            SizedBox(height: layout.compact ? 24 : 32),
            SectionHeader(title: 'Going well', count: positive.length),
            const SizedBox(height: 12),
            ResponsiveGrid(
              columns: twoUp && positive.length > 1 ? 2 : 1,
              spacing: gap,
              children: [
                for (final insight in positive) InsightCard(insight: insight),
              ],
            ),
          ],
          if (layout.compact) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _openCoach(context),
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Talk to the wellness coach'),
            ),
          ],
        ];
      },
    );
  }
}

class _WellnessCard extends StatelessWidget {
  const _WellnessCard({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final severity = prediction.wellnessSeverity;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ScoreRing(
            score: prediction.wellnessScore,
            color: c.severity(severity).solid,
            size: 80,
            strokeWidth: 8,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Overall wellness', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  prediction.wellnessLabel,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Blends addiction, focus, sleep and burnout signals.',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ScoreMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final tone = c.severity(metric.severity);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${metric.score}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  height: 1.2,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TrendLabel.metric(metric),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ShareBar(value: metric.score / 100, color: tone.solid, height: 4),
          const SizedBox(height: 8),
          Text(
            '${metric.severity.label} · '
            '${metric.higherIsBetter ? 'higher' : 'lower'} is better',
            maxLines: 2,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: c.good.solid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing needs your attention today.',
              style: theme.textTheme.bodyMedium?.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
