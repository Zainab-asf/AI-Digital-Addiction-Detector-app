import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'src/config/app_constants.dart';
import 'src/config/app_theme.dart';
import 'src/config/routes.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/auth/reset_password_screen.dart';
import 'src/screens/auth/signup_screen.dart';
import 'src/screens/main/home_shell.dart';
import 'src/screens/onboarding/onboarding_screen.dart';
import 'src/screens/splash/splash_screen.dart';
import 'src/services/preferences_service.dart';
import 'src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stack) {
    // Firebase isn't configured for this platform — auth screens will surface
    // friendly errors, but the rest of the app still runs in demo mode.
    debugPrint('Firebase init failed: $error\n$stack');
  }

  final prefs = await PreferencesService.create();
  final appState = AppState(prefs: prefs)..start();

  runApp(LoopAwareApp(appState: appState));
}

class LoopAwareApp extends StatelessWidget {
  const LoopAwareApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            initialRoute: Routes.splash,
            routes: {
              Routes.splash: (_) => const SplashScreen(),
              Routes.onboarding: (_) => const OnboardingScreen(),
              Routes.login: (_) => const LoginScreen(),
              Routes.signup: (_) => const SignupScreen(),
              Routes.resetPassword: (_) => const ResetPasswordScreen(),
              Routes.home: (_) => const HomeShell(),
            },
          );
        },
      ),
    );
  }
}
