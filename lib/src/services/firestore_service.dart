import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_constants.dart';
import '../models/prediction.dart';

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

  /// Persists a daily wellness snapshot so progress survives reinstalls.
  Future<void> saveWellnessSnapshot({
    required String uid,
    required Prediction prediction,
    required int screenMinutes,
  }) async {
    final users = _users;
    if (users == null) return;
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
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
}
