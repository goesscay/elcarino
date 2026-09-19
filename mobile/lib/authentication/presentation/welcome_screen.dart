import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_logo.dart';
import '../domain/auth_intent.dart';

/// docs/07-ui-ux-design.md §3.1 "Welcome": full-bleed brand imagery placeholder
/// (hi-fi visual design is a separate, still-outstanding track — see
/// docs/04-development-phases.md Phase 0 gate); value prop line; the two
/// buttons here are what disambiguate the email path's register-vs-login call
/// downstream (see `AuthIntent`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(width: 220),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Meaningful connections, safely.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: context.palette.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 4),
              FilledButton(
                onPressed: () =>
                    context.push('/auth/method', extra: AuthIntent.register),
                child: const Text('Create account'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () =>
                    context.push('/auth/method', extra: AuthIntent.signIn),
                child: const Text('Sign in'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
