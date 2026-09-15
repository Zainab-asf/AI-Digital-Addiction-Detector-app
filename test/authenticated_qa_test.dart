import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loopaware/src/config/app_theme.dart';
import 'package:loopaware/src/models/prediction.dart';
import 'package:loopaware/src/screens/main/home_shell.dart';
import 'package:loopaware/src/services/auth_service.dart';
import 'package:loopaware/src/services/demo_data.dart';
import 'package:loopaware/src/services/firestore_service.dart';
import 'package:loopaware/src/services/preferences_service.dart';
import 'package:loopaware/src/services/usage_service.dart';
import 'package:loopaware/src/state/app_state.dart';

/// Minimal stand-in for a signed-in Firebase user. Only the fields AppState
/// reads are implemented; nothing else is touched by these tests.
class _FakeUser implements User {
  @override
  final String uid = 'test-uid';
  @override
  final String? displayName = 'Test User';
  @override
  final String? email = 'test@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Auth service driven by a controller so tests can sign in and out.
class _FakeAuth extends AuthService {
  _FakeAuth() : _user = _FakeUser();

  User? _user;
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

/// Records every Firestore call so reads and writes can be asserted.
class _RecordingFirestore extends FirestoreService {
  final List<String> calls = [];
  Object? throwOnWrite;

  @override
  bool get isAvailable => true;

  @override
  Future<void> saveWellnessSnapshot({
    required String uid,
    required Prediction prediction,
    required int screenMinutes,
  }) async {
    calls.add('saveWellnessSnapshot:$uid:$screenMinutes');
    final err = throwOnWrite;
    if (err != null) throw err;
  }

  @override
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    calls.add('createUserProfile:$uid');
  }
}

/// Usage service with switchable behaviour: normal, empty, slow or throwing.
class _FakeUsage extends UsageService {
  _FakeUsage({this.mode = 'normal'});

  String mode;

  @override
  Future<UsageLoadResult> load({int days = 14, bool preferDemo = false}) async {
    switch (mode) {
      case 'empty':
        return const UsageLoadResult(days: [], isLive: false);
      case 'slow':
        await Future<void>.delayed(const Duration(seconds: 5));
        return UsageLoadResult(
          days: DemoData.generate(days: days),
          isLive: false,
        );
      case 'throw':
        throw StateError('usage source unavailable');
      default:
        return UsageLoadResult(days: DemoData.generate(days: days), isLive: true);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late _FakeAuth auth;
  late _RecordingFirestore firestore;

  Future<AppState> signedInState({String usageMode = 'normal'}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    auth = _FakeAuth();
    firestore = _RecordingFirestore();
    return AppState(
      prefs: prefs,
      auth: auth,
      firestore: firestore,
      usage: _FakeUsage(mode: usageMode),
    )..start();
  }

  Widget shell(AppState state, {ThemeData? theme}) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: const HomeShell(),
      ),
    );
  }

  tearDown(() => auth.dispose());

  const sizes = <String, Size>{
    'mobile-375': Size(375, 812),
    'desktop-1024': Size(1024, 768),
  };

  sizes.forEach((sizeName, size) {
    testWidgets('navigates all four tabs at $sizeName', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = await signedInState();
      await tester.pumpWidget(shell(state));
      await tester.pumpAndSettle();

      expect(state.isAuthenticated, isTrue);
      expect(state.dataLoaded, isTrue, reason: 'HomeShell loads on mount');
      expect(tester.takeException(), isNull, reason: 'Dashboard render');

      for (final label in ['Analytics', 'Insights', 'Settings', 'Home']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$label tab render at $sizeName',
        );
      }

      state.dispose();
    });
  });

  testWidgets('writes a Firestore snapshot after loading while signed in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState();
    await tester.pumpWidget(shell(state));
    await tester.pumpAndSettle();

    expect(
      firestore.calls.where((c) => c.startsWith('saveWellnessSnapshot')),
      isNotEmpty,
      reason: 'signed-in refresh should persist a snapshot',
    );
    state.dispose();
  });

  testWidgets('a failing Firestore write does not surface to the UI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState();
    firestore.throwOnWrite = StateError('permission-denied');
    await tester.pumpWidget(shell(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.dataLoaded, isTrue);
    state.dispose();
  });

  testWidgets('empty usage data renders the empty state, not a crash', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState(usageMode: 'empty');
    await tester.pumpWidget(shell(state));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.history, isEmpty);
    expect(find.textContaining('No data yet'), findsOneWidget);
    state.dispose();
  });

  testWidgets('shows the loading placeholder while usage is in flight', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState(usageMode: 'slow');
    await tester.pumpWidget(shell(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.loadingData, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(state.dataLoaded, isTrue);
    state.dispose();
  });

  testWidgets('a failing usage load leaves a recoverable UI', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState(usageMode: 'throw');
    await tester.pumpWidget(shell(state));
    await tester.pumpAndSettle();

    // The screen must not be stuck on the shimmer forever.
    expect(
      state.loadingData,
      isFalse,
      reason: 'a failed load must clear the loading flag',
    );
    state.dispose();
  });

  testWidgets('signing out clears session data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = await signedInState();
    await tester.pumpWidget(shell(state));
    await tester.pumpAndSettle();
    expect(state.history, isNotEmpty);

    await state.signOut();
    await tester.pumpAndSettle();

    expect(state.isAuthenticated, isFalse);
    expect(state.history, isEmpty, reason: 'history must not leak past logout');
    expect(state.prediction, isNull);
    state.dispose();
  });
}
