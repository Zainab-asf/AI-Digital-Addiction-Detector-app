import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/usage_log.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/cards/addiction_score_card.dart';
import '../../widgets/cards/app_usage_card.dart';
import '../../widgets/cards/insight_card.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/section_header.dart';
import '../coach/coach_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: GreetingAppBar(
        greeting: Formatters.greeting(),
        name: state.firstName,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: state.loadingData ? null : () => state.refreshUsage(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshUsage(),
        child: _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    if (!state.dataLoaded && state.loadingData) {
      return const _LoadingPlaceholder();
    }
    final today = state.todayUsage;
    final prediction = state.prediction;
    if (today == null || prediction == null) {
      return EmptyState(
        icon: Icons.insights_rounded,
        title: 'No data yet',
        message: 'Pull to refresh and we will generate today\'s wellness scores.',
        actionLabel: 'Refresh',
        onAction: () => state.refreshUsage(),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _SourceBadge(isLive: state.isLiveData),
        const SizedBox(height: 14),
        AddictionScoreCard(prediction: prediction),
        const SizedBox(height: 20),
        _StatRow(prediction: prediction, today: today, limit: state.dailyLimitMinutes),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Top apps today',
          subtitle: '${today.apps.length} apps · ${Formatters.duration(today.totalMinutes)} total',
        ),
        const SizedBox(height: 12),
        ...today.appsByUsage.take(4).map(
          (app) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppUsageCard(
              usage: app,
              dailyTotalMinutes: today.totalMinutes,
            ),
          ),
        ),
        if (prediction.insights.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionHeader(
            title: 'Top recommendation',
            subtitle: 'Based on patterns LoopAware noticed today',
          ),
          const SizedBox(height: 12),
          InsightCard(insight: prediction.prioritisedInsights.first),
          const SizedBox(height: 16),
          _CoachCta(),
        ],
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLive ? AppTheme.good : AppTheme.info;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isLive ? 'Live device data' : 'Demo data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.prediction,
    required this.today,
    required this.limit,
  });

  final Prediction prediction;
  final DailyUsage today;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final overshoot = today.totalMinutes - limit;
    final caption = overshoot <= 0
        ? '${Formatters.duration(-overshoot)} under limit'
        : '${Formatters.duration(overshoot)} over limit';

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.18,
      children: [
        StatCard(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Screen time',
          value: Formatters.duration(today.totalMinutes),
          caption: caption,
          accent: overshoot > 0 ? AppTheme.severe : AppTheme.good,
        ),
        StatCard(
          icon: Icons.touch_app_rounded,
          label: 'Pickups',
          value: '${today.pickups}',
          caption:
              'avg ${(today.pickups == 0 ? 0 : today.totalMinutes / today.pickups).toStringAsFixed(1)} min/session',
          accent: AppTheme.tertiary,
        ),
        StatCard(
          icon: Icons.center_focus_strong_rounded,
          label: prediction.focus.label,
          value: '${prediction.focus.score}',
          caption: prediction.focus.severity.label,
          accent: prediction.focus.severity.color,
        ),
        StatCard(
          icon: Icons.bedtime_rounded,
          label: 'Sleep impact',
          value: '${prediction.sleepImpact.score}',
          caption: '${Formatters.duration(today.nightMinutes)} after 10pm',
          accent: prediction.sleepImpact.severity.color,
        ),
      ],
    );
  }
}

class _CoachCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.calmGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 24,
            child: Icon(Icons.self_improvement_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talk to the wellness coach',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get a personalised plan for the next 24 hours.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoachScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: const [
        LoadingShimmer(height: 28, width: 120, borderRadius: 16),
        SizedBox(height: 14),
        LoadingShimmer(height: 188, borderRadius: 24),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: LoadingShimmer(height: 96, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: LoadingShimmer(height: 96, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: LoadingShimmer(height: 96, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: LoadingShimmer(height: 96, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 24),
        ShimmerList(count: 3),
      ],
    );
  }
}
