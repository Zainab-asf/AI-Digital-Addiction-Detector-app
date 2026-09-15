import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when an auth action is attempted but Firebase never initialised.
class AuthUnavailableException implements Exception {
  const AuthUnavailableException();

  @override
  String toString() => 'AuthUnavailableException';
}

/// Thin wrapper around [FirebaseAuth] with friendly error messages.
///
/// Firebase may fail to initialise (missing config, offline first run, an
/// unsupported platform). Resolving [FirebaseAuth.instance] would then throw
/// `[core/no-app]`, so the instance is resolved defensively and the service
/// degrades to a signed-out state instead of taking the whole app down.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? _resolve();

  final FirebaseAuth? _auth;

  static FirebaseAuth? _resolve() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// False when Firebase is unavailable; sign-in cannot succeed.
  bool get isAvailable => _auth != null;

  User? get currentUser => _auth?.currentUser;

  Stream<User?> authStateChanges() =>
      _auth?.authStateChanges() ?? Stream<User?>.value(null);

  /// Every action below is `async` so that an unavailable-Firebase failure
  /// arrives as a rejected future rather than a synchronous throw.
  FirebaseAuth get _require {
    final auth = _auth;
    if (auth == null) throw const AuthUnavailableException();
    return auth;
  }

  Future<UserCredential> signIn(String email, String password) async {
    return _require.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _require.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    await credential.user?.reload();
    return credential;
  }

  Future<void> sendPasswordReset(String email) async {
    return _require.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async => _auth?.signOut();

  /// Converts an arbitrary auth error into a user-readable message.
  static String describeError(Object error) {
    if (error is AuthUnavailableException) {
      return 'Sign-in is unavailable — the app could not connect to its '
          'account service. Check your connection and restart the app.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'That password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
