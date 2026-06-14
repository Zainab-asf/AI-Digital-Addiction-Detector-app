import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../widgets/charts/hourly_heatmap.dart';
import '../../widgets/charts/line_chart_widget.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/section_header.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _windowDays = 7;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;
    final today = state.todayUsage;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () => state.refreshUsage(),
        child: history.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No analytics yet',
                  message: 'Pull to refresh to load screen-time data.',
                  actionLabel: 'Refresh',
                  onAction: () => state.refreshUsage(),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _PeriodSelector(
                    selected: _windowDays,
                    onChanged: (v) => setState(() => _windowDays = v),
                  ),
                  const SizedBox(height: 20),
                  _ChartCard(
                    title: 'Screen time',
                    subtitle:
                        'Last $_windowDays days · target ${Formatters.duration(state.dailyLimitMinutes)}',
                    child: ScreenTimeLineChart(
                      days: _tail(history, _windowDays),
                      targetMinutes: state.dailyLimitMinutes,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Category mix',
                    subtitle: 'Where today\'s minutes went',
                    child: today == null
                        ? const SizedBox(height: 140)
                        : CategoryPieChart(slices: _slices(today)),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Average by category',
                    subtitle: 'Daily mean over the last $_windowDays days',
                    child: UsageBarChart(
                      items: _categoryAverages(
                        _tail(history, _windowDays),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Today by the hour',
                    subtitle: today == null
                        ? '—'
                        : 'Peak at ${Formatters.hourLabel(today.peakHour)} · '
                            '${Formatters.duration(today.nightMinutes)} after 10pm',
                    child: today == null
                        ? const SizedBox(height: 80)
                        : HourlyHeatmap(hourlyMinutes: today.hourlyMinutes),
                  ),
                ],
              ),
      ),
    );
  }

  List<DailyUsage> _tail(List<DailyUsage> days, int n) {
    if (days.length <= n) return days;
    return days.sublist(days.length - n);
  }

  List<UsageBarItem> _slices(DailyUsage day) {
    final entries = day.categoryMinutes.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => UsageBarItem(
              label: e.key.label,
              minutes: e.value,
              color: e.key.color,
            ))
        .toList();
  }

  List<UsageBarItem> _categoryAverages(List<DailyUsage> days) {
    if (days.isEmpty) return const [];
    final totals = <AppCategory, int>{};
    for (final d in days) {
      for (final entry in d.categoryMinutes.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final averages = totals.entries
        .map((e) =>
            (category: e.key, minutes: (e.value / days.length).round()))
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return averages
        .take(5)
        .map((e) => UsageBarItem(
              label: e.category.label,
              minutes: e.minutes,
              color: e.category.color,
            ))
        .toList();
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const List<({String label, int days})> _options = [
    (label: '7 days', days: 7),
    (label: '14 days', days: 14),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: _options.map((option) {
          final isActive = option.days == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isActive
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
