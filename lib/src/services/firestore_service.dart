import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_constants.dart';
import '../models/prediction.dart';
import '../models/usage_log.dart';

/// Reads and writes LoopAware user data in Cloud Firestore.
///
/// Like [AuthService], this resolves its Firebase handle defensively: when
/// Firebase never initialised, reads return null and writes become no-ops
/// rather than throwing `[core/no-app]` at construction time.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? _resolve();

  final FirebaseFirestore? _db;

  static FirebaseFirestore? _resolve() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// False when Firebase is unavailable; sync is skipped.
  bool get isAvailable => _db != null;

  CollectionReference<Map<String, dynamic>>? get _users =>
      _db?.collection(AppConstants.usersCollection);

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    final users = _users;
    if (users == null) return;
    await users.doc(uid).set({
      'name': name,
      'email': email,
      'dailyLimitMinutes': AppConstants.defaultDailyLimitMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final users = _users;
    if (users == null) return null;
    final doc = await users.doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    final users = _users;
    if (users == null) return;
    await users.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Persists a derived wellness snapshot. [dateKey] must come from the day
  /// the scores describe, never from DateTime.now() — a refresh just after
  /// midnight would otherwise file yesterday's scores under today.
  Future<void> saveWellnessSnapshot({
    required String uid,
    required Prediction prediction,
    required int screenMinutes,
    required String dateKey,
  }) async {
    final users = _users;
    if (users == null) return;
    await users
        .doc(uid)
        .collection(AppConstants.predictionsCollection)
        .doc(dateKey)
        .set({
          'wellnessScore': prediction.wellnessScore,
          'addictionScore': prediction.addiction.score,
          'focusScore': prediction.focus.score,
          'sleepImpactScore': prediction.sleepImpact.score,
          'burnoutScore': prediction.burnoutRisk.score,
          'screenMinutes': screenMinutes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Persists one complete [DailyUsage] under its own dateKey.
  ///
  /// Demo days are refused outright: a browser session must never be able to
  /// overwrite usage that was measured on a real device.
  Future<void> saveUsageDay({
    required String uid,
    required DailyUsage day,
  }) async {
    final users = _users;
    if (users == null) return;
    if (!day.isMeasured) return;
    await users
        .doc(uid)
        .collection(AppConstants.usageDaysCollection)
        .doc(day.dateKey)
        .set({...day.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Loads persisted usage days, newest first, as the durable history.
  Future<List<DailyUsage>> loadUsageDays({
    required String uid,
    int limit = 60,
  }) async {
    final users = _users;
    if (users == null) return const [];
    final snap = await users
        .doc(uid)
        .collection(AppConstants.usageDaysCollection)
        .orderBy('dateKey', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => DailyUsage.fromJson(d.data()))
        .toList(growable: false);
  }
}
