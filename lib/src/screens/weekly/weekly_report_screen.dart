import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/usage_log.dart';
import '../../services/scoring_engine.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/charts/screen_time_chart.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/common/status_badge.dart';

/// This week (last 7 days) against the 7 days before it.
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const WeeklyReportScreen());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;
    final thisWeek = _tail(history, 7);
    final lastWeek =
        history.length > 7
            ? _tail(history.sublist(0, history.length - thisWeek.length), 7)
            : const <DailyUsage>[];

    return PageScaffold(
      showBack: true,
      title: 'Weekly report',
      subtitle:
          thisWeek.isEmpty
              ? 'Your last 7 days at a glance'
              : '${_range(thisWeek)}'
                  '${lastWeek.isEmpty ? '' : ' · compared with ${_range(lastWeek)}'}',
      onRefresh: () => state.refreshUsage(),
      builder: (context, layout) {
        if (thisWeek.isEmpty) {
          return [
            const SizedBox(height: 48),
            EmptyState(
              icon: Icons.date_range_rounded,
              title: 'No usage history yet',
              message:
                  'The report fills in once LoopAware has a few days of '
                  'screen-time data.',
              actionLabel: 'Refresh',
              onAction: () => state.refreshUsage(),
            ),
          ];
        }

        final goal = state.dailyLimitMinutes;
        final now = _WeekFigures(thisWeek, goal);
        final prev = lastWeek.isEmpty ? null : _WeekFigures(lastWeek, goal);
        final gap = layout.gap;
        final twoUp = layout.width >= 820;

        final lastPrediction =
            lastWeek.isEmpty
                ? null
                : ScoringEngine.evaluate(
                  history.sublist(0, history.length - thisWeek.length),
                  dailyLimitMinutes: goal,
                );

        return [
          ResponsiveGrid(
            columns: layout.width >= 760 ? 4 : 2,
            spacing: gap,
            children: [
              StatCard(
                label: 'Daily average',
                value: Formatters.duration(now.average),
                caption: prev == null ? 'Per day' : 'vs last week',
                trailing:
                    prev == null
                        ? null
                        : _minutesTrend(now.average - prev.average),
                stackFooter: layout.compact,
              ),
              StatCard(
                label: 'Total screen time',
                value: Formatters.duration(now.total),
                caption: '${thisWeek.length} days',
                stackFooter: layout.compact,
              ),
              StatCard(
                label: 'Days within goal',
                value: '${now.daysWithinGoal}',
                unit: 'of ${thisWeek.length}',
                caption:
                    prev == null
                        ? 'Goal ${Formatters.duration(goal)}'
                        : 'Last week ${prev.daysWithinGoal}',
                stackFooter: layout.compact,
              ),
              StatCard(
                label: 'Pickups per day',
                value: '${now.pickupsPerDay}',
                caption: prev == null ? 'Average' : 'vs last week',
                trailing:
                    prev == null
                        ? null
                        : _countTrend(now.pickupsPerDay - prev.pickupsPerDay),
                stackFooter: layout.compact,
              ),
            ],
          ),
          SizedBox(height: gap),
          ResponsiveGrid(
            columns: twoUp ? 2 : 1,
            spacing: gap,
            flex: const [3, 2],
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CardHeader(
                      title: 'Daily screen time',
                      subtitle: 'Goal ${Formatters.duration(goal)} per day',
                    ),
                    const SizedBox(height: 20),
                    ScreenTimeChart(
                      days: thisWeek,
                      goalMinutes: goal,
                      height: 220,
                      compact: true,
                    ),
                  ],
                ),
              ),
              _Highlights(
                now: now,
                prev: prev,
                focusMinutes: _focusMinutes(state, thisWeek),
                focusCount: _focusCount(state, thisWeek),
              ),
            ],
          ),
          SizedBox(height: gap),
          ResponsiveGrid(
            columns: twoUp ? 2 : 1,
            spacing: gap,
            children: [
              _ScoresCard(current: state.prediction, previous: lastPrediction),
              _CategoryChangeCard(now: now, prev: prev),
            ],
          ),
        ];
      },
    );
  }

  static List<DailyUsage> _tail(List<DailyUsage> days, int n) =>
      days.length <= n ? days : days.sublist(days.length - n);

  static String _range(List<DailyUsage> days) =>
      '${Formatters.shortDate(days.first.date)} – '
      '${Formatters.shortDate(days.last.date)}';

  static bool _inWeek(DateTime t, List<DailyUsage> week) {
    final start = week.first.date;
    final end = week.last.date.add(const Duration(days: 1));
    return !t.isBefore(start) && t.isBefore(end);
  }

  static int _focusMinutes(AppState state, List<DailyUsage> week) => state
      .focusSessions
      .where((s) => _inWeek(s.startedAt, week))
      .fold(0, (sum, s) => sum + s.focusedMinutes);

  static int _focusCount(AppState state, List<DailyUsage> week) =>
      state.focusSessions
          .where((s) => _inWeek(s.startedAt, week) && s.completed)
          .length;
}

Widget _minutesTrend(int diff) =>
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
              diff > 0 ? TrendSentiment.negative : TrendSentiment.positive,
        );

Widget _countTrend(int diff) =>
    diff == 0
        ? const TrendLabel(
          label: 'Same',
          up: null,
          sentiment: TrendSentiment.neutral,
        )
        : TrendLabel(
          label: '${diff.abs()}',
          up: diff > 0,
          sentiment:
              diff > 0 ? TrendSentiment.negative : TrendSentiment.positive,
        );

/// Aggregates for one 7-day window.
class _WeekFigures {
  _WeekFigures(this.days, int goal)
    : total = days.fold(0, (s, d) => s + d.totalMinutes),
      daysWithinGoal = days.where((d) => d.totalMinutes <= goal).length,
      pickupsPerDay =
          days.isEmpty
              ? 0
              : (days.fold(0, (s, d) => s + d.pickups) / days.length).round() {
    average = days.isEmpty ? 0 : (total / days.length).round();
    for (final d in days) {
      d.categoryMinutes.forEach((k, v) {
        categoryTotals[k] = (categoryTotals[k] ?? 0) + v;
      });
      for (final a in d.apps) {
        appTotals[a.appName] = (appTotals[a.appName] ?? 0) + a.minutes;
      }
    }
  }

  final List<DailyUsage> days;
  final int total;
  final int daysWithinGoal;
  final int pickupsPerDay;
  late final int average;
  final Map<AppCategory, int> categoryTotals = {};
  final Map<String, int> appTotals = {};

  int categoryAverage(AppCategory c) =>
      days.isEmpty ? 0 : ((categoryTotals[c] ?? 0) / days.length).round();

  DailyUsage get lightest =>
      days.reduce((a, b) => b.totalMinutes < a.totalMinutes ? b : a);

  DailyUsage get heaviest =>
      days.reduce((a, b) => b.totalMinutes > a.totalMinutes ? b : a);

  MapEntry<String, int>? get topApp =>
      appTotals.isEmpty
          ? null
          : appTotals.entries.reduce((a, b) => b.value > a.value ? b : a);
}

class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.now,
    required this.prev,
    required this.focusMinutes,
    required this.focusCount,
  });

  final _WeekFigures now;
  final _WeekFigures? prev;
  final int focusMinutes;
  final int focusCount;

  String _day(DailyUsage d) =>
      '${Formatters.weekday(d.date)}, ${Formatters.shortDate(d.date)}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = prev;
    final lines = <({IconData icon, Color color, String text})>[];

    if (p != null) {
      final diff = now.average - p.average;
      lines.add((
        icon:
            diff <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
        color: diff <= 0 ? c.good.onSoft : c.critical.onSoft,
        text:
            diff == 0
                ? 'Daily screen time held steady versus last week.'
                : 'Screen time ${diff < 0 ? 'down' : 'up'} '
                    '${Formatters.duration(diff.abs())} a day versus last week.',
      ));
    }
    lines.add((
      icon: Icons.wb_sunny_outlined,
      color: c.textSecondary,
      text:
          'Lightest day: ${_day(now.lightest)} — '
          '${Formatters.duration(now.lightest.totalMinutes)}.',
    ));
    lines.add((
      icon: Icons.local_fire_department_outlined,
      color: c.textSecondary,
      text:
          'Heaviest day: ${_day(now.heaviest)} — '
          '${Formatters.duration(now.heaviest.totalMinutes)}.',
    ));
    final top = now.topApp;
    if (top != null) {
      lines.add((
        icon: Icons.apps_rounded,
        color: c.textSecondary,
        text:
            'Most used app: ${top.key}, '
            '${Formatters.duration((top.value / now.days.length).round())} '
            'a day on average.',
      ));
    }
    lines.add((
      icon: Icons.timer_outlined,
      color: c.textSecondary,
      text:
          focusMinutes == 0
              ? 'No focus sessions this week yet.'
              : '$focusCount completed focus '
                  '${focusCount == 1 ? 'session' : 'sessions'}, '
                  '${Formatters.duration(focusMinutes)} focused in total.',
    ));

    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHeader(title: 'Highlights'),
          const SizedBox(height: 12),
          for (var i = 0; i < lines.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border:
                    i == lines.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: c.borderSubtle)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(lines[i].icon, size: 18, color: lines[i].color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lines[i].text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoresCard extends StatelessWidget {
  const _ScoresCard({required this.current, required this.previous});

  final Prediction? current;
  final Prediction? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final now = current;
    if (now == null) {
      return const AppCard(child: CardHeader(title: 'Wellness scores'));
    }
    final before = previous;

    final rows = <({String label, int value, int? old, bool higherIsBetter})>[
      (
        label: 'Overall wellness',
        value: now.wellnessScore,
        old: before?.wellnessScore,
        higherIsBetter: true,
      ),
      for (final pair in [
        (now.addiction, before?.addiction),
        (now.focus, before?.focus),
        (now.sleepImpact, before?.sleepImpact),
        (now.burnoutRisk, before?.burnoutRisk),
      ])
        (
          label: pair.$1.label,
          value: pair.$1.score,
          old: pair.$2?.score,
          higherIsBetter: pair.$1.higherIsBetter,
        ),
    ];

    final labelStyle = theme.textTheme.labelSmall;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Wellness scores',
            subtitle:
                before == null
                    ? 'Today'
                    : 'Today compared with the end of last week',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('SCORE', style: labelStyle)),
              if (before != null)
                SizedBox(
                  width: 64,
                  child: Text(
                    'LAST WK',
                    textAlign: TextAlign.right,
                    style: labelStyle,
                  ),
                ),
              SizedBox(
                width: 56,
                child: Text(
                  'NOW',
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              ),
              if (before != null) const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: i == 0 ? c.border : c.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (before != null)
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${rows[i].old ?? '—'}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${rows[i].value}',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ),
                  if (before != null)
                    SizedBox(
                      width: 72,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _scoreTrend(rows[i]),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreTrend(
    ({String label, int value, int? old, bool higherIsBetter}) row,
  ) {
    final old = row.old;
    if (old == null) return const SizedBox.shrink();
    final diff = row.value - old;
    if (diff == 0) {
      return const TrendLabel(
        label: 'Same',
        up: null,
        sentiment: TrendSentiment.neutral,
      );
    }
    final better = (diff > 0) == row.higherIsBetter;
    return TrendLabel(
      label: '${diff.abs()}',
      up: diff > 0,
      sentiment: better ? TrendSentiment.positive : TrendSentiment.negative,
    );
  }
}

class _CategoryChangeCard extends StatelessWidget {
  const _CategoryChangeCard({required this.now, required this.prev});

  final _WeekFigures now;
  final _WeekFigures? prev;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final p = prev;
    final categories =
        {...now.categoryTotals.keys, ...?p?.categoryTotals.keys}.toList()..sort(
          (a, b) => now.categoryAverage(b).compareTo(now.categoryAverage(a)),
        );
    final shown = categories.take(6).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Categories',
            subtitle:
                p == null
                    ? 'Average per day this week'
                    : 'Average per day, this week vs last week',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < shown.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: i == 0 ? c.border : c.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.category(shown[i]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shown[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.duration(now.categoryAverage(shown[i])),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  if (p != null)
                    SizedBox(
                      width: 72,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _minutesTrend(
                          now.categoryAverage(shown[i]) -
                              p.categoryAverage(shown[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
