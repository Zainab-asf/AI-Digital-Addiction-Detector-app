import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
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

/// Ranked horizontal bars: label and duration above each bar, bar length
/// relative to the largest item. Reads cleanly at any width, unlike vertical
/// bars whose category labels collide on phones.
class UsageBarChart extends StatelessWidget {
  const UsageBarChart({super.key, required this.items, this.emptyHeight = 120});

  final List<UsageBarItem> items;
  final double emptyHeight;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return SizedBox(height: emptyHeight);
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final maxMinutes = items
        .map((e) => e.minutes)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Semantics(
            label:
                '${items[i].label}: '
                '${Formatters.duration(items[i].minutes)}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
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
                      Formatters.duration(items[i].minutes),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: c.textPrimary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ShareBar(
                  value: maxMinutes == 0 ? 0 : items[i].minutes / maxMinutes,
                  color: items[i].color,
                  height: 8,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A rounded proportional bar on a muted track.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  /// 0..1.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v == 0 ? 0 : v.clamp(0.02, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
