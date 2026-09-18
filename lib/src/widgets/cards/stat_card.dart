import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../common/app_card.dart';

/// Compact KPI card: icon + label, a large value with optional unit, and a
/// footer line pairing context ([caption]) with a trend or badge
/// ([trailing]).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.unit,
    this.caption,
    this.trailing,
    this.tooltip,
    this.stackFooter = false,
  });

  /// Put [caption] and [trailing] on separate lines (narrow grids).
  final bool stackFooter;

  final String label;
  final String value;
  final IconData? icon;
  final String? unit;
  final String? caption;
  final Widget? trailing;

  /// Optional explanation of the metric, shown on long-press / hover.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);

    Widget card = AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: c.textSecondary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              height: 32 / 26,
              fontFeatures: AppTheme.tabular,
            ),
          ),
          const SizedBox(height: 8),
          if (stackFooter) ...[
            // Narrow cards: caption and trend on their own lines so neither
            // truncates. (A Wrap would misreport its intrinsic height inside
            // an equal-height grid row.)
            Text(
              caption ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (trailing != null) ...[const SizedBox(height: 4), trailing!],
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    caption ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: trailing!),
                ],
              ],
            ),
        ],
      ),
    );

    if (tooltip != null) card = Tooltip(message: tooltip!, child: card);
    return card;
  }
}
