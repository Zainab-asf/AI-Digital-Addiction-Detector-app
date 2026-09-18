import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../utils/formatters.dart';

/// 24 columns showing when in the day the phone was used. Late-night hours
/// are tinted separately and the peak hour is emphasised.
class HourlyUsageChart extends StatelessWidget {
  const HourlyUsageChart({
    super.key,
    required this.hourlyMinutes,
    this.height = 140,
  });

  final List<int> hourlyMinutes;
  final double height;

  static bool isNightHour(int hour) =>
      hour >= AppConstants.nightUsageStartHour ||
      hour < AppConstants.nightUsageEndHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();
    final maxMinutes = hourlyMinutes.fold(0, math.max);
    final peak = maxMinutes == 0 ? -1 : hourlyMinutes.indexOf(maxMinutes);
    final yMax = math.max(10, (maxMinutes * 1.1).ceil()).toDouble();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          minY: 0,
          maxY: yMax,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final hour = value.toInt();
                  if (hour % 6 != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      Formatters.hourLabel(hour),
                      style: labelStyle.copyWith(fontSize: 11),
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
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, _, rod, __) {
                final hour = group.x;
                final fg = c.isDark ? c.textPrimary : c.surface;
                return BarTooltipItem(
                  '${Formatters.hourLabel(hour)}–'
                  '${Formatters.hourLabel(hour + 1)}\n',
                  labelStyle.copyWith(color: fg.withValues(alpha: 0.75)),
                  children: [
                    TextSpan(
                      text: Formatters.duration(hourlyMinutes[hour]),
                      style: labelStyle.copyWith(
                        color: fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var hour = 0; hour < hourlyMinutes.length; hour++)
              BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    // A sliver of height keeps empty hours visible on the
                    // baseline without implying usage.
                    toY: math.max(hourlyMinutes[hour].toDouble(), yMax * 0.015),
                    width: 7,
                    color:
                        hourlyMinutes[hour] == 0
                            ? c.border
                            : hour == peak
                            ? c.primary
                            : isNightHour(hour)
                            ? c.chartNight
                            : c.chartAccent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
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
