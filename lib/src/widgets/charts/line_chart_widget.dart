import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../utils/formatters.dart';

/// Smoothed line chart of daily screen-time across a window of days.
/// Y-axis is hours, X-axis is weekday short labels. An optional horizontal
/// target line shows the user's daily limit.
class ScreenTimeLineChart extends StatelessWidget {
  const ScreenTimeLineChart({
    super.key,
    required this.days,
    this.targetMinutes,
    this.height = 220,
  });

  final List<DailyUsage> days;
  final int? targetMinutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (days.isEmpty) {
      return SizedBox(height: height);
    }

    final spots = <FlSpot>[
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].totalMinutes / 60.0),
    ];
    final maxY = (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) +
            (targetMinutes != null ? targetMinutes! / 60 : 0))
        .clamp(2.0, double.infinity);
    final yMax = ((maxY * 1.2).ceilToDouble()).clamp(2.0, 24.0);
    final yInterval = yMax <= 4 ? 1.0 : (yMax / 4).ceilToDouble();

    final gridColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days.length - 1).toDouble(),
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${value.toStringAsFixed(0)}h',
                      style: labelStyle,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Formatters.weekday(days[i].date),
                      style: labelStyle,
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: targetMinutes == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: targetMinutes! / 60,
                      color: AppTheme.moderate.withValues(alpha: 0.55),
                      strokeWidth: 1.4,
                      dashArray: const [6, 4],
                    ),
                  ],
                ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  theme.colorScheme.surface.withValues(alpha: 0.96),
              tooltipBorder: BorderSide(
                color: theme.dividerColor,
              ),
              getTooltipItems: (items) => items.map((item) {
                final i = item.x.toInt();
                final label = i >= 0 && i < days.length
                    ? Formatters.weekday(days[i].date)
                    : '';
                final minutes = (item.y * 60).round();
                return LineTooltipItem(
                  '$label\n${Formatters.duration(minutes)}',
                  theme.textTheme.bodyMedium ?? const TextStyle(),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.32,
              barWidth: 3,
              isStrokeCapRound: true,
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: AppTheme.primary,
                  strokeColor: theme.colorScheme.surface,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.28),
                    AppTheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
