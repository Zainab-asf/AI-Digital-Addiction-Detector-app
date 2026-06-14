import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// Bottom-navigation shell that holds the four main tabs. Triggers the
/// first usage-data refresh once authenticated.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
    (
      icon: Icons.home_outlined,
      active: Icons.home_rounded,
      label: 'Home',
    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              for (final t in _tabs)
                BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.active),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
