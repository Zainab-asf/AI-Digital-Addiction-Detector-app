import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../utils/formatters.dart';
import '../charts/bar_chart_widget.dart';

/// One app in a ranked usage list: category tile, name, share-of-day bar,
/// opens and time. Renders as a table row when [table] is true (wide
/// layouts, aligned with [AppUsageTableHeader]) and as a stacked row
/// otherwise.
class AppUsageRow extends StatelessWidget {
  const AppUsageRow({
    super.key,
    required this.usage,
    required this.totalMinutes,
    this.table = false,
    this.showDivider = true,
    this.minutesLabel,
    this.opensLabel,
  });

  final AppUsage usage;

  /// Denominator for the share bar.
  final int totalMinutes;
  final bool table;
  final bool showDivider;

  /// Overrides the time text (e.g. "58m/day" for averages).
  final String? minutesLabel;

  /// Overrides the opens text.
  final String? opensLabel;

  static const double opensColumnWidth = 72;
  static const double timeColumnWidth = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final ratio =
        totalMinutes == 0
            ? 0.0
            : (usage.minutes / totalMinutes).clamp(0.0, 1.0);
    final percent = '${(ratio * 100).round()}%';
    final color = c.category(usage.category);
    // Open counts on a real device are inferred, not measured; say so.
    final estimated = usage.opensSource == UsageSource.estimated;
    final opens = opensLabel ?? '${estimated ? '≈' : ''}${usage.opens}';
    final time = minutesLabel ?? Formatters.duration(usage.minutes);

    final tile = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.categorySoft(usage.category),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(usage.category.icon, color: color, size: 18),
    );

    final name = Text(
      usage.appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall,
    );

    final numberStyle = theme.textTheme.titleSmall?.copyWith(
      fontFeatures: AppTheme.tabular,
    );

    final Widget row;
    if (table) {
      row = Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                tile,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      Text(
                        usage.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: ShareBar(value: ratio, color: color)),
                SizedBox(
                  width: 44,
                  child: Text(
                    percent,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: opensColumnWidth,
            child: Text(
              opens,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
          SizedBox(
            width: timeColumnWidth,
            child: Text(time, textAlign: TextAlign.right, style: numberStyle),
          ),
        ],
      );
    } else {
      row = Row(
        children: [
          tile,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: name),
                    const SizedBox(width: 8),
                    Text(time, style: numberStyle),
                  ],
                ),
                const SizedBox(height: 6),
                ShareBar(value: ratio, color: color, height: 4),
                const SizedBox(height: 6),
                Text(
                  '${usage.category.label} · $opens ${usage.opens == 1 ? 'open' : 'opens'} · $percent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Semantics(
      label:
          '${usage.appName}, ${usage.category.label}, '
          '$time, $opens opens, $percent of total',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border:
              showDivider
                  ? Border(bottom: BorderSide(color: c.borderSubtle))
                  : null,
        ),
        child: row,
      ),
    );
  }
}

/// Column labels matching [AppUsageRow] in table mode.
class AppUsageTableHeader extends StatelessWidget {
  const AppUsageTableHeader({
    super.key,
    this.shareLabel = 'SHARE',
    this.opensLabel = 'OPENS',
    this.timeLabel = 'TIME',
  });

  final String shareLabel;
  final String opensLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final style = theme.textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('APP', style: style)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: Text(shareLabel, style: style)),
          SizedBox(
            width: AppUsageRow.opensColumnWidth,
            child: Text(opensLabel, textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: AppUsageRow.timeColumnWidth,
            child: Text(timeLabel, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
