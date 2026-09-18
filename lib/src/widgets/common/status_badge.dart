import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';

/// Compact tinted label: severity bands, priorities, data source.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.dot = false,
    this.pill = false,
  });

  /// A badge coloured for a risk band ("Low", "Moderate", "High").
  factory StatusBadge.severity(
    BuildContext context,
    Severity severity, {
    String? label,
  }) {
    return StatusBadge(
      label: label ?? severity.label,
      tone: AppColors.of(context).severity(severity),
    );
  }

  final String label;
  final StatusTone tone;
  final bool dot;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: pill ? 26 : 22,
      padding: EdgeInsets.symmetric(horizontal: pill ? 10 : 8),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(pill ? 999 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone.solid,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone.onSoft,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Live device data" / "Demo data" indicator shown wherever numbers appear.
class DataSourceBadge extends StatelessWidget {
  const DataSourceBadge({super.key, required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message:
          isLive
              ? 'Screen time measured on this device'
              : 'Sample data — grant usage access to see your own',
      child: StatusBadge(
        label: isLive ? 'Live device data' : 'Demo data',
        tone: isLive ? c.good : c.info,
        dot: true,
        pill: true,
      ),
    );
  }
}

/// Whether a change is good, bad or neutral for the user.
enum TrendSentiment { positive, negative, neutral }

/// Arrow + short text describing a change ("↑ 3 pts", "↓ 19m").
///
/// Direction (arrow) and sentiment (color) are independent: more screen time
/// points up and is negative; a higher focus score points up and is positive.
class TrendLabel extends StatelessWidget {
  const TrendLabel({
    super.key,
    required this.label,
    required this.up,
    required this.sentiment,
    this.size = 12,
  });

  /// Trend for a [ScoreMetric] delta, respecting `higherIsBetter`.
  factory TrendLabel.metric(ScoreMetric metric, {double size = 12}) {
    if (metric.isSteady) {
      return TrendLabel(
        label: 'Steady',
        up: null,
        sentiment: TrendSentiment.neutral,
        size: size,
      );
    }
    return TrendLabel(
      label:
          '${metric.delta.abs().toStringAsFixed(0)} '
          '${metric.delta.abs().round() == 1 ? 'pt' : 'pts'}',
      up: metric.delta > 0,
      sentiment:
          metric.isImproving
              ? TrendSentiment.positive
              : TrendSentiment.negative,
      size: size,
    );
  }

  final String label;

  /// Arrow direction; null draws a flat dash.
  final bool? up;
  final TrendSentiment sentiment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final color = switch (sentiment) {
      TrendSentiment.positive => c.good.onSoft,
      TrendSentiment.negative => c.critical.onSoft,
      TrendSentiment.neutral => c.textTertiary,
    };
    final icon = switch (up) {
      true => Icons.arrow_upward_rounded,
      false => Icons.arrow_downward_rounded,
      null => Icons.remove_rounded,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size + 2, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ),
      ],
    );
  }
}
