import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loopaware/src/config/app_theme.dart';
import 'package:loopaware/src/screens/main/analytics_screen.dart';
import 'package:loopaware/src/screens/main/dashboard_screen.dart';
import 'package:loopaware/src/screens/main/insights_screen.dart';
import 'package:loopaware/src/screens/main/settings_screen.dart';
import 'package:loopaware/src/services/preferences_service.dart';
import 'package:loopaware/src/state/app_state.dart';

/// Renders each main tab against loaded demo data to catch layout and
/// null-safety regressions that static analysis cannot see.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network from a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    state = AppState(prefs: prefs);
    await state.refreshUsage();
  });

  tearDown(() => state.dispose());

  Widget wrap(Widget child, {ThemeData? theme}) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
    );
  }

  final screens = <String, Widget>{
    'Dashboard': const DashboardScreen(),
    'Analytics': const AnalyticsScreen(),
    'Insights': const InsightsScreen(),
    'Settings': const SettingsScreen(),
  };

  // Overflows are width-dependent, so cover a small phone as well as a large
  // one. 320 is the narrowest width Android phones still ship.
  const widths = <double>[320, 430];

  screens.forEach((name, screen) {
    for (final width in widths) {
      for (final brightness in const ['light', 'dark']) {
        testWidgets(
          '$name renders with demo data at ${width.toInt()}px ($brightness)',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 1400));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            // Resolved here rather than at registration: building a theme
            // touches google_fonts, which must run inside the test zone.
            final theme =
                brightness == 'light' ? AppTheme.light : AppTheme.dark;

            await tester.pumpWidget(wrap(screen, theme: theme));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
