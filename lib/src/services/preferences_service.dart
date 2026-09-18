import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/focus_session.dart';

/// Persists lightweight user settings via [SharedPreferences].
class PreferencesService {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  bool get onboardingDone =>
      _prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(AppConstants.prefOnboardingDone, value);

  ThemeMode get themeMode {
    switch (_prefs.getString(AppConstants.prefThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(AppConstants.prefThemeMode, mode.name);

  int get dailyLimitMinutes =>
      _prefs.getInt(AppConstants.prefDailyLimit) ??
      AppConstants.defaultDailyLimitMinutes;

  Future<void> setDailyLimitMinutes(int minutes) =>
      _prefs.setInt(AppConstants.prefDailyLimit, minutes);

  bool get notificationsEnabled =>
      _prefs.getBool(AppConstants.prefNotifications) ?? true;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(AppConstants.prefNotifications, value);

  bool get useDemoData =>
      _prefs.getBool(AppConstants.prefUseDemoData) ?? false;

  Future<void> setUseDemoData(bool value) =>
      _prefs.setBool(AppConstants.prefUseDemoData, value);

  // --- Reminders ---

  bool get bedtimeReminderEnabled =>
      _prefs.getBool(AppConstants.prefBedtimeReminder) ?? true;

  Future<void> setBedtimeReminderEnabled(bool value) =>
      _prefs.setBool(AppConstants.prefBedtimeReminder, value);

  /// Minutes after midnight at which the wind-down reminder fires.
  int get reminderMinutes =>
      _prefs.getInt(AppConstants.prefReminderMinutes) ??
      AppConstants.defaultReminderMinutes;

  Future<void> setReminderMinutes(int minutes) =>
      _prefs.setInt(AppConstants.prefReminderMinutes, minutes);

  bool get goalAlertsEnabled =>
      _prefs.getBool(AppConstants.prefGoalAlerts) ?? true;

  Future<void> setGoalAlertsEnabled(bool value) =>
      _prefs.setBool(AppConstants.prefGoalAlerts, value);

  /// True if the alert [key] was already sent today.
  bool alertSent(String key) =>
      (_prefs.getStringList(AppConstants.prefSentAlerts) ?? const [])
          .contains(key);

  /// Records [key] as sent, dropping keys from previous days ([dayKey] is
  /// today's date key, which every alert key contains).
  Future<void> recordAlertSent(String key, String dayKey) {
    final kept = (_prefs.getStringList(AppConstants.prefSentAlerts) ??
            const <String>[])
        .where((k) => k.contains(dayKey))
        .toList()
      ..add(key);
    return _prefs.setStringList(AppConstants.prefSentAlerts, kept);
  }

  // --- App limits (package name -> daily minutes) ---

  Map<String, int> get appLimits {
    final raw = _prefs.getString(AppConstants.prefAppLimits);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> setAppLimits(Map<String, int> limits) =>
      _prefs.setString(AppConstants.prefAppLimits, jsonEncode(limits));

  // --- Focus sessions ---

  List<FocusSession> get focusSessions {
    final raw = _prefs.getString(AppConstants.prefFocusSessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FocusSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setFocusSessions(List<FocusSession> sessions) =>
      _prefs.setString(
        AppConstants.prefFocusSessions,
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
}
