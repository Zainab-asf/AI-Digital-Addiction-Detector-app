import 'package:flutter_test/flutter_test.dart';

import 'package:loopaware/src/config/app_constants.dart';
import 'package:loopaware/src/models/usage_log.dart';
import 'package:loopaware/src/services/firestore_service.dart';
import 'package:loopaware/src/services/usage_repository.dart';
import 'package:loopaware/src/services/usage_service.dart';

DailyUsage day(
  DateTime date, {
  required UsageSource source,
  UsageSource hourlySource = UsageSource.estimated,
  int minutes = 60,
}) {
  return DailyUsage(
    date: date,
    apps: [
      AppUsage(
        packageName: 'com.example.app',
        appName: 'Example',
        category: AppCategory.social,
        minutes: minutes,
        opens: 10,
        opensSource: source == UsageSource.device
            ? UsageSource.estimated
            : UsageSource.demo,
      ),
    ],
    hourlyMinutes: List<int>.filled(24, minutes ~/ 24),
    source: source,
    hourlySource: hourlySource,
  );
}

/// Firestore double that records writes and serves a canned history.
class _FakeFirestore extends FirestoreService {
  _FakeFirestore({List<DailyUsage>? stored}) : stored = stored ?? [];

  List<DailyUsage> stored;
  final List<String> written = [];

  @override
  bool get isAvailable => true;

  @override
  Future<List<DailyUsage>> loadUsageDays({
    required String uid,
    int limit = 60,
  }) async => stored;

  @override
  Future<void> saveUsageDay({
    required String uid,
    required DailyUsage day,
  }) async {
    // Mirrors the real guard: demo days are never persisted.
    if (!day.isMeasured) return;
    written.add(day.dateKey);
  }
}

class _FakeUsage extends UsageService {
  _FakeUsage(this.days);
  final List<DailyUsage> days;

  @override
  Future<UsageLoadResult> load({int days = 14, bool preferDemo = false}) async =>
      UsageLoadResult(days: this.days, isLive: false);
}

void main() {
  final d1 = DateTime(2026, 3, 1);
  final d2 = DateTime(2026, 3, 2);
  final d3 = DateTime(2026, 3, 3);

  group('DailyUsage serialization', () {
    test('round-trips through JSON preserving provenance', () {
      final original = day(
        d1,
        source: UsageSource.device,
        hourlySource: UsageSource.estimated,
        minutes: 143,
      );

      final restored = DailyUsage.fromJson(original.toJson());

      expect(restored.dateKey, original.dateKey);
      expect(restored.date, original.date);
      expect(restored.totalMinutes, 143);
      expect(restored.source, UsageSource.device);
      expect(restored.hourlySource, UsageSource.estimated);
      expect(restored.isMeasured, isTrue);
      expect(restored.hasMeasuredHours, isFalse);
      expect(restored.apps.single.opensSource, UsageSource.estimated);
      expect(restored.hourlyMinutes.length, 24);
    });

    test('demo provenance survives the round trip', () {
      final restored = DailyUsage.fromJson(
        day(d1, source: UsageSource.demo, hourlySource: UsageSource.demo)
            .toJson(),
      );
      expect(restored.source, UsageSource.demo);
      expect(restored.isMeasured, isFalse);
    });

    test('unknown or missing source degrades to demo, never to device', () {
      final restored = DailyUsage.fromJson({
        'date': d1.toIso8601String(),
        'apps': const [],
        'hourlyMinutes': const [],
      });
      expect(restored.source, UsageSource.demo);
      expect(restored.isMeasured, isFalse);
    });
  });

  group('dateKey generation', () {
    test('comes from the day itself and zero-pads', () {
      expect(day(DateTime(2026, 3, 7), source: UsageSource.demo).dateKey,
          '2026-03-07');
      expect(day(DateTime(2026, 12, 25), source: UsageSource.demo).dateKey,
          '2026-12-25');
    });

    test('is unaffected by the time of day the object was built', () {
      final justBeforeMidnight = DailyUsage(
        date: DateTime(2026, 3, 7, 23, 59, 59),
        apps: const [],
        hourlyMinutes: List<int>.filled(24, 0),
      );
      expect(justBeforeMidnight.dateKey, '2026-03-07');
    });

    test('serialized payload carries the key for ordering', () {
      expect(day(d2, source: UsageSource.device).toJson()['dateKey'],
          '2026-03-02');
    });
  });

  group('merge precedence', () {
    test('device data wins over a stored demo day', () {
      final merged = UsageRepository.mergeDays(
        persisted: [day(d1, source: UsageSource.demo, minutes: 10)],
        incoming: [day(d1, source: UsageSource.device, minutes: 200)],
      );
      expect(merged, hasLength(1));
      expect(merged.single.source, UsageSource.device);
      expect(merged.single.totalMinutes, 200);
    });

    test('demo data does NOT displace a stored device day', () {
      final merged = UsageRepository.mergeDays(
        persisted: [day(d1, source: UsageSource.device, minutes: 200)],
        incoming: [day(d1, source: UsageSource.demo, minutes: 10)],
      );
      expect(merged.single.source, UsageSource.device);
      expect(merged.single.totalMinutes, 200,
          reason: 'measured minutes must survive a browser refresh');
    });

    test('equal sources keep the stored copy', () {
      final merged = UsageRepository.mergeDays(
        persisted: [day(d1, source: UsageSource.device, minutes: 200)],
        incoming: [day(d1, source: UsageSource.device, minutes: 5)],
      );
      expect(merged.single.totalMinutes, 200);
    });

    test('older Firestore days are preserved when the device forgets them', () {
      final merged = UsageRepository.mergeDays(
        persisted: [
          day(d1, source: UsageSource.device),
          day(d2, source: UsageSource.device),
        ],
        incoming: [day(d3, source: UsageSource.device)],
      );
      expect(merged.map((d) => d.dateKey),
          ['2026-03-01', '2026-03-02', '2026-03-03']);
    });

    test('result is ordered oldest to newest', () {
      final merged = UsageRepository.mergeDays(
        persisted: [day(d3, source: UsageSource.demo)],
        incoming: [day(d1, source: UsageSource.demo)],
      );
      expect(merged.first.dateKey, '2026-03-01');
      expect(merged.last.dateKey, '2026-03-03');
    });

    test('bestSource reports the strongest source present', () {
      expect(
        UsageRepository.bestSource([
          day(d1, source: UsageSource.demo),
          day(d2, source: UsageSource.device),
        ]),
        UsageSource.device,
      );
      expect(
        UsageRepository.bestSource([day(d1, source: UsageSource.demo)]),
        UsageSource.demo,
      );
      expect(UsageRepository.bestSource(const []), UsageSource.demo);
    });
  });

  group('Firestore path generation', () {
    test('usageDays sits under the owning user', () {
      final d = day(d2, source: UsageSource.device);
      final path =
          '${AppConstants.usersCollection}/uid-123/'
          '${AppConstants.usageDaysCollection}/${d.dateKey}';
      expect(path, 'users/uid-123/usageDays/2026-03-02');
    });

    test('predictions remains a separate derived cache', () {
      final path =
          '${AppConstants.usersCollection}/uid-123/'
          '${AppConstants.predictionsCollection}/2026-03-02';
      expect(path, 'users/uid-123/predictions/2026-03-02');
    });
  });

  group('repository persistence guards', () {
    test('a demo refresh writes nothing to Firestore', () async {
      final fs = _FakeFirestore();
      final repo = UsageRepository(
        usage: _FakeUsage([day(d1, source: UsageSource.demo)]),
        firestore: fs,
      );

      final history = await repo.load(uid: 'uid-123');

      expect(fs.written, isEmpty,
          reason: 'demo data must never reach Firestore');
      expect(history.isLive, isFalse);
    });

    test('measured days are written', () async {
      final fs = _FakeFirestore();
      final repo = UsageRepository(
        usage: _FakeUsage([
          day(d1, source: UsageSource.device),
          day(d2, source: UsageSource.device),
        ]),
        firestore: fs,
      );

      final history = await repo.load(uid: 'uid-123');

      expect(fs.written, ['2026-03-01', '2026-03-02']);
      expect(history.isLive, isTrue);
    });

    test('a demo refresh cannot overwrite stored device data end to end',
        () async {
      final fs = _FakeFirestore(
        stored: [day(d1, source: UsageSource.device, minutes: 300)],
      );
      final repo = UsageRepository(
        usage: _FakeUsage([day(d1, source: UsageSource.demo, minutes: 5)]),
        firestore: fs,
      );

      final history = await repo.load(uid: 'uid-123');

      expect(fs.written, isEmpty);
      expect(history.days.single.source, UsageSource.device);
      expect(history.days.single.totalMinutes, 300);
      expect(history.isLive, isTrue);
    });

    test('signed out, nothing is persisted and local data still loads',
        () async {
      final fs = _FakeFirestore();
      final repo = UsageRepository(
        usage: _FakeUsage([day(d1, source: UsageSource.device)]),
        firestore: fs,
      );

      final history = await repo.load(uid: null);

      expect(fs.written, isEmpty);
      expect(history.days, hasLength(1));
    });

    test('a Firestore read failure still yields local data', () async {
      final repo = UsageRepository(
        usage: _FakeUsage([day(d1, source: UsageSource.device)]),
        firestore: _ThrowingFirestore(),
      );

      final history = await repo.load(uid: 'uid-123');

      expect(history.days, hasLength(1));
      expect(history.isLive, isTrue);
    });
  });
}

class _ThrowingFirestore extends FirestoreService {
  @override
  bool get isAvailable => true;

  @override
  Future<List<DailyUsage>> loadUsageDays({
    required String uid,
    int limit = 60,
  }) async => throw StateError('offline');

  @override
  Future<void> saveUsageDay({
    required String uid,
    required DailyUsage day,
  }) async {}
}
