import 'package:flutter/material.dart';

import '../../models/usage_log.dart';
import '../../utils/formatters.dart';

/// Single-app row: category icon + name + duration + horizontal progress bar
/// showing this app's share of the day's screen-time.
class AppUsageCard extends StatelessWidget {
  const AppUsageCard({
    super.key,
    required this.usage,
    required this.dailyTotalMinutes,
  });

  final AppUsage usage;
  final int dailyTotalMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = dailyTotalMinutes == 0
        ? 0.0
        : (usage.minutes / dailyTotalMinutes).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final color = usage.category.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(usage.category.icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        usage.appName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.duration(usage.minutes),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      usage.category.label,
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                    const SizedBox(width: 6),
                    Text('•', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 6),
                    Text(
                      '${usage.opens} opens',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      '$percent%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
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
