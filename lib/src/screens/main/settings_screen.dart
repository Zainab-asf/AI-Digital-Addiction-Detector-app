import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../config/routes.dart';
import '../../state/app_state.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/segmented_control.dart';
import '../../widgets/common/status_badge.dart';
import '../limits/app_limits_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Settings',
      subtitle: 'Your account, goals and how LoopAware reads your data',
      maxWidth: 920,
      builder: (context, layout) {
        final twoColumn = layout.width >= 720;
        final narrowRows = layout.width < 480;
        final sectionGap = twoColumn ? 28.0 : 24.0;

        Widget section(String title, String description, Widget card) =>
            _SettingsSection(
              title: title,
              description: description,
              twoColumn: twoColumn,
              child: card,
            );

        return [
          section(
            'Account',
            'The profile you\'re signed in with.',
            const _AccountCard(),
          ),
          SizedBox(height: sectionGap),
          section(
            'Goals',
            'Targets LoopAware uses to grade your day.',
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DailyGoalCard(),
                SizedBox(height: 12),
                _AppLimitsLink(),
              ],
            ),
          ),
          SizedBox(height: sectionGap),
          section(
            'Reminders',
            'Notifications that help you stick to your goals.',
            const _RemindersCard(),
          ),
          SizedBox(height: sectionGap),
          section(
            'Appearance',
            'How LoopAware looks on this device.',
            _PreferencesCard(stackControls: narrowRows),
          ),
          SizedBox(height: sectionGap),
          section(
            'Data & privacy',
            'Where your screen-time numbers come from. Scores are computed '
                'on your device.',
            const _DataCard(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.only(left: twoColumn ? 252 : 0),
            child: Text(
              '${AppConstants.appName} 1.0',
              textAlign: twoColumn ? TextAlign.left : TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ];
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.twoColumn,
    required this.child,
  });

  final String title;
  final String description;
  final bool twoColumn;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
        ),
      ],
    );

    if (twoColumn) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: heading,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(child: child),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [heading, const SizedBox(height: 12), child],
    );
  }
}

/// A row inside a settings card: title, description and a trailing control.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  /// Control placed under the text instead of beside it (narrow screens).
  final Widget? below;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border:
            showDivider
                ? Border(bottom: BorderSide(color: c.borderSubtle))
                : null,
      ),
      child: content,
    );
  }
}

/// Card that clips its rows to the rounded corners so ink splashes on the
/// first and last rows don't bleed.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg - 1),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final state = context.watch<AppState>();
    final initial =
        state.displayName.isEmpty ? '?' : state.displayName[0].toUpperCase();

    return _GroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: c.primarySoft,
                child: Text(
                  initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: c.onPrimarySoft,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.email.isEmpty ? 'No email on file' : state.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: c.borderSubtle),
        InkWell(
          onTap: () => _confirmSignOut(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 20, color: c.critical.onSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sign out',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: c.critical.onSoft,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You\'ll be returned to the sign-in screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.critical.solid,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );
    if (confirm != true || !context.mounted) return;
    await context.read<AppState>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final state = context.watch<AppState>();
    final minutes = state.dailyLimitMinutes;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily screen-time goal',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Days above this are flagged as over goal.',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  Formatters.duration(minutes),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: c.onPrimarySoft,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: minutes.toDouble().clamp(60.0, 720.0),
              min: 60,
              max: 720,
              divisions: 22,
              label: Formatters.duration(minutes),
              semanticFormatterCallback: (v) => Formatters.duration(v.round()),
              onChanged: (v) => state.setDailyLimit(v.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1h', style: theme.textTheme.bodySmall),
                Text('12h', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.stackControls});

  final bool stackControls;

  static const _themes = [
    SegmentOption(
      value: ThemeMode.system,
      label: 'System',
      icon: Icons.brightness_auto_outlined,
    ),
    SegmentOption(
      value: ThemeMode.light,
      label: 'Light',
      icon: Icons.light_mode_outlined,
    ),
    SegmentOption(
      value: ThemeMode.dark,
      label: 'Dark',
      icon: Icons.dark_mode_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final picker = SegmentedControl<ThemeMode>(
      options: _themes,
      selected: state.themeMode,
      onChanged: state.setThemeMode,
      expand: stackControls,
      semanticLabel: 'Theme',
    );

    return _GroupCard(
      children: [
        _SettingRow(
          title: 'Theme',
          subtitle: 'Match your device, or choose one.',
          showDivider: false,
          trailing: stackControls ? null : picker,
          below: stackControls ? picker : null,
        ),
      ],
    );
  }
}

class _RemindersCard extends StatelessWidget {
  const _RemindersCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = AppColors.of(context);
    final on = state.notificationsEnabled;
    final supported = state.remindersSupported;

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: state.reminderTime,
        helpText: 'Wind-down reminder',
      );
      if (picked != null) await state.setReminderTime(picked);
    }

    return _GroupCard(
      children: [
        _SettingRow(
          title: 'Wellness reminders',
          subtitle:
              supported
                  ? 'Allow LoopAware to send notifications.'
                  : 'Notifications are delivered by the Android app. Your '
                      'choices here are saved.',
          showDivider: on,
          trailing: Switch(value: on, onChanged: state.setNotificationsEnabled),
          onTap: () => state.setNotificationsEnabled(!on),
        ),
        if (on) ...[
          _SettingRow(
            title: 'Wind-down reminder',
            subtitle:
                'A nightly nudge to put the phone away before the '
                '10pm window that affects sleep.',
            trailing: Switch(
              value: state.bedtimeReminderEnabled,
              onChanged: state.setBedtimeReminderEnabled,
            ),
            onTap:
                () => state.setBedtimeReminderEnabled(
                  !state.bedtimeReminderEnabled,
                ),
          ),
          if (state.bedtimeReminderEnabled)
            _SettingRow(
              title: 'Reminder time',
              subtitle: 'Every day at this time.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.reminderTime.format(context),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.primary,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textTertiary,
                  ),
                ],
              ),
              onTap: pickTime,
            ),
          _SettingRow(
            title: 'Usage alerts',
            subtitle:
                'Once a day when you pass your daily goal or an app '
                'limit. Uses real device data only.',
            showDivider: false,
            trailing: Switch(
              value: state.goalAlertsEnabled,
              onChanged: state.setGoalAlertsEnabled,
            ),
            onTap: () => state.setGoalAlertsEnabled(!state.goalAlertsEnabled),
          ),
        ],
      ],
    );
  }
}

class _AppLimitsLink extends StatelessWidget {
  const _AppLimitsLink();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = AppColors.of(context);
    final count = state.appLimits.length;
    return _GroupCard(
      children: [
        _SettingRow(
          title: 'App limits',
          subtitle:
              count == 0
                  ? 'Set a daily budget for individual apps.'
                  : '$count ${count == 1 ? 'app has' : 'apps have'} a daily limit.',
          showDivider: false,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: c.textTertiary,
          ),
          onTap: () => Navigator.of(context).push(AppLimitsScreen.route()),
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final state = context.watch<AppState>();
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return _GroupCard(
      children: [
        _SettingRow(
          title: 'Current data source',
          subtitle:
              state.dataLoaded
                  ? 'What your dashboard is showing right now.'
                  : 'Loads with your first refresh.',
          trailing:
              state.dataLoaded
                  ? DataSourceBadge(isLive: state.isLiveData)
                  : null,
        ),
        _SettingRow(
          title: 'Use demo data',
          subtitle:
              'Show sample screen time even when device usage access is '
              'available.',
          showDivider: isAndroid,
          trailing: Switch(
            value: state.useDemoData,
            onChanged: state.setUseDemoData,
          ),
          onTap: () => state.setUseDemoData(!state.useDemoData),
        ),
        if (isAndroid)
          _SettingRow(
            title: 'Usage access',
            subtitle: 'Required to read real screen time from this device.',
            showDivider: false,
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: c.textTertiary,
            ),
            onTap: () async {
              final opened = await state.usageService.openUsageAccessSettings();
              if (!opened && context.mounted) {
                showAppSnackBar(
                  context,
                  'Couldn\'t open settings on this device.',
                  isError: true,
                );
              }
            },
          ),
      ],
    );
  }
}
