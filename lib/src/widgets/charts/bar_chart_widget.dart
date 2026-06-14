import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/formatters.dart';

/// One bar in [UsageBarChart].
class UsageBarItem {
  const UsageBarItem({
    required this.label,
    required this.minutes,
    required this.color,
  });

  final String label;
  final int minutes;
  final Color color;
}

/// Vertical bar chart used for category and "minutes by X" comparisons.
class UsageBarChart extends StatelessWidget {
  const UsageBarChart({
    super.key,
    required this.items,
    this.height = 220,
  });

  final List<UsageBarItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return SizedBox(height: height);
    }

    final maxMinutes =
        items.map((e) => e.minutes).reduce((a, b) => a > b ? a : b).toDouble();
    final yMax = ((maxMinutes / 60) * 1.25).clamp(0.5, 24.0).ceilToDouble();
    final yInterval = yMax <= 4 ? 1.0 : (yMax / 4).ceilToDouble();
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();
    final gridColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: yMax,
          minY: 0,
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
                reservedSize: 36,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= items.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      items[i].label,
                      style: labelStyle,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  theme.colorScheme.surface.withValues(alpha: 0.96),
              tooltipBorder: BorderSide(color: theme.dividerColor),
              getTooltipItem: (group, _, rod, __) {
                final i = group.x.toInt();
                if (i < 0 || i >= items.length) return null;
                final item = items[i];
                return BarTooltipItem(
                  '${item.label}\n${Formatters.duration(item.minutes)}',
                  theme.textTheme.bodyMedium ?? const TextStyle(),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: items[i].minutes / 60,
                    color: items[i].color,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
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
