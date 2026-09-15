import 'package:flutter_test/flutter_test.dart';

import 'package:loopaware/src/models/usage_log.dart';
import 'package:loopaware/src/services/usage_event_aggregator.dart';

void main() {
  final dayStart = DateTime(2026, 3, 10);
  final endOfDay = dayStart.add(const Duration(days: 1));

  UsageEvent fg(String pkg, int hour, [int minute = 0]) => UsageEvent(
    packageName: pkg,
    type: UsageEvent.foreground,
    timestamp: dayStart.add(Duration(hours: hour, minutes: minute)),
  );

  UsageEvent bg(String pkg, int hour, [int minute = 0]) => UsageEvent(
    packageName: pkg,
    type: UsageEvent.background,
    timestamp: dayStart.add(Duration(hours: hour, minutes: minute)),
  );

  DailyUsage? run(List<UsageEvent> events, {DateTime? now}) {
    return UsageEventAggregator.aggregate(
      dayStart: dayStart,
      events: events,
      now: now ?? endOfDay,
      categoryOf: (_) => AppCategory.social,
      displayNameOf: (pkg) => pkg.split('.').last,
    );
  }

  group('measured minutes and pickups', () {
    test('a single session yields its real duration and one pickup', () {
      final day = run([fg('com.a', 9), bg('com.a', 9, 30)])!;

      expect(day.apps.single.minutes, 30);
      expect(day.apps.single.opens, 1);
      expect(day.totalMinutes, 30);
    });

    test('pickups are counted from real resume events, not inferred', () {
      final day = run([
        fg('com.a', 9), bg('com.a', 9, 10),
        fg('com.a', 10), bg('com.a', 10, 10),
        fg('com.a', 11), bg('com.a', 11, 10),
      ])!;

      expect(day.apps.single.opens, 3);
      expect(day.apps.single.minutes, 30);
      expect(day.pickups, 3);
    });

    test('opens are marked device, never estimated', () {
      final day = run([fg('com.a', 9), bg('com.a', 9, 30)])!;
      expect(day.apps.single.opensSource, UsageSource.device);
    });

    test('separate apps are tracked independently', () {
      final day = run([
        fg('com.a', 8), bg('com.a', 8, 20),
        fg('com.b', 9), bg('com.b', 9, 40),
      ])!;

      final byPkg = {for (final a in day.apps) a.packageName: a};
      expect(byPkg['com.a']!.minutes, 20);
      expect(byPkg['com.b']!.minutes, 40);
      expect(day.totalMinutes, 60);
    });
  });

  group('real hourly distribution', () {
    test('a session inside one hour lands in that bucket only', () {
      final day = run([fg('com.a', 14), bg('com.a', 14, 45)])!;

      expect(day.hourlyMinutes[14], 45);
      expect(day.hourlyMinutes.where((m) => m > 0), hasLength(1));
      expect(day.hourlySource, UsageSource.device);
      expect(day.hasMeasuredHours, isTrue);
    });

    test('a session spanning hours is split across real buckets', () {
      final day = run([fg('com.a', 9, 30), bg('com.a', 11, 15)])!;

      expect(day.hourlyMinutes[9], 30);
      expect(day.hourlyMinutes[10], 60);
      expect(day.hourlyMinutes[11], 15);
      expect(day.totalMinutes, 105);
    });

    test('hourly totals reconcile with measured minutes', () {
      final day = run([
        fg('com.a', 7, 15), bg('com.a', 8, 45),
        fg('com.b', 20), bg('com.b', 20, 30),
      ])!;

      final hourSum = day.hourlyMinutes.fold<int>(0, (a, b) => a + b);
      expect(hourSum, day.totalMinutes);
    });

    test('hourly array is always 24 slots', () {
      expect(run([fg('com.a', 0), bg('com.a', 0, 5)])!.hourlyMinutes.length, 24);
    });
  });

  group('night minutes and peak hour become measured', () {
    test('night usage is computed from real late-night events', () {
      final day = run([
        fg('com.a', 23), bg('com.a', 23, 40),
        fg('com.a', 13), bg('com.a', 13, 20),
      ])!;

      expect(day.nightMinutes, 40, reason: 'only the 23:00 session is night');
      expect(day.hasMeasuredHours, isTrue);
    });

    test('early-morning usage counts as night', () {
      final day = run([fg('com.a', 2), bg('com.a', 2, 25)])!;
      expect(day.nightMinutes, 25);
    });

    test('daytime-only usage reports zero night minutes', () {
      final day = run([fg('com.a', 12), bg('com.a', 13)])!;
      expect(day.nightMinutes, 0);
    });

    test('peak hour is the genuinely busiest hour', () {
      final day = run([
        fg('com.a', 9), bg('com.a', 9, 10),
        fg('com.a', 21), bg('com.a', 21, 50),
        fg('com.a', 15), bg('com.a', 15, 20),
      ])!;

      expect(day.peakHour, 21);
    });
  });

  group('edge cases', () {
    test('an unclosed session is bounded by now, not left open', () {
      final day = run(
        [fg('com.a', 10)],
        now: dayStart.add(const Duration(hours: 10, minutes: 20)),
      )!;

      expect(day.apps.single.minutes, 20);
      expect(day.hourlyMinutes[10], 20);
    });

    test('a resume without a pause closes the prior session', () {
      final day = run([fg('com.a', 9), fg('com.a', 9, 30), bg('com.a', 10)])!;

      expect(day.apps.single.minutes, 60);
      expect(day.apps.single.opens, 2);
    });

    test('a stray background event is ignored', () {
      expect(run([bg('com.a', 9)]), isNull);
    });

    test('no events yields null so the caller can fall back', () {
      expect(run(const []), isNull);
    });

    test('sub-minute usage rounds away and does not fabricate a day', () {
      expect(
        run([
          UsageEvent(
            packageName: 'com.a',
            type: UsageEvent.foreground,
            timestamp: dayStart.add(const Duration(hours: 9)),
          ),
          UsageEvent(
            packageName: 'com.a',
            type: UsageEvent.background,
            timestamp: dayStart.add(const Duration(hours: 9, seconds: 5)),
          ),
        ]),
        isNull,
      );
    });

    test('events are clipped to the day, not counted twice', () {
      final day = run([
        UsageEvent(
          packageName: 'com.a',
          type: UsageEvent.foreground,
          timestamp: dayStart.subtract(const Duration(hours: 1)),
        ),
        bg('com.a', 0, 30),
      ])!;

      expect(day.apps.single.minutes, 30,
          reason: 'only the portion inside the day counts');
    });

    test('out-of-order events are handled', () {
      final day = run([bg('com.a', 9, 30), fg('com.a', 9)])!;
      expect(day.apps.single.minutes, 30);
    });

    test('the produced day is fully device-sourced', () {
      final day = run([fg('com.a', 9), bg('com.a', 9, 30)])!;
      expect(day.source, UsageSource.device);
      expect(day.hourlySource, UsageSource.device);
      expect(day.isMeasured, isTrue);
      expect(day.hasMeasuredHours, isTrue);
    });
  });

  group('platform decoding', () {
    test('decodes a well-formed platform map', () {
      final e = UsageEvent.fromPlatform({
        'packageName': 'com.a',
        'type': 1,
        'timestamp': dayStart.millisecondsSinceEpoch,
      })!;

      expect(e.packageName, 'com.a');
      expect(e.isForeground, isTrue);
      expect(e.timestamp, dayStart);
    });

    test('rejects malformed entries instead of guessing', () {
      expect(UsageEvent.fromPlatform(null), isNull);
      expect(UsageEvent.fromPlatform('nonsense'), isNull);
      expect(UsageEvent.fromPlatform({'packageName': 'com.a'}), isNull);
      expect(
        UsageEvent.fromPlatform(
          {'packageName': 'com.a', 'type': 'fg', 'timestamp': 1},
        ),
        isNull,
      );
    });
  });
}
