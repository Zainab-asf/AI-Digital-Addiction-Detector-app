import 'dart:math';

import '../models/usage_log.dart';

/// One entry in the demo app catalog.
class _DemoApp {
  const _DemoApp(
    this.packageName,
    this.name,
    this.category,
    this.appeal,
    this.sessionMinutes,
  );

  final String packageName;
  final String name;
  final AppCategory category;

  /// Relative pull — how much daily time tends to flow to this app.
  final double appeal;

  /// Typical length of one session, drives the pickup count.
  final double sessionMinutes;
}

/// Generates realistic seeded screen-time data so LoopAware is fully
/// functional on emulators, desktop, or when usage permission is denied.
class DemoData {
  DemoData._();

  static const List<_DemoApp> _catalog = [
    _DemoApp('com.instagram.android', 'Instagram', AppCategory.social, 5.0, 3),
    _DemoApp(
      'com.zhiliaoapp.musically',
      'TikTok',
      AppCategory.entertainment,
      5.5,
      9,
    ),
    _DemoApp(
      'com.google.android.youtube',
      'YouTube',
      AppCategory.entertainment,
      4.0,
      13,
    ),
    _DemoApp('com.whatsapp', 'WhatsApp', AppCategory.communication, 3.5, 2),
    _DemoApp('com.snapchat.android', 'Snapchat', AppCategory.social, 3.0, 3),
    _DemoApp('com.twitter.android', 'X', AppCategory.social, 2.8, 4),
    _DemoApp('com.reddit.frontpage', 'Reddit', AppCategory.social, 2.5, 7),
    _DemoApp('com.facebook.katana', 'Facebook', AppCategory.social, 2.0, 5),
    _DemoApp(
      'com.netflix.mediaclient',
      'Netflix',
      AppCategory.entertainment,
      2.2,
      28,
    ),
    _DemoApp(
      'com.spotify.music',
      'Spotify',
      AppCategory.entertainment,
      1.8,
      18,
    ),
    _DemoApp(
      'com.supercell.clashofclans',
      'Clash of Clans',
      AppCategory.games,
      2.0,
      12,
    ),
    _DemoApp('com.android.chrome', 'Chrome', AppCategory.utilities, 2.0, 5),
    _DemoApp('com.google.android.gm', 'Gmail', AppCategory.productivity, 1.4, 4),
    _DemoApp('com.Slack', 'Slack', AppCategory.productivity, 1.2, 6),
    _DemoApp('com.duolingo', 'Duolingo', AppCategory.education, 1.0, 9),
    _DemoApp(
      'com.google.android.apps.maps',
      'Maps',
      AppCategory.utilities,
      0.8,
      6,
    ),
  ];

  /// Relative likelihood of phone activity for each hour of the day.
  static const List<double> _hourProfile = [
    0.6, 0.3, 0.2, 0.15, 0.15, 0.3, // 0-5
    0.9, 2.0, 3.0, 2.4, 1.9, 1.9, // 6-11
    2.8, 2.6, 2.2, 1.9, 2.0, 2.6, // 12-17
    3.2, 4.2, 4.6, 4.0, 2.6, 1.4, // 18-23
  ];

  /// Returns [days] of usage ending today, ordered oldest -> newest.
  static List<DailyUsage> generate({int days = 14}) {
    final today = DateTime.now();
    final result = <DailyUsage>[];
    for (var offset = days - 1; offset >= 0; offset--) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: offset));
      result.add(_buildDay(date, offset));
    }
    return result;
  }

  static DailyUsage _buildDay(DateTime date, int offset) {
    // Deterministic per calendar day so charts stay stable across rebuilds.
    final rng = Random(date.year * 10000 + date.month * 100 + date.day);
    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;

    // Total daily screen time target (minutes).
    var total = 215 + rng.nextInt(150);
    if (isWeekend) total += 60 + rng.nextInt(70);
    // A couple of mindful days to give the trend some movement.
    if (offset == 2 || offset == 9) total = (total * 0.62).round();

    // Pick the apps active today.
    final active = [..._catalog]..shuffle(rng);
    final appCount = 8 + rng.nextInt(4);
    final chosen = active.take(appCount).toList();

    final weights = chosen
        .map((a) => a.appeal * (0.6 + rng.nextDouble() * 0.9))
        .toList();
    final minutesPerApp = _distribute(total, weights, rng);

    final apps = <AppUsage>[];
    for (var i = 0; i < chosen.length; i++) {
      final app = chosen[i];
      final minutes = minutesPerApp[i];
      if (minutes <= 0) continue;
      final raw = minutes / app.sessionMinutes;
      final opens = max(1, raw.round() + rng.nextInt(3) - 1);
      apps.add(
        AppUsage(
          packageName: app.packageName,
          appName: app.name,
          category: app.category,
          minutes: minutes,
          opens: opens,
        ),
      );
    }

    final realTotal = apps.fold(0, (sum, a) => sum + a.minutes);
    final hourWeights = List<double>.generate(
      24,
      (h) => _hourProfile[h] * (0.7 + rng.nextDouble() * 0.6),
    );
    final hourly = _distribute(realTotal, hourWeights, rng);

    return DailyUsage(date: date, apps: apps, hourlyMinutes: hourly);
  }

  /// Splits [total] across buckets weighted by [weights] while preserving
  /// the exact sum (largest-remainder method).
  static List<int> _distribute(int total, List<double> weights, Random rng) {
    final sumW = weights.fold(0.0, (a, b) => a + b);
    if (sumW <= 0) return List<int>.filled(weights.length, 0);

    final raw = weights.map((w) => total * w / sumW).toList();
    final result = raw.map((r) => r.floor()).toList();
    var remainder = total - result.fold(0, (a, b) => a + b);

    final order = List<int>.generate(weights.length, (i) => i)
      ..sort((a, b) =>
          (raw[b] - result[b]).compareTo(raw[a] - result[a]));
    for (var i = 0; i < remainder && i < order.length; i++) {
      result[order[i]]++;
    }
    return result;
  }
}
