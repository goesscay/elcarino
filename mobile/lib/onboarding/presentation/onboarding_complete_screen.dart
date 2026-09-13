import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// docs/07-ui-ux-design.md §3.1 "Onboarding complete": "Confirmation; CTA
/// into Discover." Discover (Phase 1 item 5) doesn't exist yet, so the CTA
/// routes to the Phase 0 placeholder home instead — an honest stand-in, not a
/// faked Discover screen.
class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 72,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "You're all set!",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Your profile is ready.', textAlign: TextAlign.center),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Continue'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
