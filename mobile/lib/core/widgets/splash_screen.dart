import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/data/onboarding_gate.dart';
import '../../onboarding/domain/onboarding_step.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';

/// docs/07-ui-ux-design.md §3.1 "Splash": "Logo centred; decides authed vs
/// not; <= 1.5s then routes." [AuthController] resolves the token
/// synchronously from secure storage (fast); an authenticated session then
/// waits on [OnboardingGate] (a couple of API round-trips) before routing —
/// the "offline" state mentioned in the doc isn't specially handled: a
/// failed resolve just falls back to re-authenticating rather than hanging.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status != AuthStatus.unknown) _resolveAndGo(context, ref, next);
    });

    // authControllerProvider may have already resolved before this widget
    // subscribed (e.g. returning to '/' right after a successful sign-in) —
    // ref.listen only fires on a change *after* it's registered, so handle
    // the already-resolved case too.
    final current = ref.read(authControllerProvider);
    if (current.status != AuthStatus.unknown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _resolveAndGo(context, ref, current);
      });
    }

    // The logo in white, centred on the brand red (the logo's own red),
    // full-bleed. Exactly what the native launch screen shows (same colour,
    // same 170 dp logo), so the hand-off from it to this screen is invisible.
    // Always red, in light and dark mode alike: it is the brand's moment, not
    // a themed page.
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: AppLogo(width: 170, white: true)),
      ),
    );
  }

  Future<void> _resolveAndGo(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
  ) async {
    if (authState.status == AuthStatus.unauthenticated) {
      context.go('/welcome');
      return;
    }

    var path = '/welcome';
    try {
      final step = await ref.read(onboardingGateProvider).resolveNextStep();
      path = _pathForStep(step);
    } catch (_) {
      // A network hiccup or an invalid/expired token — fail safe to
      // re-authenticating rather than getting stuck on the splash screen.
      await ref.read(authControllerProvider.notifier).signedOut();
    }

    if (context.mounted) context.go(path);
  }

  String _pathForStep(OnboardingStep step) => switch (step) {
    OnboardingStep.basics => '/onboarding/basics',
    OnboardingStep.photos => '/onboarding/photos',
    OnboardingStep.prompts => '/onboarding/prompts',
    OnboardingStep.preferences => '/onboarding/preferences',
    OnboardingStep.location => '/onboarding/location',
    OnboardingStep.notifications => '/onboarding/notifications',
    OnboardingStep.complete => '/home',
  };
}
