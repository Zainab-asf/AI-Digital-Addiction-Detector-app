import '../models/usage_log.dart';
import 'firestore_service.dart';
import 'usage_service.dart';

/// Result of a history load, including where the bulk of it came from.
class UsageHistory {
  const UsageHistory({required this.days, required this.source});

  final List<DailyUsage> days;

  /// Best source present in [days]. `device` means at least one day was
  /// actually measured on this device.
  final UsageSource source;

  bool get isLive => source.isReal;
}

/// Sits between [UsageService] (what this device can see right now) and
/// [FirestoreService] (what was durably recorded before).
///
/// The device window is short — Android's usage-stats retention drops detail
/// after roughly a week — so neither source alone is the history. This merges
/// them by dateKey and enforces one rule above all others: measured data
/// always beats estimated or demo data, and demo data is never written back.
class UsageRepository {
  UsageRepository({UsageService? usage, FirestoreService? firestore})
    : _usage = usage ?? UsageService(),
      _firestore = firestore ?? FirestoreService();

  final UsageService _usage;
  final FirestoreService _firestore;

  /// Loads [days] of history for [uid], merging device and persisted data.
  ///
  /// [uid] may be null (signed out), in which case only local data is used
  /// and nothing is persisted.
  Future<UsageHistory> load({
    int days = 14,
    bool preferDemo = false,
    String? uid,
  }) async {
    final local = await _usage.load(days: days, preferDemo: preferDemo);

    final persisted = <DailyUsage>[];
    if (uid != null) {
      try {
        persisted.addAll(await _firestore.loadUsageDays(uid: uid, limit: 90));
      } catch (_) {
        // History is a best-effort enrichment; a read failure must not stop
        // the app from showing what this device can see.
      }
    }

    final merged = mergeDays(persisted: persisted, incoming: local.days);

    if (uid != null) {
      await _persist(uid: uid, days: local.days);
    }

    return UsageHistory(days: merged, source: bestSource(merged));
  }

  /// Merges two sets of days by dateKey, keeping whichever version of a day
  /// has the more trustworthy source. Days that exist only in Firestore are
  /// preserved, so history outlives the device's retention window.
  ///
  /// Exposed for testing.
  static List<DailyUsage> mergeDays({
    required List<DailyUsage> persisted,
    required List<DailyUsage> incoming,
  }) {
    final byKey = <String, DailyUsage>{};
    for (final day in persisted) {
      byKey[day.dateKey] = day;
    }
    for (final day in incoming) {
      final existing = byKey[day.dateKey];
      // Strictly greater: a tie keeps the stored copy, so a demo refresh
      // cannot displace an equally-ranked stored day.
      if (existing == null || day.source.rank > existing.source.rank) {
        byKey[day.dateKey] = day;
      }
    }
    final result = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  /// The most trustworthy source present across [days].
  static UsageSource bestSource(List<DailyUsage> days) {
    var best = UsageSource.demo;
    for (final day in days) {
      if (day.source.rank > best.rank) best = day.source;
    }
    return best;
  }

  /// Writes measured days only. [FirestoreService.saveUsageDay] refuses demo
  /// days as well, so this is belt-and-braces on the same invariant.
  Future<void> _persist({required String uid, required List<DailyUsage> days}) async {
    for (final day in days) {
      if (!day.isMeasured) continue;
      try {
        await _firestore.saveUsageDay(uid: uid, day: day);
      } catch (_) {
        // Best-effort: a failed sync must not break the refresh.
      }
    }
  }
}
