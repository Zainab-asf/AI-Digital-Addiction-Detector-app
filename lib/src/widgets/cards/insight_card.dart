import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/prediction.dart';
import '../common/app_card.dart';
import '../common/status_badge.dart';

/// Renders one [Insight] as what happened, why it matters and what to do.
///
/// Positive insights render as a short confirmation row. [dense] drops the
/// category overline and rationale for tight spaces such as the dashboard.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insight,
    this.dense = false,
    this.sideLabels = false,
    this.eyebrow,
    this.footer,
  });

  final Insight insight;
  final bool dense;

  /// Put "What happened" / "Why it matters" labels beside the text (wide
  /// cards) instead of above it.
  final bool sideLabels;

  /// Replaces the category overline (e.g. "Top recommendation").
  final String? eyebrow;

  /// Extra content under the card body, such as a link.
  final Widget? footer;

  /// Why each kind of pattern matters. Written as general, modest guidance;
  /// kinds whose engine description already explains the impact return null.
  static String? whyItMatters(InsightKind kind) => switch (kind) {
    InsightKind.screenTime =>
      'Going past a goal you set is the clearest sign that usage is drifting '
          'from your intentions.',
    InsightKind.pickups =>
      'Each check interrupts what you were doing, and getting back into a '
          'task takes time.',
    InsightKind.dopamineLoop =>
      'Short, repeated sessions reinforce habitual checking more than '
          'deliberate use does.',
    InsightKind.focus =>
      'Deep work depends on longer stretches of uninterrupted attention.',
    InsightKind.balance =>
      'When most time goes to feeds and video, less is left for rest, work '
          'or learning.',
    InsightKind.burnout =>
      'Heavy use without lighter days lets fatigue build from one day to the '
          'next.',
    InsightKind.nightUsage => null,
    InsightKind.achievement => null,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tone = insight.positive ? c.good : c.severity(insight.priority);
    if (insight.positive && !dense) return _PositiveRow(insight: insight);

    final theme = Theme.of(context);
    final why = insight.positive ? null : whyItMatters(insight.kind);
    final badge = StatusBadge(
      label: insight.positive ? 'Good news' : insight.priority.label,
      tone: tone,
    );

    return AppCard(
      padding: EdgeInsets.all(dense ? 18 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dense) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    eyebrow ?? insight.kind.label,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 10),
            Text(insight.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              insight.description,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(icon: insight.kind.icon, tone: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (eyebrow ?? insight.kind.label).toUpperCase(),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(insight.title, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                badge,
              ],
            ),
            const SizedBox(height: 14),
            _LabeledText(
              label: 'What happened',
              text: insight.description,
              side: sideLabels,
              emphasis: true,
            ),
            if (why != null) ...[
              const SizedBox(height: 10),
              _LabeledText(
                label: 'Why it matters',
                text: why,
                side: sideLabels,
              ),
            ],
          ],
          if (insight.recommendation != null) ...[
            const SizedBox(height: 14),
            _ActionBox(text: insight.recommendation!),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.tone});

  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(icon, color: tone.onSoft, size: 18),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({
    required this.label,
    required this.text,
    required this.side,
    this.emphasis = false,
  });

  final String label;
  final String text;
  final bool side;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 19 / 13,
      color: emphasis ? c.textPrimary : c.textSecondary,
    );
    if (side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 116, child: Text(label, style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: textStyle)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle?.copyWith(fontSize: 12)),
        const SizedBox(height: 2),
        Text(text, style: textStyle),
      ],
    );
  }
}

class _ActionBox extends StatelessWidget {
  const _ActionBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Try this: ',
                    style: TextStyle(color: c.textSecondary),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 19 / 13,
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositiveRow extends StatelessWidget {
  const _PositiveRow({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: Icons.check_circle_outline_rounded, tone: c.good),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
