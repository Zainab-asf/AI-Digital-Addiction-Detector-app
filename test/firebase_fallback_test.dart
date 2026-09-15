import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loopaware/src/services/auth_service.dart';
import 'package:loopaware/src/services/firestore_service.dart';
import 'package:loopaware/src/services/preferences_service.dart';
import 'package:loopaware/src/state/app_state.dart';

/// Firebase is never initialised in these tests, which reproduces the
/// real-world case where `Firebase.initializeApp` fails at startup. Nothing
/// here may throw `[core/no-app]`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AuthService degrades to a signed-out state', () {
    final auth = AuthService();
    expect(auth.isAvailable, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.authStateChanges(), emits(isNull));
  });

  test('AuthService surfaces a friendly error instead of crashing', () async {
    final auth = AuthService();
    await expectLater(
      auth.signIn('a@b.com', 'password'),
      throwsA(isA<AuthUnavailableException>()),
    );
    expect(
      AuthService.describeError(const AuthUnavailableException()),
      contains('unavailable'),
    );
  });

  test('FirestoreService writes become no-ops', () async {
    final firestore = FirestoreService();
    expect(firestore.isAvailable, isFalse);
    await expectLater(firestore.getUserProfile('uid'), completion(isNull));
    await expectLater(
      firestore.createUserProfile(uid: 'uid', name: 'A', email: 'a@b.com'),
      completes,
    );
  });

  test('AppState starts and loads demo data without Firebase', () async {
    final prefs = await PreferencesService.create();
    final state = AppState(prefs: prefs)..start();

    expect(state.isAuthenticated, isFalse);
    expect(state.displayName, 'there');

    await state.refreshUsage();
    expect(state.dataLoaded, isTrue);
    expect(state.history, isNotEmpty);
    expect(state.prediction, isNotNull);
    expect(state.isLiveData, isFalse);

    await state.setThemeMode(ThemeMode.dark);
    expect(state.themeMode, ThemeMode.dark);

    state.dispose();
  });
}
