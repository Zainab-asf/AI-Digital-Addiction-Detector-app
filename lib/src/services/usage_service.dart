import 'package:app_usage/app_usage.dart' as app_usage;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/usage_log.dart';
import 'demo_data.dart';

/// Result of a usage-data load, including which source was used.
class UsageLoadResult {
  const UsageLoadResult({required this.days, required this.isLive});

  final List<DailyUsage> days;

  /// True when the data came from the device; false when demo data was used.
  final bool isLive;
}

/// Loads screen-time data from the Android usage-stats API, falling back to
/// seeded demo data on other platforms or when permission is unavailable.
class UsageService {
  static const MethodChannel _channel = MethodChannel('loopaware/usage');

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens the system "Usage access" settings page. Returns false if the
  /// platform cannot honour the request.
  Future<bool> openUsageAccessSettings() async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Best-effort check for whether usage access has been granted by probing
  /// the last 24 hours for any recorded activity.
  Future<bool> hasUsageAccess() async {
    if (!isAndroid) return false;
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 24));
      final infos = await app_usage.AppUsage().getAppUsage(start, end);
      return infos.any((i) => i.usage.inMinutes > 0);
    } catch (_) {
      return false;
    }
  }

  /// Loads [days] of usage. When [preferDemo] is true, or when live data is
  /// unavailable, realistic demo data is returned instead.
  Future<UsageLoadResult> load({
    int days = 14,
    bool preferDemo = false,
  }) async {
    if (!preferDemo && isAndroid) {
      final live = await _fetchLive(days);
      if (live != null) {
        return UsageLoadResult(days: live, isLive: true);
      }
    }
    return UsageLoadResult(days: DemoData.generate(days: days), isLive: false);
  }

  Future<List<DailyUsage>?> _fetchLive(int days) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final result = <DailyUsage>[];
      for (var offset = days - 1; offset >= 0; offset--) {
        final dayStart = today.subtract(Duration(days: offset));
        final dayEnd =
            offset == 0 ? now : dayStart.add(const Duration(days: 1));
        final infos =
            await app_usage.AppUsage().getAppUsage(dayStart, dayEnd);
        result.add(_mapDay(dayStart, infos));
      }
      final hasData = result.any((d) => d.totalMinutes > 0);
      return hasData ? result : null;
    } catch (_) {
      return null;
    }
  }

  DailyUsage _mapDay(DateTime date, List<app_usage.AppUsageInfo> infos) {
    final apps = <AppUsage>[];
    for (final info in infos) {
      final minutes = info.usage.inMinutes;
      if (minutes <= 0) continue;
      final meta = _resolve(info.packageName);
      final opens = (minutes / meta.session).round().clamp(1, 999);
      apps.add(
        AppUsage(
          packageName: info.packageName,
          appName: meta.name,
          category: meta.category,
          minutes: minutes,
          opens: opens,
        ),
      );
    }
    final total = apps.fold(0, (sum, a) => sum + a.minutes);
    return DailyUsage(
      date: date,
      apps: apps,
      hourlyMinutes: _spreadHourly(total),
    );
  }

  static const List<double> _hourProfile = [
    0.6, 0.3, 0.2, 0.15, 0.15, 0.3,
    0.9, 2.0, 3.0, 2.4, 1.9, 1.9,
    2.8, 2.6, 2.2, 1.9, 2.0, 2.6,
    3.2, 4.2, 4.6, 4.0, 2.6, 1.4,
  ];

  List<int> _spreadHourly(int total) {
    final sum = _hourProfile.reduce((a, b) => a + b);
    return _hourProfile.map((w) => (total * w / sum).round()).toList();
  }

  ({String name, AppCategory category, double session}) _resolve(
    String packageName,
  ) {
    final known = _knownApps[packageName];
    if (known != null) {
      return (
        name: known.$1,
        category: known.$2,
        session: _sessionFor(known.$2),
      );
    }
    final category = _guessCategory(packageName);
    return (
      name: _prettifyPackage(packageName),
      category: category,
      session: _sessionFor(category),
    );
  }

  static double _sessionFor(AppCategory category) {
    switch (category) {
      case AppCategory.communication:
        return 2.5;
      case AppCategory.social:
        return 3.5;
      case AppCategory.entertainment:
        return 14;
      case AppCategory.games:
        return 13;
      case AppCategory.productivity:
        return 6;
      case AppCategory.education:
        return 9;
      case AppCategory.news:
        return 5;
      case AppCategory.shopping:
        return 6;
      case AppCategory.health:
        return 6;
      case AppCategory.utilities:
      case AppCategory.other:
        return 5;
    }
  }

  AppCategory _guessCategory(String pkg) {
    final p = pkg.toLowerCase();
    if (p.contains('game') || p.contains('supercell') || p.contains('king')) {
      return AppCategory.games;
    }
    if (p.contains('mail') || p.contains('office') || p.contains('docs')) {
      return AppCategory.productivity;
    }
    if (p.contains('news')) return AppCategory.news;
    if (p.contains('shop') || p.contains('store') || p.contains('amazon')) {
      return AppCategory.shopping;
    }
    if (p.contains('music') || p.contains('video') || p.contains('tv')) {
      return AppCategory.entertainment;
    }
    if (p.contains('chat') || p.contains('messeng') || p.contains('call')) {
      return AppCategory.communication;
    }
    return AppCategory.other;
  }

  String _prettifyPackage(String pkg) {
    final segment = pkg.split('.').last;
    if (segment.isEmpty) return pkg;
    return segment[0].toUpperCase() + segment.substring(1);
  }

  static const Map<String, (String, AppCategory)> _knownApps = {
    'com.instagram.android': ('Instagram', AppCategory.social),
    'com.zhiliaoapp.musically': ('TikTok', AppCategory.entertainment),
    'com.google.android.youtube': ('YouTube', AppCategory.entertainment),
    'com.whatsapp': ('WhatsApp', AppCategory.communication),
    'com.snapchat.android': ('Snapchat', AppCategory.social),
    'com.twitter.android': ('X', AppCategory.social),
    'com.reddit.frontpage': ('Reddit', AppCategory.social),
    'com.facebook.katana': ('Facebook', AppCategory.social),
    'com.facebook.orca': ('Messenger', AppCategory.communication),
    'com.netflix.mediaclient': ('Netflix', AppCategory.entertainment),
    'com.spotify.music': ('Spotify', AppCategory.entertainment),
    'com.supercell.clashofclans': ('Clash of Clans', AppCategory.games),
    'com.android.chrome': ('Chrome', AppCategory.utilities),
    'com.google.android.gm': ('Gmail', AppCategory.productivity),
    'com.Slack': ('Slack', AppCategory.productivity),
    'com.duolingo': ('Duolingo', AppCategory.education),
    'com.google.android.apps.maps': ('Maps', AppCategory.utilities),
    'com.google.android.apps.docs': ('Drive', AppCategory.productivity),
    'com.linkedin.android': ('LinkedIn', AppCategory.social),
    'com.pinterest': ('Pinterest', AppCategory.social),
    'com.amazon.mShop.android.shopping': ('Amazon', AppCategory.shopping),
    'com.discord': ('Discord', AppCategory.communication),
    'org.telegram.messenger': ('Telegram', AppCategory.communication),
  };
}
