import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loopaware/src/config/app_theme.dart';
import 'package:loopaware/src/models/focus_session.dart';
import 'package:loopaware/src/screens/focus/focus_screen.dart';
import 'package:loopaware/src/screens/limits/app_limits_screen.dart';
import 'package:loopaware/src/screens/main/dashboard_screen.dart';
import 'package:loopaware/src/screens/main/settings_screen.dart';
import 'package:loopaware/src/screens/weekly/weekly_report_screen.dart';
import 'package:loopaware/src/services/preferences_service.dart';
import 'package:loopaware/src/state/app_state.dart';

/// Covers the weekly report, focus timer, app limits and reminder settings.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('PreferencesService', () {
    late PreferencesService prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await PreferencesService.create();
    });

    test('app limits round-trip', () async {
      await prefs.setAppLimits({'com.instagram.android': 30});
      expect(prefs.appLimits, {'com.instagram.android': 30});
    });

    test('focus sessions round-trip', () async {
      final session = FocusSession(
        startedAt: DateTime(2026, 9, 18, 10),
        plannedMinutes: 25,
        focusedMinutes: 25,
        completed: true,
      );
      await prefs.setFocusSessions([session]);
      final loaded = prefs.focusSessions.single;
      expect(loaded.startedAt, session.startedAt);
      expect(loaded.focusedMinutes, 25);
      expect(loaded.completed, isTrue);
    });

    test('sent alerts are remembered for the day and pruned after', () async {
      await prefs.recordAlertSent('goal:2026-09-17', '2026-09-17');
      expect(prefs.alertSent('goal:2026-09-17'), isTrue);

      await prefs.recordAlertSent('goal:2026-09-18', '2026-09-18');
      expect(prefs.alertSent('goal:2026-09-18'), isTrue);
      expect(
        prefs.alertSent('goal:2026-09-17'),
        isFalse,
        reason: 'yesterday\'s keys are dropped',
      );
    });

    test('corrupt stored JSON falls back to empty', () async {
      SharedPreferences.setMockInitialValues({
        'app_limits': 'not json',
        'focus_sessions': '{',
      });
      final p = await PreferencesService.create();
      expect(p.appLimits, isEmpty);
      expect(p.focusSessions, isEmpty);
    });
  });

  group('AppState', () {
    test('limits and focus sessions persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();
      final state = AppState(prefs: prefs);

      await state.setAppLimit('com.zhiliaoapp.musically', 45);
      await state.addFocusSession(
        FocusSession(
          startedAt: DateTime.now(),
          plannedMinutes: 25,
          focusedMinutes: 12,
          completed: false,
        ),
      );

      final reloaded = AppState(prefs: await PreferencesService.create());
      expect(reloaded.appLimits, {'com.zhiliaoapp.musically': 45});
      expect(reloaded.focusSessions.single.focusedMinutes, 12);

      await reloaded.setAppLimit('com.zhiliaoapp.musically', null);
      expect(reloaded.appLimits, isEmpty);

      state.dispose();
      reloaded.dispose();
    });

    test(
      'reminders are unsupported off-device and settings still save',
      () async {
        SharedPreferences.setMockInitialValues({});
        final state = AppState(prefs: await PreferencesService.create());
        expect(state.remindersSupported, isFalse);

        await state.setReminderTime(const TimeOfDay(hour: 22, minute: 15));
        await state.setBedtimeReminderEnabled(false);
        await state.setGoalAlertsEnabled(false);

        final reloaded = AppState(prefs: await PreferencesService.create());
        expect(reloaded.reminderTime, const TimeOfDay(hour: 22, minute: 15));
        expect(reloaded.bedtimeReminderEnabled, isFalse);
        expect(reloaded.goalAlertsEnabled, isFalse);
        state.dispose();
        reloaded.dispose();
      },
    );
  });

  group('screens render with demo data', () {
    late AppState state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState(prefs: await PreferencesService.create());
      await state.refreshUsage();
      // A limit on the busiest app so the limits UI has something to show.
      final top = state.todayUsage!.appsByUsage.first;
      await state.setAppLimit(top.packageName, 15);
    });

    tearDown(() => state.dispose());

    final screens = <String, Widget>{
      'Weekly report': const WeeklyReportScreen(),
      'Focus session': const FocusScreen(),
      'App limits': const AppLimitsScreen(),
      'Dashboard with limits': const DashboardScreen(),
      'Settings with reminders': const SettingsScreen(),
    };

    for (final entry in screens.entries) {
      for (final width in const <double>[320, 430, 768, 1280]) {
        for (final dark in const [false, true]) {
          testWidgets(
            '${entry.key} at ${width.toInt()}px (${dark ? 'dark' : 'light'})',
            (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 1600));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              await tester.pumpWidget(
                ChangeNotifierProvider<AppState>.value(
                  value: state,
                  child: MaterialApp(
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    home: entry.value,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('limits card names apps not used today', (tester) async {
      final todayPackages =
          state.todayUsage!.apps.map((a) => a.packageName).toSet();
      final unused = state.history
          .expand((d) => d.apps)
          .firstWhere((a) => !todayPackages.contains(a.packageName));
      await state.setAppLimit(unused.packageName, 30);

      await tester.binding.setSurfaceSize(const Size(430, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(unused.appName), findsWidgets);
      expect(find.text(unused.packageName.split('.').last), findsNothing);
    });

    testWidgets('focus timer starts, pauses and ends early', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(theme: AppTheme.light, home: const FocusScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Start'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Focusing'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.text('End early'));
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
