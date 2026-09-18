import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/cards/app_usage_row.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../widgets/charts/hourly_usage_chart.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/charts/screen_time_chart.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/common/segmented_control.dart';
import '../../widgets/common/status_badge.dart';
import '../weekly/weekly_report_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _windowDays = 7;

  static const _periods = [
    SegmentOption(value: 7, label: '7 days'),
    SegmentOption(value: 14, label: '14 days'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;
    final today = state.todayUsage;

    Widget periodPicker({bool expand = false}) => SegmentedControl<int>(
      options: _periods,
      selected: _windowDays,
      onChanged: (v) => setState(() => _windowDays = v),
      expand: expand,
      semanticLabel: 'Time period',
    );

    return PageScaffold(
      title: 'Analytics',
      subtitle: 'Screen-time patterns across your recent history',
      onRefresh: () => state.refreshUsage(),
      actions:
          (layout) => [
            if (history.isNotEmpty && layout.compact)
              IconButton.outlined(
                tooltip: 'Weekly report',
                onPressed:
                    () =>
                        Navigator.of(context).push(WeeklyReportScreen.route()),
                icon: const Icon(Icons.date_range_outlined, size: 18),
              ),
            if (history.isNotEmpty && !layout.compact) ...[
              OutlinedButton.icon(
                onPressed:
                    () =>
                        Navigator.of(context).push(WeeklyReportScreen.route()),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: const Text('Weekly report'),
              ),
              periodPicker(),
            ],
          ],
      builder: (context, layout) {
        if (history.isEmpty) {
          return [
            const SizedBox(height: 48),
            EmptyState(
              icon: Icons.bar_chart_rounded,
              title:
                  state.loadingData ? 'Loading analytics…' : 'No analytics yet',
              message: 'Refresh to load your screen-time history.',
              actionLabel: state.loadingData ? null : 'Refresh',
              onAction: state.loadingData ? null : () => state.refreshUsage(),
            ),
          ];
        }

        final window = _tail(history, _windowDays);
        final previous =
            history.length >= window.length * 2
                ? history.sublist(
                  history.length - window.length * 2,
                  history.length - window.length,
                )
                : const <DailyUsage>[];
        final goal = state.dailyLimitMinutes;
        final gap = layout.gap;
        final halfColumns = layout.width >= 820 ? 2 : 1;

        final dailyChart = AppCard(
          padding: EdgeInsets.fromLTRB(
            layout.compact ? 16 : 22,
            20,
            layout.compact ? 16 : 22,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                title: 'Daily screen time',
                subtitle:
                    '${_rangeLabel(window)} · compared with your '
                    '${Formatters.duration(goal)} goal',
                trailing: layout.compact ? null : const _ChartLegend(),
              ),
              if (layout.compact) ...[
                const SizedBox(height: 12),
                const _ChartLegend(),
              ],
              const SizedBox(height: 20),
              ScreenTimeChart(
                days: window,
                goalMinutes: goal,
                height: layout.compact ? 200 : 240,
              ),
            ],
          ),
        );

        final categoryMix = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                title: 'Category mix',
                subtitle:
                    today == null
                        ? 'Today'
                        : 'Where today\'s '
                            '${Formatters.duration(today.totalMinutes)} went',
              ),
              const SizedBox(height: 20),
              if (today == null || today.totalMinutes == 0)
                const _NoDataNote('No usage recorded yet today.')
              else
                CategoryPieChart(
                  slices: _slices(context, today),
                  stacked:
                      layout.width < 460 ||
                      (halfColumns == 2 && layout.width < 1000),
                  centerCaption: 'today',
                ),
            ],
          ),
        );

        final averages = _categoryAverages(context, window);
        final categoryAverages = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                title: 'Average by category',
                subtitle: 'Daily mean over ${_periodLabel(window.length)}',
              ),
              const SizedBox(height: 20),
              if (averages.isEmpty)
                const _NoDataNote('No category data in this period.')
              else
                UsageBarChart(items: averages),
            ],
          ),
        );

        final hourly = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHeader(
                title: 'Today by the hour',
                subtitle:
                    today == null || today.totalMinutes == 0
                        ? 'No usage recorded yet today'
                        : 'Peak at ${Formatters.hourLabel(today.peakHour)} · '
                            '${Formatters.duration(today.nightMinutes)} '
                            'between 10pm and 5am',
                trailing:
                    today != null && today.hourlySource == UsageSource.estimated
                        ? Tooltip(
                          message:
                              'Your device reports daily totals only, so '
                              'the hourly split is estimated.',
                          child: StatusBadge(
                            label: 'Estimated',
                            tone: AppColors.of(context).info,
                          ),
                        )
                        : null,
              ),
              const SizedBox(height: 20),
              if (today == null)
                const _NoDataNote('No usage recorded yet today.')
              else ...[
                HourlyUsageChart(hourlyMinutes: today.hourlyMinutes),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _LegendSwatch(kind: _Swatch.day, label: 'Daytime'),
                    _LegendSwatch(kind: _Swatch.night, label: '10pm – 5am'),
                    _LegendSwatch(kind: _Swatch.peak, label: 'Peak hour'),
                  ],
                ),
              ],
            ],
          ),
        );

        final topApps = _WindowTopApps(
          window: window,
          table: layout.width >= 640 && halfColumns == 1,
        );

        return [
          if (layout.compact) ...[
            periodPicker(expand: true),
            SizedBox(height: gap),
          ],
          _SummaryStats(
            window: window,
            previous: previous,
            goal: goal,
            columns: layout.width >= 760 ? 4 : 2,
            gap: gap,
            stackFooter: layout.compact,
          ),
          SizedBox(height: gap),
          dailyChart,
          SizedBox(height: gap),
          ResponsiveGrid(
            columns: halfColumns,
            spacing: gap,
            children: [categoryMix, categoryAverages],
          ),
          SizedBox(height: gap),
          ResponsiveGrid(
            columns: halfColumns,
            spacing: gap,
            children: [hourly, topApps],
          ),
        ];
      },
    );
  }

  List<DailyUsage> _tail(List<DailyUsage> days, int n) {
    if (days.length <= n) return days;
    return days.sublist(days.length - n);
  }

  static String _periodLabel(int days) =>
      days == 1 ? 'the last day' : 'the last $days days';

  static String _rangeLabel(List<DailyUsage> days) {
    if (days.isEmpty) return '';
    if (days.length == 1) return Formatters.shortDate(days.first.date);
    return '${Formatters.shortDate(days.first.date)} – '
        '${Formatters.shortDate(days.last.date)}';
  }

  List<UsageBarItem> _slices(BuildContext context, DailyUsage day) {
    final c = AppColors.of(context);
    final entries =
        day.categoryMinutes.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) => UsageBarItem(
            label: e.key.label,
            minutes: e.value,
            color: c.category(e.key),
          ),
        )
        .toList();
  }

  List<UsageBarItem> _categoryAverages(
    BuildContext context,
    List<DailyUsage> days,
  ) {
    if (days.isEmpty) return const [];
    final c = AppColors.of(context);
    final totals = <AppCategory, int>{};
    for (final d in days) {
      for (final entry in d.categoryMinutes.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final averages =
        totals.entries
            .map(
              (e) => (
                category: e.key,
                minutes: (e.value / days.length).round(),
              ),
            )
            .where((e) => e.minutes > 0)
            .toList()
          ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return averages
        .take(5)
        .map(
          (e) => UsageBarItem(
            label: e.category.label,
            minutes: e.minutes,
            color: c.category(e.category),
          ),
        )
        .toList();
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({
    required this.window,
    required this.previous,
    required this.goal,
    required this.columns,
    required this.gap,
    required this.stackFooter,
  });

  final List<DailyUsage> window;
  final List<DailyUsage> previous;
  final int goal;
  final int columns;
  final double gap;
  final bool stackFooter;

  @override
  Widget build(BuildContext context) {
    final total = window.fold<int>(0, (s, d) => s + d.totalMinutes);
    final average = (total / window.length).round();
    final overGoal = window.where((d) => d.totalMinutes > goal).length;
    final busiest = window.reduce(
      (a, b) => b.totalMinutes > a.totalMinutes ? b : a,
    );

    Widget? averageTrend;
    String averageCaption = 'Per day';
    if (previous.isNotEmpty) {
      final prevAverage =
          (previous.fold<int>(0, (s, d) => s + d.totalMinutes) /
                  previous.length)
              .round();
      final diff = average - prevAverage;
      averageCaption = 'vs prior ${previous.length} days';
      averageTrend =
          diff == 0
              ? const TrendLabel(
                label: 'Same',
                up: null,
                sentiment: TrendSentiment.neutral,
              )
              : TrendLabel(
                label: Formatters.duration(diff.abs()),
                up: diff > 0,
                sentiment:
                    diff > 0
                        ? TrendSentiment.negative
                        : TrendSentiment.positive,
              );
    }

    return ResponsiveGrid(
      columns: columns,
      spacing: gap,
      children: [
        StatCard(
          stackFooter: stackFooter,
          label: 'Daily average',
          value: Formatters.duration(average),
          caption: averageCaption,
          trailing: averageTrend,
        ),
        StatCard(
          stackFooter: stackFooter,
          label: 'Total screen time',
          value: Formatters.duration(total),
          caption: '${window.length} days',
        ),
        StatCard(
          stackFooter: stackFooter,
          label: 'Days over goal',
          value: '$overGoal',
          unit: 'of ${window.length}',
          caption: 'Goal ${Formatters.duration(goal)} per day',
        ),
        StatCard(
          stackFooter: stackFooter,
          label: 'Busiest day',
          value: Formatters.duration(busiest.totalMinutes),
          caption:
              '${Formatters.weekday(busiest.date)}, '
              '${Formatters.shortDate(busiest.date)}',
        ),
      ],
    );
  }
}

/// Most-used apps across the selected period, as a daily average.
class _WindowTopApps extends StatelessWidget {
  const _WindowTopApps({required this.window, required this.table});

  final List<DailyUsage> window;
  final bool table;

  @override
  Widget build(BuildContext context) {
    final byPackage = <String, AppUsage>{};
    for (final day in window) {
      for (final app in day.apps) {
        final existing = byPackage[app.packageName];
        byPackage[app.packageName] = AppUsage(
          packageName: app.packageName,
          appName: app.appName,
          category: app.category,
          minutes: (existing?.minutes ?? 0) + app.minutes,
          opens: (existing?.opens ?? 0) + app.opens,
          opensSource: app.opensSource,
        );
      }
    }
    final ranked =
        byPackage.values.toList()
          ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final top = ranked.take(5).toList();
    final total = window.fold<int>(0, (s, d) => s + d.totalMinutes);
    final days = window.isEmpty ? 1 : window.length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Top apps',
            subtitle: 'Average per day over the last $days days',
          ),
          const SizedBox(height: 10),
          if (top.isEmpty)
            const _NoDataNote('No app usage in this period.')
          else ...[
            if (table)
              const AppUsageTableHeader(
                shareLabel: 'SHARE OF PERIOD',
                opensLabel: 'OPENS/DAY',
                timeLabel: 'PER DAY',
              ),
            for (var i = 0; i < top.length; i++)
              AppUsageRow(
                usage: top[i],
                totalMinutes: total,
                table: table,
                showDivider: i < top.length - 1,
                minutesLabel: Formatters.duration(
                  (top[i].minutes / days).round(),
                ),
                opensLabel:
                    '${top[i].opensSource == UsageSource.estimated ? '≈' : ''}'
                    '${(top[i].opens / days).round()}',
              ),
          ],
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _LegendSwatch(kind: _Swatch.withinGoal, label: 'Within goal'),
        _LegendSwatch(kind: _Swatch.overGoal, label: 'Over goal'),
        _LegendSwatch(kind: _Swatch.goalLine, label: 'Goal'),
      ],
    );
  }
}

enum _Swatch { withinGoal, overGoal, goalLine, day, night, peak }

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.kind, required this.label});

  final _Swatch kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final color = switch (kind) {
      _Swatch.withinGoal => c.primary,
      _Swatch.overGoal => c.warning.solid,
      _Swatch.goalLine => c.textTertiary,
      _Swatch.day => c.chartAccent,
      _Swatch.night => c.chartNight,
      _Swatch.peak => c.primary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kind == _Swatch.goalLine)
          SizedBox(
            width: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                3,
                (_) => Container(width: 3, height: 2, color: color),
              ),
            ),
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _NoDataNote extends StatelessWidget {
  const _NoDataNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
