import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

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
}
