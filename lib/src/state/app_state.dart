import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/prediction.dart';
import '../models/usage_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/preferences_service.dart';
import '../services/scoring_engine.dart';
import '../services/usage_service.dart';

/// Central app store: auth session, screen-time data, derived scores and
/// user settings. Exposed to the widget tree via [Provider].
class AppState extends ChangeNotifier {
  AppState({
    required PreferencesService prefs,
    AuthService? auth,
    FirestoreService? firestore,
    UsageService? usage,
  })  : _prefs = prefs,
        _auth = auth ?? AuthService(),
        _firestore = firestore ?? FirestoreService(),
        _usage = usage ?? UsageService() {
    _themeMode = prefs.themeMode;
    _dailyLimit = prefs.dailyLimitMinutes;
    _notifications = prefs.notificationsEnabled;
    _useDemoData = prefs.useDemoData;
  }

  final PreferencesService _prefs;
  final AuthService _auth;
  final FirestoreService _firestore;
  final UsageService _usage;

  StreamSubscription<User?>? _authSub;

  // Settings
  late ThemeMode _themeMode;
  late int _dailyLimit;
  late bool _notifications;
  late bool _useDemoData;

  // Session
  User? _user;

  // Data
  List<DailyUsage> _history = const [];
  Prediction? _prediction;
  bool _loadingData = false;
  bool _dataLoaded = false;
  bool _isLiveData = false;

  /// Begins listening to Firebase auth state. Call once after startup.
  void start() {
    _user = _auth.currentUser;
    _authSub = _auth.authStateChanges().listen((user) {
      final wasSignedIn = _user != null;
      _user = user;
      if (wasSignedIn && user == null) {
        _history = const [];
        _prediction = null;
        _dataLoaded = false;
      }
      notifyListeners();
    });
  }

  // --- Settings getters ---
  ThemeMode get themeMode => _themeMode;
  int get dailyLimitMinutes => _dailyLimit;
  bool get notificationsEnabled => _notifications;
  bool get useDemoData => _useDemoData;
  bool get onboardingDone => _prefs.onboardingDone;

  // --- Session getters ---
  bool get isAuthenticated => _user != null;
  String get displayName {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = _user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  String get firstName => displayName.split(' ').first;
  String get email => _user?.email ?? '';

  // --- Data getters ---
  List<DailyUsage> get history => _history;
  bool get loadingData => _loadingData;
  bool get dataLoaded => _dataLoaded;
  bool get isLiveData => _isLiveData;
  Prediction? get prediction => _prediction;
  UsageService get usageService => _usage;

  DailyUsage? get todayUsage => _history.isEmpty ? null : _history.last;

  List<DailyUsage> get last7Days {
    if (_history.length <= 7) return _history;
    return _history.sublist(_history.length - 7);
  }

  /// Loads screen-time data and recomputes all scores.
  Future<void> refreshUsage() async {
    _loadingData = true;
    notifyListeners();

    final result = await _usage.load(days: 14, preferDemo: _useDemoData);
    _history = result.days;
    _isLiveData = result.isLive;
    _prediction =
        ScoringEngine.evaluate(_history, dailyLimitMinutes: _dailyLimit);
    _dataLoaded = true;
    _loadingData = false;
    notifyListeners();

    unawaited(_saveSnapshot());
  }

  Future<void> _saveSnapshot() async {
    final user = _user;
    final prediction = _prediction;
    final today = todayUsage;
    if (user == null || prediction == null || today == null) return;
    try {
      await _firestore.saveWellnessSnapshot(
        uid: user.uid,
        prediction: prediction,
        screenMinutes: today.totalMinutes,
      );
    } catch (_) {
      // Snapshot sync is best-effort; ignore network failures.
    }
  }

  // --- Auth actions (return null on success, else an error message) ---
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signIn(email, password);
      return null;
    } catch (error) {
      return AuthService.describeError(error);
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.register(
        name: name,
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        try {
          await _firestore.createUserProfile(
            uid: user.uid,
            name: name,
            email: email,
          );
        } catch (_) {
          // Profile creation is best-effort.
        }
      }
      return null;
    } catch (error) {
      return AuthService.describeError(error);
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordReset(email);
      return null;
    } catch (error) {
      return AuthService.describeError(error);
    }
  }

  Future<void> signOut() => _auth.signOut();

  // --- Settings actions ---
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setThemeMode(mode);
  }

  Future<void> setDailyLimit(int minutes) async {
    _dailyLimit = minutes;
    if (_history.isNotEmpty) {
      _prediction =
          ScoringEngine.evaluate(_history, dailyLimitMinutes: _dailyLimit);
    }
    notifyListeners();
    await _prefs.setDailyLimitMinutes(minutes);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notifications = value;
    notifyListeners();
    await _prefs.setNotificationsEnabled(value);
  }

  Future<void> setUseDemoData(bool value) async {
    _useDemoData = value;
    await _prefs.setUseDemoData(value);
    await refreshUsage();
  }

  Future<void> completeOnboarding() async {
    await _prefs.setOnboardingDone(true);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
