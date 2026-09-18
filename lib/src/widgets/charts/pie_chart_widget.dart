import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/formatters.dart';
import 'bar_chart_widget.dart';

/// Donut of the category breakdown with a legend table (minutes and share).
///
/// Side-by-side by default; pass [stacked] on narrow cards to put the legend
/// under the donut instead of squeezing it.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({
    super.key,
    required this.slices,
    this.size = 148,
    this.stacked = false,
    this.centerCaption = 'total',
  });

  final List<UsageBarItem> slices;
  final double size;
  final bool stacked;
  final String centerCaption;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.minutes);
    if (total == 0) return SizedBox(height: size);

    final donut = _Donut(
      slices: slices,
      total: total,
      size: size,
      caption: centerCaption,
    );
    final legend = _Legend(slices: slices, total: total);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Center(child: donut), const SizedBox(height: 16), legend],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [donut, const SizedBox(width: 24), Expanded(child: legend)],
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({
    required this.slices,
    required this.total,
    required this.size,
    required this.caption,
  });

  final List<UsageBarItem> slices;
  final int total;
  final double size;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = size * 0.14;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size / 2 - ring,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    color: s.color,
                    value: s.minutes.toDouble(),
                    radius: ring,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.duration(total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              Text(caption, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices, required this.total});

  final List<UsageBarItem> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slices.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border:
                  i == slices.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: c.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slices[i].color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slices[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.duration(slices[i].minutes),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: c.textPrimary,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(slices[i].minutes / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
