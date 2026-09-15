import '../models/usage_log.dart';

/// A single foreground/background transition reported by Android's
/// UsageStatsManager.queryEvents.
class UsageEvent {
  const UsageEvent({
    required this.packageName,
    required this.type,
    required this.timestamp,
  });

  /// ACTIVITY_RESUMED / MOVE_TO_FOREGROUND.
  static const int foreground = 1;

  /// ACTIVITY_PAUSED / MOVE_TO_BACKGROUND.
  static const int background = 2;

  final String packageName;
  final int type;
  final DateTime timestamp;

  bool get isForeground => type == foreground;
  bool get isBackground => type == background;

  static UsageEvent? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final pkg = raw['packageName'];
    final type = raw['type'];
    final ts = raw['timestamp'];
    if (pkg is! String || type is! int || ts is! int) return null;
    return UsageEvent(
      packageName: pkg,
      type: type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }
}

/// Turns raw Android usage events into a [DailyUsage].
///
/// This is where fabricated data is retired: foreground/background pairs give
/// genuinely measured per-app minutes, real pickup counts, and a real hourly
/// histogram, so `_spreadHourly` is not consulted when events are available.
///
/// Pure and platform-free so it can be tested without a device.
class UsageEventAggregator {
  const UsageEventAggregator._();

  /// Builds a measured [DailyUsage] for the calendar day starting at
  /// [dayStart]. [events] may span a wider range; anything outside the day is
  /// clipped. [now] bounds an unfinished session on the current day.
  ///
  /// Returns null when there is nothing usable, so the caller can fall back
  /// rather than publish an empty day as if it were measured.
  static DailyUsage? aggregate({
    required DateTime dayStart,
    required List<UsageEvent> events,
    required DateTime now,
    required AppCategory Function(String packageName) categoryOf,
    required String Function(String packageName) displayNameOf,
  }) {
    final dayEnd = dayStart.add(const Duration(days: 1));
    final bound = now.isBefore(dayEnd) ? now : dayEnd;
    if (!bound.isAfter(dayStart)) return null;

    final ordered = [...events]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final seconds = <String, int>{};
    final opens = <String, int>{};
    final hourlySeconds = List<int>.filled(24, 0);
    final openSince = <String, DateTime>{};

    void closeSession(String pkg, DateTime end) {
      final start = openSince.remove(pkg);
      if (start == null) return;
      final from = start.isBefore(dayStart) ? dayStart : start;
      final to = end.isAfter(bound) ? bound : end;
      if (!to.isAfter(from)) return;

      seconds[pkg] = (seconds[pkg] ?? 0) + to.difference(from).inSeconds;
      _addToHours(hourlySeconds, dayStart, from, to);
    }

    for (final event in ordered) {
      if (event.timestamp.isAfter(bound)) break;
      if (event.isForeground) {
        // A resume without a matching pause closes the previous session.
        closeSession(event.packageName, event.timestamp);
        openSince[event.packageName] = event.timestamp;
        // Only count pickups that actually fall inside the day.
        if (!event.timestamp.isBefore(dayStart)) {
          opens[event.packageName] = (opens[event.packageName] ?? 0) + 1;
        }
      } else if (event.isBackground) {
        closeSession(event.packageName, event.timestamp);
      }
    }

    // Anything still foregrounded runs to the end of the measured window.
    for (final pkg in openSince.keys.toList()) {
      closeSession(pkg, bound);
    }

    final apps = <AppUsage>[];
    for (final entry in seconds.entries) {
      final minutes = (entry.value / 60).round();
      if (minutes <= 0) continue;
      apps.add(
        AppUsage(
          packageName: entry.key,
          appName: displayNameOf(entry.key),
          category: categoryOf(entry.key),
          minutes: minutes,
          opens: opens[entry.key] ?? 0,
          // Counted from real ACTIVITY_RESUMED events.
          opensSource: UsageSource.device,
        ),
      );
    }

    if (apps.isEmpty) return null;

    return DailyUsage(
      date: dayStart,
      apps: apps,
      hourlyMinutes:
          hourlySeconds.map((s) => (s / 60).round()).toList(growable: false),
      source: UsageSource.device,
      // Built from real foreground intervals, not an assumed curve.
      hourlySource: UsageSource.device,
    );
  }

  /// Splits [from, to) across the hour buckets of the day at [dayStart].
  static void _addToHours(
    List<int> hourlySeconds,
    DateTime dayStart,
    DateTime from,
    DateTime to,
  ) {
    for (var hour = 0; hour < 24; hour++) {
      final hourStart = dayStart.add(Duration(hours: hour));
      final hourEnd = hourStart.add(const Duration(hours: 1));
      final overlapStart = from.isAfter(hourStart) ? from : hourStart;
      final overlapEnd = to.isBefore(hourEnd) ? to : hourEnd;
      if (overlapEnd.isAfter(overlapStart)) {
        hourlySeconds[hour] +=
            overlapEnd.difference(overlapStart).inSeconds;
      }
    }
  }
}
