import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_constants.dart';
import '../../config/app_theme.dart';
import '../../config/routes.dart';
import '../../state/app_state.dart';
import '../../utils/app_snackbar.dart';

class _OnboardSlide {
  const _OnboardSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const List<_OnboardSlide> _slides = [
    _OnboardSlide(
      icon: Icons.all_inclusive_rounded,
      title: 'Welcome to LoopAware',
      body:
          'A calm coach for your digital habits. We turn your screen-time '
          'into clear, kind insights — no guilt, no judgement.',
    ),
    _OnboardSlide(
      icon: Icons.insights_rounded,
      title: 'Spot the loops you cannot see',
      body:
          'LoopAware detects compulsive checking, late-night scrolling, and '
          'focus-killing patterns the moment they start to form.',
    ),
    _OnboardSlide(
      icon: Icons.shield_moon_rounded,
      title: 'Stays on your phone',
      body:
          'Scoring runs on-device. Your usage data never leaves your phone '
          'unless you choose to back up your wellness summary.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.login);
  }

  Future<void> _requestUsageAccess() async {
    final state = context.read<AppState>();
    final opened = await state.usageService.openUsageAccessSettings();
    if (!mounted) return;
    if (!opened) {
      await state.setUseDemoData(true);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Usage access isn\'t available on this platform — demo data is on.',
      );
    } else {
      showAppSnackBar(
        context,
        'Toggle LoopAware on in the list, then come back to the app.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _slides.length - 1;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.calmGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.all_inclusive_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.18),
                                AppTheme.secondary.withValues(alpha: 0.18),
                              ],
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            color: AppTheme.primary,
                            size: 76,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  if (isLast && isAndroid)
                    OutlinedButton.icon(
                      onPressed: _requestUsageAccess,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Allow usage access'),
                    ),
                  if (isLast && isAndroid) const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
