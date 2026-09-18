import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/usage_log.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/cards/app_usage_row.dart';
import '../../widgets/cards/insight_card.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/cards/wellness_status_card.dart';
import '../../widgets/charts/screen_time_chart.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/common/status_badge.dart';
import '../../services/scoring_engine.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../coach/coach_screen.dart';
import '../focus/focus_screen.dart';
import '../limits/app_limits_screen.dart';
import '../weekly/weekly_report_screen.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasData = state.todayUsage != null && state.prediction != null;

    return PageScaffold(
      overline: Formatters.longDate(DateTime.now()),
      title: '${Formatters.greeting()}, ${state.firstName}',
      onRefresh: () => state.refreshUsage(),
      actions:
          (layout) => [
            if (hasData && !layout.compact)
              DataSourceBadge(isLive: state.isLiveData),
            _RefreshButton(state: state, iconOnly: layout.compact),
          ],
      builder: (context, layout) {
        if (!state.dataLoaded && state.loadingData) {
          return [_DashboardSkeleton(layout: layout)];
        }
        final today = state.todayUsage;
        final prediction = state.prediction;
        if (today == null || prediction == null) {
          return [
            const SizedBox(height: 48),
            EmptyState(
              icon: Icons.insights_rounded,
              title: 'No data yet',
              message:
                  'Refresh to load today\'s screen time and generate your '
                  'wellness scores.',
              actionLabel: 'Refresh',
              onAction: () => state.refreshUsage(),
            ),
          ];
        }
        return _content(context, layout, state, today, prediction);
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    PageLayout layout,
    AppState state,
    DailyUsage today,
    Prediction prediction,
  ) {
    final history = state.history;
    final gap = layout.gap;
    final tabs = HomeTabs.maybeOf(context);

    final screenTime = _ScreenTimeCard(
      today: today,
      history: history,
      last7: state.last7Days,
      goalMinutes: state.dailyLimitMinutes,
      sideChart: layout.wide,
      compact: layout.compact,
    );
    final wellness = WellnessStatusCard(
      prediction: prediction,
      compact: layout.compact,
    );
    final stats = _KeyStats(
      today: today,
      yesterday: _previousDay(history),
      prediction: prediction,
      columns: layout.width >= 760 ? 4 : (layout.width >= 280 ? 2 : 1),
      gap: gap,
      stackFooter: layout.compact,
    );
    final topApps = _TopAppsCard(
      today: today,
      table: layout.width >= 640 && !layout.compact,
      onViewAll: tabs == null ? null : () => tabs.select(HomeTabs.analytics),
    );
    final insights = prediction.prioritisedInsights;
    final recommendation =
        insights.isEmpty
            ? null
            : InsightCard(
              insight: insights.first,
              dense: true,
              eyebrow:
                  insights.first.positive
                      ? 'Today\'s highlight'
                      : 'Top recommendation',
              footer:
                  tabs == null
                      ? null
                      : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => tabs.select(HomeTabs.insights),
                          child: Text(
                            insights.length == 1
                                ? 'Open insights'
                                : 'See all ${insights.length} insights',
                          ),
                        ),
                      ),
            );
    final coach = _ToolsCard(
      focusMinutes: ScoringEngine.suggestedFocusMinutes(today),
    );
    final limits =
        state.appLimits.isEmpty
            ? null
            : _AppLimitsCard(
              today: today,
              history: history,
              limits: state.appLimits,
            );

    if (layout.wide) {
      return [
        ResponsiveGrid(
          columns: 2,
          flex: const [2, 1],
          spacing: gap,
          children: [screenTime, wellness],
        ),
        SizedBox(height: gap),
        stats,
        SizedBox(height: gap),
        ResponsiveGrid(
          columns: 2,
          flex: const [2, 1],
          spacing: gap,
          children: [
            topApps,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recommendation != null) ...[
                  Expanded(child: recommendation),
                  SizedBox(height: gap),
                ] else
                  const Spacer(),
                coach,
              ],
            ),
          ],
        ),
        if (limits != null) ...[SizedBox(height: gap), limits],
      ];
    }

    return [
      if (layout.compact) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: DataSourceBadge(isLive: state.isLiveData),
        ),
        SizedBox(height: gap),
      ],
      screenTime,
      SizedBox(height: gap),
      wellness,
      SizedBox(height: gap),
      stats,
      SizedBox(height: gap),
      topApps,
      if (limits != null) ...[SizedBox(height: gap), limits],
      if (recommendation != null) ...[SizedBox(height: gap), recommendation],
      SizedBox(height: gap),
      coach,
    ];
  }

  static DailyUsage? _previousDay(List<DailyUsage> history) =>
      history.length >= 2 ? history[history.length - 2] : null;
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.state, required this.iconOnly});

  final AppState state;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final loading = state.loadingData;
    final icon =
        loading
            ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : const Icon(Icons.refresh_rounded, size: 18);
    final onPressed = loading ? null : () => state.refreshUsage();

    if (iconOnly) {
      return IconButton.outlined(
        tooltip: 'Refresh',
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          side: BorderSide(color: AppColors.of(context).borderStrong),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: const Text('Refresh'),
    );
  }
}

/// Today's total against the goal, with yesterday / weekly-average
/// comparisons and a 7-day history.
class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard({
    required this.today,
    required this.history,
    required this.last7,
    required this.goalMinutes,
    required this.sideChart,
    required this.compact,
  });

  final DailyUsage today;
  final List<DailyUsage> history;
  final List<DailyUsage> last7;
  final int goalMinutes;
  final bool sideChart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final total = today.totalMinutes;
    final over = total - goalMinutes;

    final previous = history.length >= 2 ? history[history.length - 2] : null;
    final prior =
        history.length >= 2
            ? history.sublist(
              math.max(0, history.length - 8),
              history.length - 1,
            )
            : const <DailyUsage>[];
    final priorAverage =
        prior.isEmpty
            ? null
            : (prior.fold<int>(0, (s, d) => s + d.totalMinutes) / prior.length)
                .round();
    final previousLabel =
        previous == null
            ? 'vs yesterday'
            : today.date.difference(previous.date).inDays == 1
            ? 'vs yesterday'
            : 'vs ${Formatters.shortDate(previous.date)}';

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CardHeader(title: 'Screen time today', muted: true),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              Formatters.duration(total),
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: compact ? 34 : 40,
                fontFeatures: AppTheme.tabular,
              ),
            ),
            StatusBadge(
              label:
                  over > 0
                      ? '${Formatters.duration(over)} over goal'
                      : over == 0
                      ? 'At goal'
                      : '${Formatters.duration(-over)} left',
              tone: over > 0 ? c.critical : c.good,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GoalBar(total: total, goal: goalMinutes),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                goalMinutes == 0
                    ? ''
                    : '${(total / goalMinutes * 100).round()}% of daily goal',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(
              'Goal ${Formatters.duration(goalMinutes)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: c.border),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Comparison(
                  label: previousLabel,
                  today: total,
                  reference: previous?.totalMinutes,
                  referenceLabel:
                      previous == null
                          ? 'No earlier data'
                          : 'Was ${Formatters.duration(previous.totalMinutes)}',
                ),
              ),
              VerticalDivider(color: c.border, width: 32),
              Expanded(
                child: _Comparison(
                  label: 'vs ${prior.length}-day average',
                  today: total,
                  reference: priorAverage,
                  referenceLabel:
                      priorAverage == null
                          ? 'No earlier data'
                          : 'Average ${Formatters.duration(priorAverage)}',
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Last ${last7.length} days',
                style: theme.textTheme.labelMedium,
              ),
            ),
            _LegendDash(color: c.warning.solid, label: 'Goal'),
          ],
        ),
        const SizedBox(height: 12),
        ScreenTimeChart(
          days: last7,
          goalMinutes: goalMinutes,
          compact: true,
          height: sideChart ? 150 : 110,
        ),
      ],
    );

    return AppCard(
      padding: EdgeInsets.all(compact ? 18 : 22),
      child:
          sideChart
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  VerticalDivider(color: c.border, width: 48),
                  SizedBox(width: 260, child: chart),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: 16),
                  Divider(color: c.border),
                  const SizedBox(height: 14),
                  chart,
                ],
              ),
    );
  }
}

/// Progress toward the daily goal; any overshoot is drawn in red past the
/// goal mark.
class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.total, required this.goal});

  final int total;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scale = math.max(math.max(total, goal), 1);
    final within = math.min(total, goal);
    final over = math.max(0, total - goal);
    final remaining = math.max(0, scale - within - over);

    return Semantics(
      label:
          '${Formatters.duration(total)} of '
          '${Formatters.duration(goal)} goal',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 8,
          color: c.surfaceMuted,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (within > 0)
                Expanded(flex: within, child: ColoredBox(color: c.primary)),
              if (over > 0) ...[
                const SizedBox(width: 2),
                Expanded(
                  flex: over,
                  child: ColoredBox(color: c.critical.solid),
                ),
              ],
              if (remaining > 0)
                Expanded(flex: remaining, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.label,
    required this.today,
    required this.reference,
    required this.referenceLabel,
  });

  final String label;
  final int today;
  final int? reference;
  final String referenceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = reference;
    final diff = ref == null ? 0 : today - ref;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        if (ref == null)
          Text('—', style: theme.textTheme.titleMedium)
        else if (diff == 0)
          const TrendLabel(
            label: 'Same',
            up: null,
            sentiment: TrendSentiment.neutral,
            size: 15,
          )
        else
          TrendLabel(
            label:
                '${Formatters.duration(diff.abs())} '
                '${diff > 0 ? 'more' : 'less'}',
            up: diff > 0,
            sentiment:
                diff > 0 ? TrendSentiment.negative : TrendSentiment.positive,
            size: 15,
          ),
        const SizedBox(height: 2),
        Text(
          referenceLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(width: 4, height: 2, color: color),
        ],
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _KeyStats extends StatelessWidget {
  const _KeyStats({
    required this.today,
    required this.yesterday,
    required this.prediction,
    required this.columns,
    required this.gap,
    required this.stackFooter,
  });

  final DailyUsage today;
  final DailyUsage? yesterday;
  final Prediction prediction;
  final int columns;
  final double gap;
  final bool stackFooter;

  @override
  Widget build(BuildContext context) {
    final pickupDiff =
        yesterday == null ? null : today.pickups - yesterday!.pickups;
    final avgSession =
        today.pickups == 0 ? 0.0 : today.totalMinutes / today.pickups;

    Widget? pickupTrend() {
      final diff = pickupDiff;
      if (diff == null) return null;
      if (diff == 0) {
        return const TrendLabel(
          label: 'Same',
          up: null,
          sentiment: TrendSentiment.neutral,
        );
      }
      return TrendLabel(
        label: '${diff.abs()}',
        up: diff > 0,
        sentiment: diff > 0 ? TrendSentiment.negative : TrendSentiment.positive,
      );
    }

    return ResponsiveGrid(
      columns: columns,
      spacing: gap,
      children: [
        StatCard(
          stackFooter: stackFooter,
          icon: Icons.smartphone_rounded,
          label: 'Pickups',
          value: '${today.pickups}',
          caption: '${avgSession.toStringAsFixed(1)} min/session',
          trailing: pickupTrend(),
          tooltip: 'App opens today. Trend compares with the previous day.',
        ),
        StatCard(
          stackFooter: stackFooter,
          icon: Icons.center_focus_strong_outlined,
          label: prediction.focus.label,
          value: '${prediction.focus.score}',
          unit: '/100',
          caption: prediction.focus.severity.label,
          trailing: TrendLabel.metric(prediction.focus),
          tooltip: 'Higher is better. Trend compares with your recent average.',
        ),
        StatCard(
          stackFooter: stackFooter,
          icon: Icons.bedtime_outlined,
          label: 'Sleep impact',
          value: '${prediction.sleepImpact.score}',
          unit: '/100',
          caption: '${Formatters.duration(today.nightMinutes)} after 10pm',
          trailing: TrendLabel.metric(prediction.sleepImpact),
          tooltip: 'Lower is better. Based on use between 10pm and 5am.',
        ),
        StatCard(
          stackFooter: stackFooter,
          icon: Icons.speed_rounded,
          label: 'Burnout risk',
          value: '${prediction.burnoutRisk.score}',
          unit: '/100',
          caption: prediction.burnoutRisk.severity.label,
          trailing: TrendLabel.metric(prediction.burnoutRisk),
          tooltip: 'Lower is better. Reflects heavy use across the week.',
        ),
      ],
    );
  }
}

class _TopAppsCard extends StatelessWidget {
  const _TopAppsCard({
    required this.today,
    required this.table,
    required this.onViewAll,
  });

  final DailyUsage today;
  final bool table;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apps = today.appsByUsage.take(5).toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Top apps today',
            subtitle:
                '${today.apps.length} apps · '
                '${Formatters.duration(today.totalMinutes)} total',
            trailing:
                onViewAll == null
                    ? null
                    : TextButton(
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('View analytics'),
                    ),
          ),
          const SizedBox(height: 10),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No app usage recorded yet today.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else ...[
            if (table) const AppUsageTableHeader(shareLabel: 'SHARE OF DAY'),
            for (var i = 0; i < apps.length; i++)
              AppUsageRow(
                usage: apps[i],
                totalMinutes: today.totalMinutes,
                table: table,
                showDivider: i < apps.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

/// Shortcuts to the focus timer, weekly report and wellness coach.
class _ToolsCard extends StatelessWidget {
  const _ToolsCard({required this.focusMinutes});

  /// Suggested focus-block length for today.
  final int focusMinutes;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nav = Navigator.of(context);
    final tools = [
      (
        icon: Icons.timer_outlined,
        title: 'Focus session',
        subtitle: 'Start a ${Formatters.duration(focusMinutes)} block',
        open: () => nav.push(FocusScreen.route()),
      ),
      (
        icon: Icons.date_range_outlined,
        title: 'Weekly report',
        subtitle: 'This week against last week',
        open: () => nav.push(WeeklyReportScreen.route()),
      ),
      (
        icon: Icons.forum_outlined,
        title: 'Wellness coach',
        subtitle: 'A plan for the rest of today',
        open:
            () => nav.push(
              MaterialPageRoute<void>(builder: (_) => const CoachScreen()),
            ),
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg - 1),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tools.length; i++)
                InkWell(
                  onTap: tools[i].open,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border:
                          i == tools.length - 1
                              ? null
                              : Border(
                                bottom: BorderSide(color: c.borderSubtle),
                              ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Icon(
                            tools[i].icon,
                            color: c.onPrimarySoft,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tools[i].title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                tools[i].subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: c.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's use of each app that has a daily limit.
class _AppLimitsCard extends StatelessWidget {
  const _AppLimitsCard({
    required this.today,
    required this.history,
    required this.limits,
  });

  /// Used to name apps with a limit that have not been opened today.
  final List<DailyUsage> history;

  final DailyUsage today;
  final Map<String, int> limits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final byPackage = {for (final a in today.apps) a.packageName: a};
    final known = {
      for (final day in history)
        for (final a in day.apps) a.packageName: a,
    };
    final rows =
        limits.entries.map((e) {
            final app = byPackage[e.key];
            return (
              name: (app ?? known[e.key])?.appName ?? e.key,
              category: (app ?? known[e.key])?.category ?? AppCategory.other,
              used: app?.minutes ?? 0,
              limit: e.value,
            );
          }).toList()
          ..sort((a, b) => (b.used / b.limit).compareTo(a.used / a.limit));
    final over = rows.where((r) => r.used > r.limit).length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'App limits',
            subtitle:
                over == 0
                    ? 'All apps within their limits today'
                    : '$over ${over == 1 ? 'app is' : 'apps are'} over the limit',
            trailing: TextButton(
              onPressed:
                  () => Navigator.of(context).push(AppLimitsScreen.route()),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Manage'),
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border:
                    i == rows.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: c.borderSubtle)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${Formatters.duration(rows[i].used)} / '
                        '${Formatters.duration(rows[i].limit)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              rows[i].used > rows[i].limit
                                  ? c.critical.onSoft
                                  : c.textPrimary,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ShareBar(
                    value: rows[i].used / rows[i].limit,
                    color:
                        rows[i].used > rows[i].limit
                            ? c.critical.solid
                            : c.category(rows[i].category),
                    height: 6,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.layout});

  final PageLayout layout;

  @override
  Widget build(BuildContext context) {
    final gap = layout.gap;
    final stats = ResponsiveGrid(
      columns: layout.width >= 760 ? 4 : 2,
      spacing: gap,
      children: List.generate(4, (_) => const SkeletonCard(height: 124)),
    );
    if (layout.wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(
            columns: 2,
            flex: const [2, 1],
            spacing: gap,
            children: const [
              SkeletonCard(height: 280, lines: 3),
              SkeletonCard(height: 280, lines: 3),
            ],
          ),
          SizedBox(height: gap),
          stats,
          SizedBox(height: gap),
          const _SkeletonList(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonCard(height: 300, lines: 3),
        SizedBox(height: gap),
        const SkeletonCard(height: 180),
        SizedBox(height: gap),
        stats,
        SizedBox(height: gap),
        const _SkeletonList(),
      ],
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingShimmer(height: 14, width: 120),
          SizedBox(height: 12),
          ShimmerList(count: 3),
        ],
      ),
    );
  }
}
