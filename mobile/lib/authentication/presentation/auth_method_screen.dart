import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../domain/auth_intent.dart';

/// docs/07-ui-ux-design.md §3.1 "Auth method": phone / email / Google / Apple,
/// plus legal microcopy — ToS/Privacy links are [TBD] per that doc, so this is
/// static text, not real links, until legal copy exists.
class AuthMethodScreen extends StatelessWidget {
  const AuthMethodScreen({required this.intent, super.key});

  final AuthIntent intent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                intent == AuthIntent.register
                    ? 'Create your account'
                    : 'Welcome back',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Continue with phone'),
                onPressed: () => context.push('/auth/phone', extra: intent),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continue with email'),
                onPressed: () => context.push('/auth/email', extra: intent),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Continue with Google'),
                onPressed: () => _showNotConfigured(context, 'Google'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.apple),
                label: const Text('Continue with Apple'),
                onPressed: () => _showNotConfigured(context, 'Apple'),
              ),
              const Spacer(),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The backend's oauth/google and oauth/apple endpoints are real and tested
  // (Phase 1 feature 1) — but real sign-in needs GOOGLE_CLIENT_ID/
  // APPLE_CLIENT_ID plus native SDK setup (google_sign_in /
  // sign_in_with_apple), none of which is configured yet. Surfacing a clear
  // "not yet" beats a fake success or silently hiding the button.
  void _showNotConfigured(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$provider sign-in needs a configured client ID — coming soon.',
        ),
      ),
    );
  }
}
