import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../utils/formatters.dart';

/// Daily screen-time columns measured against the user's goal.
///
/// The full variant has an hour axis and colors each day by whether it went
/// over the goal. The [compact] variant is a sparkline-sized history for the
/// dashboard: no axis, muted past days and today emphasised.
class ScreenTimeChart extends StatelessWidget {
  const ScreenTimeChart({
    super.key,
    required this.days,
    required this.goalMinutes,
    this.height = 220,
    this.compact = false,
  });

  final List<DailyUsage> days;
  final int goalMinutes;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return SizedBox(height: height);
    // The compact variant can sit inside an IntrinsicHeight row, which a
    // LayoutBuilder cannot, so only the full chart measures its width.
    if (compact) return _chart(context, barWidth: 14, slotWidth: 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth - 40;
        final slot = plotWidth / days.length;
        return _chart(
          context,
          barWidth: (slot * 0.5).clamp(6.0, 40.0),
          slotWidth: slot,
        );
      },
    );
  }

  Widget _chart(
    BuildContext context, {
    required double barWidth,
    required double slotWidth,
  }) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();

    final maxMinutes = days.map((d) => d.totalMinutes).fold(0, math.max);
    final rawMax = math.max(maxMinutes, goalMinutes) / 60 * 1.12;
    final interval = rawMax <= 5 ? 1.0 : (rawMax <= 10 ? 2.0 : 4.0);
    final yMax = math.max(interval, (rawMax / interval).ceil() * interval);

    String bottomLabel(int i) {
      final day = days[i];
      final isToday = i == days.length - 1;
      if (compact || slotWidth < 34) return Formatters.weekday(day.date)[0];
      if (isToday && slotWidth >= 44) return 'Today';
      return Formatters.weekday(day.date);
    }

    Color barColor(int i) {
      final isLast = i == days.length - 1;
      if (compact) return isLast ? c.primary : c.chartMuted;
      return days[i].totalMinutes > goalMinutes ? c.warning.solid : c.primary;
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine:
                (_) => FlLine(color: c.borderSubtle, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goalMinutes / 60,
                color: compact ? c.warning.solid : c.textTertiary,
                strokeWidth: 1.5,
                dashArray: const [5, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !compact,
                reservedSize: 40,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max && value % interval != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      value == 0 ? '0' : '${value.toStringAsFixed(0)}h',
                      style: labelStyle.copyWith(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: compact ? 22 : 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  final isToday = i == days.length - 1;
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      bottomLabel(i),
                      style: labelStyle.copyWith(
                        fontSize: 11,
                        color: isToday ? c.textPrimary : null,
                        fontWeight: isToday ? FontWeight.w800 : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.isDark ? c.surfaceMuted : c.textPrimary,
              tooltipBorderRadius: BorderRadius.circular(AppTheme.radiusSm),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, _, rod, __) {
                final i = group.x;
                if (i < 0 || i >= days.length) return null;
                final day = days[i];
                final over = day.totalMinutes - goalMinutes;
                final fg = c.isDark ? c.textPrimary : c.surface;
                return BarTooltipItem(
                  '${Formatters.weekday(day.date)}, '
                  '${Formatters.shortDate(day.date)}\n',
                  labelStyle.copyWith(color: fg.withValues(alpha: 0.75)),
                  children: [
                    TextSpan(
                      text: Formatters.duration(day.totalMinutes),
                      style: labelStyle.copyWith(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          over > 0
                              ? '\n${Formatters.duration(over)} over goal'
                              : '\nWithin goal',
                      style: labelStyle.copyWith(
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].totalMinutes / 60,
                    color: barColor(i),
                    width: barWidth,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(math.min(6, barWidth / 3)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
