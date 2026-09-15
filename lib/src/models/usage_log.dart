import 'package:flutter/material.dart';

/// High-level category an app belongs to. Drives color coding and scoring
/// weights (e.g. social/entertainment usage is weighted heavier for
/// addiction risk than productivity usage).
enum AppCategory {
  social('Social', Icons.forum_rounded, Color(0xFFEC4899)),
  entertainment('Entertainment', Icons.play_circle_rounded, Color(0xFFEF4444)),
  communication('Communication', Icons.chat_rounded, Color(0xFF3B82F6)),
  games('Games', Icons.sports_esports_rounded, Color(0xFF8B5CF6)),
  productivity('Productivity', Icons.work_rounded, Color(0xFF22C55E)),
  education('Education', Icons.school_rounded, Color(0xFF14B8A6)),
  health('Health', Icons.favorite_rounded, Color(0xFFF43F5E)),
  news('News', Icons.article_rounded, Color(0xFF0EA5E9)),
  shopping('Shopping', Icons.shopping_bag_rounded, Color(0xFFF59E0B)),
  utilities('Utilities', Icons.build_rounded, Color(0xFF64748B)),
  other('Other', Icons.apps_rounded, Color(0xFF94A3B8));

  const AppCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// Categories that most strongly drive compulsive-use patterns.
  bool get isDistracting =>
      this == social || this == entertainment || this == games;

  static AppCategory fromName(String? name) {
    return AppCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => AppCategory.other,
    );
  }
}

/// Where a usage value came from. Lets the app distinguish measured data
/// from values it derived or invented, so the two are never confused.
enum UsageSource {
  /// Read from the device's usage-stats API.
  device('Device'),

  /// Derived from measured data rather than measured directly (for example
  /// open counts inferred from minutes, or an assumed hourly distribution).
  estimated('Estimated'),

  /// Seeded demo data. Not a real measurement of anything.
  demo('Demo');

  const UsageSource(this.label);

  final String label;

  /// Ranks sources by trustworthiness so a merge can pick a winner.
  int get rank => switch (this) {
    UsageSource.device => 2,
    UsageSource.estimated => 1,
    UsageSource.demo => 0,
  };

  bool get isReal => this == UsageSource.device;

  static UsageSource fromName(String? name) {
    return UsageSource.values.firstWhere(
      (s) => s.name == name,
      orElse: () => UsageSource.demo,
    );
  }
}

/// Usage of a single app over a single day.
class AppUsage {
  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.minutes,
    required this.opens,
    this.opensSource = UsageSource.demo,
  });

  final String packageName;
  final String appName;
  final AppCategory category;

  /// Total foreground minutes for the day.
  final int minutes;

  /// Number of times the app was opened (pickups).
  final int opens;

  /// Where [opens] came from. The usage-stats API does not report pickup
  /// counts, so on a real device this is [UsageSource.estimated].
  final UsageSource opensSource;

  /// Average length of a single session, in minutes.
  double get averageSessionMinutes => opens == 0 ? 0 : minutes / opens;

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'category': category.name,
    'minutes': minutes,
    'opens': opens,
    'opensSource': opensSource.name,
  };

  factory AppUsage.fromJson(Map<String, dynamic> json) => AppUsage(
    packageName: json['packageName'] as String? ?? 'unknown',
    appName: json['appName'] as String? ?? 'Unknown app',
    category: AppCategory.fromName(json['category'] as String?),
    minutes: (json['minutes'] as num?)?.toInt() ?? 0,
    opens: (json['opens'] as num?)?.toInt() ?? 0,
    opensSource: UsageSource.fromName(json['opensSource'] as String?),
  );
}

/// Aggregated screen-time for a single calendar day.
class DailyUsage {
  DailyUsage({
    required this.date,
    required this.apps,
    required this.hourlyMinutes,
    this.source = UsageSource.demo,
    this.hourlySource = UsageSource.demo,
  });

  /// Calendar day (time component is normalized to midnight).
  final DateTime date;

  final List<AppUsage> apps;

  /// Minutes of usage per hour of the day. Always length 24.
  final List<int> hourlyMinutes;

  /// Where this day's per-app minutes came from. [UsageSource.device] means
  /// the totals were measured on the device.
  final UsageSource source;

  /// Where [hourlyMinutes] came from. The usage-stats API reports per-app
  /// totals but no hourly breakdown, so on a real device this is
  /// [UsageSource.estimated] — [nightMinutes] and [peakHour] derive from it
  /// and inherit that accuracy.
  final UsageSource hourlySource;

  /// True when the per-app minutes were actually measured on this device.
  bool get isMeasured => source.isReal;

  /// True when hourly figures ([nightMinutes], [peakHour]) are trustworthy.
  bool get hasMeasuredHours => hourlySource.isReal;

  /// Total foreground minutes across all apps.
  int get totalMinutes =>
      apps.fold(0, (sum, app) => sum + app.minutes);

  /// Total app opens across the day.
  int get pickups => apps.fold(0, (sum, app) => sum + app.opens);

  /// Minutes used during late-night / early-morning hours.
  int get nightMinutes {
    var total = 0;
    for (var hour = 0; hour < hourlyMinutes.length; hour++) {
      if (hour >= 22 || hour < 5) total += hourlyMinutes[hour];
    }
    return total;
  }

  /// Minutes spent in distracting categories (social/entertainment/games).
  int get distractingMinutes => apps
      .where((a) => a.category.isDistracting)
      .fold(0, (sum, app) => sum + app.minutes);

  /// The single most-used app of the day, or null if there was no usage.
  AppUsage? get topApp {
    if (apps.isEmpty) return null;
    return apps.reduce((a, b) => a.minutes >= b.minutes ? a : b);
  }

  /// Apps sorted by descending usage.
  List<AppUsage> get appsByUsage {
    final sorted = [...apps]..sort((a, b) => b.minutes.compareTo(a.minutes));
    return sorted;
  }

  /// Total minutes grouped by category.
  Map<AppCategory, int> get categoryMinutes {
    final map = <AppCategory, int>{};
    for (final app in apps) {
      map[app.category] = (map[app.category] ?? 0) + app.minutes;
    }
    return map;
  }

  /// The hour (0-23) with the highest usage.
  int get peakHour {
    var peak = 0;
    for (var hour = 1; hour < hourlyMinutes.length; hour++) {
      if (hourlyMinutes[hour] > hourlyMinutes[peak]) peak = hour;
    }
    return peak;
  }

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'apps': apps.map((a) => a.toJson()).toList(),
    'hourlyMinutes': hourlyMinutes,
    'source': source.name,
    'hourlySource': hourlySource.name,
    'dateKey': dateKey,
  };

  factory DailyUsage.fromJson(Map<String, dynamic> json) {
    final rawHourly = (json['hourlyMinutes'] as List?) ?? const [];
    final hourly = List<int>.generate(
      24,
      (i) => i < rawHourly.length ? (rawHourly[i] as num).toInt() : 0,
    );
    return DailyUsage(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      apps: ((json['apps'] as List?) ?? const [])
          .map((e) => AppUsage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hourlyMinutes: hourly,
      source: UsageSource.fromName(json['source'] as String?),
      hourlySource: UsageSource.fromName(json['hourlySource'] as String?),
    );
  }

  DailyUsage copyWith({UsageSource? source, UsageSource? hourlySource}) {
    return DailyUsage(
      date: date,
      apps: apps,
      hourlyMinutes: hourlyMinutes,
      source: source ?? this.source,
      hourlySource: hourlySource ?? this.hourlySource,
    );
  }
}
