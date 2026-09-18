import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../state/app_state.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// Navigation shell that holds the four main tabs. Triggers the first
/// usage-data refresh once authenticated.
///
/// Navigation adapts to the width: a labelled sidebar on desktop, a rail on
/// tablets and a bottom bar on phones. The tabs themselves are identical.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Keeps each tab's state when the layout switches between sidebar, rail
  // and bottom bar (e.g. resizing a browser window).
  final GlobalKey _pagesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (!state.dataLoaded && !state.loadingData) {
        state.refreshUsage();
      }
    });
  }

  static const List<Widget> _pages = [
    DashboardScreen(),
    AnalyticsScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  static const List<({IconData icon, IconData active, String label})> _tabs = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.bar_chart_outlined,
      active: Icons.bar_chart_rounded,
      label: 'Analytics',
    ),
    (
      icon: Icons.lightbulb_outline_rounded,
      active: Icons.lightbulb_rounded,
      label: 'Insights',
    ),
    (
      icon: Icons.settings_outlined,
      active: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pages = HomeTabs(
      select: _select,
      child: IndexedStack(key: _pagesKey, index: _index, children: _pages),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= AppTheme.sidebarMin) {
          return Scaffold(
            body: Row(
              children: [
                _Sidebar(index: _index, onSelect: _select),
                Expanded(child: pages),
              ],
            ),
          );
        }

        if (width >= AppTheme.compactMax) {
          return Scaffold(
            body: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(right: BorderSide(color: c.border)),
                  ),
                  child: SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      groupAlignment: -1,
                      minWidth: 88,
                      leading: const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 20),
                        child: _BrandMark(size: 36),
                      ),
                      destinations: [
                        for (final t in _tabs)
                          NavigationRailDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.active),
                            label: Text(t.label),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: pages),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final t in _tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.active),
                    label: t.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lets a tab jump to another tab (e.g. "See all insights") without knowing
/// about the shell. Absent when a screen is shown on its own.
class HomeTabs extends InheritedWidget {
  const HomeTabs({super.key, required this.select, required super.child});

  final ValueChanged<int> select;

  static const int home = 0;
  static const int analytics = 1;
  static const int insights = 2;
  static const int settings = 3;

  static HomeTabs? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HomeTabs>();

  @override
  bool updateShouldNotify(HomeTabs oldWidget) => false;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final state = context.watch<AppState>();
    final name = state.displayName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const _BrandMark(size: 32),
                    const SizedBox(width: 10),
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text('MENU', style: theme.textTheme.labelSmall),
              ),
              for (var i = 0; i < _HomeShellState._tabs.length; i++) ...[
                if (i > 0) const SizedBox(height: 2),
                _SidebarItem(
                  icon: _HomeShellState._tabs[i].icon,
                  activeIcon: _HomeShellState._tabs[i].active,
                  label: _HomeShellState._tabs[i].label,
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: c.primarySoft,
                      child: Text(
                        initial,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: c.onPrimarySoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          if (state.email.isNotEmpty)
                            Text(
                              state.email,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final fg = selected ? c.onPrimarySoft : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(selected ? activeIcon : icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.all_inclusive_rounded,
        color: c.onPrimary,
        size: size * 0.6,
      ),
    );
  }
}
