import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/usage_log.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/charts/bar_chart_widget.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/status_badge.dart';

/// One app seen in recent history, with its average and today's use.
class _AppSummary {
  _AppSummary(this.app, this.averageMinutes, this.todayMinutes);

  final AppUsage app;
  final int averageMinutes;
  final int todayMinutes;
}

/// Lets the user set a daily time limit per app.
class AppLimitsScreen extends StatelessWidget {
  const AppLimitsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AppLimitsScreen());

  static List<_AppSummary> _summaries(AppState state) {
    final history = state.history;
    if (history.isEmpty) return const [];
    final totals = <String, int>{};
    final latest = <String, AppUsage>{};
    for (final day in history) {
      for (final app in day.apps) {
        totals[app.packageName] = (totals[app.packageName] ?? 0) + app.minutes;
        latest[app.packageName] = app;
      }
    }
    final today = state.todayUsage;
    final list = [
      for (final entry in latest.entries)
        _AppSummary(
          entry.value,
          (totals[entry.key]! / history.length).round(),
          today?.apps
                  .where((a) => a.packageName == entry.key)
                  .fold<int>(0, (s, a) => s + a.minutes) ??
              0,
        ),
    ];
    final limits = state.appLimits;
    // Apps with a limit first, then by average use.
    list.sort((a, b) {
      final la = limits.containsKey(a.app.packageName) ? 0 : 1;
      final lb = limits.containsKey(b.app.packageName) ? 0 : 1;
      if (la != lb) return la - lb;
      return b.averageMinutes.compareTo(a.averageMinutes);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final apps = _summaries(state);
    final limits = state.appLimits;

    return PageScaffold(
      showBack: true,
      title: 'App limits',
      subtitle:
          'Set a daily budget for the apps that pull you in. '
          'Apps past their limit are flagged on your dashboard.',
      maxWidth: 880,
      onRefresh: () => state.refreshUsage(),
      builder: (context, layout) {
        if (apps.isEmpty) {
          return [
            const SizedBox(height: 48),
            EmptyState(
              icon: Icons.apps_rounded,
              title: 'No apps yet',
              message: 'Apps appear here once LoopAware has usage data.',
              actionLabel: 'Refresh',
              onAction: () => state.refreshUsage(),
            ),
          ];
        }
        return [
          if (!state.isLiveData) ...[
            _Note(
              'You\'re viewing demo data. Limits are saved and will apply '
              'to your real usage once device access is on.',
            ),
            SizedBox(height: layout.gap),
          ],
          AppCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg - 1),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < apps.length; i++)
                      _AppLimitRow(
                        summary: apps[i],
                        limit: limits[apps[i].app.packageName],
                        showDivider: i < apps.length - 1,
                        onTap: () => _editLimit(context, apps[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  static Future<void> _editLimit(BuildContext context, _AppSummary s) async {
    final state = context.read<AppState>();
    final current = state.appLimits[s.app.packageName];
    final result = await showModalBottomSheet<_LimitChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LimitSheet(summary: s, current: current),
    );
    if (result == null) return;
    await state.setAppLimit(s.app.packageName, result.minutes);
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.info.soft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.info.onSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: c.info.onSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLimitRow extends StatelessWidget {
  const _AppLimitRow({
    required this.summary,
    required this.limit,
    required this.showDivider,
    required this.onTap,
  });

  final _AppSummary summary;
  final int? limit;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final app = summary.app;
    final lim = limit;
    final over = lim != null && summary.todayMinutes > lim;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border:
              showDivider
                  ? Border(bottom: BorderSide(color: c.borderSubtle))
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.categorySoft(app.category),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                app.category.icon,
                size: 18,
                color: c.category(app.category),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    app.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lim == null
                        ? '${Formatters.duration(summary.averageMinutes)} a day '
                            'on average'
                        : '${Formatters.duration(summary.todayMinutes)} of '
                            '${Formatters.duration(lim)} today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (lim != null) ...[
                    const SizedBox(height: 6),
                    ShareBar(
                      value: lim == 0 ? 1 : summary.todayMinutes / lim,
                      color: over ? c.critical.solid : c.primary,
                      height: 4,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (lim == null)
              Text(
                'Set limit',
                style: theme.textTheme.labelMedium?.copyWith(color: c.primary),
              )
            else
              StatusBadge(
                label: over ? 'Over' : Formatters.duration(lim),
                tone: over ? c.critical : c.good,
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Sheet result: [minutes] null means "remove the limit".
class _LimitChoice {
  const _LimitChoice(this.minutes);
  final int? minutes;
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.summary, required this.current});

  final _AppSummary summary;
  final int? current;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  static const _presets = [15, 30, 45, 60, 90, 120];
  late int _minutes;

  @override
  void initState() {
    super.initState();
    // Default to a limit a little under the current average, rounded to 5m.
    final avg = widget.summary.averageMinutes;
    final suggested = ((avg * 0.8) / 5).round() * 5;
    _minutes = widget.current ?? suggested.clamp(15, 240);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Daily limit for ${s.app.appName}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'You average ${Formatters.duration(s.averageMinutes)} a day.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                Formatters.duration(_minutes),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 36,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
            Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 240,
              divisions: 47,
              label: Formatters.duration(_minutes),
              semanticFormatterCallback: (v) => Formatters.duration(v.round()),
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(Formatters.duration(p)),
                    selected: p == _minutes,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _minutes = p),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed:
                  () => Navigator.of(context).pop(_LimitChoice(_minutes)),
              child: const Text('Save limit'),
            ),
            if (widget.current != null) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.of(context).critical.onSoft,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed:
                    () => Navigator.of(context).pop(const _LimitChoice(null)),
                child: const Text('Remove limit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
