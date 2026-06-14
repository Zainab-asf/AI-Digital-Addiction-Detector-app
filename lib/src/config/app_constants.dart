/// App-wide constants for LoopAware.
class AppConstants {
  AppConstants._();

  static const String appName = 'LoopAware';
  static const String tagline = 'Break the loop. Reclaim your focus.';

  /// Default healthy daily screen-time target (minutes).
  static const int defaultDailyLimitMinutes = 240;

  /// Hour (24h) after which usage counts as sleep-disrupting.
  static const int nightUsageStartHour = 22;
  static const int nightUsageEndHour = 5;

  /// A session shorter than this many minutes counts as a "quick check".
  static const int quickCheckMaxMinutes = 2;

  /// Returning to the same app within this window signals a dopamine loop.
  static const int loopReturnWindowMinutes = 5;

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefThemeMode = 'theme_mode';
  static const String prefDailyLimit = 'daily_limit_minutes';
  static const String prefNotifications = 'notifications_enabled';
  static const String prefUseDemoData = 'use_demo_data';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String usageCollection = 'usage_logs';
  static const String predictionsCollection = 'predictions';
}
